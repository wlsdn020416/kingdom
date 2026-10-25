class_name BuildMenu
extends Control
## 건설 도감(B). 분류별 외형·비용·조건을 확인한 뒤 설치 미리보기로 들어간다.
## 실제 건설은 기존 BuildMode → KingdomSync → Kingdom 명령 경로를 유지한다.

const DESIGN_SIZE := Vector2(1232, 672)
const REFRESH_INTERVAL := 0.25
var _build_mode: BuildMode
var _kingdom: Kingdom
var _player: Player
var _tabs := HBoxContainer.new()
var _list := GridContainer.new()
var _category: String = BuildingDB.CATEGORIES[0]
var _selected := "wood_wall"
var _shell := PanelContainer.new()
var _canvas := Control.new()
var _preview := BuildPreview.new()
var _name: Label
var _category_label: Label
var _description: Label
var _stats: Label
var _status: Label
var _technology: Label
var _costs := VBoxContainer.new()
var _choose: Button
var _refresh_time := 0.0


func setup(build_mode: BuildMode, kingdom: Kingdom, player: Player) -> void:
	_build_mode = build_mode
	_kingdom = kingdom
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
	_place(_canvas, _label("건설 도감", 27, MenuArt.TEXT), Vector2(24, 18), Vector2(200, 40))
	_place(_canvas, _label("왕국을 세우는 도구와 설비", 13, MenuArt.MUTED), Vector2(200, 30), Vector2(350, 20))
	_technology = _label("", 14, MenuArt.GOLD)
	_place(_canvas, _technology, Vector2(650, 27), Vector2(430, 25))
	var close := UiKit.button("닫기  B", hide)
	_place(_canvas, close, Vector2(1110, 17), Vector2(98, 40))
	_tabs.add_theme_constant_override("separation", 10)
	for category: String in BuildingDB.CATEGORIES:
		var tab := UiKit.button(BuildingDB.CATEGORY_NAMES[category], show_category.bind(category))
		tab.custom_minimum_size = Vector2(144, 40)
		tab.alignment = HORIZONTAL_ALIGNMENT_CENTER
		_tabs.add_child(tab)
	_place(_canvas, _tabs, Vector2(24, 72), Vector2(500, 40))
	_list.columns = 3
	_list.add_theme_constant_override("h_separation", 14)
	_list.add_theme_constant_override("v_separation", 12)
	_place(_canvas, _list, Vector2(24, 128), Vector2(790, 462))
	_build_detail()
	_place(_canvas, _label("카드를 골라 외형과 성능 확인  →  설치 모드  ·  게임은 계속 진행됩니다", 12, MenuArt.MUTED), Vector2(24, 619), Vector2(800, 23))
	_place(_canvas, _label("가방 자원부터 사용 · 부족분은 왕국 창고에서 지불  /  설치 중 좌클릭 건설 · 우클릭 철거", 11, MenuArt.MUTED), Vector2(24, 647), Vector2(1180, 20))
	resized.connect(_layout)
	_layout()
	hide()


func _build_detail() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", MenuArt.panel(0))
	_place(_canvas, panel, Vector2(850, 94), Vector2(358, 548))
	var body := Control.new()
	panel.add_child(body)
	_category_label = _label("", 12, MenuArt.GOLD)
	_place(body, _category_label, Vector2(18, 14), Vector2(322, 20))
	_name = _label("", 24, MenuArt.TEXT)
	_place(body, _name, Vector2(18, 36), Vector2(322, 32))
	_place(body, _preview, Vector2(18, 74), Vector2(322, 124))
	_description = _label("", 14, MenuArt.TEXT, true)
	_place(body, _description, Vector2(18, 206), Vector2(322, 38))
	_stats = _label("", 13, MenuArt.MUTED, true)
	_place(body, _stats, Vector2(18, 248), Vector2(322, 46))
	_place(body, _label("건설 재료   ·   필요 / 보유", 13, MenuArt.GOLD), Vector2(18, 299), Vector2(322, 20))
	_costs.add_theme_constant_override("separation", 2)
	_place(body, _costs, Vector2(18, 324), Vector2(322, 78))
	_status = _label("", 13, MenuArt.MUTED, true)
	_place(body, _status, Vector2(18, 410), Vector2(322, 42))
	_choose = UiKit.button("설치 모드", func() -> void: choose(_selected))
	_choose.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(body, _choose, Vector2(18, 466), Vector2(322, 44))
	_place(body, _label("실제 건물과 동일한 그림입니다", 11, MenuArt.MUTED), Vector2(18, 520), Vector2(322, 18))


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_time -= delta
	if _refresh_time <= 0.0:
		_refresh_time = REFRESH_INTERVAL
		_refresh()


func _layout() -> void:
	var fit := maxf(0.1, minf((size.x - 48) / DESIGN_SIZE.x, (size.y - 48) / DESIGN_SIZE.y))
	_shell.scale = Vector2.ONE * fit
	_shell.position = (size - DESIGN_SIZE * fit) / 2.0


func open() -> void:
	show()
	show_category(_category)


func show_category(category: String) -> void:
	if not BuildingDB.CATEGORIES.has(category):
		return
	_category = category
	if BuildingDB.TYPES[_selected]["category"] != category:
		_selected = BuildingDB.in_category(category)[0]
	for child in _list.get_children():
		child.queue_free()
	for id: String in BuildingDB.in_category(category):
		var card := BuildCard.new()
		card.setup(id)
		card.pressed.connect(func() -> void:
			_selected = id
			Events.ui_sound_requested.emit("click")
			_refresh())
		_list.add_child(card)
	_refresh()


func choose(type_id: String) -> void:
	if not BuildingDB.TYPES.has(type_id) or _locked_reason(type_id) != "":
		return
	hide()
	_build_mode.start(type_id)


func _locked_reason(id: String) -> String:
	var error := _kingdom.tech_error(id)
	if error == "" and BuildingDB.TYPES[id].get("unique", false) and _kingdom.has_type(id):
		return "왕국에 하나만 지을 수 있습니다"
	return error


func _refresh() -> void:
	if not visible:
		return
	_technology.text = "제작대 %d단계  ·  전체 %d종" % [_kingdom.workbench_tier(), BuildingDB.ORDER.size()]
	var perks := _player.progression.build_perks()
	for i in _tabs.get_child_count():
		(_tabs.get_child(i) as Button).add_theme_color_override("font_color", MenuArt.GOLD if BuildingDB.CATEGORIES[i] == _category else MenuArt.MUTED)
	for node in _list.get_children():
		if node.is_queued_for_deletion():
			continue
		var card := node as BuildCard
		var id := card.type_id
		var cost := BuildingDB.discounted(BuildingDB.TYPES[id]["cost"], perks["discount"])
		card.selected = id == _selected
		card.locked = _locked_reason(id) != ""
		card.affordable = _kingdom.can_afford(cost, _player.inventory)
		card.health = roundi(BuildingDB.TYPES[id]["hp"] * perks["hp_scale"])
		card.status = "해금 조건 확인" if card.locked else "설치 가능" if card.affordable else "자원 부족 · 미리보기 가능"
		card.queue_redraw()
	var info: Dictionary = BuildingDB.TYPES[_selected]
	_name.text = info["name"]
	_category_label.text = "%s  /  제작대 %d단계" % [BuildingDB.CATEGORY_NAMES[info["category"]], info["tier"]]
	_preview.type_id = _selected
	_description.text = info["description"]
	var stats := "체력 %d  ·  %s" % [roundi(info["hp"] * perks["hp_scale"]), "왕국 밖 설치 가능" if info.get("outside", false) else "왕국 영토 안에 설치"]
	if info.has("tower"):
		var tower: Dictionary = info["tower"]
		stats += "\n기본 공격 %s  ·  사거리 %d  ·  %.2f초마다" % [str(tower["damage"]), tower["range"], tower["interval"]]
	elif info.has("storage"):
		stats += "\n예비 장비 %d칸 보관" % info["storage"]
	elif info.get("workbench", false):
		stats += "\n장비 제작 · 단계 업그레이드"
	_stats.text = stats
	for child in _costs.get_children():
		_costs.remove_child(child)
		child.queue_free()
	var cost := BuildingDB.discounted(info["cost"], perks["discount"])
	for kind: String in cost:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 7)
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.custom_minimum_size = Vector2(22, 22)
		icon.texture = ItemArtDB.material_icon(kind)
		row.add_child(icon)
		var owned := _player.inventory.count(kind) + int(_kingdom.stock.get(kind, 0))
		row.add_child(_label("%s   %d / %d" % [Balance.RESOURCE_NAMES[kind], cost[kind], owned], 13, MenuArt.TEXT if owned >= cost[kind] else Color("d9937d")))
		_costs.add_child(row)
	var locked := _locked_reason(_selected)
	var affordable := _kingdom.can_afford(cost, _player.inventory)
	_status.text = locked if locked != "" else "자원이 부족합니다. 설치 미리보기는 볼 수 있습니다." if not affordable else "재료가 준비되었습니다. 위치를 골라 설치하세요."
	_status.add_theme_color_override("font_color", MenuArt.GOLD if locked == "" and affordable else MenuArt.MUTED)
	_choose.disabled = locked != ""
	_choose.text = "해금 필요" if locked != "" else "설치 모드" if affordable else "설치 미리보기"


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
