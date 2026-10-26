class_name Hud
extends CanvasLayer
## 화면 UI. 게임 상태를 매 프레임 읽어서 보여주기만 하고, 상태를 바꾸지 않는다.

const HINT := "B 건설 · I 장비 · K 패시브 · E 상자·장비 상자·제작대 · R 수리 · T 전략회의 · M 지도 · N 밤으로 넘기기"
const MESSAGE_LIMIT := 4
const MESSAGE_TIME := 4.0
const MARGIN := 16.0
const MINIMAP_SIZE := 192.0
const MINIMAP_HEIGHT := 224.0
const BAG_GAP := 10.0
const STATUS_WIDTH := 276.0
const RESOURCE_COLUMNS := 3
const RESOURCE_ICON_SIZE := 24
const MATERIAL_TEXTURE := preload("res://assets/ui/material_icons.png")
const MATERIAL_ORDER := EquipmentPanel.MATERIAL_ORDER


## 시간 규칙은 소유하지 않고 전달받은 하루의 진행만 그린다.
class ClockFace extends Control:
	var cycle := 0.0
	var night := false


	func _init() -> void:
		custom_minimum_size = Vector2(76, 76)
		mouse_filter = Control.MOUSE_FILTER_PASS


	func _draw() -> void:
		var center := size * 0.5
		draw_circle(center + Vector2(0, 2), 35, Color("10151d"))
		draw_circle(center, 34, Color("4c5969"))
		draw_circle(center, 31, Color("151e2b"))
		draw_arc(center, 27, PI, TAU, 40, Color("ddba70"), 4)
		draw_arc(center, 27, 0, PI, 40, Color("768cce"), 4)
		for tick: int in range(12):
			var direction := Vector2.from_angle(tick * TAU / 12.0)
			draw_line(center + direction * 20, center + direction * 23, Color("b4b7b3"), 1)
		var sun := center + Vector2(0, -14)
		draw_circle(sun, 4, Color("ffe09a"))
		var moon := center + Vector2(0, 14)
		draw_circle(moon, 4, Color("b8c9ff"))
		draw_circle(moon + Vector2(2, -2), 3.5, Color("151e2b"))
		var hand := Vector2.from_angle(PI + cycle * TAU)
		var color := Color("b8c9ff") if night else Color("ffe09a")
		draw_line(center - hand * 5, center + hand * 23, Color("10151d"), 5)
		draw_line(center - hand * 4, center + hand * 23, color, 2)
		draw_circle(center, 3, color)


## 재료 칸 점유율을 읽기만 한다. 소량의 서로 다른 재료도 각자 한 칸을 쓰는 실제 가방 규칙과 같다.
class BagGauge extends Control:
	signal activated
	const WIDTH := 96.0
	const HEIGHT := 84.0
	const WARNING_RATIO := 0.8
	var used := 0
	var capacity := 1
	var ratio := 0.0
	var _inventory: Inventory


	func setup(inventory: Inventory) -> void:
		_inventory = inventory
		theme = MenuArt.theme()
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_refresh()


	func _process(_delta: float) -> void:
		if used != _inventory.used_slots() or capacity != _inventory.capacity():
			_refresh()


	func _refresh() -> void:
		used = _inventory.used_slots()
		capacity = _inventory.capacity()
		ratio = clampf(float(used) / maxi(1, capacity), 0.0, 1.0)
		tooltip_text = "재료 가방 %d / %d칸 · %d칸 남음\n같은 재료 %d개가 한 칸을 씁니다.\n성 근처에서 공용 창고로 자동 입고됩니다.\n클릭: 가방·창고 재료 보기" % [used, capacity, maxi(0, capacity - used), Balance.STACK_SIZE]
		queue_redraw()


	func _draw() -> void:
		var state := 2 if used >= capacity else 1 if ratio >= WARNING_RATIO else 0
		var accent := Color("db7559") if state == 2 else MenuArt.GOLD if state == 1 else Color("94b99a")
		draw_style_box(UiKit.box_style(Color(0.04, 0.065, 0.085, 0.94), 5), Rect2(Vector2.ZERO, size))
		var font := get_theme_default_font()
		draw_string(font, Vector2(18, 15), "재료 가방", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MenuArt.GOLD)
		draw_texture_rect_region(MapView.ART, Rect2(0, 16, 48, 64), Rect2(96 + state * 48, 0, 48, 64))
		draw_rect(Rect2(14, 58, floorf(20.0 * ratio), 5), accent)
		for i in 4:
			draw_line(Vector2(18 + i * 4, 58), Vector2(18 + i * 4, 63), Color("101c27"), 1)
		draw_string(font, Vector2(44, 43), "%d/%d칸" % [used, capacity], HORIZONTAL_ALIGNMENT_CENTER, 50, 12, MenuArt.TEXT)
		draw_string(font, Vector2(44, 61), "가득 참" if state == 2 else "%d%%" % roundi(ratio * 100.0), HORIZONTAL_ALIGNMENT_CENTER, 50, 11, accent)


	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			activated.emit()
			accept_event()


var equipment_panel: EquipmentPanel
var storage_panel: StoragePanel
var build_menu: BuildMenu
var crafting_panel: CraftingPanel
var teleport_panel: TeleportPanel
var kingdom_panel: KingdomPanel
var pause_menu: PauseMenu
var threat_banner := ThreatBanner.new()
var passive_panel: PassivePanel
var meeting_panel: MeetingPanel
var game_over_panel: GameOverPanel

var _bag_gauge: BagGauge
var _minimap: MapView
var _main: Main
var _day_label: Label
var _core_bar: ProgressBar
var _hp_bar: ProgressBar
var _status_panel: PanelContainer
var _clock_face: ClockFace
var _phase_label: Label
var _resource_toggle: Button
var _resource_drawer: VBoxContainer
var _resource_scroll: ScrollContainer
var _bag_label: Label
var _resource_counts: Dictionary = {}
var _messages: VBoxContainer
var _big_map: WorldMapPanel
var _action_bar: ActionBar
var _progression_hud: ProgressionHud


func setup(main: Main) -> void:
	_main = main
	_build_status_panel()
	_build_minimap()
	_build_messages()
	_build_action_bar()
	_build_hint()
	_big_map = WorldMapPanel.new()
	add_child(_big_map)
	_big_map.setup(main.map_state, main.day_night)
	equipment_panel = EquipmentPanel.new()
	add_child(equipment_panel)
	equipment_panel.setup(main.player.equipment, main.player.inventory)
	storage_panel = StoragePanel.new()
	add_child(storage_panel)
	storage_panel.setup(main.kingdom, main.player, main.kingdom_sync)
	build_menu = BuildMenu.new()
	add_child(build_menu)
	build_menu.setup(main.build_mode, main.kingdom, main.player)
	crafting_panel = CraftingPanel.new()
	add_child(crafting_panel)
	crafting_panel.setup(main.kingdom, main.player, main.kingdom_sync)
	add_child(threat_banner)
	threat_banner.setup(main)
	teleport_panel = TeleportPanel.new()
	add_child(teleport_panel)
	teleport_panel.setup(main.kingdom, main.world, main.player, main.map_state)
	kingdom_panel = KingdomPanel.new()
	add_child(kingdom_panel)
	kingdom_panel.setup(main.kingdom, main.player, main.kingdom_sync)
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	pause_menu.setup(Session.settings)
	passive_panel = PassivePanel.new()
	add_child(passive_panel)
	passive_panel.setup(main.player.progression)
	_progression_hud.passive_requested.connect(passive_panel.toggle)
	meeting_panel = MeetingPanel.new()
	add_child(meeting_panel)
	meeting_panel.setup(main.map_state, main.map_sync, main.meeting_sync)
	game_over_panel = GameOverPanel.new()
	add_child(game_over_panel)
	Events.message.connect(show_message)


func toggle_big_map() -> void:
	_big_map.visible = not _big_map.visible


func is_big_map_open() -> bool:
	return _big_map.visible


## 닫았으면 true (열려 있었음)
func close_big_map() -> bool:
	var was_open := _big_map.visible
	_big_map.hide()
	return was_open


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
	_day_label.text = "%d일차" % clock.day
	_phase_label.text = "밤 · 침공 중" if clock.is_night() else "낮 · 탐험 시간"
	_phase_label.add_theme_color_override("font_color", Color("b8c9ff") if clock.is_night() else Color("ffe09a"))
	var duration := Balance.NIGHT_LENGTH if clock.is_night() else Balance.DAY_LENGTH
	_clock_face.cycle = (0.5 if clock.is_night() else 0.0) + clampf(clock.time / duration, 0.0, 1.0) * 0.5
	_clock_face.night = clock.is_night()
	_clock_face.tooltip_text = "다음 %s까지 %d초" % ["낮" if clock.is_night() else "밤", maxi(0, ceili(clock.time_left()))]
	_clock_face.queue_redraw()
	var core := _main.kingdom.core
	_set_bar(_core_bar, core.hp, core.max_hp, "성 %d / %d" % [ceili(core.hp), core.max_hp])
	var player := _main.player
	var max_hp := player.max_hp()
	if player.is_dead:
		_set_bar(_hp_bar, 0, max_hp, "부활까지 %d초" % ceili(player.respawn_time_left()))
	else:
		_set_bar(_hp_bar, player.hp, max_hp, "내 체력 %d / %d" % [ceili(player.hp), max_hp])
	if _resource_drawer.visible:
		_refresh_resources()


## 재화 버튼 위에서 누른 좌클릭이 폴링 기반 기본 공격으로도 처리되지 않게 한다.
func is_pointer_over_status(at: Vector2 = Vector2.INF) -> bool:
	var pointer := _status_panel.get_global_mouse_position() if at == Vector2.INF else at
	return _status_panel.get_global_rect().has_point(pointer) or _bag_gauge.get_global_rect().has_point(pointer) or _action_bar.is_pointer_over_bar(_action_bar.get_global_transform().affine_inverse() * pointer)


func _refresh_resources() -> void:
	var room := maxf(80.0, get_viewport().get_visible_rect().size.y - _resource_scroll.global_position.y - 48.0)
	var drawer_height := minf(_resource_drawer.get_combined_minimum_size().y, room)
	if not is_equal_approx(_resource_scroll.custom_minimum_size.y, drawer_height):
		_resource_scroll.custom_minimum_size.y = drawer_height
		_resource_scroll.reset_size()
		_status_panel.reset_size()
	var bag := _main.player.inventory
	_bag_label.text = "내 가방  %d / %d칸" % [bag.used_slots(), bag.capacity()]
	var sources: Dictionary = {"bag": bag.amounts(), "stock": _main.kingdom.stock}
	for source: String in sources:
		var amounts: Dictionary = sources[source]
		for kind: String in MATERIAL_ORDER:
			var label: Label = _resource_counts[source][kind]
			var amount: int = amounts.get(kind, 0)
			label.text = str(amount)
			label.get_parent().modulate.a = 1.0 if amount > 0 else 0.4


func _toggle_resources(open: bool) -> void:
	Events.ui_sound_requested.emit("click")
	_resource_drawer.visible = open
	_resource_scroll.visible = open
	_resource_toggle.text = "재화  ▴" if open else "재화  ▾"
	_resource_toggle.tooltip_text = "재화 접기" if open else "가방·창고 재화 펼치기"
	if open:
		_refresh_resources()
	# Container는 접은 자식의 이전 높이를 유지하므로 최소 크기로 되돌린다.
	_status_panel.reset_size()


func _build_status_panel() -> void:
	_status_panel = PanelContainer.new()
	_status_panel.add_theme_stylebox_override("panel", UiKit.box_style(Color(0.055, 0.075, 0.105, 0.94), 12))
	_status_panel.position = Vector2(MARGIN, MARGIN)
	_status_panel.custom_minimum_size.x = STATUS_WIDTH
	add_child(_status_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_status_panel.add_child(box)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	box.add_child(header)
	_clock_face = ClockFace.new()
	header.add_child(_clock_face)
	var time_box := VBoxContainer.new()
	time_box.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_child(time_box)
	_day_label = UiKit.heading("", 22)
	time_box.add_child(_day_label)
	_phase_label = UiKit.heading("", 13)
	time_box.add_child(_phase_label)
	_core_bar = _make_bar(HealthBarArt.Tone.GOLD)
	box.add_child(_core_bar)
	_hp_bar = _make_bar(HealthBarArt.Tone.RED)
	box.add_child(_hp_bar)
	_build_progression_hud(box)
	_resource_toggle = Button.new()
	_resource_toggle.focus_mode = Control.FOCUS_NONE
	_resource_toggle.toggle_mode = true
	_resource_toggle.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_resource_toggle.add_theme_font_size_override("font_size", 13)
	_resource_toggle.add_theme_color_override("font_color", UiKit.TEXT)
	_resource_toggle.add_theme_stylebox_override("normal", UiKit.box_style(Color("202d3a"), 5))
	_resource_toggle.add_theme_stylebox_override("pressed", UiKit.box_style(Color("304151"), 5))
	box.add_child(_resource_toggle)
	_resource_drawer = VBoxContainer.new()
	_resource_drawer.add_theme_constant_override("separation", 8)
	_resource_scroll = ScrollContainer.new()
	_resource_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_resource_scroll)
	_resource_drawer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_resource_scroll.add_child(_resource_drawer)
	_bag_label = UiKit.heading("내 가방", 13)
	_resource_drawer.add_child(_bag_label)
	_build_resource_grid("bag")
	_resource_drawer.add_child(UiKit.heading("공용 창고", 13))
	_build_resource_grid("stock")
	_resource_toggle.toggled.connect(_toggle_resources)
	_toggle_resources(false)


func _build_resource_grid(source: String) -> void:
	var grid := GridContainer.new()
	grid.columns = RESOURCE_COLUMNS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	_resource_drawer.add_child(grid)
	_resource_counts[source] = {}
	for kind: String in MATERIAL_ORDER:
		var cell := HBoxContainer.new()
		cell.custom_minimum_size = Vector2(80, 28)
		cell.tooltip_text = Balance.RESOURCE_NAMES[kind]
		grid.add_child(cell)
		var icon := TextureRect.new()
		var atlas := AtlasTexture.new()
		atlas.atlas = MATERIAL_TEXTURE
		atlas.region = Rect2(MATERIAL_ORDER.find(kind) * RESOURCE_ICON_SIZE, 0, RESOURCE_ICON_SIZE, RESOURCE_ICON_SIZE)
		icon.texture = atlas
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.custom_minimum_size = Vector2(RESOURCE_ICON_SIZE, RESOURCE_ICON_SIZE)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(icon)
		var count := UiKit.heading("0", 13)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(count)
		_resource_counts[source][kind] = count


func _build_minimap() -> void:
	var minimap := MapView.new().setup(_main.map_state)
	_minimap = minimap
	minimap.mini = true
	minimap.anchor_left = 1.0
	minimap.anchor_right = 1.0
	minimap.offset_left = -MARGIN - MINIMAP_SIZE
	minimap.offset_right = -MARGIN
	minimap.offset_top = MARGIN
	minimap.offset_bottom = MARGIN + MINIMAP_HEIGHT
	add_child(minimap)
	_bag_gauge = BagGauge.new()
	_bag_gauge.setup(_main.player.inventory)
	_bag_gauge.anchor_left = 1.0
	_bag_gauge.anchor_right = 1.0
	_bag_gauge.offset_left = -MARGIN - MINIMAP_SIZE - BAG_GAP - BagGauge.WIDTH
	_bag_gauge.offset_right = -MARGIN - MINIMAP_SIZE - BAG_GAP
	_bag_gauge.offset_top = MARGIN + 20
	_bag_gauge.offset_bottom = MARGIN + 20 + BagGauge.HEIGHT
	_bag_gauge.activated.connect(func() -> void: _resource_toggle.button_pressed = not _resource_toggle.button_pressed)
	add_child(_bag_gauge)


func _build_messages() -> void:
	_messages = VBoxContainer.new()
	_messages.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_messages.anchor_left = 0.5
	_messages.anchor_right = 0.5
	_messages.offset_left = -320
	_messages.offset_right = 320
	# 맨 위 0~56px는 보스 체력바·침공 예고(ThreatBanner, D-023) 자리
	_messages.offset_top = 60
	add_child(_messages)


func _build_action_bar() -> void:
	_action_bar = ActionBar.new()
	var bar := _action_bar
	bar.setup(_main.player, _main.build_mode, _main.kingdom)
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = -260
	bar.offset_right = 260
	bar.offset_top = -40 - ActionBar.DOCK_HEIGHT
	bar.offset_bottom = -40
	add_child(bar)


func _build_progression_hud(box: VBoxContainer) -> void:
	_progression_hud = ProgressionHud.new()
	box.add_child(_progression_hud)
	_progression_hud.setup(_main.player.progression)


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


func _make_bar(tone: HealthBarArt.Tone) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(240, 18)
	bar.show_percentage = false
	bar.add_theme_stylebox_override("fill", HealthBarArt.fill_style(tone))
	bar.add_theme_stylebox_override("background", HealthBarArt.background_style())
	var label := Label.new()
	label.name = "Text"
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_outline_color", Color("151e2b"))
	label.add_theme_constant_override("outline_size", 2)
	bar.add_child(label)
	return bar


func _set_bar(bar: ProgressBar, value: float, max_value: float, text: String) -> void:
	bar.max_value = max_value
	bar.value = value
	(bar.get_node("Text") as Label).text = text
