class_name MeetingPanel
extends Control
## 전략회의 (T). 게임 전체 시간을 멈추고 지도에 핑을 찍는다.
## 열기·준비·재개는 MeetingSync가 정한다. 누가 열든 모두 멈추고, 모두 준비 완료하면 다 같이 재개한다 (D-019).
## 그림은 전체 지도 창(WorldMapPanel)과 같은 MenuArt 판·지도 액자·범례를 쓴다.

const RESUME_DELAY := 0.25
const DESIGN_SIZE := Vector2(1080, 640)
const FLAG_ICON := Rect2(32, 0, 32, 32)
const HOURGLASS_ICON := Rect2(64, 0, 32, 32)

var _map: MapState
var _commands: MapSync
var _meeting: MeetingSync
var _status: Label
var _pings: Label
var _ready_button: Button
var _opener := ""
var _closing := false
var _shell := PanelContainer.new()


## 핑 찍기·지우기는 MapSync, 준비 완료는 MeetingSync를 거친다 (참가자는 호스트에 요청)
func setup(map: MapState, commands: MapSync, meeting: MeetingSync) -> void:
	_map = map
	_commands = commands
	_meeting = meeting
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = MenuArt.theme()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.025, 0.04, 0.055, 0.94)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	_shell.size = DESIGN_SIZE
	_shell.add_theme_stylebox_override("panel", MenuArt.panel(0))
	add_child(_shell)
	var canvas := Control.new()
	_shell.add_child(canvas)
	_place(canvas, WorldMapPanel.icon(WorldMapPanel.ICONS, FLAG_ICON, 40), Vector2(24, 16), Vector2(40, 40))
	_place(canvas, WorldMapPanel.label("전략회의", 28, MenuArt.TEXT), Vector2(76, 17), Vector2(200, 40))
	_place(canvas, WorldMapPanel.label("게임 시간이 멈췄습니다 · 지도를 눌러 모일 곳과 목표를 표시하세요", 13, MenuArt.MUTED), Vector2(220, 30), Vector2(700, 24))
	var frame := WorldMapPanel.section(canvas, Vector2(24, 72), Vector2(552, 552))
	var view := MapView.new().setup(map, true)
	view.cell_clicked.connect(commands.add_ping)
	view.cell_clicked.connect(func(_cell: Vector2i) -> void: Events.ui_sound_requested.emit("map_ping"))
	_place(frame, view, Vector2(12, 12), Vector2(528, 528))
	var info := WorldMapPanel.section(canvas, Vector2(592, 72), Vector2(464, 552))
	_place(info, WorldMapPanel.icon(WorldMapPanel.ICONS, HOURGLASS_ICON, 32), Vector2(20, 18), Vector2(32, 32))
	_place(info, WorldMapPanel.label("회의 현황", 20, MenuArt.GOLD), Vector2(62, 20), Vector2(300, 30))
	_status = WorldMapPanel.label("", 16, MenuArt.TEXT)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(info, _status, Vector2(20, 62), Vector2(424, 76))
	_place(info, WorldMapPanel.rule(424), Vector2(20, 146), Vector2(424, 2))
	_place(info, WorldMapPanel.label("핑", 20, MenuArt.GOLD), Vector2(20, 160), Vector2(80, 30))
	_pings = WorldMapPanel.label("", 16, MenuArt.TEXT)
	_place(info, _pings, Vector2(70, 164), Vector2(370, 24))
	var note := WorldMapPanel.label("핑은 회의가 끝난 뒤에도 지도와 월드에 남습니다. 가득 차면 오래된 것부터 지워집니다.", 13, MenuArt.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(info, note, Vector2(20, 196), Vector2(424, 44))
	_place(info, WorldMapPanel.rule(424), Vector2(20, 248), Vector2(424, 2))
	_place(info, WorldMapPanel.label("지도 표식", 20, MenuArt.GOLD), Vector2(20, 262), Vector2(300, 30))
	var legend := Control.new()
	_place(info, legend, Vector2(0, 0), Vector2(464, 552))
	_add_compact_legend(legend, Vector2(20, 300))
	var clear := UiKit.button("핑 지우기", commands.clear_pings)
	clear.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(info, clear, Vector2(20, 488), Vector2(160, 44))
	_ready_button = UiKit.button("준비 완료  Enter", confirm)
	_ready_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ready_button.add_theme_color_override("font_color", MenuArt.GOLD)
	_place(info, _ready_button, Vector2(196, 488), Vector2(248, 44))
	resized.connect(_layout)
	_layout()
	hide()


## opener: 회의를 연 사람 이름, total: 준비해야 하는 인원
func open(opener: String, total: int) -> void:
	_closing = false
	_opener = opener
	show_status(0, total, false)
	show()
	get_tree().paused = true


func show_status(count: int, total: int, me_ready: bool) -> void:
	_status.text = "%s님이 연 회의\n%d명 중 %d명 준비 완료" % [_opener, total, count]
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


func _process(_delta: float) -> void:
	if visible:
		_pings.text = "%d / %d개" % [_map.pings.size(), MapState.MAX_PINGS]


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("confirm"):
		confirm()
		get_viewport().set_input_as_handled()


## 범례를 두 줄 간격으로 촘촘하게 (회의 창은 오른쪽 판이 좁다)
func _add_compact_legend(parent: Control, at: Vector2) -> void:
	for i in WorldMapPanel.LEGEND.size():
		var entry: Array = WorldMapPanel.LEGEND[i]
		var column := i % 2
		var top := at.y + (i / 2) * 40.0
		var left := at.x + column * 212.0
		var marker := WorldMapPanel.icon(MapView.ART, Rect2(96 + int(entry[0]) * MapView.MARKER_SIZE, 72, MapView.MARKER_SIZE, MapView.MARKER_SIZE), 28)
		_place(parent, marker, Vector2(left, top), Vector2(28, 28))
		_place(parent, WorldMapPanel.label(entry[1], 15, MenuArt.TEXT), Vector2(left + 38, top + 3), Vector2(170, 24))


func _layout() -> void:
	var fit := maxf(0.1, minf((size.x - 32) / DESIGN_SIZE.x, (size.y - 32) / DESIGN_SIZE.y))
	_shell.scale = Vector2.ONE * fit
	_shell.position = (size - DESIGN_SIZE * fit) / 2.0


func _place(parent: Control, control: Control, at: Vector2, dimensions: Vector2) -> void:
	control.position = at
	control.size = dimensions
	parent.add_child(control)
