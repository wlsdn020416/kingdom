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
## 결과에 영향을 주는 무작위(상자·드롭·채집량·웨이브)는 전부 이 하나로 굴린다 (AGENTS 5절).
## 전역 randf()를 쓰지 않아야 "호스트에서만 굴린다"를 한 곳에서 지킬 수 있고, 테스트에서 시드로 재현할 수 있다.
var rng := RandomNumberGenerator.new()
var kills := 0
var player_sync := PlayerSync.new()
var combat_sync := CombatSync.new()
var world_sync := WorldSync.new()
## 건설·장비 상자·제작대·수리·입고는 이걸 거쳐 Kingdom 명령 메서드로 간다 (참가자는 호스트에 요청)
var kingdom_sync := KingdomSync.new()
## 탐험 칸과 핑을 서로 전한다 (핑 찍기·지우기는 이걸 거친다)
var map_sync := MapSync.new()
## 전략회의 열기·준비 완료는 이걸 거친다 (누가 열든 모두 멈춘다, D-019)
var meeting_sync := MeetingSync.new()
var sound_effects := SoundEffects.new()
var _steps := {}


func _ready() -> void:
	world.setup(WorldGenerator.generate(Session.seed_text), rng)
	kingdom.setup(world)
	map_state = MapState.new(world, kingdom)
	player.spawn_point = kingdom.core.global_position + Vector2(0, 4 * Balance.TILE)
	player.global_position = player.spawn_point
	player.set_camera_limits(world.bounds())
	day_night.setup($Darkness)
	spawner.setup(world, kingdom, player, $Enemies, rng)
	build_mode.setup(world, kingdom, player)
	$PingMarkers.setup(map_state, world)
	hud.setup(self)
	_setup_audio()
	Events.combat_effect_requested.connect(func(id: String, at: Vector2, size: float, angle: float) -> void: CombatEffect.spawn(get_tree(), id, at, size, angle))
	player_sync.name = "PlayerSync"
	player_sync.setup(Session.net, player, self)
	add_child(player_sync)
	combat_sync.name = "CombatSync"
	combat_sync.setup(Session.net, self)
	add_child(combat_sync)
	world_sync.name = "WorldSync"
	world_sync.setup(Session.net, self)
	add_child(world_sync)
	kingdom_sync.name = "KingdomSync"
	kingdom_sync.setup(Session.net, self)
	add_child(kingdom_sync)
	map_sync.name = "MapSync"
	map_sync.setup(Session.net, self)
	add_child(map_sync)
	meeting_sync.name = "MeetingSync"
	meeting_sync.setup(Session.net, self)
	add_child(meeting_sync)
	build_mode.place_requested.connect(kingdom_sync.build)
	build_mode.remove_requested.connect(kingdom_sync.demolish)
	# 적·웨이브는 호스트만 만든다. 참가자는 CombatSync가 받은 모습만 그린다 (D-017)
	if not Session.net.is_host():
		spawner.process_mode = Node.PROCESS_MODE_DISABLED

	Events.resources_gained.connect(_on_resources_gained)
	Events.chest_opened.connect(_on_chest_opened)
	Events.object_harvested.connect(_on_object_harvested)
	Events.item_crafted.connect(_on_item_crafted)
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.core_destroyed.connect(_on_core_destroyed)
	Events.night_started.connect(_on_night_started)

	world.reveal(player.global_position)
	Events.message.emit("1일차 아침 · 시드 \"%s\"" % Session.seed_text)
	sound_effects.play("day_start")


func _physics_process(_delta: float) -> void:
	_update_footsteps(_delta)
	world.reveal(player.global_position)
	if not player.is_dead:
		var moved := kingdom_sync.deposit()
		if not moved.is_empty():
			show_deposit(moved)


func show_deposit(moved: Dictionary) -> void:
	Events.ui_sound_requested.emit("deposit")
	Fx.float_text(get_tree(), kingdom.core.global_position + Vector2(0, -40), "창고 " + Balance.format_gain(moved), Color("ffe08a"))


func _process(_delta: float) -> void:
	player.attack_enabled = not (build_mode.active or hud.build_menu.visible or hud.equipment_panel.visible
		or hud.storage_panel.visible or hud.crafting_panel.visible or hud.passive_panel.visible
		or hud.is_pointer_over_status())
	player.skills_enabled = not build_mode.active


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("build_toggle"):
		_toggle_build_menu()
	elif event.is_action_pressed("equipment"):
		hud.equipment_panel.toggle()
	elif event.is_action_pressed("passives"):
		hud.passive_panel.toggle()
	elif event.is_action_pressed("meeting"):
		meeting_sync.request_open()
	elif event.is_action_pressed("world_map"):
		hud.toggle_big_map()
	elif event.is_action_pressed("interact"):
		_interact()
	elif event.is_action_pressed("repair"):
		kingdom_sync.repair()
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


## 전략회의가 열렸다 (내가 열었든 다른 사람이 열었든 MeetingSync가 부른다)
func open_meeting(opener: String, total: int) -> void:
	_close_overlays()
	hud.meeting_panel.open(opener, total)


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
	if chest == World.NO_CELL:
		return
	if Session.net.is_host():
		world.open_chest(chest, Enemy.SOURCE_LOCAL)
	else:
		world_sync.request_open_chest(chest)


## 멀티플레이에서는 보상을 받은 플레이어를 신호에 실어야 한다. 지금은 1인이라 로컬 플레이어.
func _on_resources_gained(amounts: Dictionary, at: Vector2) -> void:
	var leftover := player.inventory.add(amounts)
	var kept := amounts.duplicate()
	for kind in leftover:
		kept[kind] -= leftover[kind]
		if kept[kind] <= 0:
			kept.erase(kind)
	if not kept.is_empty():
		Events.ui_sound_requested.emit("pickup")
		Fx.float_text(get_tree(), at, Balance.format_gain(kept), Color("ffe08a"))
		# 참가자는 호스트가 정한 '알게 된 재료'를 KingdomSync로 받는다
		if Session.net.is_host():
			_learn(kept)
	if not leftover.is_empty():
		Events.message.emit("인벤토리가 가득 찼습니다. 왕국 핵 근처로 가져가세요")


## 보상은 상자를 연 호스트가 굴려서 연 사람에게 준다
func _on_chest_opened(at: Vector2, opener: int) -> void:
	var reward := Loot.roll_chest(world.data.get_terrain(world.cell_at(at)), rng, passive_value(opener, "treasure_hunter") / 100.0)
	if opener == Enemy.SOURCE_LOCAL:
		grant_chest(reward, at)
	else:
		_learn(reward["resources"])
		world_sync.send_chest(opener, reward, at)


## 상자 보상을 내 캐릭터에 준다 (호스트가 보낸 보상도 여기로 온다)
func grant_chest(reward: Dictionary, at: Vector2) -> void:
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
	var bonus := passive_value(killed.killed_by, "scavenger") / 100.0
	var drop := EnemyDB.roll_drop(killed.type_id, rng, bonus) if not killed.is_invader else {}
	if killed.killed_by == Enemy.SOURCE_LOCAL:
		grant_reward(xp, drop, at)
	else:
		_learn(drop)
		combat_sync.send_reward(killed.killed_by, xp, drop, at)


## 처치 보상을 내 캐릭터에 준다 (호스트가 보낸 보상도 여기로 온다)
func grant_reward(xp: int, resources: Dictionary, at: Vector2) -> void:
	_give_xp(player, xp, at)
	if not resources.is_empty():
		Events.resources_gained.emit(resources, at + Vector2(0, -16))


func _on_object_harvested(object_id: int, cell: Vector2i, drops: Dictionary, harvester: int) -> void:
	if harvester == Enemy.SOURCE_LOCAL:
		grant_harvest(object_id, cell, drops)
	else:
		_learn(drops)
		world_sync.send_harvest(harvester, object_id, cell, drops)


## 채집 재료·경험치를 내 캐릭터에 준다 (호스트가 보낸 보상도 여기로 온다).
## 풍요로운 손 보너스는 받는 사람의 패시브로 정한다 (호스트는 다른 사람의 패시브를 모른다, 임시)
func grant_harvest(object_id: int, cell: Vector2i, drops: Dictionary) -> void:
	var at := world.cell_center(cell)
	Events.resources_gained.emit(drops, at)
	_give_xp(player, Balance.XP_HARVEST_BY_TIER[world.data.tier_at(cell)], at)
	var extra := int(player.progression.value("bountiful"))
	if extra > 0:
		var bonus := {}
		for kind: String in WorldData.OBJECT_DROPS[object_id]:
			bonus[kind] = extra
		Events.resources_gained.emit(bonus, at + Vector2(0, -16))


func _on_item_crafted(recipe_id: String, crafter: int) -> void:
	var xp: int = Balance.XP_CRAFT_BY_TIER[RecipeDB.RECIPES[recipe_id]["tier"]]
	var remote := player_sync.remote(crafter)
	if remote == null:
		_give_xp(player, xp, player.global_position)
	else:
		combat_sync.send_reward(crafter, xp, {}, remote.global_position)


## peer_id 플레이어의 패시브 효과 값. 다른 사람 것은 PlayerSync가 받아 둔 단계로 정한다 (호스트가 보상·건설에 쓴다)
func passive_value(peer_id: int, id: String) -> float:
	if peer_id == multiplayer.get_unique_id():
		return player.progression.value(id)
	var remote := player_sync.remote(peer_id)
	return PassiveDB.value_in(remote.ranks, id) if remote != null else 0.0


## 긴급 요새화: 왕국에 배운 사람이 한 명이라도 있으면 가장 높은 단계로 회복한다. 왕국 상태라 호스트만 한다
func _on_night_started(_day: int) -> void:
	if not Session.net.is_host():
		return
	var best := player.progression.value("fortify")
	for peer_id: int in player_sync.remote_ids():
		best = maxf(best, passive_value(peer_id, "fortify"))
	if best > 0.0:
		kingdom.fortify(best / 100.0)
		Events.message.emit("긴급 요새화 · 왕국 건물과 성이 %d%% 회복했습니다" % best)


## 왕국 사람 누군가 얻은 재료를 기록하고 새로 공개된 레시피를 알린다. 호스트만 부른다
func _learn(amounts: Dictionary) -> void:
	for recipe_id in kingdom.discover(amounts):
		Events.message.emit("새 레시피: %s (제작대)" % ItemDB.ITEMS[recipe_id]["name"])


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
	sound_effects.play("core_destroyed")
	Session.last_result = summary
	_close_overlays()
	get_tree().paused = true
	hud.game_over_panel.open(summary)


func _setup_audio() -> void:
	sound_effects.name = "SoundEffects"
	add_child(sound_effects)
	sound_effects.setup(player, SoundDB.catalog())
	Events.world_sound_requested.connect(sound_effects.play)
	Events.ui_sound_requested.connect(func(id: String) -> void: sound_effects.play(id))
	player.sound_requested.connect(sound_effects.play)
	Events.day_started.connect(func(_day: int) -> void: sound_effects.play("day_start"))
	Events.night_started.connect(func(_day: int) -> void: sound_effects.play("night_start"))
	for panel: Control in [hud.equipment_panel, hud.storage_panel, hud.crafting_panel, hud.passive_panel, hud.build_menu, hud.meeting_panel, hud._big_map]:
		sound_effects.watch_panel(panel)


## 받은 위치의 보간도 실제 이동 거리로 센다. 벽에 막힘·부활 순간이동·대시에는 발소리를 내지 않는다.
func _update_footsteps(delta: float) -> void:
	var present := {}
	for actor: Node2D in get_tree().get_nodes_in_group("player"):
		var id := actor.get_instance_id()
		present[id] = true
		var previous: Dictionary = _steps.get(id, {"at": actor.global_position, "distance": 0.0})
		var distance := actor.global_position.distance_to(previous["at"])
		previous["at"] = actor.global_position
		if actor.is_dead or distance > SoundDB.MAX_STEP_DISTANCE or distance > SoundDB.MAX_STEP_SPEED * delta:
			previous["distance"] = 0.0
		else:
			previous["distance"] += distance
			if previous["distance"] >= SoundDB.STEP_DISTANCE:
				previous["distance"] = 0.0
				sound_effects.play(SoundDB.footstep(world.data.get_terrain(world.cell_at(actor.global_position))), actor.global_position)
		_steps[id] = previous
	for id: int in _steps.keys():
		if not present.has(id):
			_steps.erase(id)
