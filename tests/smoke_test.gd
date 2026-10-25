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
	main.player.use_skill(0)
	_check(not main.player.equipment.is_ready("life_charm"), "스킬바 1번(치유) 사용 후 쿨타임")

	var bag_before := main.player.equipment.bag.size()
	var wood_before: int = main.kingdom.stock["wood"]
	Events.chest_opened.emit(main.player.global_position)
	_check(main.player.equipment.bag.size() > bag_before or main.kingdom.stock["wood"] > wood_before, "상자 보상 지급")

	await _check_harvest(main)

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


## 나무 옆에서 투사체를 쏴서 채집이 되는지 확인
func _check_harvest(main: Main) -> void:
	var world := main.world
	var tree_cell := World.NO_CELL
	for radius in range(Balance.TERRITORY_RADIUS + 1, 60):
		for x in range(-radius, radius + 1):
			var cell := world.data.core_cell + Vector2i(x, radius)
			if world.data.get_object(cell) == WorldData.Obj.TREE and world.data.is_walkable(cell + Vector2i.LEFT) and world.data.is_walkable(cell + Vector2i(-2, 0)):
				tree_cell = cell
				break
		if tree_cell != World.NO_CELL:
			break
	if tree_cell == World.NO_CELL:
		_check(false, "채집 테스트용 나무를 찾지 못함")
		return
	# 돌아다니는 적이 탄을 막지 않게 잠시 치운다
	main.spawner.set_physics_process(false)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	await _frames(2)
	var wood_before: int = main.kingdom.stock["wood"]
	for shot in 5:
		Projectile.spawn(get_tree(), world.cell_center(tree_cell) - Vector2(56, 0), {"direction": Vector2.RIGHT, "damage": 10.0})
		await get_tree().create_timer(0.15).timeout
	await _frames(5)
	_check(world.data.get_object(tree_cell) == WorldData.Obj.NONE and main.kingdom.stock["wood"] > wood_before,
		"투사체로 나무 채집 (나무 %d → %d)" % [wood_before, main.kingdom.stock["wood"]])
	main.spawner.set_physics_process(true)


func _check(ok: bool, label: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + label)
	if not ok:
		_failures += 1


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
