class_name CraftingPanel
extends Control
## 제작대 창(E). 장비 목록·재료 확인·제작에 집중한다. 설비 강화는 왕국 핵 창이 맡는다.
## 상태 변경은 KingdomSync 명령만 사용하며, 호스트에서 도착한 자원·공개 상태도 갱신한다.

const DESIGN_SIZE := Vector2(1056, 648)
const REFRESH_INTERVAL := 0.2
const WARNING := Color("e5a08b")
const READY := Color("95c9b0")

var _kingdom: Kingdom
var _commands: KingdomSync
var _player: Player
var _cell := World.NO_CELL
var _shell := PanelContainer.new()
var _canvas := Control.new()
var _title: Label
var _recipes := VBoxContainer.new()
var _tabs := HBoxContainer.new()
var _hidden_note: Label
var _empty: Label
var _item_icon := TextureRect.new()
var _item_name: Label
var _item_meta: Label
var _description: Label
var _costs := VBoxContainer.new()
var _status: Label
var _craft: Button
var _owned: Label
var _selected := ""
var _filter := -1
var _refresh_timer := 0.0
var _shown := ""
var _rows := {}


func setup(kingdom: Kingdom, player: Player, commands: KingdomSync) -> void:
	_kingdom = kingdom
	_commands = commands
	_player = player
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = MenuArt.theme()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.025, 0.04, 0.055, 0.94)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	_shell.add_theme_stylebox_override("panel", MenuArt.panel(0))
	_shell.size = DESIGN_SIZE
	add_child(_shell)
	_shell.add_child(_canvas)
	_place(_canvas, _label("왕국 제작대", 28, MenuArt.TEXT), Vector2(24, 18), Vector2(270, 40))
	_place(_canvas, _label("탐험에서 얻은 재료를 새로운 장비로", 13, MenuArt.MUTED), Vector2(230, 30), Vector2(410, 24))
	_place(_canvas, UiKit.button("닫기  E", hide), Vector2(928, 18), Vector2(104, 40))
	_title = _label("", 14, MenuArt.GOLD)
	_place(_canvas, _title, Vector2(662, 28), Vector2(250, 24))
	_build_catalog()
	_build_detail()
	_place(_canvas, _label("가방 자원부터 사용 · 부족분은 왕국 창고에서 지불   /   제작한 장비는 I에서 착용", 13, MenuArt.MUTED), Vector2(24, 592), Vector2(1008, 22))
	_place(_canvas, _label("게임은 계속 진행됩니다 · 제작대에서 멀어지면 창이 닫힙니다", 12, MenuArt.MUTED), Vector2(24, 620), Vector2(1008, 20))
	resized.connect(_layout)
	_layout()
	hide()


func _build_catalog() -> void:
	var body := _panel(Vector2(24, 80), Vector2(400, 492))
	_place(body, _label("장비 설계도", 18, MenuArt.TEXT), Vector2(16, 12), Vector2(368, 30))
	_tabs.add_theme_constant_override("separation", 6)
	for tier in range(-1, RecipeDB.max_tier() + 1):
		var tab := UiKit.button("전체" if tier < 0 else "%d단계" % tier, show_tier.bind(tier))
		tab.custom_minimum_size = Vector2(64, 36)
		tab.add_theme_font_size_override("font_size", 13)
		tab.alignment = HORIZONTAL_ALIGNMENT_CENTER
		_tabs.add_child(tab)
	_place(body, _tabs, Vector2(16, 50), Vector2(368, 36))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_place(body, scroll, Vector2(16, 98), Vector2(368, 332))
	_recipes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recipes.add_theme_constant_override("separation", 6)
	scroll.add_child(_recipes)
	_empty = _label("이 단계의 설계도를 아직 모릅니다.\n새로운 재료를 찾아보세요.", 14, MenuArt.MUTED, true)
	_place(body, _empty, Vector2(24, 126), Vector2(348, 80))
	_hidden_note = _label("", 14, MenuArt.MUTED, true)
	_place(body, _hidden_note, Vector2(16, 438), Vector2(368, 46))


func _build_detail() -> void:
	var body := _panel(Vector2(440, 80), Vector2(592, 492))
	_place(body, _label("제작할 장비", 13, MenuArt.GOLD), Vector2(20, 14), Vector2(552, 22))
	_item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_place(body, _item_icon, Vector2(20, 50), Vector2(88, 88))
	_item_name = _label("설계도를 선택하세요", 24, MenuArt.TEXT)
	_place(body, _item_name, Vector2(124, 50), Vector2(448, 36))
	_item_meta = _label("", 13, MenuArt.MUTED)
	_place(body, _item_meta, Vector2(124, 92), Vector2(448, 24))
	_description = _label("", 15, MenuArt.TEXT, true)
	_place(body, _description, Vector2(20, 148), Vector2(552, 68))
	_place(body, _label("제작 재료                       보유 / 필요", 14, MenuArt.GOLD), Vector2(20, 228), Vector2(552, 24))
	_costs.add_theme_constant_override("separation", 7)
	_place(body, _costs, Vector2(20, 262), Vector2(552, 106))
	_status = _label("", 14, MenuArt.MUTED, true)
	_place(body, _status, Vector2(20, 374), Vector2(552, 36))
	_craft = UiKit.button("장비 제작", _on_craft)
	_craft.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(body, _craft, Vector2(20, 418), Vector2(552, 44))
	_owned = _label("", 14, MenuArt.MUTED)
	_place(body, _owned, Vector2(20, 464), Vector2(552, 24))


func open(cell: Vector2i) -> void:
	_cell = cell
	_shown = ""
	show()
	_refresh()


func show_tier(tier: int) -> void:
	_filter = tier
	_shown = ""
	_refresh()


func select_recipe(id: String) -> void:
	if not RecipeDB.RECIPES.has(id) or not RecipeDB.is_revealed(id, _kingdom.known_materials):
		return
	_selected = id
	_refresh()


func _process(delta: float) -> void:
	if not visible:
		return
	if _kingdom.find_workbench_near(_player.global_position) != _cell:
		hide()
		return
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = REFRESH_INTERVAL
		_refresh()


func _on_craft() -> void:
	if _selected == "" or _craft.disabled:
		return
	_commands.craft(_selected)
	_refresh()


func _refresh() -> void:
	if not visible or not _kingdom.buildings.has(_cell):
		return
	var tier := _kingdom.workbench_tier()
	var signature := str([tier, _kingdom.known_materials, _filter])
	if signature != _shown:
		_shown = signature
		_rebuild_recipes()
	_title.text = "제작대  %d / %d단계" % [tier, RecipeDB.max_tier()]
	for id: String in _rows:
		var button: Button = _rows[id]
		var reason := _recipe_status(id)
		button.text = "%s%s\n%d단계 · %s" % ["◆ " if id == _selected else "", ItemDB.ITEMS[id]["name"], RecipeDB.RECIPES[id]["tier"], reason]
		button.add_theme_color_override("font_color", MenuArt.GOLD if id == _selected else MenuArt.TEXT)
	for i in _tabs.get_child_count():
		(_tabs.get_child(i) as Button).add_theme_color_override("font_color", MenuArt.GOLD if i - 1 == _filter else MenuArt.MUTED)
	_refresh_detail()


func _rebuild_recipes() -> void:
	for child in _recipes.get_children():
		_recipes.remove_child(child)
		child.queue_free()
	_rows.clear()
	var hidden := 0
	for id: String in RecipeDB.RECIPES:
		if not RecipeDB.is_revealed(id, _kingdom.known_materials):
			hidden += 1
			continue
		if _filter >= 0 and RecipeDB.RECIPES[id]["tier"] != _filter:
			continue
		var button := UiKit.button("", select_recipe.bind(id))
		button.icon = ItemArtDB.icon(id)
		button.custom_minimum_size.y = 70
		button.add_theme_font_size_override("font_size", 14)
		button.add_theme_constant_override("h_separation", 10)
		_recipes.add_child(button)
		_rows[id] = button
	if not _rows.has(_selected):
		_selected = "" if _rows.is_empty() else str(_rows.keys()[0])
	_empty.visible = _rows.is_empty()
	_hidden_note.text = "미발견 설계도 %d개\n새 재료를 처음 얻으면 설계도가 나타납니다" % hidden if hidden > 0 else "모든 설계도를 발견했습니다"


func _recipe_status(id: String) -> String:
	var recipe: Dictionary = RecipeDB.RECIPES[id]
	if recipe["tier"] > _kingdom.workbench_tier():
		return "왕국 핵에서 제작대 강화 필요"
	var from: String = recipe.get("from", "")
	if from != "" and not _player.equipment.owns(from):
		return "%s 필요" % ItemDB.ITEMS[from]["name"]
	return "제작 가능" if _kingdom.can_afford(recipe["cost"], _player.inventory) else "재료 부족"


func _refresh_detail() -> void:
	var has_recipe := _selected != ""
	_item_icon.visible = has_recipe
	_craft.disabled = not has_recipe
	if not has_recipe:
		_item_name.text = "설계도를 선택하세요"
		_item_meta.text = ""
		_description.text = "탐험 중 새로운 재료를 얻으면\n제작할 수 있는 장비가 늘어납니다."
		_status.text = ""
		_owned.text = ""
		_update_costs(_costs, {})
		return
	var item: Dictionary = ItemDB.ITEMS[_selected]
	_item_icon.texture = ItemArtDB.icon(_selected)
	_item_name.text = item["name"]
	_item_meta.text = "%s  ·  제작대 %d단계 필요" % [ItemDB.SLOT_NAMES[item["slot"]], RecipeDB.RECIPES[_selected]["tier"]]
	_description.text = ItemDB.describe(_selected)
	_update_costs(_costs, RecipeDB.RECIPES[_selected]["cost"])
	var status := _recipe_status(_selected)
	_status.text = "재료가 준비되었습니다. 장비 1개를 제작합니다." if status == "제작 가능" else status
	_status.add_theme_color_override("font_color", READY if status == "제작 가능" else WARNING)
	_craft.disabled = status != "제작 가능"
	_craft.text = "장비 제작" if not _craft.disabled else status
	_owned.text = "보유 중인 장비입니다 · 추가 제작 가능" if _player.equipment.owns(_selected) else "제작 후 가방으로 이동 · I에서 착용"
	# 무기 강화(D-028): 이전 단계 무기를 소모하고, 들고 있었으면 손에 든 채로 바뀐다
	var from: String = RecipeDB.RECIPES[_selected].get("from", "")
	if from != "":
		if status == "제작 가능":
			_status.text = "재료가 준비되었습니다. %s을(를) 강화합니다." % ItemDB.ITEMS[from]["name"]
			_craft.text = "무기 강화"
		_owned.text = "%s을(를) 소모해 강화 · 들고 있었으면 손에 그대로" % ItemDB.ITEMS[from]["name"]


func _update_costs(container: VBoxContainer, cost: Dictionary) -> void:
	# 수량이 변할 때만 내용을 바꿔 스크롤·선택과 마우스 포커스를 유지한다.
	var signature := str([cost, _player.inventory.amounts(), _kingdom.stock])
	if container.get_meta("signature", "") == signature:
		return
	container.set_meta("signature", signature)
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
	for kind: String in cost:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var icon := TextureRect.new()
		icon.texture = ItemArtDB.material_icon(kind)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.custom_minimum_size = Vector2(24, 24)
		row.add_child(icon)
		var bag := _player.inventory.count(kind)
		var stock := int(_kingdom.stock.get(kind, 0))
		var owned := bag + stock
		var enough: bool = owned >= int(cost[kind])
		var name_label := _label(Balance.RESOURCE_NAMES[kind], 14, MenuArt.TEXT)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		row.add_child(_label("%d / %d%s" % [owned, cost[kind], "" if enough else " !"], 14, READY if enough else WARNING))
		row.tooltip_text = "가방 %d + 왕국 창고 %d%s" % [bag, stock, "" if enough else " · %d개 부족" % (int(cost[kind]) - owned)]
		container.add_child(row)


func _layout() -> void:
	var fit := maxf(0.1, minf((size.x - 32) / DESIGN_SIZE.x, (size.y - 32) / DESIGN_SIZE.y))
	_shell.scale = Vector2.ONE * fit
	_shell.position = (size - DESIGN_SIZE * fit) / 2.0


func _panel(at: Vector2, dimensions: Vector2) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", MenuArt.panel(0))
	_place(_canvas, panel, at, dimensions)
	var body := Control.new()
	panel.add_child(body)
	return body


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
