class_name LobbyPanel
extends VBoxContainer
## 시작 화면 멀티플레이 팝업의 방 칸. Steam 방 만들기·친구 초대, 개발용 IP 접속, 참가자 명단을 보여준다.
## 접속은 NetSession 메서드만 호출한다. 게임 시작은 팝업의 "시작" 버튼이 맡는다(호스트일 때 모두 함께 시작).

var _net: NetSession
var _status: Label
var _members: Label
var _invite: Button
var _address: LineEdit


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
	add_child(UiKit.note("Steam 친구가 보낸 초대를 수락하면 자동으로 들어갑니다."))
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


func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	return row


func _refresh() -> void:
	_status.text = _net.status_text
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
