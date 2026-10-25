class_name MeetingPanel
extends Control
## 전략회의 (T). 게임 전체 시간을 멈추고 지도에 핑을 찍는다.
## 열기·준비·재개는 MeetingSync가 정한다. 누가 열든 모두 멈추고, 모두 준비 완료하면 다 같이 재개한다 (D-019).

const RESUME_DELAY := 0.25

var _map: MapState
var _commands: MapSync
var _meeting: MeetingSync
var _status: Label
var _ready_button: Button
var _opener := ""
var _closing := false


## 핑 찍기·지우기는 MapSync, 준비 완료는 MeetingSync를 거친다 (참가자는 호스트에 요청)
func setup(map: MapState, commands: MapSync, meeting: MeetingSync) -> void:
	_map = map
	_commands = commands
	_meeting = meeting
	process_mode = Node.PROCESS_MODE_ALWAYS
	var box := UiKit.dialog(self, "전략회의", 520.0)
	box.add_child(UiKit.note("게임 시간이 멈췄습니다. 지도를 클릭하면 핑이 찍히고, 핑은 회의가 끝난 뒤에도 지도와 월드에 남습니다 (최대 %d개)." % MapState.MAX_PINGS))
	var view := MapView.new().setup(map, true)
	view.custom_minimum_size = Vector2(420, 420)
	view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	view.cell_clicked.connect(commands.add_ping)
	view.cell_clicked.connect(func(_cell: Vector2i) -> void: Events.ui_sound_requested.emit("map_ping"))
	box.add_child(view)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_status = UiKit.note("")
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_status)
	row.add_child(UiKit.button("핑 지우기", commands.clear_pings))
	_ready_button = UiKit.button("준비 완료 (Enter)", confirm)
	row.add_child(_ready_button)
	box.add_child(row)
	hide()


## opener: 회의를 연 사람 이름, total: 준비해야 하는 인원
func open(opener: String, total: int) -> void:
	_closing = false
	_opener = opener
	show_status(0, total, false)
	show()
	get_tree().paused = true


func show_status(count: int, total: int, me_ready: bool) -> void:
	_status.text = "%s님이 연 회의 · %d명 중 %d명 준비 완료" % [_opener, total, count]
	_ready_button.disabled = me_ready
	if me_ready:
		_status.text += " · 다른 사람을 기다리는 중"


func confirm() -> void:
	if not _closing and not _ready_button.disabled:
		_ready_button.disabled = true
		_meeting.confirm_ready()


## 모두 준비했다 (MeetingSync가 부른다)
func close() -> void:
	if _closing:
		return
	_closing = true
	_status.text = "모두 준비 완료 · 재개합니다"
	await get_tree().create_timer(RESUME_DELAY).timeout
	hide()
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("confirm"):
		confirm()
		get_viewport().set_input_as_handled()
