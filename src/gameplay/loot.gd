class_name Loot
extends RefCounted
## 상자 보상 (D-014). 상자가 놓인 바이옴의 자원이 기본이고, 낮은 확률로 장비가 함께 나온다(이미 가진 장비도 나옴).
## 장비는 주로 제작대에서 만든다. 결과에 영향을 주는 무작위라 호스트의 rng(Main.rng)로만 굴린다.

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


## 상자에서 나올 수 있는 장비. 강화로만 얻는 무기(RecipeDB "from")는 나오지 않는다 (D-028, 임시)
static func chest_items() -> Array:
	return ItemDB.ITEMS.keys().filter(func(id: String) -> bool: return not RecipeDB.RECIPES.get(id, {}).has("from"))


## {"resources": {...}} 에 낮은 확률로 "item": id 가 더해진다. item_bonus: 보물 사냥꾼 패시브 (0.1 = +10%p)
static func roll_chest(terrain: int, rng: RandomNumberGenerator, item_bonus := 0.0) -> Dictionary:
	var table: Dictionary = BIOME_RESOURCES.get(terrain, BIOME_RESOURCES[WorldData.Terrain.GRASS])
	var resources := {}
	for kind: String in table:
		var range_: Array = table[kind]
		resources[kind] = rng.randi_range(range_[0], range_[1])
	var reward := {"resources": resources}
	if rng.randf() < ITEM_CHANCE + item_bonus:
		var ids := chest_items()
		reward["item"] = ids[rng.randi_range(0, ids.size() - 1)]
	return reward
