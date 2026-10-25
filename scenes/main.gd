class_name Main
extends Node2D
## 한 판의 게임. 시스템들을 서로 연결하고 전역 단축키를 처리한다.
## 왕국이 멸망하면 Session이 이 씬을 통째로 버리고 시작 화면으로 돌아간다.

@onready var world: World = $World
@onready var kingdom: Kingdom = $Kingdom
@onready var player: Player = $Player
@onready var day_night: DayNight = $DayNight
@onready var spawner: WaveSpawner = $WaveSpawner
@onready var build_mode: BuildMode = $BuildMode
@onready var hud: Hud = $Hud

var map_state: MapState
var kills := 0
var player_sync := PlayerSync.new()
var combat_sync := CombatSync.new()


func _ready() -> void:
	world.setup(WorldGenerator.generate(Session.seed_text))
	kingdom.setup(world)
	map_state = MapState.new(world, kingdom)
	player.spawn_point = kingdom.core.global_position + Vector2(0, 4 * Balance.TILE)
	player.global_position = player.spawn_point
	player.set_camera_limits(world.bounds())
	day_night.setup($Darkness)
	spawner.setup(world, kingdom, player, $Enemies)
	build_mode.setup(world, kingdom, player)
	$PingMarkers.setup(map_state, world)
	hud.setup(self)
	player_sync.name = "PlayerSync"
	player_sync.setup(Session.net, player, self)
	add_child(player_sync)
	combat_sync.name = "CombatSync"
	combat_sync.setup(Session.net, self)
	add_child(combat_sync)
	# 적·웨이브는 호스트만 만든다. 참가자는 CombatSync가 받은 모습만 그린다 (D-017)
	if not Session.net.is_host():
		spawner.process_mode = Node.PROCESS_MODE_DISABLED

	Events.resources_gained.connect(_on_resources_gained)
	Events.chest_opened.connect(_on_chest_opened)
	Events.object_harvested.connect(_on_object_harvested)
	Events.item_crafted.connect(_on_item_crafted)
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.core_destroyed.connect(_on_core_destroyed)

	world.reveal(player.global_position)
	Events.message.emit("1일차 아침 · 시드 \"%s\"" % Session.seed_text)


func _physics_process(_delta: float) -> void:
	world.reveal(player.global_position)
	if not player.is_dead:
		var moved := kingdom.deposit(player.inventory, player.global_position)
		if not moved.is_empty():
			Fx.float_text(get_tree(), kingdom.core.global_position + Vector2(0, -40), "창고 " + Balance.format_gain(moved), Color("ffe08a"))


func _process(_delta: float) -> void:
	player.attack_enabled = not (build_mode.active or hud.build_menu.visible or hud.equipment_panel.visible
		or hud.storage_panel.visible or hud.crafting_panel.visible or hud.passive_panel.visible)
	player.skills_enabled = not build_mode.active


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("build_toggle"):
		_toggle_build_menu()
	elif event.is_action_pressed("equipment"):
		hud.equipment_panel.toggle()
	elif event.is_action_pressed("passives"):
		hud.passive_panel.toggle()
	elif event.is_action_pressed("meeting"):
		_close_overlays()
		hud.meeting_panel.open()
	elif event.is_action_pressed("world_map"):
		hud.toggle_big_map()
	elif event.is_action_pressed("interact"):
		_interact()
	elif event.is_action_pressed("repair"):
		var error := kingdom.repair(player.global_position, player.inventory)
		if error != "":
			Events.message.emit(error)
		elif not Session.net.is_host():
			combat_sync.request_repair()
	elif event.is_action_pressed("skip_night"):
		if Session.net.is_host():
			day_night.skip_to_night()
		else:
			combat_sync.request_skip_night()
	elif event.is_action_pressed("ui_cancel"):
		_close_overlays()
	else:
		return
	get_viewport().set_input_as_handled()


func _close_overlays() -> void:
	build_mode.set_active(false)
	hud.build_menu.hide()
	hud.equipment_panel.hide()
	hud.storage_panel.hide()
	hud.crafting_panel.hide()
	hud.passive_panel.hide()
	hud.close_big_map()


## B: 건설 메뉴를 열고 닫는다. 설치 중에 누르면 설치를 멈추고 메뉴로 돌아간다
func _toggle_build_menu() -> void:
	if hud.build_menu.visible:
		hud.build_menu.hide()
		return
	_close_overlays()
	hud.build_menu.open()


## E: 장비 상자·제작대 창을 열고 닫거나, 월드의 보물 상자를 연다
func _interact() -> void:
	if hud.storage_panel.visible or hud.crafting_panel.visible:
		hud.storage_panel.hide()
		hud.crafting_panel.hide()
		return
	if player.is_dead:
		return
	var storage := kingdom.find_storage_near(player.global_position)
	if storage != World.NO_CELL:
		hud.storage_panel.open(storage)
		return
	var workbench := kingdom.find_workbench_near(player.global_position)
	if workbench != World.NO_CELL:
		hud.crafting_panel.open(workbench)
		return
	var chest := world.find_chest_near(player.global_position)
	if chest != World.NO_CELL:
		world.open_chest(chest)


## 멀티플레이에서는 보상을 받은 플레이어를 신호에 실어야 한다. 지금은 1인이라 로컬 플레이어.
func _on_resources_gained(amounts: Dictionary, at: Vector2) -> void:
	var leftover := player.inventory.add(amounts)
	var kept := amounts.duplicate()
	for kind in leftover:
		kept[kind] -= leftover[kind]
		if kept[kind] <= 0:
			kept.erase(kind)
	if not kept.is_empty():
		Fx.float_text(get_tree(), at, Balance.format_gain(kept), Color("ffe08a"))
		for recipe_id in kingdom.discover(kept):
			Events.message.emit("새 레시피: %s (제작대)" % ItemDB.ITEMS[recipe_id]["name"])
	if not leftover.is_empty():
		Events.message.emit("인벤토리가 가득 찼습니다. 왕국 핵 근처로 가져가세요")


func _on_chest_opened(at: Vector2) -> void:
	var reward := Loot.roll_chest(world.data.get_terrain(world.cell_at(at)))
	Events.resources_gained.emit(reward["resources"], at)
	if reward.has("item"):
		var item_name: String = ItemDB.ITEMS[reward["item"]]["name"]
		player.equipment.add_to_bag(reward["item"])
		Events.message.emit("상자에서 %s 획득! (I로 장착)" % item_name)
		Fx.float_text(get_tree(), at + Vector2(0, -18), item_name, Palette.OBJECTS[WorldData.Obj.CHEST])


func _on_enemy_killed(enemy: Node) -> void:
	kills += 1
	var killed := enemy as Enemy
	if killed.stats.get("is_boss", false):
		Events.message.emit("보스 처치!")
	var xp: int = killed.stats.get("xp", 0)
	var at := killed.global_position
	if killed.killed_by == Enemy.SOURCE_TOWER:
		var share := Balance.tower_xp_share(xp, player_sync.player_count())
		_give_xp(player, share, at)
		for peer_id: int in player_sync.remote_ids():
			combat_sync.send_reward(peer_id, share, {}, at)
		return
	# 다른 사람의 약탈자 패시브는 호스트가 모르므로 보너스 없이 굴린다 (임시)
	var bonus := player.progression.value("scavenger") / 100.0 if killed.killed_by == Enemy.SOURCE_LOCAL else 0.0
	var drop := EnemyDB.roll_drop(killed.type_id, bonus) if not killed.is_invader else {}
	if killed.killed_by == Enemy.SOURCE_LOCAL:
		grant_reward(xp, drop, at)
	else:
		combat_sync.send_reward(killed.killed_by, xp, drop, at)


## 처치 보상을 내 캐릭터에 준다 (호스트가 보낸 보상도 여기로 온다)
func grant_reward(xp: int, resources: Dictionary, at: Vector2) -> void:
	_give_xp(player, xp, at)
	if not resources.is_empty():
		Events.resources_gained.emit(resources, at + Vector2(0, -16))


## 풍요로운 손: 부순 오브젝트의 재료를 더 준다
func _on_object_harvested(object_id: int, cell: Vector2i) -> void:
	var at := world.cell_center(cell)
	_give_xp(player, Balance.XP_HARVEST_BY_TIER[world.data.tier_at(cell)], at)
	var extra := int(player.progression.value("bountiful"))
	if extra > 0:
		var bonus := {}
		for kind: String in WorldData.OBJECT_DROPS[object_id]:
			bonus[kind] = extra
		Events.resources_gained.emit(bonus, at + Vector2(0, -16))


func _on_item_crafted(recipe_id: String) -> void:
	_give_xp(player, Balance.XP_CRAFT_BY_TIER[RecipeDB.RECIPES[recipe_id]["tier"]], player.global_position)


## 멀티플레이에서는 처치·채집·제작한 플레이어를 신호에 실어 그 사람에게 준다. 지금은 로컬 플레이어
func _give_xp(receiver: Player, amount: int, at: Vector2) -> void:
	if amount <= 0 or receiver.is_dead:
		return
	receiver.progression.add_xp(amount)
	Fx.float_text(get_tree(), at + Vector2(0, -28), "경험치 +%d" % amount, Color("b48cff"))


## 멸망 판정은 호스트만 한다. 참가자에게는 CombatSync가 같은 문장을 보낸다
func _on_core_destroyed() -> void:
	var summary := "%d일차 %s에 왕국이 무너졌습니다. 처치한 적 %d마리." % [
		day_night.day, "밤" if day_night.is_night() else "낮", kills]
	combat_sync.send_game_over(summary)
	show_game_over(summary)


func show_game_over(summary: String) -> void:
	Session.last_result = summary
	_close_overlays()
	get_tree().paused = true
	hud.game_over_panel.open(summary)
