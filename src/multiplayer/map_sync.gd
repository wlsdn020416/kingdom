class_name MapSync
extends Node
## 공유 지도 동기화 (D-018). 각자 자기 캐릭터 주변을 탐험하고, 새로 밝힌 칸을 모아 호스트를 거쳐 모두에게 전한다.
## 핑은 호스트의 MapState가 가진 목록을 모두가 따른다. 전략회의 창은 MapState 대신 이 노드의 add_ping·clear_pings를 부른다.
## RPC 경로가 모두에게 같아야 해서 Main이 이름 "MapSync"로 붙인다. 혼자 플레이면 MapState를 바로 부른다.

const SEND_INTERVAL := 0.25  # 걸으면서 밝힌 칸을 이만큼 모아서 보낸다

var _net: NetSession
var _main: Main
var _world: World
var _map: MapState
## 아직 보내지 않은 내 탐험 칸 (칸 번호). 동기화가 시작되기 전에 밝힌 칸도 모아 두었다가 보낸다
var _pending := PackedInt32Array()
var _timer := 0.0
var _pings_sent := false


func setup(net: NetSession, main: Main) -> void:
	_net = net
	_main = main
	_world = main.world
	_map = main.map_state
	if not _net.is_online():
		return
	_world.cells_explored.connect(_on_cells_explored)
	if _net.is_host():
		_map.pings_changed.connect(_send_pings)


## setup()은 트리에 붙기 전이라 거기서 끄면 Godot이 _ready 때 _physics_process를 다시 켠다. 그래서 여기서 정한다
func _ready() -> void:
	set_physics_process(_net.is_online())


func _physics_process(delta: float) -> void:
	if not _main.player_sync.is_running():
		return
	if _net.is_host() and not _pings_sent:
		_send_pings()
	_timer -= delta
	if _timer > 0.0 or _pending.is_empty():
		return
	_timer = SEND_INTERVAL
	if _net.is_host():
		_explored.rpc(_pending)
	else:
		_explored.rpc_id(1, _pending)
	_pending = PackedInt32Array()


func _on_cells_explored(cells: Array[Vector2i]) -> void:
	for cell in cells:
		_pending.append(_world.data.index(cell))


# --- 전략회의 창이 부르는 것 ---

func add_ping(cell: Vector2i) -> void:
	if _net.is_online() and not _net.is_host():
		_request_ping.rpc_id(1, cell)
	else:
		_map.add_ping(cell)


func clear_pings() -> void:
	if _net.is_online() and not _net.is_host():
		_request_clear_pings.rpc_id(1)
	else:
		_map.clear_pings()


# --- 호스트 ---

func _send_pings() -> void:
	if not _main.player_sync.is_running():
		return
	_pings_sent = true
	_pings.rpc(_map.pings)


@rpc("any_peer", "reliable")
func _request_ping(cell: Vector2i) -> void:
	if _net.is_host() and _world.data.in_bounds(cell):
		_map.add_ping(cell)


@rpc("any_peer", "reliable")
func _request_clear_pings() -> void:
	if _net.is_host():
		_map.clear_pings()


# --- RPC ---

## 다른 사람이 밝힌 칸. 호스트가 참가자에게서 받으면 나머지 참가자에게 새로 밝혀진 칸만 전한다
@rpc("any_peer", "reliable")
func _explored(indices: PackedInt32Array) -> void:
	var size := _world.data.size
	var cells: Array[Vector2i] = []
	for i in indices:
		if i >= 0 and i < size.x * size.y:
			cells.append(Vector2i(i % size.x, i / size.x))
	var changed := _world.mark_explored(cells)
	if not _net.is_host() or changed.is_empty():
		return
	var relay := PackedInt32Array()
	for cell in changed:
		relay.append(_world.data.index(cell))
	var sender := multiplayer.get_remote_sender_id()
	for peer_id: int in _main.player_sync.remote_ids():
		if peer_id != sender:
			_explored.rpc_id(peer_id, relay)


@rpc("authority", "reliable")
func _pings(cells: Array) -> void:
	_map.set_pings(cells)
