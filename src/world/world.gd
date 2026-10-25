class_name World
extends Node2D
## 월드를 타일맵으로 그리고, 채집·상자처럼 월드를 바꾸는 일을 처리한다.
## 상태는 data(WorldData)에 있고, 타일맵은 그걸 보여주기만 한다.

const NO_CELL := Vector2i(-1, -1)
const HARVESTABLE := [WorldData.Obj.TREE, WorldData.Obj.ROCK, WorldData.Obj.GOLD_ORE]

@onready var terrain_layer: TileMapLayer = $Terrain
@onready var object_layer: TileMapLayer = $Objects

var data: WorldData
var _last_reveal_center := NO_CELL


func setup(world_data: WorldData) -> void:
	data = world_data
	var tile_set := TilesetBuilder.build()
	terrain_layer.tile_set = tile_set
	object_layer.tile_set = tile_set
	for y in data.size.y:
		for x in data.size.x:
			var cell := Vector2i(x, y)
			terrain_layer.set_cell(cell, TilesetBuilder.TERRAIN_SOURCE, Vector2i(data.get_terrain(cell), 0))
			var obj := data.get_object(cell)
			if obj != WorldData.Obj.NONE:
				object_layer.set_cell(cell, TilesetBuilder.OBJECT_SOURCE, Vector2i(obj, 0))


func cell_at(at: Vector2) -> Vector2i:
	return terrain_layer.local_to_map(terrain_layer.to_local(at))


func cell_center(cell: Vector2i) -> Vector2:
	return terrain_layer.to_global(terrain_layer.map_to_local(cell))


func bounds() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(data.size * Balance.TILE))


## 나무·바위·광석에 피해. 부서지면 플레이어가 부순 경우에만 자원을 준다.
func damage_object(cell: Vector2i, amount: float, by_player: bool) -> void:
	var obj := data.get_object(cell)
	if obj == WorldData.Obj.NONE:
		return
	if obj == WorldData.Obj.CHEST:
		if by_player:
			open_chest(cell)
		return
	var i := data.index(cell)
	data.object_hp[i] -= amount
	if data.object_hp[i] > 0.0:
		return
	if by_player and WorldData.OBJECT_DROPS.has(obj):
		var drops := {}
		var base: Dictionary = WorldData.OBJECT_DROPS[obj]
		for kind in base:
			drops[kind] = base[kind] + randi_range(0, 1)
		Events.resources_gained.emit(drops, cell_center(cell))
	Fx.burst(get_tree(), cell_center(cell), Palette.OBJECTS[obj])
	_remove_object(cell)


func open_chest(cell: Vector2i) -> void:
	if data.get_object(cell) != WorldData.Obj.CHEST:
		return
	_remove_object(cell)
	Fx.burst(get_tree(), cell_center(cell), Palette.OBJECTS[WorldData.Obj.CHEST], 16)
	Events.chest_opened.emit(cell_center(cell))


func find_chest_near(at: Vector2) -> Vector2i:
	var center := cell_at(at)
	for y in range(-1, 2):
		for x in range(-1, 2):
			var cell := center + Vector2i(x, y)
			if data.get_object(cell) == WorldData.Obj.CHEST:
				return cell
	return NO_CELL


## point에서 radius 안에 걸치는 오브젝트 칸 중 가장 가까운 것.
## 타일 충돌은 여러 칸이 한 바디로 묶여 있어서, 충돌한 칸은 위치로 찾는다.
func object_cell_near(point: Vector2, radius: float) -> Vector2i:
	var center := cell_at(point)
	if data.get_object(center) != WorldData.Obj.NONE:
		return center
	var best := NO_CELL
	var best_distance := INF
	for y in range(-1, 2):
		for x in range(-1, 2):
			var cell := center + Vector2i(x, y)
			if data.get_object(cell) == WorldData.Obj.NONE:
				continue
			var tile := Rect2(cell_center(cell) - Vector2.ONE * Balance.TILE / 2.0, Vector2.ONE * Balance.TILE)
			var closest := point.clamp(tile.position, tile.end)
			var d := closest.distance_to(point)
			if d <= radius + 2.0 and d < best_distance:
				best_distance = d
				best = cell
	return best


## 플레이어 주변을 탐험한 것으로 표시한다 (지도 공유의 기반)
func reveal(at: Vector2) -> void:
	var center := cell_at(at)
	if center == _last_reveal_center:
		return
	_last_reveal_center = center
	var r := Balance.REVEAL_RADIUS
	var changed: Array[Vector2i] = []
	for y in range(center.y - r, center.y + r + 1):
		for x in range(center.x - r, center.x + r + 1):
			var cell := Vector2i(x, y)
			if not data.in_bounds(cell) or (cell - center).length_squared() > r * r:
				continue
			var i := data.index(cell)
			if data.explored[i] == 0:
				data.explored[i] = 1
				changed.append(cell)
	if not changed.is_empty():
		Events.map_cells_changed.emit(changed)


func _remove_object(cell: Vector2i) -> void:
	data.set_object(cell, WorldData.Obj.NONE)
	object_layer.erase_cell(cell)
	Events.map_cells_changed.emit([cell])
