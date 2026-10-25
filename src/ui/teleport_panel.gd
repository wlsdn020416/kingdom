class_name TeleportPanel
extends Control
## 순간이동 탑 창 (탑 옆에서 E, D-022). 모든 순간이동 탑은 연결되어 있다.
## 지도에서 탑 근처를 누르거나 목록에서 고르면 그 탑 옆으로 이동한다. 탑에서 멀어지면 닫힌다.
## 이동은 각자의 캐릭터가 정한다(D-017). 목적지는 지금 왕국에 있는 순간이동 탑만 고를 수 있다.

const PICK_RADIUS := 6  # 지도에서 누른 곳에서 이 칸 수 안의 탑으로 간다
const ARRIVE_OFFSET := Vector2(0, 1.2 * Balance.TILE)  # 탑 바로 아래에 내린다 (탑 몸에 끼지 않게)

var _kingdom: Kingdom
var _world: World
var _player: Player
var _from := World.NO_CELL
var _list: VBoxContainer
var _map: MapView


func setup(kingdom: Kingdom, world: World, player: Player, map_state: MapState) -> void:
	_kingdom = kingdom
	_world = world
	_player = player
	var box := UiKit.dialog(self, "순간이동 탑", 640.0)
	box.add_child(UiKit.note("연결된 순간이동 탑으로 이동합니다. 지도에서 탑(보라색) 근처를 누르거나 목록에서 고르세요."))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	_map = MapView.new().setup(map_state, true)
	_map.custom_minimum_size = Vector2(320, 320)
	_map.cell_clicked.connect(_on_map_clicked)
	row.add_child(_map)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_list)
	box.add_child(UiKit.button("닫기 (E)", hide))
	hide()


func open(from_cell: Vector2i) -> void:
	_from = from_cell
	show()
	_refresh()


func _process(_delta: float) -> void:
	if visible and _kingdom.find_teleport_near(_player.global_position) != _from:
		hide()


func _refresh() -> void:
	for child in _list.get_children():
		child.queue_free()
	var destinations := _destinations()
	if destinations.is_empty():
		_list.add_child(UiKit.note("연결된 다른 순간이동 탑이 없습니다. 왕국 밖에 하나 더 지어 보세요."))
	for cell in destinations:
		_list.add_child(UiKit.button(_describe(cell), travel.bind(cell)))


## 지금 탑을 뺀 모든 탑, 가까운 순서
func _destinations() -> Array[Vector2i]:
	var cells := _kingdom.teleports().filter(func(cell: Vector2i) -> bool: return cell != _from)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return Vector2(a - _from).length() < Vector2(b - _from).length())
	var result: Array[Vector2i] = []
	result.assign(cells)
	return result


func _describe(cell: Vector2i) -> String:
	var offset := cell - _kingdom.core_cell()
	var where := "왕국 안" if _kingdom.in_territory(cell) else "왕국에서 %d칸 %s" % [roundi(Vector2(offset).length()), _direction_name(offset)]
	return "순간이동 탑 · %s" % where


func _direction_name(offset: Vector2i) -> String:
	var names := ["동쪽", "남동쪽", "남쪽", "남서쪽", "서쪽", "북서쪽", "북쪽", "북동쪽"]
	var index := posmod(roundi(Vector2(offset).angle() / (PI / 4.0)), 8)
	return names[index]


func _on_map_clicked(cell: Vector2i) -> void:
	var best := World.NO_CELL
	var best_distance := float(PICK_RADIUS)
	for target in _destinations():
		var distance := Vector2(target - cell).length()
		if distance <= best_distance:
			best = target
			best_distance = distance
	if best != World.NO_CELL:
		travel(best)
	else:
		Events.message.emit("그 근처에는 순간이동 탑이 없습니다")


## 지금 탑 옆에 있고, 목적지가 아직 순간이동 탑일 때만 이동한다
func travel(cell: Vector2i) -> void:
	if _from == World.NO_CELL or _kingdom.find_teleport_near(_player.global_position) != _from \
			or not _kingdom.teleports().has(cell) or cell == _from:
		Events.message.emit("이동할 수 없습니다")
		return
	hide()
	_player.teleport_to(_world.cell_center(cell) + ARRIVE_OFFSET)
	Events.ui_sound_requested.emit("map_ping")
