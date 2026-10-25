class_name PassivePanel
extends Control
## 패시브 창 (K). 경험치로 패시브 단계를 올린다. 배우기는 Progression.learn()만 호출한다. 게임은 멈추지 않는다.

var _progression: Progression
var _xp_label: Label
var _list: GridContainer


func setup(progression: Progression) -> void:
	_progression = progression
	var box := UiKit.dialog(self, "패시브", 900.0)
	_xp_label = UiKit.heading("", 15, UiKit.ACCENT)
	box.add_child(_xp_label)
	box.add_child(UiKit.note("경험치는 적 처치·채집·제작으로 얻습니다. 죽으면 쓰지 않은 경험치는 사라지고, 배운 패시브는 남습니다."))
	# 패시브가 늘어나도 창이 화면(720) 안에 들어오게 2열로 놓는다
	_list = GridContainer.new()
	_list.columns = 2
	box.add_child(_list)
	box.add_child(UiKit.button("닫기 (K)", hide))
	_progression.changed.connect(_refresh)
	hide()


func toggle() -> void:
	visible = not visible
	_refresh()


func _learn(id: String) -> void:
	var error := _progression.learn(id)
	if error != "":
		Events.message.emit(error)


func _refresh() -> void:
	if not visible:
		return
	_xp_label.text = "경험치 %d" % _progression.xp
	for child in _list.get_children():
		child.queue_free()
	for id: String in PassiveDB.ORDER:
		var info: Dictionary = PassiveDB.PASSIVES[id]
		var rank := _progression.rank(id)
		var max_rank := PassiveDB.max_rank(id)
		var cost := _progression.next_cost(id)
		var now := PassiveDB.describe(id, rank) if rank > 0 else "아직 배우지 않음"
		var text := "%s  (%d/%d)\n지금: %s" % [info["name"], rank, max_rank, now]
		if cost >= 0:
			text += "\n다음: %s   ·   경험치 %d" % [PassiveDB.describe(id, rank + 1), cost]
		var button := UiKit.button(text, _learn.bind(id))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if cost < 0:
			button.disabled = true
		elif _progression.xp < cost:
			button.add_theme_color_override("font_color", UiKit.DANGER)
		_list.add_child(button)
