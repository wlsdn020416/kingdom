class_name TilesetBuilder
extends RefCounted
## Aseprite 바닥·생성물 아틀라스로 충돌을 포함한 타일셋을 구성한다.
## 아틀라스 좌표 규칙: 지형은 (Terrain 값, 변형 번호), 오브젝트는 (Obj 값, 0).

const TERRAIN_SOURCE := 0
const OBJECT_SOURCE := 1
const WATER_PHYSICS_LAYER := 0
const OBJECT_PHYSICS_LAYER := 1
const TERRAIN_TEXTURE := preload("res://assets/world/terrain.png")
const TERRAIN_VARIANTS := 4
const OBJECT_TEXTURE := preload("res://assets/world/objects.png")
const OBJECT_HEIGHT := 48


static func build() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(Balance.TILE, Balance.TILE)
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(WATER_PHYSICS_LAYER, PhysicsLayers.WATER)
	tile_set.set_physics_layer_collision_mask(WATER_PHYSICS_LAYER, 0)
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(OBJECT_PHYSICS_LAYER, PhysicsLayers.OBJECTS)
	tile_set.set_physics_layer_collision_mask(OBJECT_PHYSICS_LAYER, 0)

	var terrain := _add_source(tile_set, TERRAIN_SOURCE, TERRAIN_TEXTURE, WorldData.Terrain.size(), TERRAIN_VARIANTS)
	for variant in TERRAIN_VARIANTS:
		_add_square_collision(terrain, Vector2i(WorldData.Terrain.WATER, variant), WATER_PHYSICS_LAYER, Balance.TILE / 2.0)

	var objects := _add_source(tile_set, OBJECT_SOURCE, OBJECT_TEXTURE, WorldData.Obj.size(), 1, OBJECT_HEIGHT)
	# 그림 아래쪽은 기존 칸 바닥에 맞추고 나무 수관만 위로 솟게 한다.
	for obj in WorldData.Obj.size():
		objects.get_tile_data(Vector2i(obj, 0), 0).texture_origin = Vector2i(0, -(OBJECT_HEIGHT - Balance.TILE) / 2)
	for obj in World.HARVESTABLE + [WorldData.Obj.CHEST]:
		_add_square_collision(objects, Vector2i(obj, 0), OBJECT_PHYSICS_LAYER, Balance.TILE / 2.0 - 2.0)
	return tile_set


## 그림 변형이 보상 등 게임용 난수에 영향을 주지 않도록 좌표만으로 고른다.
static func terrain_coords(terrain: int, cell: Vector2i) -> Vector2i:
	return Vector2i(terrain, posmod(hash(cell), TERRAIN_VARIANTS))


static func _add_source(tile_set: TileSet, id: int, texture: Texture2D, count: int, rows: int = 1, height: int = Balance.TILE) -> TileSetAtlasSource:
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(Balance.TILE, height)
	tile_set.add_source(source, id)
	for row in rows:
		for column in count:
			source.create_tile(Vector2i(column, row))
	return source


static func _add_square_collision(source: TileSetAtlasSource, coords: Vector2i, layer: int, half: float) -> void:
	var tile := source.get_tile_data(coords, 0)
	tile.add_collision_polygon(layer)
	tile.set_collision_polygon_points(layer, 0, PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half),
	]))
