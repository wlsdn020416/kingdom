extends Node
## 게임 씬을 실제로 돌려서 핵심 흐름이 깨지지 않았는지 확인한다.
## 실행: godot --headless --path . res://tests/smoke_test.tscn
## 코드를 고친 뒤 이걸 돌려서 전부 OK면 기본 흐름은 살아 있다는 뜻이다.

var _failures := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Session.seed_text = "smoke-test"
	var main: Main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(5)

	_check(main.world.data.is_explored(main.world.data.core_cell), "시작 지점 주변이 지도에 탐험됨")

	var wall_cell := main.kingdom.core_cell() + Vector2i(3, 0)
	var error := main.kingdom.build(wall_cell, "wood_wall", main.player.global_position)
	_check(error == "" and main.kingdom.buildings.has(wall_cell), "나무벽 건설 %s" % error)
	_check(main.kingdom.build(main.kingdom.core_cell() + Vector2i(30, 0), "wood_wall", main.player.global_position) != "", "영토 밖 건설은 거부됨")

	var dash_event := InputEventAction.new()
	dash_event.action = "dash"
	dash_event.pressed = true
	Input.parse_input_event(dash_event)
	await _frames(2)
	_check(main.player.dash_cooldown_left() > 0.0, "Space 대시는 장비 없이 사용 가능, 사용 후 쿨타임")
	main.player.equipment.add_to_bag("life_charm")
	main.player.equipment.equip("life_charm")
	main.player.use_skill(0)
	_check(not main.player.equipment.is_ready("life_charm"), "장착한 치유 부적이 스킬바 1번, 사용 후 쿨타임")

	var bag_before := main.player.equipment.bag.size()
	var resources_before := _total_resources(main)
	Events.chest_opened.emit(main.player.global_position)
	_check(main.player.equipment.bag.size() > bag_before or _total_resources(main) > resources_before, "상자 보상 지급")

	await _check_harvest(main)
	await _check_melee(main)
	await _check_build_menu(main)
	await _check_storage(main)
	await _check_workbench(main)
	await _check_inventory(main)

	main.day_night.skip_to_night()
	Engine.time_scale = 3.0
	await get_tree().create_timer(8.0 * 3.0).timeout
	_check(main.day_night.is_night(), "밤으로 전환")
	_check(main.spawner.invader_count() > 0, "침공 적 등장 (%d마리)" % main.spawner.invader_count())
	await get_tree().create_timer(14.0 * 3.0).timeout
	Engine.time_scale = 1.0
	_check(main.kingdom.core.hp < main.kingdom.core.max_hp or main.kills > 0 or main.kingdom.buildings.size() < 1,
		"침공 적이 왕국에 도달 (핵 %d, 처치 %d)" % [main.kingdom.core.hp, main.kills])

	main.kingdom.core.take_damage(999999.0)
	await _frames(3)
	_check(get_tree().paused and main.hud.game_over_panel.visible, "왕국 멸망 → 일시정지 + 멸망 화면")

	print("SMOKE TEST %s (실패 %d)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(1 if _failures > 0 else 0)


## 왼쪽 두 칸이 비어 있는 나무 (왼쪽에서 오른쪽으로 공격하기 위해)
func _find_tree(world: World) -> Vector2i:
	for radius in range(Balance.TERRITORY_RADIUS + 1, 60):
		for x in range(-radius, radius + 1):
			var cell := world.data.core_cell + Vector2i(x, radius)
			if world.data.get_object(cell) == WorldData.Obj.TREE and world.data.is_walkable(cell + Vector2i.LEFT) and world.data.is_walkable(cell + Vector2i(-2, 0)):
				return cell
	return World.NO_CELL


## 나무 옆에서 투사체를 쏴서 채집이 되는지 확인
func _check_harvest(main: Main) -> void:
	var world := main.world
	var tree_cell := _find_tree(world)
	if tree_cell == World.NO_CELL:
		_check(false, "채집 테스트용 나무를 찾지 못함")
		return
	# 돌아다니는 적이 탄을 막지 않게 잠시 치운다
	main.spawner.set_physics_process(false)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	await _frames(2)
	var wood_before := _wood(main)
	for shot in 5:
		Projectile.spawn(get_tree(), world.cell_center(tree_cell) - Vector2(56, 0), {"direction": Vector2.RIGHT, "damage": 10.0})
		await get_tree().create_timer(0.15).timeout
	await _frames(5)
	_check(world.data.get_object(tree_cell) == WorldData.Obj.NONE and _wood(main) > wood_before,
		"투사체로 나무 채집 (나무 %d → %d)" % [wood_before, _wood(main)])
	main.spawner.set_physics_process(true)


## 시작 무기(근거리)로 좌클릭하면 앞의 적이 맞고, 휘두르기로 나무도 채집되는지 확인
func _check_melee(main: Main) -> void:
	var player := main.player
	main.spawner.set_physics_process(false)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	await _frames(2)
	var target := Enemy.new().setup("brute", false)
	target.position = player.global_position + player.aim_direction * 30.0
	main.get_node("Enemies").add_child(target)
	await _frames(2)
	Input.action_press("attack")
	await _frames(3)
	Input.action_release("attack")
	_check(target.hp < target.max_hp, "근거리 기본 공격이 앞의 적에게 맞음 (체력 %d/%d)" % [target.hp, target.max_hp])
	target.queue_free()

	var world := main.world
	var tree_cell := _find_tree(world)
	var wood_before := _wood(main)
	for swing in 3:
		Melee.swing(get_tree(), world.cell_center(tree_cell) - Vector2(40, 0), Vector2.RIGHT, player.equipment.weapon())
	await _frames(2)
	_check(tree_cell != World.NO_CELL and world.data.get_object(tree_cell) == WorldData.Obj.NONE and _wood(main) > wood_before,
		"근거리 공격으로 나무 채집")
	main.spawner.set_physics_process(true)


## 개인 인벤토리(D-014): 보상은 가방으로, 비용은 가방 먼저, 핵 근처에서 창고로 입고, 죽으면 가방 비움
func _check_inventory(main: Main) -> void:
	var player := main.player
	var kingdom := main.kingdom
	player.global_position = kingdom.core.global_position + Vector2(0, 9 * Balance.TILE)
	await _frames(2)
	player.inventory.clear()
	var stock_before: Dictionary = kingdom.stock.duplicate()
	Events.resources_gained.emit({"wood": 3, "stone": 2}, player.global_position)
	await _frames(2)
	_check(player.inventory.count("wood") == 3 and kingdom.stock["wood"] == stock_before["wood"],
		"핵에서 먼 곳의 보상은 개인 인벤토리로 (가방 나무 %d)" % player.inventory.count("wood"))

	var cell := World.NO_CELL
	for offset in [Vector2i(-2, 9), Vector2i(2, 9), Vector2i(-2, 7), Vector2i(2, 7), Vector2i(0, 11)]:
		var candidate: Vector2i = kingdom.core_cell() + offset
		if main.world.data.is_walkable(candidate) and not kingdom.is_occupied(candidate):
			cell = candidate
			break
	var error := kingdom.build(cell, "wood_wall", player.global_position, player.inventory)
	_check(error == "" and player.inventory.count("wood") == 0 and kingdom.stock["wood"] == stock_before["wood"] - 2,
		"건설 비용은 가방 먼저, 모자란 만큼 창고에서 (%s, 창고 나무 %d)" % [error, kingdom.stock["wood"]])

	player.global_position = player.spawn_point
	await _frames(3)
	_check(player.inventory.is_empty() and kingdom.stock["stone"] == stock_before["stone"] + 2,
		"핵 근처에 오면 가방 자원이 창고로 자동 입고")

	player.global_position = kingdom.core.global_position + Vector2(0, 9 * Balance.TILE)
	player.inventory.add({"gold": 5})
	player.equipment.add_to_bag("iron_helm")
	# 직전 피격·대시 무적이 남아 있을 수 있어 풀릴 때까지 시도한다
	for attempt in 120:
		player.take_damage(999999.0)
		if player.is_dead:
			break
		await _frames(1)
	_check(player.is_dead and player.inventory.is_empty() and player.equipment.bag.is_empty(), "죽으면 가방 자원과 가방 장비가 모두 사라짐 (사망 %s, 가방 %s, 장비 %s)" % [player.is_dead, player.inventory.amounts(), player.equipment.bag])


## B는 건설 메뉴(게임은 계속 진행), 고르면 그 건물의 설치 모드, 설치 중 B는 메뉴로 돌아감
func _check_build_menu(main: Main) -> void:
	var press := func(action: String) -> void:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = true
		Input.parse_input_event(event)
	press.call("build_toggle")
	await _frames(2)
	_check(main.hud.build_menu.visible and not main.build_mode.active and not get_tree().paused and not main.player.attack_enabled,
		"B로 건설 메뉴가 열리고 게임은 멈추지 않음")
	main.hud.build_menu.choose("stone_wall")
	await _frames(1)
	_check(not main.hud.build_menu.visible and main.build_mode.active and main.build_mode.selected_type() == "stone_wall",
		"메뉴에서 고르면 그 건물의 설치 모드")
	press.call("build_toggle")
	await _frames(2)
	_check(main.hud.build_menu.visible and not main.build_mode.active, "설치 중 B는 건설 메뉴로 돌아감")
	press.call("ui_cancel")
	await _frames(2)
	_check(not main.hud.build_menu.visible and not main.build_mode.active, "Esc로 건설 메뉴 닫힘")


## 장비 상자(D-014): 맡기기·꺼내기, 비어 있지 않으면 철거 불가, E로 창 열기
func _check_storage(main: Main) -> void:
	var player := main.player
	var kingdom := main.kingdom
	player.global_position = player.spawn_point
	await _frames(2)
	kingdom.add_resources({"wood": 15})
	var cell := World.NO_CELL
	for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1)]:
		var candidate: Vector2i = main.world.cell_at(player.spawn_point) + offset
		if main.world.data.is_walkable(candidate) and not kingdom.is_occupied(candidate):
			cell = candidate
			break
	var error := kingdom.build(cell, "gear_chest", player.global_position, player.inventory)
	_check(error == "" and kingdom.find_storage_near(player.global_position) == cell, "장비 상자 건설 %s" % error)
	if error != "":
		return
	# 앞의 상자 보상이 무작위로 같은 장비를 넣었을 수 있어 가방을 비우고 시작한다
	player.equipment.lose_bag()
	player.equipment.add_to_bag("chain_mail")
	error = kingdom.store_item(cell, player.equipment, "chain_mail", player.global_position)
	var building: Building = kingdom.buildings[cell]
	_check(error == "" and building.stored == ["chain_mail"] and not player.equipment.bag.has("chain_mail"),
		"가방 장비를 장비 상자에 맡김 %s" % error)
	_check(kingdom.store_item(cell, player.equipment, "chain_mail", player.global_position) != "", "가방에 없는 장비는 맡길 수 없음")
	_check(kingdom.take_item(cell, player.equipment, "chain_mail", player.global_position + Vector2(0, 10 * Balance.TILE)) != "",
		"멀리서는 꺼낼 수 없음")
	_check(kingdom.demolish(cell) != "" and kingdom.buildings.has(cell), "장비가 든 상자는 철거할 수 없음")

	var interact := InputEventAction.new()
	interact.action = "interact"
	interact.pressed = true
	Input.parse_input_event(interact)
	await _frames(2)
	_check(main.hud.storage_panel.visible and not player.attack_enabled, "E로 장비 상자 창이 열리고 공격이 꺼짐")
	main.hud.storage_panel.hide()

	error = kingdom.take_item(cell, player.equipment, "chain_mail", player.global_position)
	_check(error == "" and building.stored.is_empty() and player.equipment.bag.has("chain_mail"), "장비 상자에서 가방으로 꺼냄 %s" % error)
	_check(kingdom.demolish(cell) == "" and not kingdom.buildings.has(cell), "빈 장비 상자는 철거 가능")


## 제작대(D-014): 하나만, 공개된 레시피·단계 조건으로 제작, 업그레이드, 단계 오른 제작대는 철거 불가
func _check_workbench(main: Main) -> void:
	var player := main.player
	var kingdom := main.kingdom
	player.global_position = player.spawn_point
	player.equipment.lose_bag()
	await _frames(2)
	kingdom.add_resources({"wood": 100, "stone": 100})
	var cells: Array[Vector2i] = []
	for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 1)]:
		var candidate: Vector2i = main.world.cell_at(player.spawn_point) + offset
		if main.world.data.is_walkable(candidate) and not kingdom.is_occupied(candidate):
			cells.append(candidate)
	var error := kingdom.build(cells[0], "workbench", player.global_position, player.inventory)
	_check(error == "" and kingdom.workbench_tier() == 0, "제작대 건설, 0단계 %s" % error)
	_check(kingdom.build(cells[1], "workbench", player.global_position, player.inventory) != "", "제작대는 하나만 지을 수 있음")

	_check(kingdom.craft("old_bow", player.global_position, player.inventory, player.equipment) == "" and player.equipment.bag.has("old_bow"),
		"0단계 레시피(낡은 활) 제작 → 가방")
	_check(kingdom.craft("old_bow", player.global_position + Vector2(0, 10 * Balance.TILE), player.inventory, player.equipment) != "",
		"제작대에서 멀면 제작 불가")
	kingdom.known_materials.erase("gold")
	_check(kingdom.craft("iron_helm", player.global_position, player.inventory, player.equipment) == "아직 모르는 레시피입니다",
		"금을 얻기 전에는 철 투구 레시피를 모름")
	var revealed := kingdom.discover({"gold": 1})
	_check(revealed.has("iron_helm"), "금을 처음 얻으면 철 투구 레시피 공개 %s" % [revealed])
	_check(kingdom.craft("iron_helm", player.global_position, player.inventory, player.equipment).contains("1단계"), "단계가 모자라면 제작 불가")

	kingdom.add_resources({"gold": 20})
	error = kingdom.upgrade_workbench(player.global_position, player.inventory)
	_check(error == "" and kingdom.workbench_tier() == 1, "제작대 1단계 업그레이드 %s" % error)
	_check(kingdom.craft("iron_helm", player.global_position, player.inventory, player.equipment) == "", "1단계가 되면 철 투구 제작")
	_check(kingdom.demolish(cells[0]) != "" and kingdom.workbench_tier() == 1, "단계를 올린 제작대는 철거할 수 없음")

	var interact := InputEventAction.new()
	interact.action = "interact"
	interact.pressed = true
	Input.parse_input_event(interact)
	await _frames(2)
	_check(main.hud.crafting_panel.visible, "E로 제작대 창이 열림")
	main.hud.crafting_panel.hide()

	kingdom.buildings[cells[0]].take_damage(99999.0)
	await _frames(2)
	_check(kingdom.workbench_tier() == -1, "제작대가 부서지면 단계도 사라짐")


func _wood(main: Main) -> int:
	return main.kingdom.stock["wood"] + main.player.inventory.count("wood")


func _total_resources(main: Main) -> int:
	var total := 0
	for kind in main.kingdom.stock:
		total += main.kingdom.stock[kind] + main.player.inventory.count(kind)
	return total


func _check(ok: bool, label: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + label)
	if not ok:
		_failures += 1


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
