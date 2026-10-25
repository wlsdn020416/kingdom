class_name Hud
extends CanvasLayer
## 화면 UI. 게임 상태를 매 프레임 읽어서 보여주기만 하고, 상태를 바꾸지 않는다.

const HINT := "B 건설 · I 장비 · E 상자 · R 수리 · T 전략회의 · M 지도 · N 밤으로 넘기기"
const MESSAGE_LIMIT := 4
const MESSAGE_TIME := 4.0
const MARGIN := 16.0
const MINIMAP_SIZE := 180.0

var equipment_panel: EquipmentPanel
var meeting_panel: MeetingPanel
var game_over_panel: GameOverPanel

var _main: Main
var _day_label: Label
var _core_bar: ProgressBar
var _hp_bar: ProgressBar
var _stock_label: Label
var _info_label: Label
var _messages: VBoxContainer
var _big_map: MapView


func setup(main: Main) -> void:
	_main = main
	_build_status_panel()
	_build_minimap()
	_build_messages()
	_build_action_bar()
	_build_hint()
	_big_map = MapView.new().setup(main.map_state)
	_big_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 60)
	_big_map.hide()
	add_child(_big_map)
	equipment_panel = EquipmentPanel.new()
	add_child(equipment_panel)
	equipment_panel.setup(main.player.equipment)
	meeting_panel = MeetingPanel.new()
	add_child(meeting_panel)
	meeting_panel.setup(main.map_state)
	game_over_panel = GameOverPanel.new()
	add_child(game_over_panel)
	Events.message.connect(show_message)


func toggle_big_map() -> void:
	_big_map.visible = not _big_map.visible


func close_big_map() -> void:
	_big_map.hide()


func show_message(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color("ffe9b0"))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	_messages.add_child(label)
	if _messages.get_child_count() > MESSAGE_LIMIT:
		_messages.get_child(0).queue_free()
	var tween := label.create_tween()
	tween.tween_interval(MESSAGE_TIME - 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(label.queue_free)


func _process(_delta: float) -> void:
	if _main == null:
		return
	var clock := _main.day_night
	_day_label.text = "DAY %d   %s %d초" % [clock.day, "밤 · 침공 중" if clock.is_night() else "낮", ceili(clock.time_left())]
	_day_label.add_theme_color_override("font_color", Color("9fb4ff") if clock.is_night() else Color("ffe08a"))
	var core := _main.kingdom.core
	_set_bar(_core_bar, core.hp, core.max_hp, "왕국 %d / %d" % [ceili(core.hp), core.max_hp])
	var player := _main.player
	var max_hp := player.equipment.max_hp()
	if player.is_dead:
		_set_bar(_hp_bar, 0, max_hp, "부활까지 %d초" % ceili(player.respawn_time_left()))
	else:
		_set_bar(_hp_bar, player.hp, max_hp, "체력 %d / %d" % [ceili(player.hp), max_hp])
	var stock := _main.kingdom.stock
	_stock_label.text = "나무 %d    돌 %d    금 %d" % [stock["wood"], stock["stone"], stock["gold"]]
	var terrain := _main.world.data.get_terrain(_main.world.cell_at(player.global_position))
	_info_label.text = "%s · 처치 %d" % [WorldData.TERRAIN_NAMES[terrain], _main.kills]


func _build_status_panel() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.box_style(Color(0.06, 0.07, 0.07, 0.8), 10))
	panel.position = Vector2(MARGIN, MARGIN)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	_day_label = UiKit.heading("", 16)
	box.add_child(_day_label)
	_core_bar = _make_bar(Color("c9873a"))
	box.add_child(_core_bar)
	_hp_bar = _make_bar(Color("c0453a"))
	box.add_child(_hp_bar)
	_stock_label = UiKit.heading("", 14)
	box.add_child(_stock_label)
	_info_label = UiKit.note("")
	box.add_child(_info_label)


func _build_minimap() -> void:
	var minimap := MapView.new().setup(_main.map_state)
	minimap.anchor_left = 1.0
	minimap.anchor_right = 1.0
	minimap.offset_left = -MARGIN - MINIMAP_SIZE
	minimap.offset_right = -MARGIN
	minimap.offset_top = MARGIN
	minimap.offset_bottom = MARGIN + MINIMAP_SIZE
	add_child(minimap)


func _build_messages() -> void:
	_messages = VBoxContainer.new()
	_messages.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_messages.anchor_left = 0.5
	_messages.anchor_right = 0.5
	_messages.offset_left = -320
	_messages.offset_right = 320
	_messages.offset_top = 24
	add_child(_messages)


func _build_action_bar() -> void:
	var bar := ActionBar.new()
	bar.setup(_main.player, _main.build_mode, _main.kingdom)
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = -260
	bar.offset_right = 260
	bar.offset_top = -100
	bar.offset_bottom = -40
	add_child(bar)


func _build_hint() -> void:
	var hint := UiKit.note(HINT)
	hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	hint.add_theme_color_override("font_color", UiKit.TEXT)
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 4)
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = MARGIN
	hint.offset_top = -MARGIN - 20
	hint.offset_bottom = -MARGIN
	add_child(hint)


func _make_bar(fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(240, 18)
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0, 0, 0, 0.6)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", background)
	var label := Label.new()
	label.name = "Text"
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	bar.add_child(label)
	return bar


func _set_bar(bar: ProgressBar, value: float, max_value: float, text: String) -> void:
	bar.max_value = max_value
	bar.value = value
	(bar.get_node("Text") as Label).text = text
