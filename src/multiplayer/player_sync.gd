class_name PlayerSync
extends Node
## 게임 씬 안의 플레이어 동기화 (D-017). 각자 자기 캐릭터를 움직이고, 위치·조준·애니메이션 칸을 서로 보낸다.
## 이동은 각자 결정한다(호스트 권한 목록에 없음, AGENTS 5절). 호스트의 적이 RemotePlayer를 때리면 주인에게 피해를 보낸다.
## RPC 경로가 모든 참가자에게서 같아야 해서 Main이 이름 "PlayerSync"로 붙인다.

const SEND_INTERVAL := 0.05  # 초당 20번

var _net: NetSession
var _local: Player
var _remote_parent: Node
var _remotes := {}  # peer id -> RemotePlayer
var _ready_peers := {}  # 호스트만: 게임 씬을 다 불러온 peer id
var _running := false
var _send_timer := 0.0
var _sent_ranks := {}


func setup(net: NetSession, local_player: Player, remote_parent: Node) -> void:
	_net = net
	_local = local_player
	_remote_parent = remote_parent
	_net.members_changed.connect(_on_members_changed)
	_local.attack_visual_requested.connect(_send_attack_visual)
	_local.passive_visual_requested.connect(_send_passive_visual)
	_local.weapon_effect_requested.connect(_send_weapon_effect)
	_local.progression.changed.connect(_send_ranks)


## 모든 사람이 게임 씬을 불러와야 서로의 PlayerSync로 RPC를 보낼 수 있다. 호스트가 모아서 시작 신호를 준다
func _ready() -> void:
	if not _net.is_online():
		return
	if multiplayer.is_server():
		_mark_ready(1)
	else:
		_scene_loaded.rpc_id(1)


func is_running() -> bool:
	return _running


func remote_count() -> int:
	return _remotes.size()


## 나를 포함한 플레이어 수 (화살탑 경험치 나누기)
func player_count() -> int:
	return _remotes.size() + 1


func remote_ids() -> Array:
	return _remotes.keys()


func remote(peer_id: int) -> RemotePlayer:
	return _remotes.get(peer_id)


func _physics_process(delta: float) -> void:
	if not _running:
		return
	_send_timer -= delta
	if _send_timer > 0.0:
		return
	_send_timer = SEND_INTERVAL
	var look := _local.appearance()
	_state.rpc(_local.global_position, _local.aim_direction, look["frame"], look["flip"], look["shown"], _local.is_dead, look["weapon"], look["gear"])


## 패시브를 배우면 단계를 모두에게 알린다. 경험치·레벨만 바뀐 경우는 보내지 않는다
func _send_ranks() -> void:
	if _running and _local.progression.ranks != _sent_ranks:
		_sent_ranks = _local.progression.ranks.duplicate()
		_ranks.rpc(_sent_ranks)


@rpc("any_peer", "reliable")
func _ranks(ranks: Dictionary) -> void:
	var actor := remote(multiplayer.get_remote_sender_id())
	if actor == null:
		return
	actor.ranks.clear()
	for id in ranks:
		if PassiveDB.PASSIVES.has(id):
			actor.ranks[id] = clampi(int(ranks[id]), 0, PassiveDB.max_rank(id))


func _send_attack_visual(id: String, direction: Vector2) -> void:
	if _running:
		_attack_visual.rpc(id, direction)


func _send_passive_visual(id: String, at: Vector2, radius: float, angle: float) -> void:
	if _running:
		_passive_visual.rpc(id, at, radius, angle)


@rpc("any_peer", "reliable")
func _passive_visual(id: String, at: Vector2, radius: float, angle: float) -> void:
	var actor := remote(multiplayer.get_remote_sender_id())
	if actor == null or PassiveEffectDB.effect_for(id) == "" or not at.is_finite() or not is_finite(radius) or not is_finite(angle):
		return
	if actor.global_position.distance_to(at) > 6.0 * Balance.TILE or radius <= 0.0 or radius > 10.0 * Balance.TILE:
		return
	CombatEffect.spawn(get_tree(), PassiveEffectDB.effect_for(id), at, radius / PassiveEffectDB.RADIUS, angle)


@rpc("any_peer", "reliable")
func _attack_visual(id: String, direction: Vector2) -> void:
	var actor := remote(multiplayer.get_remote_sender_id())
	if actor != null and WeaponArtDB.has_art(id):
		actor.weapon_visual.attack(id, direction, PassiveDB.value_in(actor.ranks, "sword_sweep"), 1.0 + PassiveDB.value_in(actor.ranks, "blade_reach") / 100.0)


func _mark_ready(peer_id: int) -> void:
	_ready_peers[peer_id] = true
	if _net.members.keys().all(func(id: int) -> bool: return _ready_peers.has(id)):
		_begin.rpc(_net.members)


@rpc("any_peer", "reliable")
func _scene_loaded() -> void:
	if multiplayer.is_server():
		_mark_ready(multiplayer.get_remote_sender_id())


@rpc("authority", "call_local", "reliable")
func _begin(members: Dictionary) -> void:
	var me := multiplayer.get_unique_id()
	for peer_id: int in members:
		if peer_id != me and not _remotes.has(peer_id):
			var remote := RemotePlayer.new().setup(peer_id, members[peer_id], _local.spawn_point)
			remote.name = "Remote%d" % peer_id
			remote.hurt.connect(func(amount: float) -> void: _hurt.rpc_id(peer_id, amount))
			_remote_parent.add_child(remote)
			_remotes[peer_id] = remote
	_running = true
	Events.message.emit("%d명이 함께 플레이합니다" % members.size())


@rpc("any_peer", "unreliable_ordered")
func _state(at: Vector2, aim: Vector2, frame: int, flip: bool, shown: bool, dead: bool, weapon: String, gear: Dictionary = {}) -> void:
	var remote: RemotePlayer = _remotes.get(multiplayer.get_remote_sender_id())
	if remote != null:
		remote.apply_state(at, aim, frame, flip, shown, dead, weapon, gear)


## 호스트의 적이 내 캐릭터를 때렸다. 무적·보호막·사망 판정은 내 Player가 한다
@rpc("authority", "reliable")
func _hurt(amount: float) -> void:
	_local.take_damage(amount)


func _on_members_changed() -> void:
	for peer_id: int in _remotes.keys():
		if not _net.members.has(peer_id):
			_remotes[peer_id].queue_free()
			_remotes.erase(peer_id)


func _send_weapon_effect(id: String, at: Vector2, scale: float, angle: float) -> void:
	if _running:
		_weapon_effect.rpc(id, at, scale, angle)


@rpc("any_peer", "reliable")
func _weapon_effect(id: String, at: Vector2, scale: float, angle: float) -> void:
	var actor := remote(multiplayer.get_remote_sender_id())
	if actor == null or id not in WeaponArtDB.PLAYER_EFFECTS or not at.is_finite() or not is_finite(scale) or not is_finite(angle):
		return
	if scale <= 0.0 or scale > CombatEffect.MAX_DISPLAY_SCALE or actor.global_position.distance_to(at) > Skills.MAX_TARGET_RANGE + 4.0 * Balance.TILE:
		return
	CombatEffect.spawn(get_tree(), id, at, scale, angle)
