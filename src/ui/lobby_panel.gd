class_name LobbyPanel
extends VBoxContainer
## 시작 화면 멀티플레이 팝업의 방 칸. Steam 방 만들기·친구 초대, 개발용 IP 접속, 참가자 명단을 보여준다.
## 접속은 NetSession 메서드만 호출한다. 게임 시작은 팝업의 "시작" 버튼이 맡는다(호스트일 때 모두 함께 시작).

const MAX_FRIENDS_SHOWN := 8  # 팝업이 화면 밖으로 넘치지 않게

var _net: NetSession
var _status: Label
var _members: Label
var _invite: Button
var _address: LineEdit
var _friends_title: Label
var _friends: VBoxContainer


func setup(net: NetSession) -> LobbyPanel:
	_net = net
	add_theme_constant_override("separation", 6)
	add_child(UiKit.heading("멀티플레이", 15, UiKit.ACCENT))
	var steam_row := _row()
	var host_steam := UiKit.button("Steam 방 만들기", _net.host_steam)
	host_steam.disabled = not _net.steam_ready()
	steam_row.add_child(host_steam)
	_invite = UiKit.button("친구 초대", _net.invite_friends)
	steam_row.add_child(_invite)
	steam_row.add_child(UiKit.button("나가기", _net.leave))
	add_child(UiKit.note("Steam 친구가 보낸 초대를 수락하면 자동으로 들어갑니다. 초대받는 친구도 이 게임을 켜 두어야 합니다."))
	# Steam 오버레이가 안 뜨는 실행(터미널·에디터)에서도 초대할 수 있게 온라인 친구를 직접 보여준다
	var friends_row := _row()
	_friends_title = UiKit.heading("온라인 Steam 친구", 13, UiKit.MUTED)
	friends_row.add_child(_friends_title)
	friends_row.add_child(UiKit.button("새로고침", _refresh_friends))
	_friends = VBoxContainer.new()
	add_child(_friends)
	var ip_row := _row()
	ip_row.add_child(UiKit.heading("개발용 IP", 13, UiKit.MUTED))
	_address = LineEdit.new()
	_address.text = "127.0.0.1"
	_address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ip_row.add_child(_address)
	ip_row.add_child(UiKit.button("열기", func() -> void: _net.host_enet()))
	ip_row.add_child(UiKit.button("참가", func() -> void: _net.join_enet(_address.text.strip_edges())))
	_status = UiKit.note("")
	add_child(_status)
	_members = UiKit.heading("", 13)
	add_child(_members)
	_net.members_changed.connect(_refresh)
	_net.status_changed.connect(func(_text: String) -> void: _refresh())
	_refresh()
	return self


## 내가 Steam 방의 호스트일 때만 친구 목록과 초대 버튼을 보여준다
func _refresh_friends() -> void:
	for child in _friends.get_children():
		child.queue_free()
	var hosting := _net.mode == NetSession.Mode.STEAM and _net.is_host()
	_friends_title.get_parent().visible = hosting
	_friends.visible = hosting
	if not hosting:
		return
	var friends := _net.online_friends()
	if friends.is_empty():
		_friends.add_child(UiKit.note("온라인인 Steam 친구가 없습니다."))
	for friend: Dictionary in friends.slice(0, MAX_FRIENDS_SHOWN):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var name_label := UiKit.heading(friend["name"], 13)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var friend_id: int = friend["id"]
		row.add_child(UiKit.button("초대", func() -> void: _net.invite_friend(friend_id)))
		_friends.add_child(row)


func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	return row


func _refresh() -> void:
	_status.text = _net.status_text
	_refresh_friends()
	_invite.disabled = _net.mode != NetSession.Mode.STEAM or not _net.is_host()
	if not _net.is_online():
		_members.text = "혼자 플레이 (방에 들어가지 않음)"
		return
	var names := PackedStringArray()
	for peer_id: int in _net.members:
		names.append(("%s (호스트)" if peer_id == 1 else "%s") % _net.members[peer_id])
	_members.text = "참가자 %d/%d: %s" % [_net.members.size(), NetSession.MAX_PLAYERS, ", ".join(names)]
	if not _net.is_host():
		_members.text += "\n호스트가 시작하기를 기다리는 중"
