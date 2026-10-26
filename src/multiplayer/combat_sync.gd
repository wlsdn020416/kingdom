class_name CombatSync
extends Node
## 전투·시간·왕국 핵 동기화 (D-017 2단계). 적·웨이브·낮밤·핵 체력은 호스트만 계산한다.
## 호스트 → 참가자: 적 모습(EnemyPuppet), 적 죽음, 보스 탄, 낮밤 시간, 핵 체력, 처치 보상, 멸망.
## 참가자 → 호스트: 내 공격(호스트에서 다시 실행), 밤 건너뛰기(N). 핵 수리는 KingdomSync.
## RPC 경로가 모두에게 같아야 해서 Main이 이름 "CombatSync"로 붙인다. 혼자 플레이면 아무것도 하지 않는다.

const SNAPSHOT_INTERVAL := 0.1  # 초당 10번
const MAX_HITS_PER_SNAPSHOT := 48  # 피해 숫자는 적 모습과 함께 모아 보낸다. 넘치면 버린다 (연출일 뿐)
## 참가자가 보낸 공격 위치가 호스트가 아는 그 사람 위치에서 이보다 멀면 무시한다 (요청을 믿지 않는다, AGENTS 5절)
const MAX_ATTACK_OFFSET := 4.0 * Balance.TILE
const MAX_BLAST_RADIUS := 200.0  # 참가자가 보낸 범위 공격 반경 상한 (가장 큰 스킬보다 조금 크게)
const SOUND_REQUEST_INTERVAL_MS := 40

var _net: NetSession
var _main: Main
var _puppets := {}  # 적 net_id -> EnemyPuppet (참가자만)
var _timer := 0.0
var _pending_hits := []  # 호스트만: 다음 묶음에 보낼 피해 숫자
var hits_received := 0  # 참가자: 받은 피해 숫자 수 (테스트용)
var _sound_times := {}


func setup(net: NetSession, main: Main) -> void:
	_net = net
	_main = main
	if not _net.is_online():
		set_physics_process(false)
		return
	_main.player.sound_requested.connect(_relay_player_sound)
	if _net.is_host():
		_main.player.attacked.connect(_show_host_attack)
		Events.combat_effect_requested.connect(_share_effect)
		Events.world_sound_requested.connect(_relay_world_sound)
		Events.enemy_killed.connect(func(enemy: Node) -> void: _enemy_died.rpc((enemy as Enemy).net_id))
		Events.enemy_shot.connect(func(at: Vector2, params: Dictionary) -> void: _enemy_shot.rpc(at, params))
		Events.damage_dealt.connect(func(at: Vector2, amount: float, emphasis: bool, source: int) -> void:
			if _pending_hits.size() < MAX_HITS_PER_SNAPSHOT:
				_pending_hits.append([at, amount, emphasis, source]))
		Events.screen_shake_requested.connect(func(at: Vector2, strength: float) -> void:
			if _main.player_sync.is_running():
				_shake.rpc(at, strength))
	else:
		_main.player.attacked.connect(func(kind: String, data: Dictionary) -> void: _replay_attack.rpc_id(1, kind, data))
		_main.day_night.follows_host = true


func _show_host_attack(kind: String, data: Dictionary) -> void:
	if kind == "projectile" and _main.player_sync.is_running():
		_share_projectile(data["at"], data["params"], Enemy.SOURCE_LOCAL)


func _share_projectile(at: Vector2, params: Dictionary, owner_peer: int) -> void:
	for peer_id: int in _main.player_sync.remote_ids():
		if peer_id != owner_peer:
			_friendly_projectile.rpc_id(peer_id, at, params)


@rpc("authority", "reliable")
func _friendly_projectile(at: Vector2, params: Dictionary) -> void:
	params["visual_only"] = true
	params["hits_world"] = false
	params["team"] = Projectile.Team.PLAYER
	Projectile.spawn(get_tree(), at, params)


func _share_effect(id: String, at: Vector2, size: float, angle: float) -> void:
	if _main.player_sync.is_running():
		_effect.rpc(id, at, size, angle)


@rpc("authority", "unreliable")
func _effect(id: String, at: Vector2, size: float, angle: float) -> void:
	CombatEffect.spawn(get_tree(), id, at, size, angle)


## 호스트의 피해 숫자 묶음 [위치, 피해, 강조, 때린 사람 peer id] (D-023). 내가 때린 것이면 내 무기 타격감도 낸다 (D-029)
@rpc("authority", "reliable")
func _hits(hits: Array) -> void:
	hits_received += hits.size()
	for hit: Array in hits:
		_main.show_damage(hit[0], hit[1], hit[2], hit[3])


@rpc("authority", "unreliable")
func _shake(at: Vector2, strength: float) -> void:
	_main.shake_screen(at, strength)


func _relay_world_sound(id: String, at: Vector2) -> void:
	if _main.player_sync.is_running():
		_sound.rpc(id, at)


func _relay_player_sound(id: String, at: Vector2) -> void:
	if not _main.player_sync.is_running():
		return
	if _net.is_host():
		_sound.rpc(id, at)
	else:
		_player_sound.rpc_id(1, id)


## UI 소리와 상태 변경 권한은 보내지 않는다. 참가자 음원·좌표는 호스트가 허용 목록·그 사람 위치로 정한다.
@rpc("any_peer", "unreliable")
func _player_sound(id: String) -> void:
	if not _net.is_host() or not SoundDB.PLAYER_SOUNDS.has(id):
		return
	var sender := multiplayer.get_remote_sender_id()
	var actor := _main.player_sync.remote(sender)
	var now := Time.get_ticks_msec()
	if actor == null or now - int(_sound_times.get(sender, -100000)) < SOUND_REQUEST_INTERVAL_MS:
		return
	_sound_times[sender] = now
	_main.sound_effects.play(id, actor.global_position)
	for peer_id: int in _main.player_sync.remote_ids():
		if peer_id != sender:
			_sound.rpc_id(peer_id, id, actor.global_position)


@rpc("authority", "unreliable")
func _sound(id: String, at: Vector2) -> void:
	_main.sound_effects.play(id, at)


func _physics_process(delta: float) -> void:
	if not _net.is_host() or not _main.player_sync.is_running():
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = SNAPSHOT_INTERVAL
	var enemies := []
	for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
		enemies.append(enemy.appearance())
	var clock := _main.day_night
	_snapshot.rpc(enemies, clock.phase, clock.day, clock.time, _main.kingdom.core.hp)
	if not _pending_hits.is_empty():
		_hits.rpc(_pending_hits)
		_pending_hits = []


# --- 호스트가 부르는 것 ---

## 처치 보상을 그 사람에게 보낸다
func send_reward(peer_id: int, xp: int, resources: Dictionary, at: Vector2) -> void:
	if _net.is_online() and peer_id != multiplayer.get_unique_id():
		_reward.rpc_id(peer_id, xp, resources, at)


func send_game_over(summary: String, victory := false) -> void:
	if _net.is_online() and _net.is_host():
		_game_over.rpc(summary, victory)


# --- 참가자가 부르는 것 ---

func request_skip_night() -> void:
	_skip_night.rpc_id(1)


# --- RPC ---

@rpc("authority", "unreliable_ordered")
func _snapshot(enemies: Array, phase: int, day: int, time: float, core_hp: float) -> void:
	var seen := {}
	for look: Array in enemies:
		var id: int = look[0]
		seen[id] = true
		var puppet: EnemyPuppet = _puppets.get(id)
		if puppet == null:
			puppet = EnemyPuppet.new().setup(look[1], look[2])
			_main.get_node("Enemies").add_child(puppet)
			_puppets[id] = puppet
		puppet.apply(look[2], look[3], look[4], look[5], look[6])
	# 목록에서 빠진 적은 사라진 것 (멀어져서 없어짐, 아침에 타 버림)
	for id: int in _puppets.keys():
		if not seen.has(id):
			_puppets[id].queue_free()
			_puppets.erase(id)
	_main.day_night.apply_host_time(phase, day, time)
	_main.kingdom.core.set_synced_hp(core_hp)


@rpc("authority", "reliable")
func _enemy_died(net_id: int) -> void:
	var puppet: EnemyPuppet = _puppets.get(net_id)
	if puppet != null:
		_puppets.erase(net_id)
		puppet.die()


## 같은 탄을 내 화면에도 만든다. 내 캐릭터가 맞았는지는 내 화면에서 판정한다. 나무·바위 피해는 호스트의 탄만 준다
@rpc("authority", "reliable")
func _enemy_shot(at: Vector2, params: Dictionary) -> void:
	params["hits_world"] = false
	Projectile.spawn(get_tree(), at, params)


@rpc("authority", "reliable")
func _reward(xp: int, resources: Dictionary, at: Vector2) -> void:
	_main.grant_reward(xp, resources, at)


@rpc("authority", "reliable")
func _game_over(summary: String, victory: bool) -> void:
	_main.show_game_over(summary, victory)


## 참가자의 공격을 호스트 화면에서 다시 실행한다. 적 피해와 나무·바위·상자 채집이 모두 여기서 정해지고,
## 채집 보상은 source(보낸 사람)에게 간다. 참가자 화면의 공격은 월드를 건드리지 않는다 (Player.hits_world, D-017 3단계)
@rpc("any_peer", "reliable")
func _replay_attack(kind: String, data: Dictionary) -> void:
	if not _net.is_host():
		return
	var sender := multiplayer.get_remote_sender_id()
	var attacker := _main.player_sync.remote(sender)
	var origin: Vector2 = data.get("at", data.get("origin", Vector2.INF))
	if attacker == null or attacker.is_dead or attacker.global_position.distance_to(origin) > MAX_ATTACK_OFFSET:
		return
	match kind:
		"projectile":
			var params: Dictionary = data["params"]
			params["source"] = sender
			params["hits_world"] = true
			params["visual_only"] = false
			params.erase("team")
			Projectile.spawn(get_tree(), origin, params)
			_share_projectile(origin, params, sender)
		"swing":
			var weapon: Dictionary = data["weapon"]
			weapon["source"] = sender
			weapon["hits_world"] = true
			Melee.swing(get_tree(), origin, data["direction"], weapon)
		"blast":
			# 조준 지점 스킬(화살비·낙뢰·돌진 베기)은 center가 보낸 사람에게서 너무 멀면 버린다 (D-028)
			var center: Vector2 = data.get("center", origin)
			if center.distance_to(origin) > Skills.MAX_TARGET_RANGE + 1.0:
				return
			Melee.blast(get_tree(), center, minf(data["radius"], MAX_BLAST_RADIUS), data["damage"], sender,
				data.get("slow_factor", 1.0), data.get("slow_time", 0.0))


@rpc("any_peer", "reliable")
func _skip_night() -> void:
	if _net.is_host():
		_main.day_night.skip_to_night()
