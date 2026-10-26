class_name SettingsPanel
extends Control
## 환경 설정 창 (D-030). 시작 화면의 설정 버튼과 게임 중 Esc 메뉴에서 연다.
## 바꾸는 즉시 적용하고, 닫을 때 파일에 저장한다. 값은 Session.settings(GameSettings)가 가진다.
## 그림은 다른 메뉴와 같은 MenuArt 판에 assets/ui/settings_ui의 섹션 아이콘·슬라이더·체크박스를 쓴다.

const DESIGN_SIZE := Vector2(880, 470)
const ART := preload("res://assets/ui/settings_ui.png")
const ICONS := {"sound": Rect2(0, 0, 32, 32), "screen": Rect2(32, 0, 32, 32), "effects": Rect2(64, 0, 32, 32), "gear": Rect2(96, 0, 32, 32)}
const TRACK := Rect2(0, 32, 64, 12)
const FILL := Rect2(64, 32, 64, 12)
const GRABBER := Rect2(128, 32, 16, 20)
const GRABBER_HOVER := Rect2(144, 32, 16, 20)
const UNCHECKED := Rect2(160, 32, 24, 24)
const CHECKED := Rect2(184, 32, 24, 24)
const SECTION_SIZE := Vector2(272, 310)

var _settings: GameSettings
var _controls := {}  # 설정 키 -> HSlider 또는 CheckBox
var _values := {}  # 설정 키 -> 슬라이더 옆 퍼센트 Label
var _shell := PanelContainer.new()
var _canvas := Control.new()


static func icon(id: String) -> AtlasTexture:
	return _atlas(ICONS[id])


func setup(settings: GameSettings) -> void:
	_settings = settings
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = _theme()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.025, 0.04, 0.055, 0.94)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	_shell.size = DESIGN_SIZE
	_shell.add_theme_stylebox_override("panel", MenuArt.panel(0))
	add_child(_shell)
	_shell.add_child(_canvas)
	_place(_canvas, _icon("gear", 40), Vector2(24, 16), Vector2(40, 40))
	_place(_canvas, _label("설정", 28, MenuArt.TEXT), Vector2(76, 17), Vector2(100, 40))
	_place(_canvas, _label("이 기기에만 저장됩니다 · 멀티플레이 상대에게는 영향이 없습니다", 13, MenuArt.MUTED), Vector2(150, 30), Vector2(560, 24))
	_place(_canvas, _button("닫기  Esc", hide), Vector2(760, 16), Vector2(96, 40))
	var sound := _section("sound", "소리", Vector2(24, 72))
	_add_slider(sound, 0, "master_volume", "전체 볼륨", 0.0, 1.0, 0.05)
	_add_slider(sound, 1, "music_volume", "음악", 0.0, 1.0, 0.05)
	_add_slider(sound, 2, "sfx_volume", "효과음", 0.0, 1.0, 0.05)
	var screen := _section("screen", "화면", Vector2(304, 72))
	_add_slider(screen, 0, "ui_scale", "UI 크기", GameSettings.UI_SCALE_MIN, GameSettings.UI_SCALE_MAX, 0.05)
	_add_check(screen, 0, "fullscreen", "전체 화면")
	_add_check(screen, 1, "vsync", "수직 동기화")
	var effects := _section("effects", "연출", Vector2(584, 72))
	_add_slider(effects, 0, "shake", "화면 흔들림", 0.0, 1.0, 0.1)
	_add_check(effects, 0, "damage_numbers", "피해 숫자 표시")
	_add_check(effects, 1, "hitstop", "타격 멈칫")
	_place(effects, _label("타격 멈칫은 혼자 플레이에서만 납니다", 12, MenuArt.MUTED, true), Vector2(20, 254), Vector2(232, 40))
	_place(_canvas, _button("기본값으로", _settings.reset), Vector2(24, 404), Vector2(160, 40))
	_place(_canvas, _label("바꾸는 즉시 적용 · 창을 닫으면 저장", 13, MenuArt.MUTED), Vector2(200, 412), Vector2(400, 24))
	_settings.changed.connect(_refresh)
	visibility_changed.connect(func() -> void:
		if not visible:
			_settings.save_file())
	resized.connect(_layout)
	_layout()
	hide()


func open() -> void:
	show()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		hide()
		get_viewport().set_input_as_handled()


## 아이콘·제목이 있는 안쪽 판. 안에 슬라이더·체크박스를 차례로 둔다
func _section(icon_id: String, title: String, at: Vector2) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", MenuArt.style(Rect2(0, 96, 128, 48), 0))
	_place(_canvas, panel, at, SECTION_SIZE)
	var body := Control.new()
	panel.add_child(body)
	_place(body, _icon(icon_id, 32), Vector2(18, 16), Vector2(32, 32))
	_place(body, _label(title, 20, MenuArt.GOLD), Vector2(60, 18), Vector2(180, 30))
	var rule := ColorRect.new()
	rule.color = Color(0.48, 0.57, 0.62, 0.35)
	_place(body, rule, Vector2(18, 58), Vector2(SECTION_SIZE.x - 36, 2))
	return body


## 슬라이더는 위에서부터, 체크박스는 슬라이더 아래부터 쌓는다
func _add_slider(body: Control, row: int, key: String, title: String, low: float, high: float, step: float) -> void:
	var top := 76.0 + row * 72.0
	_place(body, _label(title, 15, MenuArt.TEXT), Vector2(20, top), Vector2(160, 24))
	var value := _label("", 15, MenuArt.GOLD)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(body, value, Vector2(180, top), Vector2(72, 24))
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(func(amount: float) -> void:
		value.text = "%d%%" % roundi(amount * 100.0)
		_settings.set_value(key, amount))
	_place(body, slider, Vector2(20, top + 28), Vector2(232, 24))
	_controls[key] = slider
	_values[key] = value


func _add_check(body: Control, row: int, key: String, title: String) -> void:
	var sliders := 0
	for control: Control in _controls.values():
		if control is HSlider and control.get_parent() == body:
			sliders += 1
	var check := CheckBox.new()
	check.text = title
	check.focus_mode = Control.FOCUS_NONE
	check.add_theme_font_size_override("font_size", 15)
	check.toggled.connect(func(on: bool) -> void: _settings.set_value(key, on))
	_place(body, check, Vector2(16, 76.0 + sliders * 72.0 + row * 44.0), Vector2(240, 36))
	_controls[key] = check


## 설정 값으로 컨트롤을 맞춘다. 신호를 내지 않고 바꿔서 되돌림 고리를 만들지 않는다
func _refresh() -> void:
	for key: String in _controls:
		var control: Control = _controls[key]
		if control is Range:
			(control as Range).set_value_no_signal(_settings.get_value(key))
			(_values[key] as Label).text = "%d%%" % roundi(float(_settings.get_value(key)) * 100.0)
		else:
			(control as CheckBox).set_pressed_no_signal(_settings.get_value(key))


func _layout() -> void:
	var fit := maxf(0.1, minf((size.x - 32) / DESIGN_SIZE.x, (size.y - 32) / DESIGN_SIZE.y))
	_shell.scale = Vector2.ONE * fit
	_shell.position = (size - DESIGN_SIZE * fit) / 2.0


## 다른 메뉴 테마(MenuArt)에 픽셀 슬라이더·체크박스를 더한다
static func _theme() -> Theme:
	var result := MenuArt.theme()
	var track := _box(TRACK, 6.0)
	var fill := _box(FILL, 6.0)
	result.set_stylebox("slider", "HSlider", track)
	result.set_stylebox("grabber_area", "HSlider", fill)
	result.set_stylebox("grabber_area_highlight", "HSlider", fill)
	result.set_icon("grabber", "HSlider", _atlas(GRABBER))
	result.set_icon("grabber_highlight", "HSlider", _atlas(GRABBER_HOVER))
	result.set_icon("unchecked", "CheckBox", _atlas(UNCHECKED))
	result.set_icon("checked", "CheckBox", _atlas(CHECKED))
	result.set_constant("h_separation", "CheckBox", 12)
	var plain := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		result.set_stylebox(state, "CheckBox", plain)
	result.set_color("font_color", "CheckBox", MenuArt.TEXT)
	result.set_color("font_hover_color", "CheckBox", Color("fff0cf"))
	result.set_color("font_pressed_color", "CheckBox", MenuArt.TEXT)
	result.set_color("font_hover_pressed_color", "CheckBox", Color("fff0cf"))
	return result


static func _box(region: Rect2, margin: float) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = _atlas(region)
	for side in [SIDE_LEFT, SIDE_RIGHT]:
		box.set_texture_margin(side, 3.0)
	for side in [SIDE_TOP, SIDE_BOTTOM]:
		box.set_texture_margin(side, 3.0)
		box.set_content_margin(side, margin)
	return box


static func _atlas(region: Rect2) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = ART
	texture.region = region
	return texture


func _icon(id: String, pixels: int) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = icon(id)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2.ONE * pixels
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _button(text: String, on_pressed: Callable) -> Button:
	var button := UiKit.button(text, on_pressed)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	return button


func _place(parent: Control, control: Control, at: Vector2, dimensions: Vector2) -> void:
	control.position = at
	control.size = dimensions
	parent.add_child(control)


func _label(text: String, font_size: int, color: Color, wrap := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
