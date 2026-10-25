class_name PassiveTree
extends Control
## 중앙에서 뻗는 패시브 노드와 선행 연결선. 배치는 시각 데이터, 실제 선행 관계는 PassiveDB를 따른다.

signal node_selected(id: String)

const CENTER_SIZE := 80.0
const REFERENCE_SIZE := Vector2(880, 566)

var buttons := {}
var _progression: Progression
var _selected := "sword_mastery"
var _branch := ""


func setup(progression: Progression) -> void:
	_progression = progression
	for id: String in PassiveArtDB.ICON_ORDER:
		var button := PassiveNode.new()
		button.setup(id)
		button.pressed.connect(func() -> void:
			Events.ui_sound_requested.emit("click")
			node_selected.emit(id))
		add_child(button)
		buttons[id] = button
	resized.connect(_layout_nodes)
	_layout_nodes()


func center_at() -> Vector2:
	return size / 2.0


func node_center(id: String) -> Vector2:
	return center_at() + PassiveArtDB.offset(id)


func _layout_nodes() -> void:
	for id: String in buttons:
		buttons[id].position = node_center(id) - Vector2.ONE * PassiveArtDB.NODE_SIZE / 2.0
	queue_redraw()


func refresh(selected: String, branch: String) -> void:
	_selected = selected
	_branch = branch
	for id: String in buttons:
		var button: PassiveNode = buttons[id]
		var rank := _progression.rank(id)
		var missing := PassiveDB.missing_requirements(id, _progression.ranks)
		var maximum := PassiveDB.max_rank(id)
		var cost := _progression.next_cost(id)
		var available := missing.is_empty() and cost >= 0 and _progression.xp >= cost
		button.state = PassiveNode.State.COMPLETE if rank >= maximum else PassiveNode.State.LEARNED if rank > 0 else PassiveNode.State.AVAILABLE if available else PassiveNode.State.LOCKED
		button.selected = id == selected
		button.rank_text = "%d/%d" % [rank, maximum]
		button.modulate.a = 1.0 if branch == "" or PassiveDB.PASSIVES[id]["branch"] == branch or id == selected else 0.3
		button.tooltip_text = "%s · %d/%d\n%s" % [PassiveDB.PASSIVES[id]["name"], rank, maximum, PassiveDB.describe(id, mini(rank + 1, maximum))]
		button.queue_redraw()
	queue_redraw()


func _draw() -> void:
	if _progression == null:
		return
	var center := center_at()
	for radius: Vector2 in PassiveArtDB.RADII.slice(1):
		var points := PackedVector2Array()
		for i in 97:
			var angle := TAU * float(i) / 96.0
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		draw_polyline(points, Color(0.28, 0.39, 0.45, 0.12), 1.0)
	for id: String in buttons:
		var info: Dictionary = PassiveDB.PASSIVES[id]
		var sources: Array = info["requires"]
		if sources.is_empty():
			_draw_link(center, node_center(id), id, _progression.rank(id) > 0)
		else:
			for required: String in sources:
				_draw_link(node_center(required), node_center(id), id, _progression.rank(required) > 0)
	var crest := Rect2(center - Vector2.ONE * CENTER_SIZE / 2.0, Vector2.ONE * CENTER_SIZE)
	draw_circle(center, 45, Color(0.85, 0.66, 0.3, 0.07))
	draw_texture_rect_region(MenuArt.TEXTURE, crest, MenuArt.CREST)
	draw_string(get_theme_default_font(), center + Vector2(-60, 65), "나의 성장", HORIZONTAL_ALIGNMENT_CENTER, 120, 16, MenuArt.GOLD)
	var labels := {"combat": Vector2(82, 68), "survival": Vector2(690, 48), "building": Vector2(650, 510)}
	for branch: String in labels:
		var at: Vector2 = labels[branch]
		var tint: Color = MenuArt.BRANCH_COLORS[branch]
		if _branch != "" and _branch != branch:
			tint.a = 0.3
		draw_string(get_theme_default_font(), at, PassiveDB.BRANCH_NAMES[branch], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, tint)
		draw_string(get_theme_default_font(), at + Vector2(0, 20), " · ".join(PassiveDB.LANES[branch]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(tint, tint.a * 0.65))


func _draw_link(from: Vector2, to: Vector2, id: String, active: bool) -> void:
	var branch: String = PassiveDB.PASSIVES[id]["branch"]
	var tint: Color = MenuArt.BRANCH_COLORS[branch]
	var alpha := 0.8 if active else 0.23
	if _branch != "" and branch != _branch:
		alpha *= 0.25
	if active:
		draw_line(from, to, Color(tint, alpha * 0.1), 7.0)
	draw_line(from, to, Color(tint, alpha), 1.5)
