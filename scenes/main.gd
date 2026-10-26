class_name Main
extends Node2D
## 한 판의 게임. 시스템들을 서로 연결하고 전역 단축키를 처리한다.
## 왕국이 멸망하면 Session이 이 씬을 통째로 버리고 시작 화면으로 돌아간다.

const SHAKE_RANGE := 640.0  # 이 거리 밖의 폭발·돌진은 화면을 흔들지 않는다 (D-023)
const HITSTOP_SCALE := 0.05  # 멈칫: 게임 속도를 잠깐 이만큼 늦춘다. 혼자 플레이에서만
const HITSTOP_EMPHASIS := 0.05  # 강조 공격 멈칫 시간(초, 실제 시간)
const HITSTOP_BOSS := 0.15  # 보스 처치 멈칫
const REGROW_PLAYER_GAP := 3.0 * Balance.TILE  # 아침 재생이 플레이어 이 거리 안에는 자라지 않는다 (D-035)
const HIT_FEEL_INTERVAL_MS := 60  # 한 번에 여러 적을 맞혀도(산탄·범위) 타격감은 이 간격에 한 번 (D-029)

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
## 낮 의뢰 (D-037). 호스트가 굴리고 QuestSync로 참가자에게 보낸다
var quest_board := QuestBoard.new()
var quest_sync := QuestSync.new()
var sound_effects := SoundEffects.new()
var boss_music := MusicPlayer.new()
var _steps := {}


func _ready() -> void:
	CursorArt.attach(self, true)
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
	Events.damage_dealt.connect(show_damage)
	Events.screen_shake_requested.connect(shake_screen)
	_base_zoom = player.camera.zoom
	add_child(_prompt)
	Session.settings.changed.connect(_apply_settings)
	_apply_settings()
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
	quest_board.name = "QuestBoard"
	quest_board.setup(world, spawner, map_state, rng, reward_everyone, grow_objects, Session.net.is_host())
	add_child(quest_board)
	quest_sync.name = "QuestSync"
	quest_sync.setup(Session.net, self)
	add_child(quest_sync)
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
	Events.day_started.connect(_on_day_started)

	world.reveal(player.global_position)
	Events.message.emit("1일차 아침 · 시드 \"%s\"" % Session.seed_text)
	sound_effects.play("day_start")


func _physics_process(_delta: float) -> void:
	_update_footsteps(_delta)
	world.reveal(player.global_position)
	player.in_territory = kingdom.in_territory(world.cell_at(player.global_position))
	_campfire_heal(_delta)
	if not player.is_dead:
		var moved := kingdom_sync.deposit()
		if not moved.is_empty():
			show_deposit(moved)


## 모닥불(D-022) 근처에 있으면 체력이 차오른다. 내 캐릭터는 내 화면이 정한다
func _campfire_heal(delta: float) -> void:
	for building: Building in kingdom.buildings.values():
		var aura: Array = building.info.get("heal_aura", [])
		if not aura.is_empty() and building.global_position.distance_to(player.global_position) <= float(aura[0]) * Balance.TILE:
			player.restore(float(aura[1]) * delta)
			return


## 살아 있는 보스 하나 {"id", "ratio", "key"}. 없으면 {}. 호스트는 Enemy, 참가자는 EnemyPuppet을 본다 (ThreatBanner)
func boss_status() -> Dictionary:
	for child in $Enemies.get_children():
		if child.is_queued_for_deletion():
			continue
		if child is Enemy and (child as Enemy).is_boss():
			var boss := child as Enemy
			return {"id": boss.type_id, "ratio": boss.hp / boss.max_hp, "key": boss.get_instance_id()}
		if child is EnemyPuppet and EnemyDB.TYPES[(child as EnemyPuppet).type_id].get("is_boss", false):
			var puppet := child as EnemyPuppet
			return {"id": puppet.type_id, "ratio": puppet.hp_ratio(), "key": puppet.get_instance_id()}
	return {}


## 환경 설정(D-030) 중 게임 화면이 읽는 값. UI 크기는 창 전체 배율을 바꾸므로 카메라 줌을 그만큼 되돌려 월드 크기는 그대로 둔다
func _apply_settings() -> void:
	var settings := Session.settings
	player.shake_scale = settings.get_value("shake")
	player.camera.zoom = _base_zoom / float(settings.get_value("ui_scale"))


## 피해 숫자 (D-023). 참가자 화면에는 CombatSync가 호스트의 숫자를 모아서 보낸다.
## source가 나(peer id)면 지금 든 무기의 타격감을 낸다 (D-029). 탑(-1)·다른 사람이 때린 것은 숫자만
func show_damage(at: Vector2, amount: float, emphasis: bool, source := 0) -> void:
	if Session.settings.get_value("damage_numbers"):
		Fx.damage_number(get_tree(), at, amount, emphasis)
	var hitstop := HITSTOP_EMPHASIS if emphasis else 0.0
	if source == multiplayer.get_unique_id() and Time.get_ticks_msec() - _last_hit_feel >= HIT_FEEL_INTERVAL_MS:
		_last_hit_feel = Time.get_ticks_msec()
		var feel := WeaponArtDB.feel(player.equipment.item_in("weapon"))
		player.add_shake(feel["shake"])
		hitstop = maxf(hitstop, feel["hitstop"])
	if hitstop > 0.0:
		_hitstop(hitstop)


## 내 캐릭터와 가까울수록 세게 흔든다. 무한 좌표(보스 등장·처치)는 거리와 무관
func shake_screen(at: Vector2, strength: float) -> void:
	var falloff := 1.0
	if at.is_finite():
		falloff = 1.0 - player.global_position.distance_to(at) / SHAKE_RANGE
	if falloff > 0.0:
		player.add_shake(strength * falloff)
	if not at.is_finite() and strength >= 10.0:
		_hitstop(HITSTOP_BOSS)


var _hitstopping := false
## 테스트용: 마우스 대신 이 월드 좌표를 쓴다 (INF면 실제 마우스)
var mouse_override := Vector2.INF
var _prompt := InteractPrompt.new()
var _base_zoom := Vector2.ONE
var _last_hit_feel := 0


## 멈칫: 게임 속도를 실제 시간 duration초 동안 늦춘다. 멀티플레이에서는 호스트 속도가 모두의 게임을 바꾸므로 하지 않는다
func _hitstop(duration: float) -> void:
	if Session.net.is_online() or _hitstopping or get_tree().paused or not Session.settings.get_value("hitstop"):
		return
	_hitstopping = true
	var before := Engine.time_scale
	Engine.time_scale = before * HITSTOP_SCALE
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = before
	_hitstopping = false


func show_deposit(moved: Dictionary) -> void:
	Events.ui_sound_requested.emit("deposit")
	Fx.float_text(get_tree(), kingdom.core.global_position + Vector2(0, -40), "창고 " + Balance.format_gain(moved), Color("ffe08a"))


func _process(_delta: float) -> void:
	boss_music.set_active(not boss_status().is_empty())
	player.attack_enabled = not (build_mode.active or hud.build_menu.visible or hud.equipment_panel.visible
		or hud.storage_panel.visible or hud.crafting_panel.visible or hud.passive_panel.visible or hud.teleport_panel.visible
		or hud.kingdom_panel.visible or hud.pause_menu.visible or hud.is_big_map_open() or hud.is_pointer_over_status())
	player.skills_enabled = not build_mode.active
	# 창이 열려 있거나 설치 중이면 E 안내를 숨긴다 (기본 공격이 막힌 상태와 같다)
	_prompt.show_target(interact_target(mouse_world()) if player.attack_enabled and not player.is_dead else {})


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
		# 열린 창이 있으면 닫기만 하고, 아무것도 없을 때 Esc 메뉴를 연다 (D-030)
		if hud.pause_menu.visible:
			hud.pause_menu.close()
		elif not _close_overlays():
			hud.pause_menu.show()
	else:
		return
	get_viewport().set_input_as_handled()


## 전략회의가 열렸다 (내가 열었든 다른 사람이 열었든 MeetingSync가 부른다)
func open_meeting(opener: String, total: int) -> void:
	_close_overlays()
	hud.meeting_panel.open(opener, total)


## 열린 창·설치 모드를 모두 닫는다. 하나라도 열려 있었으면 true (Esc가 메뉴를 열지 판단한다)
func _close_overlays() -> bool:
	var panels: Array[Control] = [hud.build_menu, hud.equipment_panel, hud.storage_panel, hud.crafting_panel,
		hud.teleport_panel, hud.kingdom_panel, hud.passive_panel, hud.pause_menu]
	var was_open := build_mode.active
	for panel in panels:
		was_open = was_open or panel.visible
		panel.hide()
	build_mode.set_active(false)
	return hud.close_big_map() or was_open


## B: 건설 메뉴를 열고 닫는다. 설치 중에 누르면 설치를 멈추고 메뉴로 돌아간다
func _toggle_build_menu() -> void:
	if hud.build_menu.visible:
		hud.build_menu.hide()
		return
	_close_overlays()
	hud.build_menu.open()


## E: 장비 상자·제작대·순간이동 탑·왕국 핵 창을 열고 닫거나, 월드의 보물 상자를 연다
func _interact() -> void:
	if hud.storage_panel.visible or hud.crafting_panel.visible or hud.teleport_panel.visible or hud.kingdom_panel.visible:
		hud.storage_panel.hide()
		hud.crafting_panel.hide()
		hud.teleport_panel.hide()
		hud.kingdom_panel.hide()
		return
	if player.is_dead:
		return
	var target := interact_target(mouse_world())
	match target.get("kind", ""):
		"storage":
			hud.storage_panel.open(target["cell"])
		"workbench":
			hud.crafting_panel.open(target["cell"])
		"teleport":
			hud.teleport_panel.open(target["cell"])
		"core":
			hud.kingdom_panel.open()
		"chest":
			if Session.net.is_host():
				world.open_chest(target["cell"], Enemy.SOURCE_LOCAL)
			else:
				world_sync.request_open_chest(target["cell"])


## E로 열 대상 (D-031). 주변에 하나면 그것, 여럿이면 mouse(월드 좌표)에 가장 가까운 것. 없으면 {}
func interact_target(mouse: Vector2) -> Dictionary:
	var options := interactables()
	if options.size() <= 1:
		return options[0] if not options.is_empty() else {}
	var best: Dictionary = options[0]
	for option: Dictionary in options:
		if mouse.distance_to(option["at"]) < mouse.distance_to(best["at"]):
			best = option
	return best


## 지금 내 캐릭터가 E로 열 수 있는 것 모두: {"kind", "cell", "at", "name", "size"}.
## 건물은 Balance.USE_REACH, 왕국 핵은 CORE_USE_RANGE, 보물 상자는 둘레 한 칸 안
func interactables() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var at := player.global_position
	for cell: Vector2i in kingdom.buildings:
		var building: Building = kingdom.buildings[cell]
		if building.global_position.distance_to(at) > Balance.USE_REACH:
			continue
		var kind := "storage" if building.storage_capacity() > 0 else "workbench" if building.is_workbench() \
			else "teleport" if building.info.get("teleport", false) else ""
		if kind != "":
			result.append({"kind": kind, "cell": cell, "at": building.global_position, "name": building.info["name"], "size": Balance.TILE})
	if kingdom.core_use_error(at) == "":
		result.append({"kind": "core", "cell": kingdom.core_cell(), "at": kingdom.core.global_position, "name": "왕국 집무실", "size": Balance.TILE * 3})
	var center := world.cell_at(at)
	for y in range(-1, 2):
		for x in range(-1, 2):
			var cell := center + Vector2i(x, y)
			if world.data.get_object(cell) == WorldData.Obj.CHEST:
				result.append({"kind": "chest", "cell": cell, "at": world.cell_center(cell), "name": "보물 상자", "size": Balance.TILE})
	return result


## 마우스가 가리키는 월드 위치. 테스트는 mouse_override로 정한다
func mouse_world() -> Vector2:
	return mouse_override if mouse_override.is_finite() else get_global_mouse_position()


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
		if player.progression.value("treasure_hunter") > 0.0:
			player.show_passive("treasure_hunter", at)
		var item_name: String = ItemDB.ITEMS[reward["item"]]["name"]
		player.equipment.add_to_bag(reward["item"])
		Events.message.emit("상자에서 %s 획득! (I로 장착)" % item_name)
		Fx.float_text(get_tree(), at + Vector2(0, -18), item_name, Palette.OBJECTS[WorldData.Obj.CHEST])


func _on_enemy_killed(enemy: Node) -> void:
	kills += 1
	var killed := enemy as Enemy
	if killed.stats.get("final", false):
		_on_victory(killed.stats["name"])
		return
	if killed.is_boss():
		# 보스의 정수(D-022)는 왕국 창고로 들어와 최상위 벽·탑 재료가 된다
		var essence := {"boss_essence": Balance.BOSS_ESSENCE_PER_BOSS}
		kingdom.add_resources(essence)
		_learn(essence)
		Events.message.emit("보스 %s 처치! 보스의 정수가 왕국 창고에 들어왔습니다" % killed.stats["name"])
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
	var xp := Balance.roll_harvest_xp(world.data.tier_at(cell), rng)
	if harvester == Enemy.SOURCE_LOCAL:
		grant_harvest(object_id, cell, drops, xp)
	else:
		_learn(drops)
		world_sync.send_harvest(harvester, object_id, cell, drops, xp)


## 채집 재료·경험치를 내 캐릭터에 준다 (호스트가 보낸 보상도 여기로 온다).
## xp = 호스트가 굴린 기본 채집 경험치(안 나왔으면 0). 채집 학자 보너스와
## 풍요로운 손 보너스는 받는 사람의 패시브로 정한다 (호스트는 다른 사람의 패시브를 모른다, 임시)
func grant_harvest(object_id: int, cell: Vector2i, drops: Dictionary, xp: int) -> void:
	var at := world.cell_center(cell)
	Events.resources_gained.emit(drops, at)
	if xp > 0:
		_give_xp(player, roundi(xp * (1.0 + player.progression.value("harvest_scholar") / 100.0)), at)
	var herb := player.progression.value("herbalist")
	if herb > 0.0 and not player.is_dead:
		player.heal(herb)
		player.show_passive("herbalist")
	var extra := int(player.progression.value("bountiful"))
	if extra > 0:
		player.show_passive("bountiful", at)
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


## 새벽의 축복: 내 캐릭터는 내 화면에서 회복한다 (참가자도 호스트 시간에 맞춰 아침 신호를 받는다)
func _on_day_started(_day: int) -> void:
	var blessing := player.progression.value("dawn_blessing")
	if blessing > 0.0 and not player.is_dead:
		player.heal(player.max_hp() * blessing / 100.0)
		player.show_passive("dawn_blessing")
	if Session.net.is_host():
		regrow_resources()


## 아침 재생 (D-035): 나무·바위·광석을 처음 총량까지 다시 자라게 하고 참가자에게 알린다. 월드 상태라 호스트만 한다
func regrow_resources() -> int:
	var grown := world.regrow(rng, _regrowth_blocked)
	world_sync.send_regrowth(grown)
	if not grown.is_empty():
		Events.message.emit("밤사이 나무와 광맥이 다시 자랐습니다 (%d곳)" % grown.size())
	return grown.size()


## 모두가 받는 보상 (낮 의뢰, D-037). 호스트만 부른다. 참가자 몫은 CombatSync로 보낸다
func reward_everyone(xp: int, resources: Dictionary, at: Vector2) -> void:
	_learn(resources)
	grant_reward(xp, resources, at)
	for peer_id: int in player_sync.remote_ids():
		combat_sync.send_reward(peer_id, xp, resources, at)


## 오브젝트를 새로 놓고 참가자에게도 알린다 (낮 의뢰 광맥, D-037). 호스트만 부른다
func grow_objects(grown: Array) -> void:
	world.apply_grown(grown)
	world_sync.send_regrowth(grown)


## 왕국 영토·건물 칸과 플레이어 바로 옆에는 다시 자라지 않는다 (몸에 끼거나 지을 자리를 막지 않게)
func _regrowth_blocked(cell: Vector2i) -> bool:
	if kingdom.in_territory(cell) or kingdom.is_occupied(cell):
		return true
	var at := world.cell_center(cell)
	for someone: Node2D in get_tree().get_nodes_in_group("player"):
		if someone.global_position.distance_to(at) < REGROW_PLAYER_GAP:
			return true
	return false


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
	var levels := receiver.progression.add_xp(amount)
	Fx.float_text(get_tree(), at + Vector2(0, -28), "경험치 +%d" % amount, Color("b48cff"))
	if levels > 0:
		Fx.float_text(get_tree(), receiver.global_position + Vector2(0, -48), "레벨 업!", Color("ffd24a"))
		Events.message.emit("레벨 %d! 패시브 포인트 +%d (K)" % [receiver.progression.level, levels])
		Events.ui_sound_requested.emit("level_up")


## 멸망 판정은 호스트만 한다. 참가자에게는 CombatSync가 같은 문장을 보낸다
func _on_core_destroyed() -> void:
	var summary := "%d일차 %s에 왕국이 무너졌습니다. 처치한 적 %d마리." % [
		day_night.day, "밤" if day_night.is_night() else "낮", kills]
	combat_sync.send_game_over(summary)
	show_game_over(summary)


## 최종 보스를 쓰러뜨리면 승리 (D-021, 임시). 판정은 적이 있는 호스트만 하고 참가자에게 같은 문장을 보낸다
func _on_victory(boss_name: String) -> void:
	var summary := "%d일차에 최종 보스 %s을(를) 쓰러뜨려 왕국을 지켰습니다! 처치한 적 %d마리." % [day_night.day, boss_name, kills]
	combat_sync.send_game_over(summary, true)
	show_game_over(summary, true)


func show_game_over(summary: String, victory := false) -> void:
	boss_music.set_active(false)
	if victory:
		Events.ui_sound_requested.emit("level_up")
	else:
		sound_effects.play("core_destroyed")
	Session.last_result = ("승리 · " if victory else "") + summary
	_close_overlays()
	get_tree().paused = true
	hud.game_over_panel.open(summary, victory)


func _setup_audio() -> void:
	boss_music.name = "BossMusic"
	add_child(boss_music)
	boss_music.setup(SoundDB.BOSS_MUSIC, SoundDB.BOSS_MUSIC_VOLUME_DB, SoundDB.BOSS_MUSIC_FADE_SECONDS)
	sound_effects.name = "SoundEffects"
	add_child(sound_effects)
	sound_effects.setup(player, SoundDB.catalog())
	Events.world_sound_requested.connect(sound_effects.play)
	Events.ui_sound_requested.connect(func(id: String) -> void: sound_effects.play(id))
	player.sound_requested.connect(sound_effects.play)
	Events.day_started.connect(func(_day: int) -> void: sound_effects.play("day_start"))
	Events.night_started.connect(func(_day: int) -> void: sound_effects.play("night_start"))
	for panel: Control in [hud.equipment_panel, hud.storage_panel, hud.crafting_panel, hud.teleport_panel, hud.passive_panel, hud.build_menu, hud.meeting_panel, hud._big_map]:
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
