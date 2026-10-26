class_name QuestSync
extends Node
## 낮 의뢰 동기화 (D-037). 호스트의 QuestBoard 목록이 바뀔 때마다 참가자에게 통째로 보낸다.
## 첫날 의뢰는 모두가 씬을 불러오기 전에 굴려지므로, 시작 신호 뒤에 한 번 더 보낸다.
## RPC 경로가 모두에게 같아야 해서 Main이 이름 "QuestSync"로 붙인다. 혼자 플레이면 아무것도 하지 않는다.

var _net: NetSession
var _main: Main
var _flushed := false


func setup(net: NetSession, main: Main) -> void:
	_net = net
	_main = main
	if _net.is_online() and _net.is_host():
		_main.quest_board.changed.connect(_send)


## setup()은 트리에 붙기 전이라 거기서 끄면 Godot이 _ready 때 _physics_process를 다시 켠다. 그래서 여기서 정한다
func _ready() -> void:
	set_physics_process(_net.is_online() and _net.is_host())


func _physics_process(_delta: float) -> void:
	if _flushed or not _main.player_sync.is_running():
		return
	_flushed = true
	set_physics_process(false)
	_send()


func _send() -> void:
	if _flushed:
		_quests.rpc(_main.quest_board.quests)


@rpc("authority", "reliable")
func _quests(list: Array) -> void:
	_main.quest_board.apply_remote(list)
