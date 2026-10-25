class_name CombatSync
extends Node
## 전투·시간·왕국 핵 동기화 (D-017 2단계). 적·웨이브·낮밤·핵 체력은 호스트만 계산한다.
## 호스트 → 참가자: 적 모습(EnemyPuppet), 적 죽음, 보스 탄, 낮밤 시간, 핵 체력, 처치 보상, 멸망.
## 참가자 → 호스트: 내 공격(호스트의 적에게 다시 실행), 핵 수리, 밤 건너뛰기(N).
## RPC 경로가 모두에게 같아야 해서 Main이 이름 "CombatSync"로 붙인다. 혼자 플레이면 아무것도 하지 않는다.

const SNAPSHOT_INTERVAL := 0.1  # 초당 10번
## 참가자가 보낸 공격 위치가 호스트가 아는 그 사람 위치에서 이보다 멀면 무시한다 (요청을 믿지 않는다, AGENTS 5절)
const MAX_ATTACK_OFFSET := 4.0 * Balance.TILE

var _net: NetSession
var _main: Main
var _puppets := {}  # 적 net_id -> EnemyPuppet (참가자만)
var _timer := 0.0


func setup(net: NetSession, main: Main) -> void:
	_net = net
	_main = main
	if not _net.is_online():
		set_physics_process(false)
		return
	if _net.is_host():
		Events.enemy_killed.connect(func(enemy: Node) -> void: _enemy_died.rpc((enemy as Enemy).net_id))
		Events.enemy_shot.connect(func(at: Vector2, params: Dictionary) -> void: _enemy_shot.rpc(at, params))
	else:
		_main.player.attacked.connect(func(kind: String, data: Dictionary) -> void: _replay_attack.rpc_id(1, kind, data))
		_main.day_night.follows_host = true


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


# --- 호스트가 부르는 것 ---

## 처치 보상을 그 사람에게 보낸다
func send_reward(peer_id: int, xp: int, resources: Dictionary, at: Vector2) -> void:
	if _net.is_online() and peer_id != multiplayer.get_unique_id():
		_reward.rpc_id(peer_id, xp, resources, at)


func send_game_over(summary: String) -> void:
	if _net.is_online() and _net.is_host():
		_game_over.rpc(summary)


# --- 참가자가 부르는 것 ---

func request_repair() -> void:
	_repair.rpc_id(1)


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


## 같은 탄을 내 화면에도 만든다. 내 캐릭터가 맞았는지는 내 화면에서 판정한다
@rpc("authority", "reliable")
func _enemy_shot(at: Vector2, params: Dictionary) -> void:
	Projectile.spawn(get_tree(), at, params)


@rpc("authority", "reliable")
func _reward(xp: int, resources: Dictionary, at: Vector2) -> void:
	_main.grant_reward(xp, resources, at)


@rpc("authority", "reliable")
func _game_over(summary: String) -> void:
	_main.show_game_over(summary)


## 참가자의 공격을 호스트의 적에게 다시 실행한다. 나무·바위 채집은 참가자 화면에서 이미 했으므로 건드리지 않는다
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
			params["hits_world"] = false
			params.erase("team")
			Projectile.spawn(get_tree(), origin, params)
		"swing":
			var weapon: Dictionary = data["weapon"]
			weapon["source"] = sender
			weapon["hits_world"] = false
			Melee.swing(get_tree(), origin, data["direction"], weapon)
		"blast":
			Melee.blast(get_tree(), origin, data["radius"], data["damage"], sender)


## 수리 비용은 참가자가 자기 화면에서 이미 냈다. 창고·가방 동기화는 3단계 (D-017)
@rpc("any_peer", "reliable")
func _repair() -> void:
	if _net.is_host():
		_main.kingdom.core.repair(Balance.REPAIR_AMOUNT)


@rpc("any_peer", "reliable")
func _skip_night() -> void:
	if _net.is_host():
		_main.day_night.skip_to_night()
