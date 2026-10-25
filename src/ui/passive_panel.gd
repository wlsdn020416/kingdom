class_name PassivePanel
extends Control
## 중앙에서 뻗는 패시브 성장 지도와 선택한 노드의 상세·학습 버튼.
## 배치는 PassiveArtDB, 선행 조건·비용·효과는 PassiveDB, 학습 명령은 Progression이 소유한다.

const DESIGN_SIZE := Vector2(1232, 672)
const VIEW_MARGIN := 24.0

var _progression: Progression
var _shell := PanelContainer.new()
var _canvas := Control.new()
var _tree := PassiveTree.new()
var _xp_label: Label
var _detail_icon: TextureRect
var _name_label: Label
var _branch_label: Label
var _current_label: Label
var _next_label: Label
var _requires_label: Label
var _cost_label: Label
var _learn_button: Button
var _tabs := {}
var _selected_id := "sword_mastery"
var _branch := ""


func setup(progression: Progression) -> void:
	_progression = progression
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = MenuArt.theme()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.025, 0.045, 0.065, 0.96)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	_shell.add_theme_stylebox_override("panel", MenuArt.panel(0))
	_shell.size = DESIGN_SIZE
	add_child(_shell)
	_shell.add_child(_canvas)
	_build_header()
	_tree.position = Vector2(18, 90)
	_tree.size = Vector2(880, 566)
	_canvas.add_child(_tree)
	_tree.setup(_progression)
	_tree.node_selected.connect(_select_node)
	_build_details()
	var hint := _label("노드를 선택하면 효과와 선행 조건을 확인할 수 있습니다.  ·  K / Esc 닫기", 12, MenuArt.MUTED)
	hint.position = Vector2(34, 646)
	_canvas.add_child(hint)
	resized.connect(_layout)
	_progression.changed.connect(_refresh)
	_layout()
	hide()


func _build_header() -> void:
	var title := _label("패시브", 26, MenuArt.TEXT)
	title.position = Vector2(24, 17)
	_canvas.add_child(title)
	var subtitle := _label("왕국을 지키는 나만의 성장 경로", 13, MenuArt.MUTED)
	subtitle.position = Vector2(136, 28)
	_canvas.add_child(subtitle)
	_xp_label = _label("", 22, MenuArt.GOLD)
	_xp_label.position = Vector2(850, 20)
	_xp_label.size.x = 242
	_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_canvas.add_child(_xp_label)
	var close := UiKit.button("닫기", hide)
	close.position = Vector2(1120, 16)
	close.custom_minimum_size = Vector2(88, 40)
	_canvas.add_child(close)
	var keys := ["", "combat", "survival", "building"]
	for i in keys.size():
		var key: String = keys[i]
		var text: String = "전체 경로" if key == "" else PassiveDB.BRANCH_NAMES[key]
		var button := UiKit.button(text, show_branch.bind(key))
		button.position = Vector2(24 + i * 106, 59)
		button.custom_minimum_size = Vector2(98, 32)
		button.add_theme_font_size_override("font_size", 13)
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		_canvas.add_child(button)
		_tabs[key] = button


func _build_details() -> void:
	var side := PanelContainer.new()
	side.position = Vector2(918, 92)
	side.size = Vector2(290, 550)
	side.add_theme_stylebox_override("panel", MenuArt.panel(18))
	_canvas.add_child(side)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	side.add_child(box)
	_branch_label = _label("", 13, MenuArt.GOLD)
	box.add_child(_branch_label)
	var center := CenterContainer.new()
	_detail_icon = TextureRect.new()
	_detail_icon.custom_minimum_size = Vector2(64, 64)
	_detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	center.add_child(_detail_icon)
	box.add_child(center)
	_name_label = _label("", 23, MenuArt.TEXT)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_name_label)
	box.add_child(HSeparator.new())
	box.add_child(_label("현재 효과", 12, MenuArt.MUTED))
	_current_label = _label("", 16, MenuArt.TEXT, true)
	_current_label.custom_minimum_size.y = 42
	box.add_child(_current_label)
	box.add_child(_label("다음 단계", 12, MenuArt.MUTED))
	_next_label = _label("", 15, MenuArt.TEXT, true)
	_next_label.custom_minimum_size.y = 44
	box.add_child(_next_label)
	_requires_label = _label("", 13, MenuArt.MUTED, true)
	_requires_label.custom_minimum_size.y = 42
	box.add_child(_requires_label)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	_cost_label = _label("", 18, MenuArt.GOLD)
	box.add_child(_cost_label)
	_learn_button = UiKit.button("배우기", func() -> void: _learn(_selected_id))
	_learn_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_learn_button.custom_minimum_size.y = 46
	box.add_child(_learn_button)
	var note := _label("배운 패시브는 이 판의 성장입니다.\n왕국이 멸망하면 초기화됩니다.", 12, MenuArt.MUTED, true)
	box.add_child(note)


func _layout() -> void:
	var fit := minf((size.x - VIEW_MARGIN * 2.0) / DESIGN_SIZE.x, (size.y - VIEW_MARGIN * 2.0) / DESIGN_SIZE.y)
	fit = maxf(0.1, fit)
	_shell.scale = Vector2.ONE * fit
	_shell.position = (size - DESIGN_SIZE * fit) / 2.0


func toggle() -> void:
	visible = not visible
	_refresh()


func show_branch(branch: String) -> void:
	if branch != "" and not PassiveDB.BRANCHES.has(branch):
		return
	_branch = branch
	if branch != "" and PassiveDB.PASSIVES[_selected_id]["branch"] != branch:
		_selected_id = PassiveDB.nodes_in(branch)[0]
	_refresh()


func _select_node(id: String) -> void:
	_selected_id = id
	_refresh()


func _learn(id: String) -> void:
	var error := _progression.learn(id)
	if error == "":
		(_tree.buttons[id] as PassiveNode).pulse()
	if error != "":
		Events.message.emit(error)
	Events.ui_sound_requested.emit("error" if error != "" else "level_up")


func _refresh() -> void:
	if not visible:
		return
	_xp_label.text = "경험치  %d" % _progression.xp
	for branch: String in _tabs:
		var button: Button = _tabs[branch]
		button.add_theme_color_override("font_color", MenuArt.GOLD if branch == _branch else MenuArt.MUTED)
	_tree.refresh(_selected_id, _branch)
	var info: Dictionary = PassiveDB.PASSIVES[_selected_id]
	var rank := _progression.rank(_selected_id)
	var maximum := PassiveDB.max_rank(_selected_id)
	var cost := _progression.next_cost(_selected_id)
	var missing := PassiveDB.missing_requirements(_selected_id, _progression.ranks)
	var icon := AtlasTexture.new()
	icon.atlas = PassiveNode.ICONS
	icon.region = PassiveArtDB.icon_region(_selected_id)
	_detail_icon.texture = icon
	_name_label.text = info["name"]
	_branch_label.text = "%s  /  %s    ·    %d / %d" % [PassiveDB.BRANCH_NAMES[info["branch"]], PassiveDB.LANES[info["branch"]][info["lane"]], rank, maximum]
	_branch_label.add_theme_color_override("font_color", MenuArt.BRANCH_COLORS[info["branch"]])
	_current_label.text = PassiveDB.describe(_selected_id, rank) if rank > 0 else "아직 배우지 않은 능력"
	_next_label.text = PassiveDB.describe(_selected_id, rank + 1) if cost >= 0 else "모든 단계를 배웠습니다."
	var names := PackedStringArray()
	for required: String in info["requires"]:
		names.append(("✓ " if _progression.rank(required) > 0 else "· ") + PassiveDB.PASSIVES[required]["name"])
	_requires_label.text = "중앙에서 바로 시작할 수 있습니다." if names.is_empty() else "선행 노드\n" + "\n".join(names)
	_cost_label.text = "최고 단계 달성" if cost < 0 else "필요 경험치  %d" % cost
	var can_learn := cost >= 0 and missing.is_empty() and _progression.xp >= cost
	_learn_button.disabled = not can_learn
	_learn_button.text = "최고 단계" if cost < 0 else "선행 노드 필요" if not missing.is_empty() else "경험치 부족" if _progression.xp < cost else "배우기"
	_cost_label.add_theme_color_override("font_color", MenuArt.GOLD if can_learn or cost < 0 else MenuArt.MUTED)


func _label(text: String, font_size: int, color: Color, wrap := false) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	if wrap:
		result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return result
