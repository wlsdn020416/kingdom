class_name PauseMenu
extends Control
## 게임 중 Esc 메뉴 (D-030). 다른 창이 하나도 열려 있지 않을 때 Esc로 열린다.
## 게임은 멈추지 않는다(멀티플레이에서 한 사람이 모두를 멈출 수 없으므로 혼자 플레이도 같게 한다).
## 그림은 다른 메뉴와 같은 MenuArt 판·문장·버튼을 쓴다.

const DESIGN_SIZE := Vector2(400, 384)
const QUIT_TEXT := "게임 종료"
const QUIT_CONFIRM_TEXT := "정말 종료할까요? 한 번 더"

var settings_panel := SettingsPanel.new()
var quit_button: Button
var _shell := PanelContainer.new()


func setup(settings: GameSettings) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = MenuArt.theme()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.025, 0.04, 0.055, 0.82)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	_shell.size = DESIGN_SIZE
	_shell.add_theme_stylebox_override("panel", MenuArt.panel(0))
	add_child(_shell)
	var canvas := Control.new()
	_shell.add_child(canvas)
	var crest := TextureRect.new()
	crest.texture = MenuArt.texture(MenuArt.CREST)
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(canvas, crest, Vector2((DESIGN_SIZE.x - 64) / 2.0, 20), Vector2(64, 64))
	var title := _label("메뉴", 26, MenuArt.TEXT)
	_place(canvas, title, Vector2(0, 90), Vector2(DESIGN_SIZE.x, 36))
	var note := _label("게임은 멈추지 않고 계속 진행됩니다", 13, MenuArt.MUTED)
	_place(canvas, note, Vector2(0, 126), Vector2(DESIGN_SIZE.x, 22))
	_place(canvas, _button("계속하기", hide), Vector2(60, 164), Vector2(280, 48))
	var settings_button := _button("설정", open_settings)
	var gear := TextureRect.new()
	gear.texture = SettingsPanel.icon("gear")
	gear.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gear.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(settings_button, gear, Vector2(18, 10), Vector2(28, 28))
	_place(canvas, settings_button, Vector2(60, 228), Vector2(280, 48))
	quit_button = _button(QUIT_TEXT, _on_quit)
	_place(canvas, quit_button, Vector2(60, 292), Vector2(280, 48))
	# 메뉴를 닫았다 열면 종료 확인을 처음부터 다시 받는다
	visibility_changed.connect(func() -> void:
		quit_button.text = QUIT_TEXT
		quit_button.remove_theme_color_override("font_color"))
	add_child(settings_panel)
	settings_panel.setup(settings)
	resized.connect(_layout)
	_layout()
	hide()


func open_settings() -> void:
	settings_panel.open()


## 잘못 눌러 판을 잃지 않게 두 번 눌러야 끈다
func _on_quit() -> void:
	if quit_button.text == QUIT_TEXT:
		quit_button.text = QUIT_CONFIRM_TEXT
		quit_button.add_theme_color_override("font_color", Color("e2a08a"))
		return
	Session.quit_game()


## 설정 창이 열려 있으면 그것만 닫는다
func close() -> void:
	if settings_panel.visible:
		settings_panel.hide()
	else:
		hide()


func _layout() -> void:
	var fit := maxf(0.1, minf((size.x - 32) / DESIGN_SIZE.x, (size.y - 32) / DESIGN_SIZE.y))
	fit = minf(fit, 1.5)  # 작은 메뉴라 큰 창에서 지나치게 커지지 않게 한다
	_shell.scale = Vector2.ONE * fit
	_shell.position = (size - DESIGN_SIZE * fit) / 2.0


func _button(text: String, on_pressed: Callable) -> Button:
	var button := UiKit.button(text, on_pressed)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_size_override("font_size", 18)
	return button


func _place(parent: Control, control: Control, at: Vector2, dimensions: Vector2) -> void:
	control.position = at
	control.size = dimensions
	parent.add_child(control)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
