class_name Loot
extends RefCounted
## 상자 보상 (D-014). 상자가 놓인 바이옴의 자원이 기본이고, 낮은 확률로 장비가 함께 나온다(이미 가진 장비도 나옴).
## 장비는 주로 제작대에서 만든다. 결과에 영향을 주는 무작위라 멀티플레이에서는 호스트만 굴린다.

const ITEM_CHANCE := 0.15

## 바이옴(지형) -> 자원 id -> [최소, 최대]. 희귀 재료(몬스터 드롭)는 상자에서 나오지 않는다.
const BIOME_RESOURCES := {
	WorldData.Terrain.GRASS: {"wood": [4, 8], "stone": [3, 6]},
	WorldData.Terrain.SAND: {"wood": [2, 5], "stone": [2, 5]},
	WorldData.Terrain.FOREST: {"wood": [6, 10], "hardwood": [2, 4]},
	WorldData.Terrain.DESERT: {"stone": [4, 8], "copper": [2, 4]},
	WorldData.Terrain.SNOW: {"stone": [4, 8], "iron_ore": [2, 4]},
	WorldData.Terrain.SWAMP: {"wood": [3, 6], "moss": [2, 4]},
	WorldData.Terrain.VOLCANO: {"stone": [4, 8], "obsidian": [2, 3]},
}


## {"resources": {...}} 에 낮은 확률로 "item": id 가 더해진다
static func roll_chest(terrain: int) -> Dictionary:
	var table: Dictionary = BIOME_RESOURCES.get(terrain, BIOME_RESOURCES[WorldData.Terrain.GRASS])
	var resources := {}
	for kind: String in table:
		var range_: Array = table[kind]
		resources[kind] = randi_range(range_[0], range_[1])
	var reward := {"resources": resources}
	if randf() < ITEM_CHANCE:
		reward["item"] = ItemDB.ITEMS.keys().pick_random()
	return reward
