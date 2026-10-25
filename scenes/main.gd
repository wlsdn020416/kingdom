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

	Events.resources_gained.connect(_on_resources_gained)
	Events.chest_opened.connect(_on_chest_opened)
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
	player.attack_enabled = not (build_mode.active or hud.build_menu.visible or hud.equipment_panel.visible or hud.storage_panel.visible)
	player.skills_enabled = not build_mode.active


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("build_toggle"):
		_toggle_build_menu()
	elif event.is_action_pressed("equipment"):
		hud.equipment_panel.toggle()
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
	elif event.is_action_pressed("skip_night"):
		day_night.skip_to_night()
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
	hud.close_big_map()


## B: 건설 메뉴를 열고 닫는다. 설치 중에 누르면 설치를 멈추고 메뉴로 돌아간다
func _toggle_build_menu() -> void:
	if hud.build_menu.visible:
		hud.build_menu.hide()
		return
	_close_overlays()
	hud.build_menu.open()


## E: 장비 상자 창을 열고 닫거나, 월드의 보물 상자를 연다
func _interact() -> void:
	if hud.storage_panel.visible:
		hud.storage_panel.hide()
		return
	var storage := kingdom.find_storage_near(player.global_position)
	if storage != World.NO_CELL and not player.is_dead:
		hud.storage_panel.open(storage)
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
	if not leftover.is_empty():
		Events.message.emit("인벤토리가 가득 찼습니다. 왕국 핵 근처로 가져가세요")


func _on_chest_opened(at: Vector2) -> void:
	var reward := Loot.roll_chest(player.equipment)
	if reward.has("item"):
		var item_name: String = ItemDB.ITEMS[reward["item"]]["name"]
		player.equipment.add_to_bag(reward["item"])
		Events.message.emit("상자에서 %s 획득! (I로 장착)" % item_name)
		Fx.float_text(get_tree(), at, item_name, Palette.OBJECTS[WorldData.Obj.CHEST])
	else:
		Events.resources_gained.emit(reward["resources"], at)


func _on_enemy_killed(enemy: Node) -> void:
	kills += 1
	var killed := enemy as Enemy
	if killed.stats.get("is_boss", false):
		Events.resources_gained.emit({"gold": Balance.BOSS_GOLD}, killed.global_position)
		Events.message.emit("보스 처치!")
	elif randf() < Balance.KILL_GOLD_CHANCE:
		Events.resources_gained.emit({"gold": 1}, killed.global_position)


func _on_core_destroyed() -> void:
	var summary := "%d일차 %s에 왕국이 무너졌습니다. 처치한 적 %d마리." % [
		day_night.day, "밤" if day_night.is_night() else "낮", kills]
	Session.last_result = summary
	_close_overlays()
	get_tree().paused = true
	hud.game_over_panel.open(summary)
