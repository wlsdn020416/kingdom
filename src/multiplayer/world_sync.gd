class_name WorldSync
extends Node
## 월드 변경 동기화 (D-017 3단계). 나무·바위·광석·상자는 호스트의 World만 바꾼다.
## 호스트 → 참가자: 오브젝트 체력·파괴, 그 사람이 받을 채집·상자 보상.
## 참가자 → 호스트: 상자 열기(E). 채집은 CombatSync가 참가자의 공격을 호스트에서 다시 실행해서 일어난다.
## RPC 경로가 모두에게 같아야 해서 Main이 이름 "WorldSync"로 붙인다. 혼자 플레이면 아무것도 하지 않는다.

const CHEST_REACH := 2  # 칸

var _net: NetSession
var _main: Main
## 호스트만: 게임 시작 뒤 바뀐 오브젝트 칸 -> 체력. 동기화가 시작되기 전의 변경도 모아 두었다가 한 번에 보낸다
var _changed := {}
var _flushed := false


func setup(net: NetSession, main: Main) -> void:
	_net = net
	_main = main
	if not _net.is_online():
		return
	if _net.is_host():
		_main.world.object_changed.connect(_on_object_changed)
	else:
		_main.player.hits_world = false


## setup()은 트리에 붙기 전이라 거기서 끄면 Godot이 _ready 때 _physics_process를 다시 켠다. 그래서 여기서 정한다
func _ready() -> void:
	set_physics_process(_net.is_online() and _net.is_host())


## 모두가 씬을 불러오기 전에 보낸 RPC는 닿지 않으므로, 시작 신호 뒤에 그동안의 변경을 보낸다
func _physics_process(_delta: float) -> void:
	if _flushed or not _main.player_sync.is_running():
		return
	_flushed = true
	set_physics_process(false)
	for cell: Vector2i in _changed:
		_object_state.rpc(cell, _changed[cell])


func _on_object_changed(cell: Vector2i, hp: float) -> void:
	_changed[cell] = hp
	if _flushed:
		_object_state.rpc(cell, hp)


# --- 호스트가 부르는 것 ---

func send_harvest(peer_id: int, object_id: int, cell: Vector2i, drops: Dictionary) -> void:
	if _net.is_online():
		_harvest.rpc_id(peer_id, object_id, cell, drops)


func send_chest(peer_id: int, reward: Dictionary, at: Vector2) -> void:
	if _net.is_online():
		_chest.rpc_id(peer_id, reward, at)


# --- 참가자가 부르는 것 ---

func request_open_chest(cell: Vector2i) -> void:
	_open_chest.rpc_id(1, cell)


# --- RPC ---

@rpc("authority", "reliable")
func _object_state(cell: Vector2i, hp: float) -> void:
	_main.world.apply_object_state(cell, hp)


@rpc("authority", "reliable")
func _harvest(object_id: int, cell: Vector2i, drops: Dictionary) -> void:
	_main.grant_harvest(object_id, cell, drops)


@rpc("authority", "reliable")
func _chest(reward: Dictionary, at: Vector2) -> void:
	_main.grant_chest(reward, at)


## 호스트가 아는 그 사람 위치 근처의 상자일 때만 연다 (요청을 믿지 않는다, AGENTS 5절).
## 위치는 초당 20번만 오므로 E 키 범위(주변 1칸)보다 1칸 더 봐준다
@rpc("any_peer", "reliable")
func _open_chest(cell: Vector2i) -> void:
	if not _net.is_host():
		return
	var sender := multiplayer.get_remote_sender_id()
	var opener := _main.player_sync.remote(sender)
	if opener == null or opener.is_dead:
		return
	var offset := (cell - _main.world.cell_at(opener.global_position)).abs()
	if maxi(offset.x, offset.y) <= CHEST_REACH:
		_main.world.open_chest(cell, sender)
