class_name StoragePanel
extends Control
## 장비 상자 창 (상자 옆에서 E). 가방 장비를 누르면 맡기고, 상자 장비를 누르면 꺼낸다.
## 옮기기는 KingdomSync를 거쳐 Kingdom.store_item()·take_item()만 호출한다. 상자에서 멀어지면 닫힌다.

const REFRESH_INTERVAL := 0.2

var _kingdom: Kingdom
var _commands: KingdomSync
var _player: Player
var _cell := World.NO_CELL
var _title: Label
var _bag: VBoxContainer
var _stored: VBoxContainer
var _refresh_timer := 0.0
var _shown := []  # 마지막으로 그린 [가방, 상자] 내용. 바뀐 경우에만 버튼을 다시 만든다


func setup(kingdom: Kingdom, player: Player, commands: KingdomSync) -> void:
	_kingdom = kingdom
	_commands = commands
	_player = player
	var box := UiKit.dialog(self, "장비 상자", 640.0)
	_title = UiKit.note("")
	box.add_child(_title)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	box.add_child(columns)
	_bag = _add_column(columns, "가방 (클릭해서 맡기기)")
	_stored = _add_column(columns, "상자 (클릭해서 꺼내기)")
	box.add_child(UiKit.note("죽으면 가방 장비는 모두 사라집니다. 상자가 부서지면 맡긴 장비도 사라집니다."))
	box.add_child(UiKit.button("닫기 (E)", hide))
	_player.equipment.changed.connect(_refresh)
	hide()


func open(cell: Vector2i) -> void:
	_cell = cell
	show()
	_refresh()


func _process(delta: float) -> void:
	if visible and _kingdom.find_storage_near(_player.global_position) != _cell:
		hide()
		return
	# 멀티플레이 참가자는 상자 내용이 호스트에게서 나중에 오므로 열려 있는 동안 가끔 다시 그린다
	_refresh_timer -= delta
	if visible and _refresh_timer <= 0.0:
		_refresh_timer = REFRESH_INTERVAL
		_refresh_if_changed()


func _add_column(parent: Control, title: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(UiKit.note(title))
	var list := VBoxContainer.new()
	column.add_child(list)
	parent.add_child(column)
	return list


func _move(id: String, to_storage: bool) -> void:
	if to_storage:
		_commands.store_item(_cell, id)
	else:
		_commands.take_item(_cell, id)
	_refresh()


func _refresh_if_changed() -> void:
	var building: Building = _kingdom.buildings.get(_cell)
	if building != null and [_player.equipment.bag, building.stored] != _shown:
		_refresh()


func _refresh() -> void:
	if not visible or not _kingdom.buildings.has(_cell):
		return
	var building: Building = _kingdom.buildings[_cell]
	_shown = [_player.equipment.bag.duplicate(), building.stored.duplicate()]
	_title.text = "보관 %d / %d" % [building.stored.size(), building.storage_capacity()]
	for child in _bag.get_children() + _stored.get_children():
		child.queue_free()
	if _player.equipment.bag.is_empty():
		_bag.add_child(UiKit.note("가방이 비어 있습니다."))
	for id in _player.equipment.bag:
		_bag.add_child(UiKit.button(_describe(id), _move.bind(id, true)))
	if building.stored.is_empty():
		_stored.add_child(UiKit.note("맡긴 장비가 없습니다."))
	for id in building.stored:
		_stored.add_child(UiKit.button(_describe(id), _move.bind(id, false)))


func _describe(id: String) -> String:
	var item: Dictionary = ItemDB.ITEMS[id]
	return "%s: %s\n%s" % [ItemDB.SLOT_NAMES[item["slot"]], item["name"], ItemDB.describe(id)]
