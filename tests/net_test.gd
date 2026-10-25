extends Node
## 멀티플레이 테스트 (D-017). 같은 기기에서 headless 호스트·참가자 두 프로세스를 띄워 IP(ENet)로 붙인다.
## 1단계: 접속·같은 시드·상대 위치. 2단계: 호스트의 적이 참가자를 때림, 참가자의 공격이 호스트의 적을 죽이고 보상을 받음,
## 낮/밤과 왕국 핵 체력이 참가자에게 전달됨.
## 실행: tests/run_all.sh 가 "-- --role=host" 와 "-- --role=client" 로 동시에 실행한다.
## 게임이 시작되면 이 씬은 main.tscn으로 바뀌어 사라지므로, 검사는 루트에 붙인 Runner가 이어서 한다.

const DEFAULT_PORT := 24691  # run_all.sh는 실행마다 --port=로 다른 포트를 준다
const SEED := "net-test"
## 참가자가 자기 캐릭터를 옮겨 두는 자리. 호스트 화면의 상대 캐릭터가 여기로 와야 한다
const CLIENT_OFFSET := Vector2(96, 0)
const TIMEOUT_MS := 45000
const CORE_HIT := 100.0


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
		_check(main.player_sync.remote_count() == 1, "상대 캐릭터 1명 생성")
		if role == "client":
			_check(main.spawner.process_mode == Node.PROCESS_MODE_DISABLED, "참가자는 적을 만들지 않음 (1단계)")
			main.player.global_position = main.player.spawn_point + CLIENT_OFFSET
		var remote := _remote(main)
		var expected := main.player.spawn_point + (CLIENT_OFFSET if role == "host" else Vector2.ZERO)
		await _until(func() -> bool: return remote != null and remote.position.distance_to(expected) < 4.0, deadline)
		_check(remote != null and remote.position.distance_to(expected) < 4.0,
			"상대 위치가 전달됨 (%s, 기대 %s)" % [remote.position if remote != null else "없음", expected])
		if role == "host":
			await _host_combat(main, remote, deadline)
		else:
			await _client_combat(main, deadline)
		_finish()

	## 참가자 옆에 늑대를 만들고, 참가자의 공격으로 죽는지 본 뒤 밤으로 넘기고 핵에 피해를 준다.
	## 끝나면 참가자가 나갈 때까지 기다린다 (참가자의 검사에 호스트 상태가 필요하다)
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
		var expected_hp := Balance.CORE_MAX_HP - CORE_HIT
		await _until(func() -> bool: return is_equal_approx(main.kingdom.core.hp, expected_hp), deadline)
		_check(is_equal_approx(main.kingdom.core.hp, expected_hp), "참가자: 왕국 핵 체력이 호스트와 같음 (%d)" % main.kingdom.core.hp)
		await _until(func() -> bool: return main.day_night.is_night(), deadline)
		_check(main.day_night.is_night(), "참가자: 호스트가 밤으로 넘기면 나도 밤")

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
