class_name PassivePanel
extends Control
## 패시브 창 (K). 갈래(전투·생존·건설) 탭과, 노드를 PassiveDB의 pos(열, 행)대로 놓은 격자를 보여준다 (D-020).
## 배우기는 Progression.learn()만 호출한다. 게임은 멈추지 않는다.
## 노드 그래픽(연결선·아이콘)은 따로 들어올 예정이라, 여기서는 배치·잠금·단계 표시만 한다.

const NODE_SIZE := Vector2(136, 64)

var _progression: Progression
var _xp_label: Label
var _lanes_label: Label
var _tabs: HBoxContainer
var _grid: GridContainer
var _branch: String = PassiveDB.BRANCHES[0]


func setup(progression: Progression) -> void:
	_progression = progression
	var box := UiKit.dialog(self, "패시브", 900.0)
	_xp_label = UiKit.heading("", 15, UiKit.ACCENT)
	box.add_child(_xp_label)
	box.add_child(UiKit.note("경험치는 적 처치·채집·제작으로 얻습니다. 죽으면 쓰지 않은 경험치는 사라지고, 배운 패시브는 남습니다. 위쪽 노드를 배워야 아래 노드가 열립니다."))
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 8)
	for branch: String in PassiveDB.BRANCHES:
		_tabs.add_child(UiKit.button(PassiveDB.BRANCH_NAMES[branch], show_branch.bind(branch)))
	box.add_child(_tabs)
	_lanes_label = UiKit.note("")
	box.add_child(_lanes_label)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	box.add_child(_grid)
	box.add_child(UiKit.button("닫기 (K)", hide))
	_progression.changed.connect(_refresh)
	hide()


func toggle() -> void:
	visible = not visible
	_refresh()


func show_branch(branch: String) -> void:
	_branch = branch
	_refresh()


func _learn(id: String) -> void:
	var error := _progression.learn(id)
	if error != "":
		Events.message.emit(error)
	Events.ui_sound_requested.emit("error" if error != "" else "level_up")


func _refresh() -> void:
	if not visible:
		return
	_xp_label.text = "경험치 %d" % _progression.xp
	for i in _tabs.get_child_count():
		var tab := _tabs.get_child(i) as Button
		tab.disabled = PassiveDB.BRANCHES[i] == _branch
	_lanes_label.text = "묶음: " + " · ".join(PassiveDB.LANES[_branch])
	for child in _grid.get_children():
		child.queue_free()
	var ids := PassiveDB.nodes_in(_branch)
	var size := Vector2i.ZERO
	var at := {}  # pos -> id
	for id in ids:
		var pos: Vector2i = PassiveDB.PASSIVES[id]["pos"]
		at[pos] = id
		size = Vector2i(maxi(size.x, pos.x + 1), maxi(size.y, pos.y + 1))
	_grid.columns = size.x
	for row in size.y:
		for column in size.x:
			var pos := Vector2i(column, row)
			if at.has(pos):
				_grid.add_child(_node_button(at[pos]))
			else:
				var gap := Control.new()
				gap.custom_minimum_size = NODE_SIZE
				_grid.add_child(gap)


func _node_button(id: String) -> Button:
	var info: Dictionary = PassiveDB.PASSIVES[id]
	var rank := _progression.rank(id)
	var cost := _progression.next_cost(id)
	var missing := PassiveDB.missing_requirements(id, _progression.ranks)
	var state := "최고 단계" if cost < 0 else ("잠김" if not missing.is_empty() else "경험치 %d" % cost)
	var button := UiKit.button("%s  %d/%d\n%s" % [info["name"], rank, PassiveDB.max_rank(id), state], _learn.bind(id))
	button.custom_minimum_size = NODE_SIZE
	var tip := "지금: %s" % (PassiveDB.describe(id, rank) if rank > 0 else "아직 배우지 않음")
	if cost >= 0:
		tip += "\n다음: %s" % PassiveDB.describe(id, rank + 1)
	if not missing.is_empty():
		var names := PackedStringArray()
		for required in missing:
			names.append(PassiveDB.PASSIVES[required]["name"])
		tip += "\n먼저 배울 것: %s" % ", ".join(names)
	button.tooltip_text = tip
	if cost < 0 or not missing.is_empty():
		button.disabled = true
	elif _progression.xp < cost:
		button.add_theme_color_override("font_color", UiKit.DANGER)
	return button
