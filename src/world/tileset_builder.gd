class_name TilesetBuilder
extends RefCounted
## 임시 타일셋을 코드로 그려서 만든다.
## Phase 2에서 Aseprite 타일셋 PNG를 쓰게 되면 _terrain_image(), _object_image()만 교체하면 된다.
## 아틀라스 좌표 규칙: 지형은 (Terrain 값, 0), 오브젝트는 (Obj 값, 0).

const TERRAIN_SOURCE := 0
const OBJECT_SOURCE := 1
const WATER_PHYSICS_LAYER := 0
const OBJECT_PHYSICS_LAYER := 1


static func build() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(Balance.TILE, Balance.TILE)
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(WATER_PHYSICS_LAYER, PhysicsLayers.WATER)
	tile_set.set_physics_layer_collision_mask(WATER_PHYSICS_LAYER, 0)
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(OBJECT_PHYSICS_LAYER, PhysicsLayers.OBJECTS)
	tile_set.set_physics_layer_collision_mask(OBJECT_PHYSICS_LAYER, 0)

	var terrain := _add_source(tile_set, TERRAIN_SOURCE, _terrain_image(), WorldData.Terrain.size())
	_add_square_collision(terrain, WorldData.Terrain.WATER, WATER_PHYSICS_LAYER, Balance.TILE / 2.0)

	var objects := _add_source(tile_set, OBJECT_SOURCE, _object_image(), WorldData.Obj.size())
	for obj in [WorldData.Obj.TREE, WorldData.Obj.ROCK, WorldData.Obj.GOLD_ORE, WorldData.Obj.CHEST]:
		_add_square_collision(objects, obj, OBJECT_PHYSICS_LAYER, Balance.TILE / 2.0 - 2.0)
	return tile_set


static func _add_source(tile_set: TileSet, id: int, image: Image, count: int) -> TileSetAtlasSource:
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = Vector2i(Balance.TILE, Balance.TILE)
	tile_set.add_source(source, id)
	for i in count:
		source.create_tile(Vector2i(i, 0))
	return source


static func _add_square_collision(source: TileSetAtlasSource, column: int, layer: int, half: float) -> void:
	var tile := source.get_tile_data(Vector2i(column, 0), 0)
	tile.add_collision_polygon(layer)
	tile.set_collision_polygon_points(layer, 0, PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half),
	]))


static func _terrain_image() -> Image:
	var t := Balance.TILE
	var image := Image.create_empty(t * Palette.TERRAIN.size(), t, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in Palette.TERRAIN.size():
		image.fill_rect(Rect2i(i * t, 0, t, t), Palette.TERRAIN[i])
		for speck in 6:
			image.fill_rect(Rect2i(i * t + rng.randi_range(0, t - 4), rng.randi_range(0, t - 4), 3, 3), Palette.TERRAIN_SPECK[i])
	return image


static func _object_image() -> Image:
	var t := Balance.TILE
	var image := Image.create_empty(t * WorldData.Obj.size(), t, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var tree := WorldData.Obj.TREE * t
	image.fill_rect(Rect2i(tree + 13, 18, 6, 12), Color("5a3a1e"))
	image.fill_rect(Rect2i(tree + 4, 2, 24, 20), Color("1d3d1a"))
	image.fill_rect(Rect2i(tree + 8, 4, 12, 8), Color("2c5a26"))
	var rock := WorldData.Obj.ROCK * t
	image.fill_rect(Rect2i(rock + 4, 8, 24, 20), Color("6d6f72"))
	image.fill_rect(Rect2i(rock + 8, 10, 10, 6), Color("8f9194"))
	var ore := WorldData.Obj.GOLD_ORE * t
	image.fill_rect(Rect2i(ore + 4, 8, 24, 20), Color("6d6f72"))
	image.fill_rect(Rect2i(ore + 9, 12, 5, 5), Color("e3b341"))
	image.fill_rect(Rect2i(ore + 18, 18, 5, 5), Color("e3b341"))
	var chest := WorldData.Obj.CHEST * t
	image.fill_rect(Rect2i(chest + 6, 10, 20, 16), Color("8a5a2b"))
	image.fill_rect(Rect2i(chest + 6, 15, 20, 2), Color("5a3a1e"))
	image.fill_rect(Rect2i(chest + 14, 15, 4, 5), Color("f0d070"))
	return image
