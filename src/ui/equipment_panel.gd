class_name EquipmentPanel
extends Control
## 부위별 장착과 장비·재료 가방을 보여준다. 상태 변경은 Equipment의 명령을 거친다.
## 장비·재료 아이콘은 ItemArtDB의 공용 원본을 사용한다.

enum PanelTone { WINDOW, CARD, TOOLTIP }

const UI_TEXTURE := preload("res://assets/ui/equipment_ui.png")
const MATERIAL_TEXTURE := preload("res://assets/ui/material_icons.png")
const MATERIAL_ORDER := ItemArtDB.MATERIAL_ORDER
const SLOT_SIZE := 64
const BAG_CELL_SIZE := 72
const GRID_COLUMNS := 6
const MIN_GEAR_CELLS := 24
const WEAPON_ICON_SIZE := Vector2(48, 48)
const WEAPON_ICON_TOP := 5.0
const WEAPON_NAME_TOP := 43.0
const MATERIAL_POLL_TIME := 0.2
const SLOT_POSITIONS := {
	"head": Vector2(160, 16), "weapon": Vector2(16, 144),
	"armor": Vector2(160, 144), "offhand": Vector2(304, 144),
	"boots": Vector2(160, 288), "charm": Vector2(304, 272),
}
const ACCENT := Color("e5c888")
const TEXT := Color("e7e8dd")
const MUTED := Color("9cabb1")

var _equipment: Equipment
var _inventory: Inventory
var _slot_buttons: Dictionary = {}
var _bag: GridContainer
var _materials: GridContainer
var _tabs: TabContainer
var _bag_count: Label
var _material_count: Label
var _skill_preview: Label
var _stats: Label
var _tooltip: PanelContainer
var _tooltip_name: Label
var _tooltip_kind: Label
var _tooltip_body: Label
var _tooltip_action: Label
var _highlighted_slot := ""
var _last_materials: Dictionary = {}
var _last_capacity := -1
var _poll_time := 0.0
var _built := false


func setup(equipment: Equipment, inventory: Inventory) -> void:
	_equipment = equipment
	_inventory = inventory
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_equipment.changed.connect(_refresh)
	visibility_changed.connect(_on_visibility_changed)
	hide()
	set_process(false)


func toggle() -> void:
	if not visible:
		_ensure_built()
	visible = not visible


## 닫힌 장비창의 노드와 스타일은 만들지 않고, 처음 열 때 한 번만 구성한다.
func _ensure_built() -> void:
	if _built:
		return
	_build_window()
	_build_tooltip()
	_built = true


func _build_window() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.025, 0.04, 0.06, 0.82)
	add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1040, 600)
	panel.add_theme_stylebox_override("panel", _panel_style(PanelTone.WINDOW, 20))
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	var title := _label("장비 · 소지품", 23, ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := UiKit.button("닫기  I / Esc", hide)
	close.add_theme_font_size_override("font_size", 14)
	close.add_theme_color_override("font_color", MUTED)
	header.add_child(close)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(columns)
	_build_equipped(columns)
	_build_bags(columns)
	_skill_preview = _label("", 13, ACCENT)
	content.add_child(_skill_preview)
	content.add_child(_label("장비 클릭: 착용·해제     마우스 올리기: 자세히 보기     게임은 계속 진행됩니다", 12, MUTED))


func _build_equipped(parent: HBoxContainer) -> void:
	var card := PanelContainer.new()
	card.custom_minimum_size.x = 416
	card.add_theme_stylebox_override("panel", _panel_style(PanelTone.CARD, 14))
	parent.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	box.add_child(_label("착용 장비", 17, TEXT))
	var paper := Control.new()
	paper.custom_minimum_size = Vector2(384, 360)
	paper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(paper)
	var mannequin := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = UI_TEXTURE
	atlas.region = Rect2(0, 0, 96, 160)
	mannequin.texture = atlas
	mannequin.position = Vector2(96, 32)
	mannequin.size = Vector2(192, 320)
	mannequin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mannequin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.add_child(mannequin)
	for slot: String in ItemDB.SLOTS:
		var at: Vector2 = SLOT_POSITIONS[slot]
		var caption := _label(ItemDB.SLOT_NAMES[slot], 12, MUTED)
		caption.position = at - Vector2(0, 18)
		caption.size.x = SLOT_SIZE
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		paper.add_child(caption)
		var button := _cell(SLOT_SIZE)
		button.position = at
		button.pressed.connect(_unequip_item.bind(slot))
		button.mouse_entered.connect(_show_equipped_tooltip.bind(slot))
		button.mouse_exited.connect(_hide_tooltip)
		paper.add_child(button)
		_slot_buttons[slot] = button
	_stats = _label("", 12, MUTED)
	box.add_child(_stats)


func _build_bags(parent: HBoxContainer) -> void:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _panel_style(PanelTone.CARD, 14))
	parent.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)
	box.add_child(_label("가방", 17, TEXT))
	_tabs = TabContainer.new()
	_tabs.use_hidden_tabs_for_min_size = true
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_theme_stylebox_override("panel", _panel_style(PanelTone.CARD, 8))
	_tabs.add_theme_stylebox_override("tab_selected", _panel_style(PanelTone.TOOLTIP, 8))
	_tabs.add_theme_stylebox_override("tab_unselected", _panel_style(PanelTone.CARD, 8))
	_tabs.add_theme_color_override("font_selected_color", ACCENT)
	_tabs.add_theme_color_override("font_unselected_color", MUTED)
	_tabs.add_theme_font_size_override("font_size", 15)
	_tabs.tab_changed.connect(func(_tab: int) -> void: _hide_tooltip())
	_tabs.tab_changed.connect(func(_tab: int) -> void:
		if _built and visible:
			Events.ui_sound_requested.emit("click"))
	box.add_child(_tabs)
	var gear_box := _tab("장비")
	_bag_count = _label("", 12, MUTED)
	gear_box.add_child(_bag_count)
	_bag = _grid(gear_box)
	var material_box := _tab("재료")
	_material_count = _label("", 12, MUTED)
	material_box.add_child(_material_count)
	_materials = _grid(material_box)
	material_box.add_child(_label("왕국 핵 근처에서 공용 창고로 자동 입고됩니다", 12, MUTED))


func _tab(title: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = title
	box.add_theme_constant_override("separation", 10)
	_tabs.add_child(box)
	return box


func _grid(parent: VBoxContainer) -> GridContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(488, 300)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	return grid


func _build_tooltip() -> void:
	_tooltip = PanelContainer.new()
	_tooltip.name = "ItemTooltip"
	_tooltip.custom_minimum_size.x = 300
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.z_index = 100
	_tooltip.add_theme_stylebox_override("panel", _panel_style(PanelTone.TOOLTIP, 16))
	add_child(_tooltip)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 8)
	_tooltip.add_child(box)
	_tooltip_name = _label("", 18, ACCENT)
	_tooltip_kind = _label("", 12, MUTED)
	_tooltip_body = _label("", 14, TEXT)
	_tooltip_body.custom_minimum_size.x = 268
	_tooltip_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_action = _label("", 12, ACCENT)
	for label: Label in [_tooltip_name, _tooltip_kind, _tooltip_body, _tooltip_action]:
		box.add_child(label)
	_tooltip.hide()


func _refresh() -> void:
	if not visible:
		return
	_hide_tooltip()
	for slot: String in ItemDB.SLOTS:
		var button: Button = _slot_buttons[slot]
		var id := _equipment.item_in(slot)
		_set_cell_name(button, ItemDB.ITEMS[id]["name"] if id != "" else "—", id)
		button.disabled = slot == "weapon" or id == ""
		var style := _slot_style(256 if id != "" else 128)
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("disabled", style)
	_clear_grid(_bag)
	for id in _equipment.bag:
		var button := _cell(BAG_CELL_SIZE)
		_set_cell_name(button, ItemDB.ITEMS[id]["name"], id)
		var item: Dictionary = ItemDB.ITEMS[id]
		var category := _label(ItemDB.SLOT_NAMES[item["slot"]], 10, MUTED)
		category.position = Vector2(6, 4)
		button.add_child(category)
		button.pressed.connect(_equip_item.bind(id))
		button.mouse_entered.connect(_show_item_tooltip.bind(id))
		button.mouse_exited.connect(_hide_tooltip)
		_bag.add_child(button)
	var padded := maxi(MIN_GEAR_CELLS, ceili(float(_equipment.bag.size()) / GRID_COLUMNS) * GRID_COLUMNS)
	for i in padded - _equipment.bag.size():
		var empty := _cell(BAG_CELL_SIZE)
		empty.disabled = true
		_bag.add_child(empty)
	_bag_count.text = "장비 %d개  ·  클릭해서 착용" % _equipment.bag.size()
	var skills := PackedStringArray()
	var bar := _equipment.skill_bar()
	for i in bar.size():
		skills.append("%d  %s" % [i + 1, ItemDB.ITEMS[bar[i]]["skill"]["name"]])
	_skill_preview.text = "장착 스킬  ·  " + ("    ".join(skills) if not skills.is_empty() else "없음")
	_stats.text = "장비 효과  ·  체력 +%d   이동 속도 +%d%%" % [roundi(_equipment.max_hp() - Balance.PLAYER_BASE_HP), roundi((_equipment.move_speed() / Balance.PLAYER_SPEED - 1.0) * 100.0)]
	_refresh_materials()


func _refresh_materials() -> void:
	_hide_tooltip()
	_last_materials = _inventory.amounts()
	_last_capacity = _inventory.capacity()
	_clear_grid(_materials)
	for kind: String in MATERIAL_ORDER:
		var remaining := _inventory.count(kind)
		while remaining > 0:
			var count := mini(remaining, Balance.STACK_SIZE)
			remaining -= count
			var button := _cell(BAG_CELL_SIZE)
			button.mouse_default_cursor_shape = Control.CURSOR_HELP
			var icon := TextureRect.new()
			icon.texture = ItemArtDB.material_icon(kind)
			icon.position = Vector2(12, 3)
			icon.size = Vector2(48, 48)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(icon)
			var name_label := _label(Balance.RESOURCE_NAMES[kind], 11, TEXT)
			name_label.position = Vector2(3, 53)
			name_label.size = Vector2(66, 16)
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_label.clip_text = true
			button.add_child(name_label)
			var amount := _label(str(count), 13, TEXT)
			amount.position = Vector2(37, 5)
			amount.size = Vector2(28, 18)
			amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			amount.add_theme_color_override("font_outline_color", Color("101924"))
			amount.add_theme_constant_override("outline_size", 3)
			button.add_child(amount)
			button.mouse_entered.connect(_show_material_tooltip.bind(kind, count))
			button.mouse_exited.connect(_hide_tooltip)
			_materials.add_child(button)
	for i in maxi(0, _inventory.capacity() - _inventory.used_slots()):
		var empty := _cell(BAG_CELL_SIZE)
		empty.disabled = true
		_materials.add_child(empty)
	_material_count.text = "%d / %d칸 사용  ·  한 칸에 최대 %d개" % [_inventory.used_slots(), _inventory.capacity(), Balance.STACK_SIZE]


func _show_equipped_tooltip(slot: String) -> void:
	_show_gear_info(_equipment.item_in(slot), slot, true)


func _show_item_tooltip(id: String) -> void:
	var slot: String = ItemDB.ITEMS[id]["slot"]
	_show_gear_info(id, slot, false)
	_highlighted_slot = slot
	var button: Button = _slot_buttons[slot]
	button.add_theme_stylebox_override("normal", _slot_style(192))
	button.add_theme_stylebox_override("disabled", _slot_style(192))


func _show_gear_info(id: String, slot: String, equipped: bool) -> void:
	_hide_tooltip()
	_tooltip_name.text = ItemDB.ITEMS[id]["name"] if id != "" else ItemDB.SLOT_NAMES[slot]
	_tooltip_kind.text = ItemDB.SLOT_NAMES[slot] + ("  ·  착용 중" if equipped and id != "" else "")
	_tooltip_body.text = ItemDB.describe(id).replace(" · ", "\n") if id != "" else "이 부위에 장비를 장착할 수 있습니다."
	if id == "":
		_tooltip_action.text = "가방에서 같은 부위의 장비를 선택하세요"
	elif equipped:
		_tooltip_action.text = "무기는 해제할 수 없습니다" if slot == "weapon" else "클릭해서 가방으로 옮기기"
	else:
		_tooltip_action.text = "클릭해서 착용 · 기존 장비는 가방으로 이동"
	_open_tooltip()


func _show_material_tooltip(kind: String, count: int) -> void:
	_hide_tooltip()
	_tooltip_name.text = Balance.RESOURCE_NAMES[kind]
	_tooltip_kind.text = "재료  ·  총 %d개 소지" % _inventory.count(kind)
	_tooltip_body.text = "이 칸 %d / %d개\n건설·제작에 사용하는 재료입니다." % [count, Balance.STACK_SIZE]
	_tooltip_action.text = "왕국 핵 근처에서 공용 창고로 자동 입고"
	_open_tooltip()


func _open_tooltip() -> void:
	_tooltip.reset_size()
	_tooltip.show()
	_position_tooltip()


func _position_tooltip() -> void:
	var bounds := get_viewport_rect().size
	var at := get_global_mouse_position() + Vector2(18, 18)
	at.x = clampf(at.x, 8.0, maxf(8.0, bounds.x - _tooltip.size.x - 8.0))
	at.y = clampf(at.y, 8.0, maxf(8.0, bounds.y - _tooltip.size.y - 8.0))
	_tooltip.position = at.round()


func _hide_tooltip() -> void:
	if _tooltip != null:
		_tooltip.hide()
	if _highlighted_slot != "":
		var button: Button = _slot_buttons[_highlighted_slot]
		var id := _equipment.item_in(_highlighted_slot)
		var style := _slot_style(256 if id != "" else 128)
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("disabled", style)
		_highlighted_slot = ""


func _equip_item(id: String) -> void:
	if _equipment.bag.has(id):
		_equipment.equip(id)
		Events.ui_sound_requested.emit("equip")


func _unequip_item(slot: String) -> void:
	if slot != "weapon" and _equipment.item_in(slot) != "":
		_equipment.unequip(slot)
		Events.ui_sound_requested.emit("equip")


func _on_visibility_changed() -> void:
	set_process(visible)
	if visible:
		_ensure_built()
		_refresh()
	else:
		_hide_tooltip()


func _process(delta: float) -> void:
	if _tooltip.visible:
		_position_tooltip()
	_poll_time -= delta
	if _poll_time <= 0.0:
		_poll_time = MATERIAL_POLL_TIME
		if _last_materials != _inventory.amounts() or _last_capacity != _inventory.capacity():
			_refresh_materials()


func _cell(size: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2.ONE * size
	button.size = Vector2.ONE * size
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", _slot_style(128))
	button.add_theme_stylebox_override("hover", _slot_style(192))
	button.add_theme_stylebox_override("pressed", _slot_style(256))
	button.add_theme_stylebox_override("disabled", _slot_style(320))
	return button


func _set_cell_name(button: Button, text: String, id := "") -> void:
	var label := button.get_node_or_null("Name") as Label
	if label == null:
		label = _label("", 12, TEXT)
		label.name = "Name"
		label.position = Vector2(5, 18)
		label.size = Vector2(button.custom_minimum_size.x - 10, button.custom_minimum_size.y - 23)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_child(label)
	label.text = text
	label.add_theme_font_size_override("font_size", 10 if button.custom_minimum_size.x <= SLOT_SIZE else 11)
	var icon := button.get_node_or_null("WeaponIcon") as TextureRect
	if not ItemArtDB.ORDER.has(id):
		if icon != null:
			icon.hide()
		label.position.y = 18
		label.size.y = button.custom_minimum_size.y - 23
		return
	if icon == null:
		icon = TextureRect.new()
		icon.name = "WeaponIcon"
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
	icon.texture = ItemArtDB.icon(id)
	icon.size = WEAPON_ICON_SIZE
	icon.position = Vector2((button.custom_minimum_size.x - icon.size.x) / 2.0, WEAPON_ICON_TOP)
	icon.show()
	label.position.y = WEAPON_NAME_TOP
	label.size.y = button.custom_minimum_size.y - WEAPON_NAME_TOP - 2


func _clear_grid(grid: GridContainer) -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _slot_style(x: int) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = UI_TEXTURE
	atlas.region = Rect2(x, 0, 64, 64)
	style.texture = atlas
	style.texture_margin_left = 8
	style.texture_margin_right = 8
	style.texture_margin_top = 8
	style.texture_margin_bottom = 8
	return style


func _panel_style(tone: PanelTone, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1d2c3f") if tone == PanelTone.WINDOW else Color("172534")
	style.border_color = Color("8f744c") if tone != PanelTone.CARD else Color("435b70")
	style.set_border_width_all(2)
	if tone != PanelTone.CARD:
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
		style.shadow_size = 6
	style.set_content_margin_all(margin)
	return style
