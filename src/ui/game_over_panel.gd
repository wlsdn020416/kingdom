class_name GameOverPanel
extends Control
## 왕국 멸망 화면. 처음으로 돌아가면 게임 씬을 버려서 진행 상황이 완전히 초기화된다.

var _summary: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var box := UiKit.dialog(self, "왕국 멸망")
	(box.get_child(0) as Label).add_theme_color_override("font_color", UiKit.DANGER)
	_summary = UiKit.note("")
	box.add_child(_summary)
	box.add_child(UiKit.note("진행 상황이 모두 초기화됩니다."))
	box.add_child(UiKit.button("처음으로 (Enter)", Session.back_to_title))
	hide()


func open(summary: String) -> void:
	_summary.text = summary
	show()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("confirm"):
		get_viewport().set_input_as_handled()
		Session.back_to_title()
