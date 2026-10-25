class_name EquipmentPanel
extends Control
## 장비창 (I). 착용 장비를 누르면 해제, 가방 장비를 누르면 착용한다. 게임은 멈추지 않는다.

var _equipment: Equipment
var _slots: VBoxContainer
var _bag: VBoxContainer
var _skill_preview: Label


func setup(equipment: Equipment) -> void:
	_equipment = equipment
	var box := UiKit.dialog(self, "장비", 640.0)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	box.add_child(columns)
	_slots = _add_column(columns, "착용 중 (클릭해서 해제)")
	_bag = _add_column(columns, "가방 (클릭해서 착용)")
	_skill_preview = UiKit.heading("", 15, UiKit.ACCENT)
	box.add_child(_skill_preview)
	box.add_child(UiKit.note("스킬 정렬 규칙(기획 미정)은 임시로 슬롯 순서를 따릅니다. 5번째 스킬부터는 스킬바에 나오지 않습니다. 장비창을 열어도 게임은 멈추지 않습니다."))
	box.add_child(UiKit.button("닫기 (I)", toggle))
	_equipment.changed.connect(_refresh)
	hide()


func toggle() -> void:
	visible = not visible
	if visible:
		_refresh()


func _add_column(parent: Control, title: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(UiKit.note(title))
	var list := VBoxContainer.new()
	column.add_child(list)
	parent.add_child(column)
	return list


func _refresh() -> void:
	if not visible:
		return
	for child in _slots.get_children() + _bag.get_children():
		child.queue_free()
	for slot: String in ItemDB.SLOTS:
		var id := _equipment.item_in(slot)
		var text: String = "%s: %s" % [ItemDB.SLOT_NAMES[slot], ItemDB.ITEMS[id]["name"] if id != "" else "비어 있음"]
		if id != "":
			text += "\n" + ItemDB.describe(id)
		_slots.add_child(UiKit.button(text, _equipment.unequip.bind(slot)))
	if _equipment.bag.is_empty():
		_bag.add_child(UiKit.note("상자를 열면 장비가 들어옵니다."))
	for id in _equipment.bag:
		var item: Dictionary = ItemDB.ITEMS[id]
		var text: String = "%s: %s\n%s" % [ItemDB.SLOT_NAMES[item["slot"]], item["name"], ItemDB.describe(id)]
		_bag.add_child(UiKit.button(text, _equipment.equip.bind(id)))
	var names := PackedStringArray()
	var bar := _equipment.skill_bar()
	for i in bar.size():
		names.append("%d %s" % [i + 1, ItemDB.ITEMS[bar[i]]["skill"]["name"]])
	_skill_preview.text = "스킬바: " + ("  ·  ".join(names) if not names.is_empty() else "없음")
