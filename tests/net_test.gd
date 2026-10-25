extends Node
## 멀티플레이 테스트 (D-017). 같은 기기에서 headless 호스트·참가자 두 프로세스를 띄워 IP(ENet)로 붙인다.
## 1단계: 접속·같은 시드·상대 위치. 2단계: 호스트의 적이 참가자를 때림, 참가자의 공격이 호스트의 적을 죽이고 보상을 받음,
## 낮/밤과 왕국 핵 체력이 참가자에게 전달됨. 3단계: 참가자가 부순 나무·연 상자가 양쪽 월드에서 사라지고 보상은 참가자가 받음,
## 참가자가 핵 근처에서 입고한 자원이 호스트 창고로 가고, 참가자의 건설 요청으로 지은 벽이 양쪽에 생김.
## 공유 지도(D-018): 서로 밝힌 칸이 상대 지도에도 탐험되고, 참가자가 찍은 핑이 호스트를 거쳐 양쪽에 보임.
## 전략회의(D-019): 참가자가 열면 양쪽이 멈추고, 한 명만 준비하면 계속 멈춰 있고, 둘 다 준비하면 같이 재개.
## 실행: tests/run_all.sh 가 "-- --role=host" 와 "-- --role=client" 로 동시에 실행한다.
## 게임이 시작되면 이 씬은 main.tscn으로 바뀌어 사라지므로, 검사는 루트에 붙인 Runner가 이어서 한다.

const DEFAULT_PORT := 24691  # run_all.sh는 실행마다 --port=로 다른 포트를 준다
const SEED := "net-test"
## 참가자가 자기 캐릭터를 옮겨 두는 자리. 호스트 화면의 상대 캐릭터가 여기로 와야 한다
const CLIENT_OFFSET := Vector2(96, 0)
const TIMEOUT_MS := 45000
const CORE_HIT := 100.0
## 호스트가 마지막에 걸어가 밝히는 곳 (핵 기준 칸). 참가자 지도에 탐험되어야 한다
const HOST_SCOUT_OFFSET := Vector2i(0, -40)
## 참가자가 찍는 핑 (핵 기준 칸)
const PING_OFFSET := Vector2i(5, 5)


func _ready() -> void:
	var runner := Runner.new()
	runner.role = "host"
	runner.port = DEFAULT_PORT
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			runner.role = arg.trim_prefix("--role=")
		elif arg.begins_with("--port="):
			runner.port = int(arg.trim_prefix("--port="))
	get_tree().root.add_child.call_deferred(runner)


class Runner extends Node:
	var role := ""
	var port := DEFAULT_PORT
	var _failures := 0
	var _heard: Array[String] = []

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		var deadline := Time.get_ticks_msec() + TIMEOUT_MS
		var net: NetSession = Session.net
		if role == "host":
			net.host_enet(port)
			await _until(func() -> bool: return net.members.size() == 2, deadline)
			_check(net.members.size() == 2, "호스트: 참가자가 들어와 명단 2명 %s" % [net.members])
			net.start_game(SEED)
		else:
			# 호스트가 아직 안 떴을 수 있어 연결될 때까지 다시 시도한다
			while Time.get_ticks_msec() < deadline and net.members.size() < 2:
				if not net.is_online():
					net.join_enet("127.0.0.1", port)
				await get_tree().create_timer(0.5).timeout
			_check(net.members.size() == 2, "참가자: 호스트에 접속, 명단 2명 %s" % [net.members])
		await _until(func() -> bool: return _main() != null and _main().player_sync.is_running(), deadline)
		var main := _main()
		_check(main != null and Session.seed_text == SEED, "같은 시드로 게임 시작 (%s)" % Session.seed_text)
		if main == null:
			_finish()
			return
		main.sound_effects.played.connect(func(id: String, _at: Vector2) -> void: _heard.append(id))
		_check(main.player_sync.remote_count() == 1, "상대 캐릭터 1명 생성")
		if role == "client":
			_check(main.spawner.process_mode == Node.PROCESS_MODE_DISABLED, "참가자는 적을 만들지 않음 (1단계)")
			main.player.global_position = main.player.spawn_point + CLIENT_OFFSET
		var remote := _remote(main)
		var expected := main.player.spawn_point + (CLIENT_OFFSET if role == "host" else Vector2.ZERO)
		await _until(func() -> bool: return remote != null and remote.position.distance_to(expected) < 4.0, deadline)
		_check(remote != null and remote.position.distance_to(expected) < 4.0,
			"상대 위치가 전달됨 (%s, 기대 %s)" % [remote.position if remote != null else "없음", expected])
		await _check_network_audio(main, deadline)
		await _check_weapon_visuals(main, remote, deadline)
		if role == "host":
			await _host_combat(main, remote, deadline)
		else:
			await _client_combat(main, deadline)
		_finish()

	func _check_network_audio(main: Main, deadline: int) -> void:
		if role == "host":
			await _until(func() -> bool: return _heard.has("shield"), deadline)
			_check(_heard.count("shield") == 1, "호스트: 참가자 행동음이 그 사람 위치에서 한 번 전달됨")
			_check(not _heard.has("core_destroyed"), "호스트: 참가자가 요청한 월드 멸망음은 허용 목록에서 거부됨")
			Events.world_sound_requested.emit("upgrade", main.player.global_position)
			main.player.sound_requested.emit("rally", main.player.global_position)
		else:
			# 임의의 월드 결과음을 요청해도 상태·오디오를 바꿀 수 없어야 한다.
			main.combat_sync._relay_player_sound("core_destroyed", main.player.global_position)
			await get_tree().process_frame
			main.player.sound_requested.emit("shield", main.player.global_position)
			await _until(func() -> bool: return _heard.has("upgrade") and _heard.has("rally"), deadline)
			_check(_heard.has("upgrade") and _heard.has("rally"), "참가자: 호스트 월드 결과음과 호스트 캐릭터 행동음을 받음")
			_check(_heard.count("shield") == 1, "참가자: 내 행동음은 즉시 한 번 들리고 호스트가 되돌려 보내지 않음")

	func _check_weapon_visuals(main: Main, remote: RemotePlayer, deadline: int) -> void:
		var worn := "iron_helm" if role == "host" else "cloth_shoes"
		main.player.equipment.add_to_bag(worn)
		main.player.equipment.equip(worn)
		if role == "host":
			await _until(func() -> bool: return remote.weapon_visual.weapon_id == "old_bow" and remote.weapon_visual.attack_item == "old_bow", deadline)
			_check(remote.weapon_visual.weapon_id == "old_bow" and remote.weapon_visual.attack_item == "old_bow", "호스트: 참가자의 활 장착과 발사 모션이 같은 원본으로 표시됨")
			main.player.equipment.add_to_bag("obsidian_blade")
			main.player.equipment.equip("obsidian_blade")
			main.player._show_attack("obsidian_blade")
			main.player.fire({"direction": Vector2.UP, "damage": 0.0, "lifetime": 2.0, "art": "ember"})
		else:
			main.player.equipment.add_to_bag("old_bow")
			main.player.equipment.equip("old_bow")
			main.player._show_attack("old_bow")
			await _until(func() -> bool: return remote.weapon_visual.weapon_id == "obsidian_blade" and remote.weapon_visual.attack_item == "obsidian_blade", deadline)
			_check(remote.weapon_visual.weapon_id == "obsidian_blade" and remote.weapon_visual.attack_item == "obsidian_blade", "참가자: 호스트의 흑요석 검과 휘두르기 모션이 전달됨")
			var seen := func() -> bool:
				return main.get_node("Projectiles").get_children().any(func(node: Node) -> bool: return node is Projectile and node.visual_only and node.art_id == "ember")
			await _until(seen, deadline)
			_check(seen.call(), "참가자: 호스트가 쏜 화염탄은 피해 없는 표시 복제본으로 보임")
		var expected_slot := "boots" if role == "host" else "head"
		var expected_item := "cloth_shoes" if role == "host" else "iron_helm"
		await _until(func() -> bool: return remote.equipment_visual._items.get(expected_slot) == expected_item, deadline)
		_check(remote.equipment_visual._items.get(expected_slot) == expected_item, "상대가 착용한 장비 외형이 같은 시트로 전달됨")

	## 참가자 옆에 늑대를 만들고 참가자의 공격으로 죽는지 본다. 그다음 적 생성을 끄고, 핵에 피해를 주고, 밤으로 넘긴다.
	## 끝나면 참가자가 나갈 때까지 기다린다 (참가자의 검사에 호스트 상태가 필요하다)
	func _host_combat(main: Main, remote: RemotePlayer, deadline: int) -> void:
		var killer := [0]
		Events.enemy_killed.connect(func(enemy: Node) -> void: killer[0] = (enemy as Enemy).killed_by)
		var wolf := Enemy.new().setup("wolf", false)
		wolf.position = remote.global_position + Vector2(40, 0)
		main.get_node("Enemies").add_child(wolf)
		await _until(func() -> bool: return killer[0] != 0, deadline)
		_check(killer[0] == remote.peer_id, "호스트: 참가자의 공격이 내 적을 죽임 (막타 %d)" % killer[0])
		# 침공 적이 핵을 더 깎으면 참가자가 비교할 값이 흔들리므로 이 뒤로는 적을 만들지 않는다
		main.spawner.process_mode = Node.PROCESS_MODE_DISABLED
		main.kingdom.core.take_damage(CORE_HIT)
		main.day_night.skip_to_night()
		# 참가자가 고를 나무·상자는 같은 시드라 호스트도 똑같이 고른다
		var targets := _world_targets(main.world)
		var kingdom := main.kingdom
		var wood_before: int = kingdom.stock.get("wood", 0)
		var gone := func() -> bool:
			return main.world.data.get_object(targets["tree"]) == WorldData.Obj.NONE and main.world.data.get_object(targets["chest"]) == WorldData.Obj.NONE
		await _until(gone, deadline)
		_check(gone.call(), "호스트: 참가자가 부순 나무와 연 상자가 내 월드에서도 사라짐")
		await _until(func() -> bool: return kingdom.stock.get("wood", 0) > wood_before, deadline)
		_check(kingdom.stock.get("wood", 0) > wood_before, "호스트: 참가자가 입고한 나무가 내 창고로 (%d → %d)" % [wood_before, kingdom.stock.get("wood", 0)])
		var wall := _wall_cell(main)
		await _until(func() -> bool: return kingdom.buildings.has(wall), deadline)
		_check(kingdom.buildings.has(wall) and kingdom.buildings[wall].type_id == "wood_wall", "호스트: 참가자의 건설 요청으로 내 왕국에 벽이 생김")
		var data := main.world.data
		_check(data.is_explored(targets["tree"]) and data.is_explored(targets["chest"]),
			"호스트: 참가자가 다녀온 나무·상자 근처가 내 지도에도 탐험됨")
		var ping := data.core_cell + PING_OFFSET
		await _until(func() -> bool: return main.map_state.pings.has(ping), deadline)
		_check(main.map_state.pings.has(ping), "호스트: 참가자가 찍은 핑이 내 지도에 보임")
		main.player.global_position = main.world.cell_center(data.core_cell + HOST_SCOUT_OFFSET)
		# 참가자가 회의를 열면 내 게임도 멈춘다. 내가 먼저 준비하고, 참가자가 준비하면 같이 재개된다
		await _until(func() -> bool: return get_tree().paused, deadline)
		_check(get_tree().paused and main.hud.meeting_panel.visible, "호스트: 참가자가 연 전략회의로 내 게임도 멈춤")
		main.hud.meeting_panel.confirm()
		await _until(func() -> bool: return not get_tree().paused, deadline)
		_check(not get_tree().paused and not main.hud.meeting_panel.visible, "호스트: 둘 다 준비 완료하자 재개됨")
		await _until(func() -> bool: return remote.ranks.get("scavenger", 0) == 1, deadline)
		_check(remote.ranks.get("scavenger", 0) == 1 and main.passive_value(remote.peer_id, "scavenger") > 0.0,
			"호스트: 참가자가 배운 패시브 단계를 알고 보상에 쓸 수 있음 (D-020)")
		await _until(func() -> bool: return Session.net.members.size() < 2, deadline)

	func _client_combat(main: Main, deadline: int) -> void:
		var enemies := main.get_node("Enemies")
		# 호스트가 낮에 만드는 배회 적(슬라임)도 보일 수 있어서 늑대를 골라 지켜본다
		var wolf_puppet := func() -> EnemyPuppet:
			for child in enemies.get_children():
				if child is EnemyPuppet and child.type_id == "wolf" and not child.is_queued_for_deletion():
					return child
			return null
		await _until(func() -> bool: return wolf_puppet.call() != null, deadline)
		var wolf: EnemyPuppet = wolf_puppet.call()
		_check(wolf != null and get_tree().get_nodes_in_group("enemies").is_empty(),
			"참가자: 호스트의 적이 그림(EnemyPuppet)으로 보이고 진짜 적은 없음")
		if wolf == null:
			return
		var max_hp := main.player.max_hp()
		await _until(func() -> bool: return main.player.hp < max_hp, deadline)
		_check(main.player.hp < max_hp, "참가자: 호스트의 적이 나를 때림 (체력 %d/%d)" % [main.player.hp, max_hp])
		var xp_before := main.player.progression.xp
		main.player.blast(6.0 * Balance.TILE, 9999.0)
		await _until(func() -> bool: return main.player.progression.xp > xp_before, deadline)
		_check(main.player.progression.xp >= xp_before + int(EnemyDB.TYPES["wolf"]["xp"]),
			"참가자: 내 공격으로 잡은 적의 경험치를 받음 (%d → %d)" % [xp_before, main.player.progression.xp])
		await _until(func() -> bool: return not is_instance_valid(wolf) or wolf.is_queued_for_deletion(), deadline)
		_check(not is_instance_valid(wolf) or wolf.is_queued_for_deletion(), "참가자: 죽은 적이 화면에서 사라짐")
		await _until(func() -> bool: return main.combat_sync.hits_received > 0, deadline)
		_check(main.combat_sync.hits_received > 0, "참가자: 호스트의 피해 숫자를 받아 내 화면에 띄움 (D-023)")
		var expected_hp := Balance.CORE_MAX_HP - CORE_HIT
		await _until(func() -> bool: return is_equal_approx(main.kingdom.core.hp, expected_hp), deadline)
		_check(is_equal_approx(main.kingdom.core.hp, expected_hp), "참가자: 왕국 핵 체력이 호스트와 같음 (%d)" % main.kingdom.core.hp)
		await _until(func() -> bool: return main.day_night.is_night(), deadline)
		_check(main.day_night.is_night(), "참가자: 호스트가 밤으로 넘기면 나도 밤")
		await _client_world(main, deadline)

	## 나무 옆에 서서 쏘고, 상자 옆에 서서 E로 연다. 내 화면의 공격은 월드를 바꾸지 않고 호스트가 정한 결과만 따른다
	func _client_world(main: Main, deadline: int) -> void:
		var world := main.world
		var targets := _world_targets(world)
		var tree: Vector2i = targets["tree"]
		var wood_before := main.player.inventory.count("wood")
		main.player.global_position = world.cell_center(tree + Vector2i.LEFT)
		await get_tree().create_timer(0.5).timeout  # 호스트가 내 새 위치를 알 때까지
		main.player.fire({"direction": Vector2.RIGHT, "damage": 9999.0, "speed": 600.0})
		await _until(func() -> bool: return world.data.get_object(tree) == WorldData.Obj.NONE, deadline)
		_check(world.data.get_object(tree) == WorldData.Obj.NONE, "참가자: 내가 쏜 나무가 호스트에서 부서지고 내 월드에도 반영")
		await _until(func() -> bool: return main.player.inventory.count("wood") > wood_before, deadline)
		_check(main.player.inventory.count("wood") > wood_before, "참가자: 채집 재료는 내 가방으로 (나무 %d → %d)" % [wood_before, main.player.inventory.count("wood")])
		var chest: Vector2i = targets["chest"]
		var total_before := _total(main.player.inventory)
		main.player.global_position = world.cell_center(chest + Vector2i.LEFT)
		await get_tree().create_timer(0.5).timeout
		main._interact()
		await _until(func() -> bool: return world.data.get_object(chest) == WorldData.Obj.NONE and _total(main.player.inventory) > total_before, deadline)
		_check(world.data.get_object(chest) == WorldData.Obj.NONE and _total(main.player.inventory) > total_before,
			"참가자: E로 연 상자가 사라지고 호스트가 굴린 보상을 받음")
		await _client_kingdom(main, deadline)

	## 핵 근처로 와서 가방을 입고하고, 벽을 짓는다. 창고·건물은 호스트가 정한 상태를 받는다
	func _client_kingdom(main: Main, deadline: int) -> void:
		var kingdom := main.kingdom
		main.player.global_position = main.player.spawn_point + Vector2(0, -Balance.TILE)
		await _until(func() -> bool: return main.player.inventory.is_empty(), deadline)
		_check(main.player.inventory.is_empty(), "참가자: 핵 근처에 오면 가방 자원이 호스트 창고로 입고됨")
		var wall := _wall_cell(main)
		var stock_before: int = kingdom.stock.get("wood", 0)
		await get_tree().create_timer(0.3).timeout  # 입고가 반영된 창고 상태를 먼저 받는다
		stock_before = kingdom.stock.get("wood", 0)
		main.kingdom_sync.build(wall, "wood_wall")
		await _until(func() -> bool: return kingdom.buildings.has(wall), deadline)
		_check(kingdom.buildings.has(wall), "참가자: 내가 요청한 벽이 호스트에서 지어져 내 화면에도 생김")
		var cost: int = BuildingDB.TYPES["wood_wall"]["cost"].get("wood", 0)
		await _until(func() -> bool: return kingdom.stock.get("wood", 0) == stock_before - cost, deadline)
		_check(kingdom.stock.get("wood", 0) == stock_before - cost,
			"참가자: 건설 비용이 빠진 호스트 창고를 받음 (나무 %d → %d)" % [stock_before, kingdom.stock.get("wood", 0)])
		await _client_map(main, deadline)

	## 핑을 찍고, 호스트가 걸어가 밝힌 곳이 내 지도에 탐험되는지 본다
	func _client_map(main: Main, deadline: int) -> void:
		var data := main.world.data
		var ping := data.core_cell + PING_OFFSET
		main.map_sync.add_ping(ping)
		await _until(func() -> bool: return main.map_state.pings.has(ping), deadline)
		_check(main.map_state.pings.size() == 1 and main.map_state.pings[0] == ping, "참가자: 내가 찍은 핑이 호스트를 거쳐 내 지도에 보임 %s" % [main.map_state.pings])
		var scout := data.core_cell + HOST_SCOUT_OFFSET
		await _until(func() -> bool: return data.is_explored(scout), deadline)
		_check(data.is_explored(scout), "참가자: 호스트가 밝힌 먼 곳이 내 지도에도 탐험됨")
		await _client_meeting(main, deadline)

	## 내가 회의를 열고, 호스트만 준비한 동안은 멈춰 있다가 내가 준비하면 재개되는지 본다
	func _client_meeting(main: Main, deadline: int) -> void:
		var panel := main.hud.meeting_panel
		main.meeting_sync.request_open()
		await _until(func() -> bool: return get_tree().paused, deadline)
		_check(get_tree().paused and panel.visible, "참가자: 내가 연 전략회의로 게임이 멈춤")
		await _until(func() -> bool: return main.meeting_sync.ready_count == 1, deadline)
		_check(main.meeting_sync.ready_count == 1 and get_tree().paused, "참가자: 호스트만 준비했을 때는 계속 멈춰 있음 (2명 중 1명)")
		panel.confirm()
		await _until(func() -> bool: return not get_tree().paused, deadline)
		_check(not get_tree().paused and not panel.visible, "참가자: 내가 마저 준비하자 재개됨")
		main.player.progression.add_xp(100)
		_check(main.player.progression.learn("scavenger") == "", "참가자: 약탈자 패시브를 배움")
		await get_tree().create_timer(0.5).timeout  # 호스트가 단계를 받을 때까지 접속을 유지한다

	## 핵 오른쪽 아래에서 처음으로 지을 수 있는 칸 (호스트·참가자가 같은 칸을 고른다)
	func _wall_cell(main: Main) -> Vector2i:
		var core := main.kingdom.core_cell()
		for x in range(3, 10):
			var cell := core + Vector2i(x, 3)
			if main.world.data.is_walkable(cell) and not main.kingdom.is_occupied(cell):
				return cell
		return World.NO_CELL

	## 핵에서 가까운 순으로, 왼쪽 칸에 설 수 있는 나무와 상자 하나씩
	func _world_targets(world: World) -> Dictionary:
		var found := {}
		var core := world.data.core_cell
		for r in range(4, 120):
			for y in range(core.y - r, core.y + r + 1):
				for x in range(core.x - r, core.x + r + 1):
					if maxi(absi(x - core.x), absi(y - core.y)) != r:
						continue
					var cell := Vector2i(x, y)
					var obj := world.data.get_object(cell)
					var key := "tree" if obj == WorldData.Obj.TREE else "chest" if obj == WorldData.Obj.CHEST else ""
					if key != "" and not found.has(key) and world.data.is_walkable(cell + Vector2i.LEFT):
						found[key] = cell
			if found.size() == 2:
				return found
		return found

	func _total(inventory: Inventory) -> int:
		var sum := 0
		for kind: String in inventory.amounts():
			sum += inventory.count(kind)
		return sum

	func _main() -> Main:
		return get_tree().current_scene as Main

	func _remote(main: Main) -> RemotePlayer:
		for child in main.get_children():
			if child is RemotePlayer:
				return child
		return null

	func _until(condition: Callable, deadline: int) -> void:
		while not condition.call() and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame

	func _check(ok: bool, label: String) -> void:
		print(("  OK   " if ok else "  FAIL ") + label)
		if not ok:
			_failures += 1

	func _finish() -> void:
		var name := "NET HOST" if role == "host" else "NET CLIENT"
		print("%s %s (실패 %d)" % [name, "PASS" if _failures == 0 else "FAIL", _failures])
		Session.net.leave()
		get_tree().quit(1 if _failures > 0 else 0)
