class_name UiKit
extends RefCounted
## 패널 공통 모양. 나중에 Theme 리소스로 옮기기 전까지 색은 여기서 관리한다.

const BACKDROP := Color(0.03, 0.04, 0.035, 0.75)
const PANEL := Color("1b211c")
const BORDER := Color("3b4636")
const TEXT := Color("ece6d2")
const MUTED := Color("9ba28f")
const ACCENT := Color("e3b341")
const DANGER := Color("d4553a")


## root를 화면 전체를 덮는 대화상자로 만들고, 내용을 넣을 VBox를 돌려준다
static func dialog(root: Control, title: String, width := 560.0) -> VBoxContainer:
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = BACKDROP
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = width
	panel.add_theme_stylebox_override("panel", box_style(PANEL, 20))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(heading(title))
	return box


static func box_style(color: Color, margin := 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = BORDER
	style.set_border_width_all(2)
	style.set_content_margin_all(margin)
	return style


static func heading(text: String, font_size := 22, color := TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


static func note(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", MUTED)
	return label


static func button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(func() -> void: Events.ui_sound_requested.emit("click"))
	b.pressed.connect(on_pressed)
	return b
