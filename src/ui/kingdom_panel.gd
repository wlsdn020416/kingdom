class_name KingdomPanel
extends Control
## 왕국 핵의 픽셀 운영 창(E). 성·체력·영토 현황과 네 가지 명령의 재료/조건을 보여준다.
## 실제 강화·확장·수리는 KingdomSync 명령만 호출하고 핵에서 멀어지면 닫는다.

const DESIGN_SIZE := Vector2(1200, 672)
const REFRESH_INTERVAL := 0.2
const ICONS := preload("res://assets/ui/kingdom_ui.png")
const ICON_ORDER := ["workbench", "defense", "territory", "repair"]
const READY := Color("97c8ad")
const WARNING := Color("e2a08a")


class SeatPreview extends Control:
	var radius := 13
	var level := 0


	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("11212c"))
		for x in range(0, int(size.x), 16):
			draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.35, 0.5, 0.6, 0.1))
		for y in range(0, int(size.y), 16):
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.35, 0.5, 0.6, 0.1))
		var center := Vector2(size.x / 2.0, 202)
		draw_set_transform(center, 0, Vector2(1, 0.32))
		for i in range(3, 0, -1):
			draw_arc(Vector2.ZERO, 38 + i * 24, 0, TAU, 64, Color(0.6, 0.8, 0.65, 0.12 + i * 0.03), 1)
		draw_arc(Vector2.ZERO, 52 + level * 18, 0, TAU, 64, MenuArt.GOLD, 2)
		draw_set_transform(Vector2.ZERO)
		draw_texture_rect(Core.SPRITE_TEXTURE, Rect2(Vector2(size.x / 2 - 72, 16), Vector2(144, 192)), false)
		draw_string(UiKit.GAME_FONT, Vector2(0, 246), "현재 영토  ·  반지름 %d칸" % radius, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, MenuArt.GOLD)


var _kingdom: Kingdom
var _commands: KingdomSync
var _player: Player
var _rows := {}
var _refresh_timer := 0.0
var _shell := PanelContainer.new()
var _canvas := Control.new()
var _preview := SeatPreview.new()
var _health := ProgressBar.new()
var _health_text: Label
var _overview: Label


func setup(kingdom: Kingdom, player: Player, commands: KingdomSync) -> void:
	_kingdom = kingdom
	_player = player
	_commands = commands
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = MenuArt.theme()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.025, 0.04, 0.055, 0.94)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	_shell.size = DESIGN_SIZE
	_shell.add_theme_stylebox_override("panel", MenuArt.panel(0))
	add_child(_shell)
	_shell.add_child(_canvas)
	_place(_canvas, _label("왕국 집무실", 28, MenuArt.TEXT), Vector2(24, 19), Vector2(260, 40))
	_place(_canvas, _label("왕국을 지키고 다음 성장을 준비하세요", 14, MenuArt.MUTED), Vector2(300, 30), Vector2(600, 24))
	_place(_canvas, UiKit.button("닫기  E", hide), Vector2(1072, 18), Vector2(104, 40))
	_build_overview()
	_add_card("workbench", "제작대 강화", "몬스터 재료로 새 장비 레시피 해금", _commands.upgrade_workbench, Vector2(332, 82))
	_add_card("defense", "방어 강화", "채집 재료로 벽·공성탑·생활 설비 해금", _commands.upgrade_defense, Vector2(762, 82))
	_add_card("territory", "영토 확장", "재료를 모아 왕국의 건설 범위 확장", _commands.expand_territory, Vector2(332, 350))
	_add_card("repair", "성채 수리", "성채 체력 회복 · R로도 수리 가능", _commands.repair, Vector2(762, 350))
	_place(_canvas, _label("가방 자원부터 사용 · 부족분은 왕국 창고에서 지불   /   재료 아이콘에 마우스를 올리면 보유처를 확인할 수 있습니다", 13, MenuArt.MUTED), Vector2(24, 628), Vector2(1152, 24))
	resized.connect(_layout)
	_layout()
	hide()


func _build_overview() -> void:
	var body := _panel(Vector2(24, 82), Vector2(292, 522))
	_place(body, _label("왕국의 심장", 21, MenuArt.TEXT), Vector2(18, 16), Vector2(190, 30))
	var crest := _icon(4, 48)
	_place(body, crest, Vector2(222, 8), Vector2(48, 48))
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(body, _preview, Vector2(16, 58), Vector2(260, 262))
	_health.max_value = _kingdom.core.max_hp
	_health.show_percentage = false
	_health.add_theme_stylebox_override("background", HealthBarArt.background_style())
	_health.add_theme_stylebox_override("fill", HealthBarArt.fill_style(HealthBarArt.Tone.GOLD))
	_place(body, _health, Vector2(18, 340), Vector2(256, 20))
	_health_text = _label("", 13, MenuArt.TEXT)
	_health_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_health_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_health_text.add_theme_color_override("font_outline_color", Color("101923"))
	_health_text.add_theme_constant_override("outline_size", 2)
	_health_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_health.add_child(_health_text)
	_overview = _label("", 15, MenuArt.TEXT, true)
	_place(body, _overview, Vector2(18, 382), Vector2(256, 82))
	_place(body, _label("운영 중에도 게임은 계속 진행됩니다.\n왕국 핵에서 멀어지면 창이 닫힙니다.", 13, MenuArt.MUTED, true), Vector2(18, 474), Vector2(256, 42))


func _add_card(id: String, title: String, hint: String, command: Callable, at: Vector2) -> void:
	var body := _panel(at, Vector2(414, 254))
	_place(body, _icon(ICON_ORDER.find(id), 48), Vector2(16, 10), Vector2(48, 48))
	_place(body, _label(title, 22, MenuArt.TEXT), Vector2(78, 14), Vector2(318, 32))
	var status := _label("", 14, MenuArt.GOLD)
	_place(body, status, Vector2(78, 48), Vector2(318, 24))
	_place(body, _label(hint, 14, MenuArt.MUTED), Vector2(18, 81), Vector2(378, 20))
	var cost := GridContainer.new()
	cost.columns = 2
	cost.add_theme_constant_override("h_separation", 12)
	cost.add_theme_constant_override("v_separation", 6)
	_place(body, cost, Vector2(18, 111), Vector2(378, 64))
	var state := _label("", 13, MenuArt.MUTED)
	_place(body, state, Vector2(18, 180), Vector2(378, 22))
	var button := UiKit.button("", func() -> void:
		command.call()
		_refresh())
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(body, button, Vector2(18, 210), Vector2(378, 32))
	_rows[id] = {"status": status, "cost": cost, "state": state, "button": button}


func open() -> void:
	show()
	_refresh()


func _process(delta: float) -> void:
	if not visible:
		return
	if _kingdom.core_use_error(_player.global_position) != "":
		hide()
		return
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = REFRESH_INTERVAL
		_refresh()


func _refresh() -> void:
	if not visible:
		return
	var tier := _kingdom.workbench_tier()
	if tier < 0:
		_show("workbench", "제작대가 없습니다", {}, "", "B 건설에서 제작대를 먼저 설치하세요")
	elif tier >= RecipeDB.max_tier():
		_show("workbench", "%d / %d단계 · 최고 단계" % [tier, RecipeDB.max_tier()], {}, "", "모든 장비 제작 단계를 갖췄습니다")
	else:
		_show("workbench", "%d / %d단계 → %d단계" % [tier, RecipeDB.max_tier(), tier + 1], RecipeDB.UPGRADES[tier], "제작대 강화")
	var defense := _kingdom.defense_tier
	if defense >= BuildingDB.max_defense_tier():
		_show("defense", "%d / %d단계 · 최고 단계" % [defense, BuildingDB.max_defense_tier()], {}, "", "모든 방어 건물 단계를 갖췄습니다")
	else:
		_show("defense", "%d / %d단계 → %d단계" % [defense, BuildingDB.max_defense_tier(), defense + 1], BuildingDB.DEFENSE_UPGRADES[defense], "방어 강화")
	var level := _kingdom.territory_level
	var radius := _kingdom.territory_radius()
	if level >= Balance.TERRITORY_UPGRADES.size():
		_show("territory", "반지름 %d칸 · 최대 영토" % radius, {}, "", "왕국 영토를 최대로 넓혔습니다")
	else:
		_show("territory", "반지름 %d칸 → %d칸" % [radius, radius + Balance.TERRITORY_STEP], Balance.TERRITORY_UPGRADES[level], "영토 확장")
	var core := _kingdom.core
	var perks := _player.progression.repair_perks()
	var cost := BuildingDB.discounted(Balance.REPAIR_COST, perks.get("discount", 0.0))
	var heal := mini(ceili(Balance.REPAIR_AMOUNT * (1.0 + perks.get("amount_bonus", 0.0))), ceili(core.max_hp - core.hp))
	_show("repair", "체력 %d / %d · 수리 시 +%d" % [core.hp, core.max_hp, heal], cost if core.hp < core.max_hp else {}, "성채 수리" if core.hp < core.max_hp else "", "성채의 체력이 가득 찼습니다")
	_health.value = core.hp
	_health_text.text = "성채 체력 %d / %d" % [ceili(core.hp), ceili(core.max_hp)]
	_overview.text = "방어  %d / %d단계\n제작대  %s\n영토 확장  %d / %d회" % [defense, BuildingDB.max_defense_tier(), "미설치" if tier < 0 else "%d / %d단계" % [tier, RecipeDB.max_tier()], level, Balance.TERRITORY_UPGRADES.size()]
	_preview.radius = radius
	_preview.level = level
	_preview.queue_redraw()


func _show(id: String, status: String, cost: Dictionary, action: String, finished_note := "") -> void:
	var row: Dictionary = _rows[id]
	(row["status"] as Label).text = status
	_update_costs(row["cost"], cost)
	var button: Button = row["button"]
	var state: Label = row["state"]
	if action == "":
		state.text = finished_note
		state.add_theme_color_override("font_color", MenuArt.MUTED)
		button.text = "제작대 설치 필요" if id == "workbench" and _kingdom.workbench_tier() < 0 else "체력 가득" if id == "repair" else "최고 단계 달성"
		button.disabled = true
		return
	var affordable := _kingdom.can_afford(cost, _player.inventory)
	state.text = "재료가 준비되었습니다 · 보유 / 필요" if affordable else "재료가 부족합니다 · 보유 / 필요"
	state.add_theme_color_override("font_color", READY if affordable else WARNING)
	button.text = action
	button.disabled = not affordable


func _update_costs(container: GridContainer, cost: Dictionary) -> void:
	var signature := str([cost, _player.inventory.amounts(), _kingdom.stock])
	if container.get_meta("signature", "") == signature:
		return
	container.set_meta("signature", signature)
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
	for kind: String in cost:
		var row := HBoxContainer.new()
		row.custom_minimum_size.x = 183
		row.add_theme_constant_override("separation", 4)
		var icon := TextureRect.new()
		icon.texture = ItemArtDB.material_icon(kind)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.custom_minimum_size = Vector2(22, 22)
		row.add_child(icon)
		var name_label := _label(Balance.RESOURCE_NAMES[kind], 13, MenuArt.TEXT)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var bag := _player.inventory.count(kind)
		var stock := int(_kingdom.stock.get(kind, 0))
		var enough: bool = bag + stock >= int(cost[kind])
		row.add_child(_label("%d/%d" % [bag + stock, cost[kind]], 13, READY if enough else WARNING))
		row.tooltip_text = "%s · 가방 %d + 창고 %d%s" % [Balance.RESOURCE_NAMES[kind], bag, stock, "" if enough else " · %d개 부족" % (int(cost[kind]) - bag - stock)]
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


func _icon(index: int, pixels: int) -> TextureRect:
	var texture := AtlasTexture.new()
	texture.atlas = ICONS
	texture.region = Rect2(index * 48, 0, 48, 48) if index < 4 else Rect2(192, 0, 64, 64)
	var icon := TextureRect.new()
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2.ONE * pixels
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


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
