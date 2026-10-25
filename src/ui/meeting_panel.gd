class_name MeetingPanel
extends Control
## 전략회의 (T). 게임 전체 시간을 멈추고 지도에 핑을 찍는다.
## 모든 플레이어가 준비 완료하면 재개한다. (지금은 1인이라 내가 준비하면 바로 재개)

const PLAYER_COUNT := 1
const RESUME_DELAY := 0.25

var _map: MapState
var _status: Label
var _closing := false


func setup(map: MapState) -> void:
	_map = map
	process_mode = Node.PROCESS_MODE_ALWAYS
	var box := UiKit.dialog(self, "전략회의", 520.0)
	box.add_child(UiKit.note("게임 시간이 멈췄습니다. 지도를 클릭하면 핑이 찍히고, 핑은 회의가 끝난 뒤에도 지도와 월드에 남습니다 (최대 %d개)." % MapState.MAX_PINGS))
	var view := MapView.new().setup(map, true)
	view.custom_minimum_size = Vector2(420, 420)
	view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	view.cell_clicked.connect(map.add_ping)
	box.add_child(view)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_status = UiKit.note("")
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_status)
	row.add_child(UiKit.button("핑 지우기", map.clear_pings))
	row.add_child(UiKit.button("준비 완료 (Enter)", confirm))
	box.add_child(row)
	hide()


func open() -> void:
	_closing = false
	_status.text = "참가자 %d명 중 0명 준비 완료" % PLAYER_COUNT
	show()
	get_tree().paused = true


func confirm() -> void:
	if _closing:
		return
	_closing = true
	_status.text = "참가자 %d명 중 %d명 준비 완료 · 재개합니다" % [PLAYER_COUNT, PLAYER_COUNT]
	await get_tree().create_timer(RESUME_DELAY).timeout
	hide()
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("confirm"):
		confirm()
		get_viewport().set_input_as_handled()
