class_name WorldGenerator
extends RefCounted
## 시드 문자열 → WorldData. 같은 시드는 항상 같은 월드를 만든다.
## 지형 분포를 바꾸려면 아래 상수를 고치고 tools/world_stats.gd 로 비율을 확인한다.

const ELEVATION_FREQUENCY := 1.0 / 28.0
const MOISTURE_FREQUENCY := 1.0 / 36.0
const WATER_LEVEL := 0.40
const BEACH_LEVEL := 0.43
const SNOW_LEVEL := 0.74
const DRY_LEVEL := 0.43  # 이보다 건조하면 사막
const WET_LEVEL := 0.56  # 이보다 습하면 숲
const CENTER_LIFT := 0.15  # 중앙을 높여서 왕국 주변이 육지가 되게 한다
const COAST_START := 0.7  # 중심에서 이 비율보다 멀어지면 점점 바다가 된다 (월드 경계)
const COAST_DROP := 1.4
const KINGDOM_FLOOR_RADIUS := 3
const CHEST_COUNT := 40
const CHEST_MIN_DISTANCE := 20.0


static func generate(seed_text: String) -> WorldData:
	var data := WorldData.new(Balance.WORLD_SIZE, seed_text)
	var seed_value := seed_text.hash()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var elevation := _make_noise(seed_value, ELEVATION_FREQUENCY)
	var moisture := _make_noise(seed_value + 1, MOISTURE_FREQUENCY)
	var center := Vector2(data.size) / 2.0
	for y in data.size.y:
		for x in data.size.x:
			var cell := Vector2i(x, y)
			var edge := (Vector2(cell) - center).length() / center.x
			var e := _sample(elevation, cell) + CENTER_LIFT - maxf(0.0, edge - COAST_START) * COAST_DROP
			var terrain := _terrain_for(e, _sample(moisture, cell))
			data.set_terrain(cell, terrain)
			data.set_object(cell, _object_for(terrain, rng.randf()))
	_clear_kingdom_site(data)
	_place_chests(data, rng)
	return data


static func _make_noise(seed_value: int, frequency: float) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = frequency
	noise.fractal_octaves = 4
	return noise


## 노이즈 값(-1~1)을 대략 0~1로
static func _sample(noise: FastNoiseLite, cell: Vector2i) -> float:
	return noise.get_noise_2d(cell.x, cell.y) * 0.5 + 0.5


static func _terrain_for(elevation: float, moisture: float) -> int:
	if elevation < WATER_LEVEL:
		return WorldData.Terrain.WATER
	if elevation < BEACH_LEVEL:
		return WorldData.Terrain.SAND
	if elevation > SNOW_LEVEL:
		return WorldData.Terrain.SNOW
	if moisture < DRY_LEVEL:
		return WorldData.Terrain.DESERT
	if moisture > WET_LEVEL:
		return WorldData.Terrain.FOREST
	return WorldData.Terrain.GRASS


## 바이옴별 자원 배치. roll은 0~1 난수.
static func _object_for(terrain: int, roll: float) -> int:
	match terrain:
		WorldData.Terrain.FOREST:
			if roll < 0.33: return WorldData.Obj.TREE
			if roll < 0.345: return WorldData.Obj.ROCK
		WorldData.Terrain.GRASS:
			if roll < 0.04: return WorldData.Obj.TREE
			if roll < 0.055: return WorldData.Obj.ROCK
		WorldData.Terrain.SNOW:
			if roll < 0.14: return WorldData.Obj.ROCK
			if roll < 0.165: return WorldData.Obj.GOLD_ORE
		WorldData.Terrain.DESERT:
			if roll < 0.02: return WorldData.Obj.TREE
			if roll < 0.05: return WorldData.Obj.ROCK
			if roll < 0.065: return WorldData.Obj.GOLD_ORE
	return WorldData.Obj.NONE


## 왕국 영토를 평지로 정리한다
static func _clear_kingdom_site(data: WorldData) -> void:
	var core := data.core_cell
	var r := Balance.TERRITORY_RADIUS
	for y in range(core.y - r, core.y + r + 1):
		for x in range(core.x - r, core.x + r + 1):
			var cell := Vector2i(x, y)
			var d := Vector2(cell - core).length()
			if d > r:
				continue
			data.set_terrain(cell, WorldData.Terrain.FLOOR if d < KINGDOM_FLOOR_RADIUS else WorldData.Terrain.GRASS)
			data.set_object(cell, WorldData.Obj.NONE)


static func _place_chests(data: WorldData, rng: RandomNumberGenerator) -> void:
	var placed := 0
	for attempt in 4000:
		if placed >= CHEST_COUNT:
			return
		var cell := Vector2i(rng.randi_range(0, data.size.x - 1), rng.randi_range(0, data.size.y - 1))
		if data.is_walkable(cell) and Vector2(cell - data.core_cell).length() > CHEST_MIN_DISTANCE:
			data.set_object(cell, WorldData.Obj.CHEST)
			placed += 1
