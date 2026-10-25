extends Control
## 시작 화면. 로고와 싱글플레이·멀티플레이 버튼만 보여주고, 누르면 팝업에서 시드·접속 정보를 받는다.
## 싱글플레이 팝업: 시드 → 시작. 멀티플레이 팝업: 방 만들기·참가(LobbyPanel) + 시드 → 호스트가 시작(모두 같은 시드로).

const CONTROLS := [
	["WASD", "이동"],
	["마우스", "조준 / 좌클릭 기본 공격 (나무·바위·광석도 공격해서 채집)"],
	["Space", "대시 (이동 방향, 멈춰 있으면 조준 방향)"],
	["1-4", "장비 액티브 스킬 (스킬 있는 장비만 빈칸 없이 배치)"],
	["E", "상자 열기 · 장비 상자 · 제작대"],
	["B", "건설 메뉴 (고른 건물 설치: 좌클릭 설치 · 우클릭 철거 · Esc 종료)"],
	["R", "왕국 핵 근처에서 수리"],
	["I", "장비창"],
	["K", "패시브 (경험치로 배우기)"],
	["T", "전략회의 (게임 일시정지, 지도에 핑)"],
	["M", "전체 지도"],
	["N", "바로 밤으로 넘기기 (테스트용)"],
]
const LOGO := preload("res://assets/branding/Logo.png")
const LOGO_SIZE := Vector2(540, 360)  # 원본 1536×1024와 같은 비율
const MENU_BUTTON_SIZE := Vector2(320, 56)

var _sound_effects := SoundEffects.new()
var _single_popup := Control.new()
var _single_seed: LineEdit
var _multi_popup := Control.new()
var _multi_seed: LineEdit
var _multi_start: Button


func _ready() -> void:
	if Session.autostart_seed != "":
		var seed_text := Session.autostart_seed
		Session.autostart_seed = ""
		Session.start_game.call_deferred(seed_text)
		return
	add_child(_sound_effects)
	_sound_effects.setup(null, SoundDB.catalog())
	Events.ui_sound_requested.connect(func(id: String) -> void: _sound_effects.play(id))
	var background := ColorRect.new()
	background.color = Color("0f1311")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	_build_menu()
	_build_single_popup()
	_build_multi_popup()
	# Steam 초대를 수락해 방에 들어오면 멀티플레이 팝업을 연다
	Session.net.members_changed.connect(_on_net_changed)
	Session.net.status_changed.connect(func(_text: String) -> void: _on_net_changed())
	if Session.net.is_online():
		_open(_multi_popup)


func _build_menu() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(column)
	var logo := TextureRect.new()
	logo.texture = LOGO
	logo.custom_minimum_size = LOGO_SIZE
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(logo)
	column.add_child(_menu_button("싱글플레이", func() -> void: _open(_single_popup)))
	column.add_child(_menu_button("멀티플레이", func() -> void: _open(_multi_popup)))


func _menu_button(text: String, on_pressed: Callable) -> Button:
	var button := UiKit.button(text, on_pressed)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = MENU_BUTTON_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 22)
	return button


func _build_single_popup() -> void:
	add_child(_single_popup)
	var box := UiKit.dialog(_single_popup, "싱글플레이", 600.0)
	box.add_child(UiKit.note("낮에는 탐험하고 자원을 모아 왕국을 강화하고, 밤에는 몰려오는 적과 보스로부터 왕국을 지키세요. 왕국이 무너지면 새 월드에서 처음부터 다시 시작합니다."))
	if Session.last_result != "":
		box.add_child(UiKit.heading("지난 판: " + Session.last_result, 14, UiKit.DANGER))
	_single_seed = _seed_row(box, _start_single)
	box.add_child(_controls_grid())
	box.add_child(_popup_buttons(UiKit.button("시작", _start_single), _single_popup))
	_single_popup.hide()


func _build_multi_popup() -> void:
	add_child(_multi_popup)
	var box := UiKit.dialog(_multi_popup, "멀티플레이", 600.0)
	box.add_child(UiKit.note("방을 만들거나 참가한 뒤, 호스트가 시작하면 모두 같은 월드에서 시작합니다. 시드는 호스트의 것을 씁니다."))
	box.add_child(LobbyPanel.new().setup(Session.net))
	var steam_color := UiKit.ACCENT if Session.steam.available else UiKit.MUTED
	box.add_child(UiKit.heading("Steam: " + Session.steam.status_text, 13, steam_color))
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
