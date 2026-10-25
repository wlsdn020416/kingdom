class_name MeetingSync
extends Node
## 전략회의 동기화 (D-019). 누가 열든 모두의 게임이 멈추고, 모든 플레이어가 준비 완료하면 다 같이 재개한다.
## 회의 상태(열림, 준비한 사람)는 호스트가 가진다. 회의 중에 나간 사람은 준비 인원에서 빠진다.
## RPC 경로가 모두에게 같아야 해서 Main이 이름 "MeetingSync"로 붙인다. 혼자 플레이면 내가 준비하면 바로 재개한다.
## 게임이 멈춰도 RPC는 도착하므로(일시정지는 처리 함수만 멈춘다) 이 노드는 따로 PROCESS_MODE_ALWAYS가 필요 없다.

var _net: NetSession
var _main: Main
## 호스트만: 회의 중인지, 준비한 peer id
var _active := false
var _ready := {}
## 모두: 마지막으로 받은 준비 현황 (테스트·화면 표시용)
var ready_count := 0


func setup(net: NetSession, main: Main) -> void:
	_net = net
	_main = main
	_net.members_changed.connect(_on_members_changed)


func _panel() -> MeetingPanel:
	return _main.hud.meeting_panel


# --- 입력·회의 창이 부르는 것 ---

func request_open() -> void:
	if not _net.is_online():
		_opened(_my_name(), 1)
	elif _net.is_host():
		_host_open(multiplayer.get_unique_id())
	else:
		_request_open.rpc_id(1)


func confirm_ready() -> void:
	if not _net.is_online():
		_closed()
	elif _net.is_host():
		_host_ready(multiplayer.get_unique_id())
	else:
		_request_ready.rpc_id(1)


func _my_name() -> String:
	return _net.members.get(multiplayer.get_unique_id(), "나")


# --- 호스트 ---

func _host_open(opener: int) -> void:
	if _active:
		return
	_active = true
	_ready.clear()
	_opened.rpc(_net.members.get(opener, "누군가"), _net.members.size())


func _host_ready(peer_id: int) -> void:
	if not _active:
		return
	_ready[peer_id] = true
	_host_check()


## 지금 명단 기준으로 준비 현황을 알리고, 모두 준비했으면 회의를 끝낸다
func _host_check() -> void:
	for peer_id: int in _ready.keys():
		if not _net.members.has(peer_id):
			_ready.erase(peer_id)
	var total := _net.members.size()
	if _ready.size() >= total:
		_active = false
		_closed.rpc()
	else:
		_status.rpc(_ready.size(), total, _ready.keys())


func _on_members_changed() -> void:
	if _active and _net.is_host():
		_host_check()


@rpc("any_peer", "reliable")
func _request_open() -> void:
	if _net.is_host():
		_host_open(multiplayer.get_remote_sender_id())


@rpc("any_peer", "reliable")
func _request_ready() -> void:
	if _net.is_host():
		_host_ready(multiplayer.get_remote_sender_id())


# --- 모두 ---

@rpc("authority", "call_local", "reliable")
func _opened(opener_name: String, total: int) -> void:
	ready_count = 0
	_main.open_meeting(opener_name, total)


@rpc("authority", "call_local", "reliable")
func _status(count: int, total: int, ready_ids: Array) -> void:
	ready_count = count
	_panel().show_status(count, total, ready_ids.has(multiplayer.get_unique_id()))


@rpc("authority", "call_local", "reliable")
func _closed() -> void:
	ready_count = 0
	_panel().close()
