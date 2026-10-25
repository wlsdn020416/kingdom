class_name BuildMode
extends Node2D
## B로 켜는 건설 모드. 1~3으로 건물 선택, 좌클릭 설치, 우클릭 철거.

var active := false
var selected := 0

var _world: World
var _kingdom: Kingdom
var _player: Player


func setup(world: World, kingdom: Kingdom, player: Player) -> void:
	_world = world
	_kingdom = kingdom
	_player = player
	set_active(false)


func set_active(value: bool) -> void:
	active = value
	visible = value
	set_process(value)


func selected_type() -> String:
	return BuildingDB.ORDER[selected]


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	for i in BuildingDB.ORDER.size():
		if event.is_action_pressed("skill_%d" % (i + 1)):
			selected = i
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("attack"):
		var error := _kingdom.build(_hovered_cell(), selected_type(), _player.global_position, _player.inventory)
		if error != "":
			Events.message.emit(error)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("build_remove"):
		_kingdom.demolish(_hovered_cell())
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	queue_redraw()


func _hovered_cell() -> Vector2i:
	return _world.cell_at(get_global_mouse_position())


## 설치 미리보기 (초록: 가능, 빨강: 불가)
func _draw() -> void:
	var cell := _hovered_cell()
	var can_place := _kingdom.in_territory(cell) and _world.data.is_walkable(cell) and not _kingdom.is_occupied(cell)
	var rect := Rect2(_world.cell_center(cell) - Vector2.ONE * Balance.TILE / 2.0, Vector2.ONE * Balance.TILE)
	var color: Color = BuildingDB.TYPES[selected_type()]["color"]
	draw_rect(rect, Color(color, 0.5))
	draw_rect(rect.grow(-1.0), Color("6fcf6f") if can_place else Color("ff5040"), false, 2.0)
