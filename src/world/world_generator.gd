class_name WorldGenerator
extends RefCounted
## 시드 문자열 → WorldData. 같은 시드는 항상 같은 월드를 만든다.
## 바이옴은 왕국(중앙)에서의 거리로 단계를 정하고(D-014), 같은 단계 안의 두 바이옴은 습도로 나눈다.
## 물과 해변은 높이로 정한다. 상수를 바꾸면 tools/world_stats.gd 로 비율을 확인한다.

const ELEVATION_FREQUENCY := 1.0 / 28.0
const MOISTURE_FREQUENCY := 1.0 / 36.0
const RING_FREQUENCY := 1.0 / 20.0
const WATER_LEVEL := 0.40
const BEACH_LEVEL := 0.43
## 단계 경계(핵에서 칸 거리). [0→1, 1→2, 2→3]
const RING_EDGES := [34.0, 54.0, 73.0]
const RING_WOBBLE := 6.0  # 경계를 노이즈로 이만큼(칸) 흔들어 원 모양이 드러나지 않게 한다
const WET_LEVEL := 0.5  # 같은 단계 안에서 이보다 습하면 숲·늪, 아니면 사막·설원
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
	var ring_noise := _make_noise(seed_value + 2, RING_FREQUENCY)
	var center := Vector2(data.size) / 2.0
	for y in data.size.y:
		for x in data.size.x:
			var cell := Vector2i(x, y)
			var distance := (Vector2(cell) - center).length()
			var edge := distance / center.x
			var e := _sample(elevation, cell) + CENTER_LIFT - maxf(0.0, edge - COAST_START) * COAST_DROP
			var wobbled := distance + ring_noise.get_noise_2d(x, y) * RING_WOBBLE
			var terrain := _terrain_for(e, _sample(moisture, cell), _ring_for(wobbled))
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


## 흔들린 거리 → 바이옴 단계 0~3
static func _ring_for(distance: float) -> int:
	for tier in RING_EDGES.size():
		if distance < RING_EDGES[tier]:
			return tier
	return RING_EDGES.size()


static func _terrain_for(elevation: float, moisture: float, ring: int) -> int:
	if elevation < WATER_LEVEL:
		return WorldData.Terrain.WATER
	if elevation < BEACH_LEVEL:
		return WorldData.Terrain.SAND
	var wet := moisture > WET_LEVEL
	match ring:
		0:
			return WorldData.Terrain.GRASS
		1:
			return WorldData.Terrain.FOREST if wet else WorldData.Terrain.DESERT
		2:
			return WorldData.Terrain.SWAMP if wet else WorldData.Terrain.SNOW
	return WorldData.Terrain.VOLCANO


## 바이옴별 자원 배치. roll은 0~1 난수. 바이옴마다 그곳에서만 나는 재료가 있다 (D-014)
static func _object_for(terrain: int, roll: float) -> int:
	match terrain:
		WorldData.Terrain.GRASS:
			if roll < 0.04: return WorldData.Obj.TREE
			if roll < 0.055: return WorldData.Obj.ROCK
		WorldData.Terrain.FOREST:
			if roll < 0.22: return WorldData.Obj.TREE
			if roll < 0.31: return WorldData.Obj.HARDWOOD_TREE
			if roll < 0.325: return WorldData.Obj.ROCK
		WorldData.Terrain.DESERT:
			if roll < 0.01: return WorldData.Obj.TREE
			if roll < 0.04: return WorldData.Obj.ROCK
			if roll < 0.065: return WorldData.Obj.COPPER_ORE
		WorldData.Terrain.SNOW:
			if roll < 0.10: return WorldData.Obj.ROCK
			if roll < 0.135: return WorldData.Obj.IRON_ORE
		WorldData.Terrain.SWAMP:
			if roll < 0.08: return WorldData.Obj.TREE
			if roll < 0.14: return WorldData.Obj.MOSS
		WorldData.Terrain.VOLCANO:
			if roll < 0.06: return WorldData.Obj.ROCK
			if roll < 0.10: return WorldData.Obj.OBSIDIAN
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
