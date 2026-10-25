class_name MapState
extends RefCounted
## 팀이 공유하는 탐험 지도(1칸 = 1픽셀 이미지)와 핑.
## 멀티플레이에서는 explored 정보와 pings를 동기화하면 모두 같은 지도를 보게 된다.

signal pings_changed

const MAX_PINGS := 5

var image: Image
var texture: ImageTexture
var pings: Array[Vector2i] = []
var world: World
var kingdom: Kingdom
var _dirty := false


func _init(target_world: World, target_kingdom: Kingdom) -> void:
	world = target_world
	kingdom = target_kingdom
	image = Image.create_empty(world.data.size.x, world.data.size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	texture = ImageTexture.create_from_image(image)
	Events.map_cells_changed.connect(_on_cells_changed)


## 지도 화면이 그리기 전에 부른다. 바뀐 게 있을 때만 GPU 텍스처를 갱신한다.
func flush() -> void:
	if _dirty:
		texture.update(image)
		_dirty = false


func world_size_pixels() -> Vector2:
	return Vector2(world.data.size * Balance.TILE)


func add_ping(cell: Vector2i) -> void:
	pings.append(cell)
	if pings.size() > MAX_PINGS:
		pings.pop_front()
	pings_changed.emit()


func clear_pings() -> void:
	pings.clear()
	pings_changed.emit()


func _on_cells_changed(cells: Array) -> void:
	for cell: Vector2i in cells:
		if world.data.is_explored(cell):
			image.set_pixelv(cell, _color_for(cell))
			_dirty = true


func _color_for(cell: Vector2i) -> Color:
	if kingdom.is_core_cell(cell):
		return Palette.CORE
	if kingdom.buildings.has(cell):
		return (kingdom.buildings[cell] as Building).info["color"]
	var obj := world.data.get_object(cell)
	if obj != WorldData.Obj.NONE:
		return Palette.OBJECTS[obj]
	return Palette.TERRAIN[world.data.get_terrain(cell)]
