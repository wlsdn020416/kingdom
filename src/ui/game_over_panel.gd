class_name GameOverPanel
extends Control
## 판이 끝난 화면: 왕국 멸망 또는 최종 보스 처치(승리, D-021). 처음으로 돌아가면 게임 씬을 버려서 진행 상황이 완전히 초기화된다.

var _title: Label
var _summary: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var box := UiKit.dialog(self, "왕국 멸망")
	_title = box.get_child(0) as Label
	_summary = UiKit.note("")
	box.add_child(_summary)
	box.add_child(UiKit.note("진행 상황이 모두 초기화됩니다."))
	box.add_child(UiKit.button("처음으로 (Enter)", Session.back_to_title))
	hide()


func open(summary: String, victory := false) -> void:
	_title.text = "승리!" if victory else "왕국 멸망"
	_title.add_theme_color_override("font_color", UiKit.ACCENT if victory else UiKit.DANGER)
	_summary.text = summary
	show()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("confirm"):
		get_viewport().set_input_as_handled()
		Session.back_to_title()
