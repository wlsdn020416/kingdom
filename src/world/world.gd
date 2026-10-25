class_name World
extends Node2D
## 월드를 타일맵으로 그리고, 채집·상자처럼 월드를 바꾸는 일을 처리한다.
## 상태는 data(WorldData)에 있고, 타일맵은 그걸 보여주기만 한다.
## 멀티플레이에서는 호스트의 World만 오브젝트를 바꾸고, 참가자는 apply_object_state()로 결과만 받는다 (D-017 3단계).

## 오브젝트 체력이 바뀌거나(hp > 0) 사라짐(hp = 0). 호스트의 WorldSync가 참가자에게 전달한다
signal object_changed(cell: Vector2i, hp: float)
## 내 캐릭터 주변을 새로 탐험함. MapSync가 다른 사람에게 전한다 (다른 사람이 밝힌 칸은 mark_explored로 들어오고 이 신호를 내지 않는다)
signal cells_explored(cells: Array[Vector2i])

const NO_CELL := Vector2i(-1, -1)
## 채집 보상을 받을 사람이 없음 (적이 부숨). 그 밖의 harvester 값은 플레이어의 peer id (혼자 플레이면 1)
const NOBODY := 0
const HARVESTABLE := [
	WorldData.Obj.TREE, WorldData.Obj.ROCK, WorldData.Obj.HARDWOOD_TREE, WorldData.Obj.COPPER_ORE,
	WorldData.Obj.IRON_ORE, WorldData.Obj.MOSS, WorldData.Obj.OBSIDIAN,
]

@onready var terrain_layer: TileMapLayer = $Terrain
@onready var object_layer: TileMapLayer = $Objects

const HP_BAR_TIME := 4.0  # 마지막으로 맞은 뒤 채집물 체력 바가 보이는 시간(초)

var data: WorldData
var _rng: RandomNumberGenerator  # 채집 드롭용. Main.rng를 받는다
var _last_reveal_center := NO_CELL
var _hp_bar_time := {}  # Vector2i -> 남은 표시 시간
## 오브젝트 타일보다 위에 그려야 해서 별도 노드에 그린다 (World 자신의 _draw는 자식 타일맵 아래에 깔린다)
var _hp_overlay := Node2D.new()


func setup(world_data: WorldData, rng: RandomNumberGenerator) -> void:
	data = world_data
	_rng = rng
	_hp_overlay.z_index = 1
	_hp_overlay.draw.connect(_draw_hp_bars)
	add_child(_hp_overlay)
	var tile_set := TilesetBuilder.build()
	terrain_layer.tile_set = tile_set
	object_layer.tile_set = tile_set
	for y in data.size.y:
		for x in data.size.x:
			var cell := Vector2i(x, y)
			terrain_layer.set_cell(cell, TilesetBuilder.TERRAIN_SOURCE, TilesetBuilder.terrain_coords(data.get_terrain(cell), cell))
			var obj := data.get_object(cell)
			if obj != WorldData.Obj.NONE:
				object_layer.set_cell(cell, TilesetBuilder.OBJECT_SOURCE, Vector2i(obj, 0))


func cell_at(at: Vector2) -> Vector2i:
	return terrain_layer.local_to_map(terrain_layer.to_local(at))


func cell_center(cell: Vector2i) -> Vector2:
	return terrain_layer.to_global(terrain_layer.map_to_local(cell))


func bounds() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(data.size * Balance.TILE))


## 나무·바위·광석에 피해. 부서지면 플레이어가 부순 경우(harvester != NOBODY)에만 재료를 준다.
func damage_object(cell: Vector2i, amount: float, harvester: int) -> void:
	var obj := data.get_object(cell)
	if obj == WorldData.Obj.NONE:
		return
	if obj == WorldData.Obj.CHEST:
		if harvester != NOBODY:
			open_chest(cell, harvester)
		return
	var i := data.index(cell)
	var woody := obj in [WorldData.Obj.TREE, WorldData.Obj.HARDWOOD_TREE, WorldData.Obj.MOSS]
	Events.world_sound_requested.emit("wood_hit" if woody else "stone_hit", cell_center(cell))
	data.object_hp[i] -= amount
	if data.object_hp[i] > 0.0:
		_show_hp_bar(cell)
		object_changed.emit(cell, data.object_hp[i])
		return
	if harvester != NOBODY and WorldData.OBJECT_DROPS.has(obj):
		var drops := {}
		var base: Dictionary = WorldData.OBJECT_DROPS[obj]
		for kind in base:
			drops[kind] = base[kind] + _rng.randi_range(0, 1)
		Events.object_harvested.emit(obj, cell, drops, harvester)
	Events.world_sound_requested.emit("tree_break" if woody else "rock_break", cell_center(cell))
	_break_object(cell)


## 참가자: 호스트가 정한 오브젝트 체력을 그대로 따른다. 0이면 부서진 것
func apply_object_state(cell: Vector2i, hp: float) -> void:
	if data.get_object(cell) == WorldData.Obj.NONE:
		return
	if hp <= 0.0:
		_break_object(cell)
		return
	data.object_hp[data.index(cell)] = hp
	_show_hp_bar(cell)


## 광역 채집 패시브: cell과 그 주변 radius칸 안의 나무·바위·광석에 같은 피해 (상자는 제외)
func damage_objects_around(cell: Vector2i, amount: float, radius: float, harvester: int) -> void:
	var reach := ceili(radius)
	for y in range(-reach, reach + 1):
		for x in range(-reach, reach + 1):
			var offset := Vector2i(x, y)
			var target := cell + offset
			if offset == Vector2i.ZERO or (Vector2(offset).length() <= radius and data.get_object(target) in HARVESTABLE):
				damage_object(target, amount, harvester)


func open_chest(cell: Vector2i, opener: int) -> void:
	if data.get_object(cell) != WorldData.Obj.CHEST:
		return
	Events.world_sound_requested.emit("chest_open", cell_center(cell))
	_break_object(cell)
	Events.chest_opened.emit(cell_center(cell), opener)


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
	var around: Array[Vector2i] = []
	for y in range(center.y - r, center.y + r + 1):
		for x in range(center.x - r, center.x + r + 1):
			var cell := Vector2i(x, y)
			if (cell - center).length_squared() <= r * r:
				around.append(cell)
	var changed := mark_explored(around)
	if not changed.is_empty():
		cells_explored.emit(changed)


## 감시탑(D-022): cell 주변 radius칸을 탐험하고, 내가 밝힌 칸처럼 다른 사람에게도 전한다(cells_explored)
func reveal_area(cell: Vector2i, radius: int) -> void:
	var around: Array[Vector2i] = []
	for y in range(cell.y - radius, cell.y + radius + 1):
		for x in range(cell.x - radius, cell.x + radius + 1):
			var target := Vector2i(x, y)
			if (target - cell).length_squared() <= radius * radius:
				around.append(target)
	var changed := mark_explored(around)
	if not changed.is_empty():
		cells_explored.emit(changed)


## 칸들을 탐험한 것으로 표시하고 새로 탐험된 칸만 돌려준다. 다른 사람이 밝힌 칸도 여기로 들어온다
func mark_explored(cells: Array[Vector2i]) -> Array[Vector2i]:
	var changed: Array[Vector2i] = []
	for cell in cells:
		if not data.in_bounds(cell):
			continue
		var i := data.index(cell)
		if data.explored[i] == 0:
			data.explored[i] = 1
			changed.append(cell)
	if not changed.is_empty():
		Events.map_cells_changed.emit(changed)
	return changed


func _show_hp_bar(cell: Vector2i) -> void:
	_hp_bar_time[cell] = HP_BAR_TIME
	_hp_overlay.queue_redraw()


func _break_object(cell: Vector2i) -> void:
	var obj := data.get_object(cell)
	Fx.burst(get_tree(), cell_center(cell), Palette.OBJECTS[obj], 16 if obj == WorldData.Obj.CHEST else 10)
	_remove_object(cell)
	object_changed.emit(cell, 0.0)


func _remove_object(cell: Vector2i) -> void:
	_hp_bar_time.erase(cell)
	_hp_overlay.queue_redraw()
	data.set_object(cell, WorldData.Obj.NONE)
	object_layer.erase_cell(cell)
	Events.map_cells_changed.emit([cell])


func _process(delta: float) -> void:
	if _hp_bar_time.is_empty():
		return
	for cell: Vector2i in _hp_bar_time.keys():
		_hp_bar_time[cell] -= delta
		if _hp_bar_time[cell] <= 0.0:
			_hp_bar_time.erase(cell)
	_hp_overlay.queue_redraw()


## 나무 수관이 바를 가리지 않도록 나무만 높여 그린다. 표시 시간은 기존대로 유지한다.
func _draw_hp_bars() -> void:
	for cell: Vector2i in _hp_bar_time:
		var obj := data.get_object(cell)
		var max_hp: float = WorldData.OBJECT_HP.get(obj, 0.0)
		if max_hp <= 0.0:
			continue
		var hp := data.object_hp[data.index(cell)]
		var bar_y := -40.0 if obj in [WorldData.Obj.TREE, WorldData.Obj.HARDWOOD_TREE] else -24.0
		var top_left := _hp_overlay.to_local(cell_center(cell)) + Vector2(-HealthBarArt.WIDTH / 2.0, bar_y)
		HealthBarArt.draw_bar(_hp_overlay, top_left, hp / max_hp, HealthBarArt.Tone.GOLD)
