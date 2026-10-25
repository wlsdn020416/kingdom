class_name NetSession
extends Node
## 멀티플레이 접속과 대기실 (D-017). 호스트가 방을 열고, 참가자가 들어오고, 호스트가 시드와 함께 시작한다.
## 연결 방식은 Steam 로비(SteamMultiplayerPeer, 실제 플레이)와 IP 직접 접속(ENet, 개발·자동 테스트) 두 가지다.
## 접속 후의 RPC 코드는 어느 방식이든 같다. Session이 자식으로 들고 있어 씬이 바뀌어도 연결이 유지된다.

signal members_changed
## 접속 실패·끊김 등 사람이 봐야 하는 상태 문장
signal status_changed(text: String)

enum Mode { OFFLINE, ENET, STEAM }

const MAX_PLAYERS := 4
const DEFAULT_PORT := 24680
const STEAM_VIRTUAL_PORT := 0
const FRIEND_FLAG_IMMEDIATE := 4  # Steam 친구 목록의 "친구" (요청 중·차단 제외)
const PERSONA_STATE_OFFLINE := 0

var mode := Mode.OFFLINE
## peer id -> 표시 이름. 호스트가 정하고 모두에게 보낸다
var members := {}
var status_text := ""
var lobby_id := 0

var _steam: Object
var _pending_lobby_join := 0


func setup(steam: SteamService) -> void:
	_steam = steam.api()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(func() -> void: _fail("호스트에 접속하지 못했습니다"))
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	if _steam != null:
		_steam.connect("lobby_created", _on_lobby_created)
		_steam.connect("lobby_joined", _on_lobby_joined)
		_steam.connect("join_requested", _on_join_requested)
		# 친구 목록에서 "게임 참가"를 누르면 rich presence의 connect 문자열이 온다
		if _steam.has_signal("join_game_requested"):
			_steam.connect("join_game_requested", _on_join_game_requested)
		_check_launch_invite()


func is_online() -> bool:
	return mode != Mode.OFFLINE


func is_host() -> bool:
	return not is_online() or multiplayer.is_server()


func steam_ready() -> bool:
	return _steam != null


func host_steam() -> void:
	if _steam == null:
		_set_status("Steam이 연결되어 있지 않습니다")
		return
	leave()
	_set_status("Steam 방을 만드는 중...")
	_steam.createLobby(_steam_const("LOBBY_TYPE_FRIENDS_ONLY", 1), MAX_PLAYERS)


## 방을 만든 뒤 Steam 오버레이의 친구 초대 창을 연다.
## 오버레이는 Steam이 직접 실행한 게임에만 붙는다(터미널·에디터 실행, 특히 macOS는 대부분 안 붙음). 그때는 친구 목록 초대를 쓴다
func invite_friends() -> void:
	if _steam == null or lobby_id == 0:
		return
	if overlay_available():
		_steam.activateGameOverlayInviteDialog(lobby_id)
	else:
		_set_status("Steam 오버레이를 쓸 수 없습니다. 아래 친구 목록에서 초대하세요")


func overlay_available() -> bool:
	return _steam != null and _steam.has_method("isOverlayEnabled") and _steam.isOverlayEnabled()


## 지금 온라인인 Steam 친구 [{"id", "name"}] (이름 순). Steam이 없으면 []
func online_friends() -> Array:
	var friends := []
	if _steam == null or not _steam.has_method("getFriendCount"):
		return friends
	for i in _steam.getFriendCount(FRIEND_FLAG_IMMEDIATE):
		var friend_id: int = _steam.getFriendByIndex(i, FRIEND_FLAG_IMMEDIATE)
		if _steam.getFriendPersonaState(friend_id) != PERSONA_STATE_OFFLINE:
			friends.append({"id": friend_id, "name": _steam.getFriendPersonaName(friend_id)})
	friends.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["name"]).naturalnocasecmp_to(b["name"]) < 0)
	return friends


## 오버레이 없이 Steam 초대를 보낸다. 친구는 Steam 채팅에서 받고, 이 게임을 켜 둔 상태로 수락하면 들어온다
func invite_friend(friend_id: int) -> void:
	if _steam == null or lobby_id == 0 or not _steam.has_method("inviteUserToLobby"):
		return
	var sent: bool = _steam.inviteUserToLobby(lobby_id, friend_id)
	var name: String = _steam.getFriendPersonaName(friend_id)
	_set_status(("%s에게 초대를 보냈습니다" if sent else "%s에게 초대를 보내지 못했습니다") % name)


func join_steam(target_lobby: int) -> void:
	if _steam == null:
		return
	leave()
	_set_status("Steam 방에 들어가는 중...")
	_steam.joinLobby(target_lobby)


func host_enet(port := DEFAULT_PORT) -> void:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MAX_PLAYERS - 1)
	if error != OK:
		_fail("포트 %d로 방을 열지 못했습니다 (%s)" % [port, error_string(error)])
		return
	_use_peer(peer, Mode.ENET)
	_set_status("IP 방을 열었습니다 (포트 %d)" % port)


func join_enet(address: String, port := DEFAULT_PORT) -> void:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port)
	if error != OK:
		_fail("%s:%d 에 접속하지 못했습니다 (%s)" % [address, port, error_string(error)])
		return
	_use_peer(peer, Mode.ENET)
	_set_status("%s:%d 에 접속하는 중..." % [address, port])


func leave() -> void:
	if _steam != null and lobby_id != 0:
		_steam.leaveLobby(lobby_id)
		if _steam.has_method("clearRichPresence"):
			_steam.clearRichPresence()
	lobby_id = 0
	if multiplayer.multiplayer_peer != null and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	mode = Mode.OFFLINE
	members.clear()
	members_changed.emit()


## 호스트만: 모두에게 같은 시드로 게임을 시작하게 한다
func start_game(seed_text: String) -> void:
	if not is_online() or not multiplayer.is_server():
		return
	_start.rpc(seed_text if seed_text != "" else Session.random_seed())


func my_name() -> String:
	if _steam != null:
		return _steam.getPersonaName()
	return "플레이어 %d" % multiplayer.get_unique_id()


func _use_peer(peer: MultiplayerPeer, new_mode: int) -> void:
	multiplayer.multiplayer_peer = peer
	mode = new_mode
	members.clear()
	if multiplayer.is_server():
		members[1] = my_name()
		members_changed.emit()


func _set_status(text: String) -> void:
	status_text = text
	print("Net: " + text)
	status_changed.emit(text)


func _fail(text: String) -> void:
	leave()
	_set_status(text)


func _steam_const(name: String, fallback: int) -> int:
	if ClassDB.class_has_integer_constant("Steam", name):
		return ClassDB.class_get_integer_constant("Steam", name)
	return fallback


func _new_steam_peer() -> MultiplayerPeer:
	if not ClassDB.class_exists("SteamMultiplayerPeer"):
		return null
	var peer: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer")
	# 참가자끼리 직접 잇지 않고 호스트를 거쳐 주고받는다 (호스트 권한 구조, D-005)
	if "server_relay" in peer:
		peer.set("server_relay", true)
	return peer


# --- Steam 로비 ---

func _on_lobby_created(result: int, new_lobby_id: int) -> void:
	if result != _steam_const("RESULT_OK", 1):
		_fail("Steam 방을 만들지 못했습니다 (코드 %d)" % result)
		return
	var peer := _new_steam_peer()
	if peer == null or peer.call("create_host", STEAM_VIRTUAL_PORT) != OK:
		_fail("Steam 멀티플레이 연결을 만들지 못했습니다")
		_steam.leaveLobby(new_lobby_id)
		return
	lobby_id = new_lobby_id
	_steam.setLobbyData(lobby_id, "name", "%s의 왕국" % my_name())
	# 친구가 Steam 친구 목록에서 "게임 참가"로도 들어올 수 있게 한다
	if _steam.has_method("setRichPresence"):
		_steam.setRichPresence("connect", "+connect_lobby %d" % lobby_id)
	_use_peer(peer, Mode.STEAM)
	_set_status("Steam 방을 만들었습니다. 친구를 초대하세요")
	invite_friends()


func _on_lobby_joined(joined_lobby: int, _permissions: int, _locked, response: int) -> void:
	if response != _steam_const("CHAT_ROOM_ENTER_RESPONSE_SUCCESS", 1):
		_fail("Steam 방에 들어가지 못했습니다 (코드 %d)" % response)
		return
	var owner: int = _steam.getLobbyOwner(joined_lobby)
	# 방을 만든 호스트도 이 신호를 받는다. 호스트는 이미 _on_lobby_created에서 연결을 만들었다
	if owner == _steam.getSteamID():
		return
	var peer := _new_steam_peer()
	if peer == null or peer.call("create_client", owner, STEAM_VIRTUAL_PORT) != OK:
		_fail("호스트에 Steam으로 접속하지 못했습니다")
		return
	lobby_id = joined_lobby
	_use_peer(peer, Mode.STEAM)
	_set_status("%s의 방에 접속하는 중..." % _steam.getFriendPersonaName(owner))


## 게임을 켜 둔 채 친구 초대를 수락했을 때
func _on_join_requested(target_lobby: int, _friend_id: int) -> void:
	join_steam(target_lobby)


## Steam 친구 목록의 "게임 참가": connect 문자열 "+connect_lobby <id>"
func _on_join_game_requested(_friend_id: int, connect: String) -> void:
	var parts := connect.split(" ", false)
	var index := parts.find("+connect_lobby")
	if index >= 0 and index + 1 < parts.size():
		join_steam(int(parts[index + 1]))


## 게임이 꺼진 상태에서 초대를 수락하면 Steam이 "+connect_lobby <id>"를 붙여 실행한다
func _check_launch_invite() -> void:
	var args := OS.get_cmdline_args()
	var index := args.find("+connect_lobby")
	if index >= 0 and index + 1 < args.size():
		_pending_lobby_join = int(args[index + 1])
		join_steam.call_deferred(_pending_lobby_join)


# --- 접속자 명단 (호스트가 관리) ---

## 게임 중에 호스트가 나가면 시작 화면으로 돌아가 이유를 보여준다
func _on_server_disconnected() -> void:
	var in_game := get_tree().current_scene is Main
	_fail("호스트와 연결이 끊겼습니다")
	if in_game:
		Session.last_result = status_text
		Session.back_to_title()


func _on_connected_to_server() -> void:
	_set_status("접속했습니다. 호스트가 시작하기를 기다리는 중")
	_register.rpc_id(1, my_name())


func _on_peer_connected(_peer_id: int) -> void:
	pass  # 참가자가 _register로 이름을 보내면 명단에 넣는다


func _on_peer_disconnected(peer_id: int) -> void:
	if members.erase(peer_id):
		Events.message.emit("%d번 플레이어가 나갔습니다" % peer_id)
		if multiplayer.is_server():
			_set_members.rpc(members)
		members_changed.emit()


@rpc("any_peer", "reliable")
func _register(player_name: String) -> void:
	if not multiplayer.is_server():
		return
	members[multiplayer.get_remote_sender_id()] = player_name
	_set_members.rpc(members)
	members_changed.emit()


@rpc("authority", "reliable")
func _set_members(new_members: Dictionary) -> void:
	members = new_members
	members_changed.emit()


@rpc("authority", "call_local", "reliable")
func _start(seed_text: String) -> void:
	_set_status("게임을 시작합니다 (시드 %s)" % seed_text)
	Session.start_game(seed_text)
