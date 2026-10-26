extends Control
## 시작 화면. 로고와 싱글플레이·멀티플레이 버튼만 보여주고, 누르면 팝업에서 시드·접속 정보를 받는다.
## 싱글플레이 팝업: 시드 → 시작. 멀티플레이 팝업: 방 만들기·참가(LobbyPanel) + 시드 → 호스트가 시작(모두 같은 시드로).

const CONTROLS := [
	["WASD", "이동"],
	["마우스", "조준 / 좌클릭 기본 공격 (나무·바위·광석도 공격해서 채집) / 우클릭 무기 스킬 (스킬 있는 무기만)"],
	["Space", "대시 (이동 방향, 멈춰 있으면 조준 방향)"],
	["1-4", "무기 외 장비 액티브 스킬 (스킬 있는 장비만 빈칸 없이 배치)"],
	["E", "상자 열기 · 장비 상자 · 제작대 · 순간이동 탑 · 왕국 핵 (제작대·방어 강화, 영토 확장, 수리)"],
	["B", "건설 메뉴 (벽·공성탑·생활 탭, 좌클릭 설치 · 우클릭 철거 · Esc 종료)"],
	["R", "왕국 핵 근처에서 수리"],
	["I", "장비창"],
	["K", "패시브 (레벨업 포인트로 배우기)"],
	["T", "전략회의 (게임 일시정지, 지도에 핑)"],
	["M", "전체 지도"],
	["N", "바로 밤으로 넘기기 (테스트용)"],
]
const LOGO := preload("res://assets/branding/Logo.png")
const LOGO_SIZE := Vector2(520, 347)  # 원본 로고의 비율을 유지한다
const MENU_BUTTON_SIZE := Vector2(360, 60)
const BACKGROUND := preload("res://assets/branding/title_background.png")
const MENU_DESIGN_SIZE := Vector2(560, 720)

var _sound_effects := SoundEffects.new()
var _menu_music := AudioStreamPlayer.new()
var _single_popup := Control.new()
var _single_seed: LineEdit
var _multi_popup := Control.new()
var _multi_seed: LineEdit
var _multi_start: Button
var _menu := Control.new()
var _background := TextureRect.new()
var _settings_panel := SettingsPanel.new()


func _ready() -> void:
	CursorArt.attach(self, false)
	if Session.autostart_seed != "":
		var seed_text := Session.autostart_seed
		Session.autostart_seed = ""
		Session.start_game.call_deferred(seed_text)
		return
	add_child(_sound_effects)
	_sound_effects.setup(null, SoundDB.catalog())
	_start_music()
	Events.ui_sound_requested.connect(func(id: String) -> void: _sound_effects.play(id))
	theme = MenuArt.theme()
	_background.texture = BACKGROUND
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)
	var shade := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.015, 0.025, 0.04, 0.62))
	gradient.set_color(1, Color(0.015, 0.025, 0.04, 0.0))
	var fade := GradientTexture2D.new()
	fade.gradient = gradient
	fade.fill_from = Vector2(0.0, 0.5)
	fade.fill_to = Vector2(0.65, 0.5)
	shade.texture = fade
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_build_menu()
	_build_single_popup()
	_build_multi_popup()
	_skin_popup(_single_popup)
	_skin_popup(_multi_popup)
	# 오른쪽 위 설정 버튼 (D-030). 창은 게임 중 Esc 메뉴와 같은 것을 쓴다
	var settings_button := UiKit.button("설정", _settings_panel.open)
	settings_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_button.custom_minimum_size = Vector2(96, 40)
	settings_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	settings_button.position = Vector2(-120, 20)
	settings_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	settings_button.custom_minimum_size = Vector2(112, 44)
	settings_button.position = Vector2(-136, 20)
	var gear := TextureRect.new()
	gear.texture = SettingsPanel.icon("gear")
	gear.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gear.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gear.position = Vector2(10, 10)
	gear.size = Vector2(24, 24)
	settings_button.add_child(gear)
	add_child(settings_button)
	add_child(_settings_panel)
	_settings_panel.setup(Session.settings)
	for popup in [_single_popup, _multi_popup]:
		popup.visibility_changed.connect(_update_menu_focus)
		_sound_effects.watch_panel(popup)
	resized.connect(_layout_menu)
	_layout_menu()
	# Steam 초대를 수락해 방에 들어오면 멀티플레이 팝업을 연다
	Session.net.members_changed.connect(_on_net_changed)
	Session.net.status_changed.connect(func(_text: String) -> void: _on_net_changed())
	if Session.net.is_online():
		_open(_multi_popup)


## 음악은 시작 화면이 소유한다. 팝업에서 이어지고 씬을 버리면 재생기도 함께 끝난다.
func _start_music() -> void:
	var stream := SoundDB.TITLE_MUSIC.duplicate() as AudioStreamOggVorbis
	stream.loop = true
	_menu_music.name = "MenuMusic"
	_menu_music.stream = stream
	_menu_music.volume_db = -60.0
	_menu_music.bus = GameSettings.MUSIC_BUS
	add_child(_menu_music)
	_menu_music.play()
	create_tween().tween_property(_menu_music, "volume_db", SoundDB.TITLE_MUSIC_VOLUME_DB, SoundDB.TITLE_MUSIC_FADE_SECONDS)


func _build_menu() -> void:
	_menu.size = MENU_DESIGN_SIZE
	_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_menu)
	var kicker := UiKit.heading("\ue000  함께 세우고, 끝까지 지키는 왕국", 14, MenuArt.GOLD)
	kicker.position = Vector2(60, 70)
	kicker.size.x = 440
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu.add_child(kicker)
	var logo := TextureRect.new()
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.texture = LOGO
	logo.position = Vector2(20, 100)
	logo.size = LOGO_SIZE
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.add_child(logo)
	var subtitle := UiKit.heading("낮에는 개척하고 · 밤에는 방어하세요", 15, MenuArt.TEXT)
	subtitle.position = Vector2(40, 445)
	subtitle.size.x = 480
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu.add_child(subtitle)
	var single := _menu_button("싱글플레이", func() -> void: _open(_single_popup))
	single.position = Vector2(100, 488)
	_add_button_icon(single, MenuArt.SINGLE_ICON)
	_menu.add_child(single)
	var multi := _menu_button("멀티플레이", func() -> void: _open(_multi_popup))
	multi.position = Vector2(100, 564)
	_add_button_icon(multi, MenuArt.MULTI_ICON)
	_menu.add_child(multi)
	var foot := UiKit.heading("탐험 · 건설 · 성장 · 침공 방어", 12, MenuArt.MUTED)
	foot.position = Vector2(60, 655)
	foot.size.x = 440
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu.add_child(foot)


func _menu_button(text: String, on_pressed: Callable) -> Button:
	var button := UiKit.button(text, on_pressed)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = MENU_BUTTON_SIZE
	button.size = MENU_BUTTON_SIZE
	button.add_theme_font_size_override("font_size", 20)
	button.focus_mode = Control.FOCUS_ALL
	return button


func _add_button_icon(button: Button, region: Rect2) -> void:
	var icon := TextureRect.new()
	icon.texture = MenuArt.texture(region)
	icon.position = Vector2(22, 14)
	icon.size = Vector2(32, 32)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	var arrow := TextureRect.new()
	arrow.texture = MenuArt.texture(MenuArt.CHEVRON)
	arrow.position = Vector2(MENU_BUTTON_SIZE.x - 36, 22)
	arrow.size = Vector2(16, 16)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(arrow)


func _layout_menu() -> void:
	var fit := minf(size.x / 1280.0, size.y / MENU_DESIGN_SIZE.y)
	_menu.scale = Vector2.ONE * fit
	_menu.position = Vector2(maxf(0.0, (size.x - 1280.0 * fit) / 2.0), (size.y - MENU_DESIGN_SIZE.y * fit) / 2.0)


func _skin_popup(popup: Control) -> void:
	for node in popup.find_children("*", "PanelContainer", true, false):
		(node as PanelContainer).add_theme_stylebox_override("panel", MenuArt.panel(24))


func _update_menu_focus() -> void:
	if not is_instance_valid(_menu):
		return
	var popup_open := _single_popup.visible or _multi_popup.visible
	for node in _menu.find_children("*", "Button", true, false):
		(node as Button).focus_mode = Control.FOCUS_NONE if popup_open else Control.FOCUS_ALL


func _build_single_popup() -> void:
	add_child(_single_popup)
	var box := UiKit.dialog(_single_popup, "싱글플레이", 680.0)
	box.add_child(UiKit.note("낮에는 탐험하고 자원을 모아 왕국을 강화하고, 밤에는 몰려오는 적과 보스로부터 왕국을 지키세요. 왕국이 무너지면 새 월드에서 처음부터 다시 시작합니다."))
	if Session.last_result != "":
		box.add_child(UiKit.heading("지난 판: " + Session.last_result, 14, UiKit.DANGER))
	_single_seed = _seed_row(box, _start_single)
	box.add_child(_controls_grid())
	box.add_child(_popup_buttons(UiKit.button("시작", _start_single), _single_popup))
	_single_popup.hide()


func _build_multi_popup() -> void:
	add_child(_multi_popup)
	var box := UiKit.dialog(_multi_popup, "멀티플레이", 680.0)
	box.add_child(UiKit.note("방을 만들거나 참가한 뒤, 호스트가 시작하면 모두 같은 월드에서 시작합니다. 시드는 호스트의 것을 씁니다."))
	box.add_child(LobbyPanel.new().setup(Session.net))
	var steam_color := UiKit.ACCENT if Session.steam.available else UiKit.MUTED
	var steam_note := UiKit.note("Steam: " + Session.steam.status_text)
	steam_note.add_theme_color_override("font_color", steam_color)
	box.add_child(steam_note)
	_multi_seed = _seed_row(box, _start_multi)
	_multi_start = UiKit.button("시작", _start_multi)
	box.add_child(_popup_buttons(_multi_start, _multi_popup))
	_multi_popup.hide()
	_refresh_multi()


func _seed_row(box: VBoxContainer, on_submit: Callable) -> LineEdit:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(UiKit.heading("월드 시드", 14, UiKit.MUTED))
	var input := LineEdit.new()
	input.text = Session.random_seed()
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.text_submitted.connect(func(_text: String) -> void: on_submit.call())
	row.add_child(input)
	box.add_child(row)
	return input


func _popup_buttons(start: Button, popup: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_END
	start.alignment = HORIZONTAL_ALIGNMENT_CENTER
	start.custom_minimum_size.x = 110
	var close := UiKit.button("닫기 (Esc)", popup.hide)
	close.alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(close)
	row.add_child(start)
	return row


func _controls_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	for entry in CONTROLS:
		grid.add_child(UiKit.heading(entry[0], 13, UiKit.ACCENT))
		grid.add_child(UiKit.heading(entry[1], 13))
	return grid


func _open(popup: Control) -> void:
	_single_popup.hide()
	_multi_popup.hide()
	popup.show()
	(_single_seed if popup == _single_popup else _multi_seed).grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and (_single_popup.visible or _multi_popup.visible):
		_single_popup.hide()
		_multi_popup.hide()
		get_viewport().set_input_as_handled()


func _on_net_changed() -> void:
	_refresh_multi()
	if Session.net.is_online() and not _multi_popup.visible:
		_open(_multi_popup)


## 시작은 방의 호스트만 할 수 있다. 참가자는 호스트가 시작하기를 기다린다
func _refresh_multi() -> void:
	var net := Session.net
	_multi_start.disabled = not (net.is_online() and net.is_host())
	_multi_seed.editable = not net.is_online() or net.is_host()


## 방에 들어가 있었다면 나가고 혼자 시작한다
func _start_single() -> void:
	if Session.net.is_online():
		Session.net.leave()
	Session.start_game(_single_seed.text.strip_edges())


func _start_multi() -> void:
	if Session.net.is_online() and Session.net.is_host():
		Session.net.start_game(_multi_seed.text.strip_edges())
