class_name WorldData
extends RefCounted
## 월드 한 판의 상태: 지형, 오브젝트(나무·바위·상자), 탐험 여부.
## 노드와 분리된 순수 데이터라 저장이나 멀티플레이 동기화를 붙이기 쉽다.

## 값이 타일 아틀라스 열 번호이자 Palette 배열 순서라서 새 값은 맨 뒤에 붙인다
enum Terrain { WATER, SAND, GRASS, FOREST, DESERT, SNOW, FLOOR, SWAMP, VOLCANO }
enum Obj { NONE, TREE, ROCK, CHEST, HARDWOOD_TREE, COPPER_ORE, IRON_ORE, MOSS, OBSIDIAN }

const TERRAIN_NAMES := ["바다", "해변", "초원", "숲", "사막", "설원", "왕국", "늪", "화산"]
## 바이옴 단계 (D-014). 왕국에서 멀수록 높다. 0 초원 / 1 숲·사막 / 2 설원·늪 / 3 화산
const TERRAIN_TIER := [0, 0, 0, 1, 1, 2, 0, 2, 3]
const OBJECT_HP := {
	Obj.TREE: 30.0, Obj.ROCK: 50.0, Obj.CHEST: 1.0, Obj.HARDWOOD_TREE: 55.0,
	Obj.COPPER_ORE: 70.0, Obj.IRON_ORE: 90.0, Obj.MOSS: 20.0, Obj.OBSIDIAN: 120.0,
}
## 채집 보상 기본값. 실제로는 0~1개가 랜덤으로 더해진다.
const OBJECT_DROPS := {
	Obj.TREE: {"wood": 3}, Obj.ROCK: {"stone": 3}, Obj.HARDWOOD_TREE: {"hardwood": 2, "resin": 1},
	Obj.COPPER_ORE: {"copper": 2, "coal": 1}, Obj.IRON_ORE: {"iron_ore": 2, "coal": 1}, Obj.MOSS: {"moss": 2}, Obj.OBSIDIAN: {"obsidian": 2},
}

var size: Vector2i
var seed_text: String
var core_cell: Vector2i
var terrain := PackedByteArray()
var objects := PackedByteArray()
var object_hp := PackedFloat32Array()
## 바이옴·종류별 나무·바위·광석 목표 수 (Vector2i(지형, 오브젝트) -> 개수). 시드로 정해져 모두가 같다 (D-035)
var resource_targets := {}
var explored := PackedByteArray()


func _init(world_size: Vector2i, text: String) -> void:
	size = world_size
	seed_text = text
	core_cell = world_size / 2
	var count := size.x * size.y
	terrain.resize(count)
	terrain.fill(Terrain.WATER)
	objects.resize(count)
	objects.fill(Obj.NONE)
	object_hp.resize(count)
	object_hp.fill(0.0)
	explored.resize(count)
	explored.fill(0)


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


func index(cell: Vector2i) -> int:
	return cell.y * size.x + cell.x


func get_terrain(cell: Vector2i) -> int:
	return terrain[index(cell)] if in_bounds(cell) else Terrain.WATER


func tier_at(cell: Vector2i) -> int:
	return TERRAIN_TIER[get_terrain(cell)]


func set_terrain(cell: Vector2i, value: int) -> void:
	terrain[index(cell)] = value


func get_object(cell: Vector2i) -> int:
	return objects[index(cell)] if in_bounds(cell) else Obj.NONE


func set_object(cell: Vector2i, value: int) -> void:
	var i := index(cell)
	objects[i] = value
	object_hp[i] = OBJECT_HP.get(value, 0.0)


func is_explored(cell: Vector2i) -> bool:
	return in_bounds(cell) and explored[index(cell)] == 1


## 물도 오브젝트도 없는 칸 (건물 여부는 Kingdom이 따로 확인)
func is_walkable(cell: Vector2i) -> bool:
	return in_bounds(cell) and get_terrain(cell) != Terrain.WATER and get_object(cell) == Obj.NONE
