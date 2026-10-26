class_name QuestDB
extends RefCounted
## 낮 의뢰 (D-037). 아침마다 무작위로 나타나 해가 지면 사라진다. 보상은 함께 하는 모두가 받는다. 수치는 임시.
## 종류: "elite"(정예 사냥) · "runner"(도망치는 보물 고블린) · "vein"(운석 광맥 캐기).

const PER_DAY := 2
## 의뢰는 플레이어에게서 이만큼 떨어진 곳에 나타난다 (칸)
const MIN_DISTANCE := 15.0
## 그날 나올 수 있는 바이옴 단계: 1~4일 1단계, 5~8일 2단계, 9일부터 3단계까지
const DAYS_PER_TIER := 4

const KINDS := {
	"elite": {
		"title": "%s의 정예 %s", "goal": "정예 %s 처치",
		"hp_scale": 5.0, "damage_scale": 1.5,
		"xp": [30, 50, 70, 90], "drop_amount": [4, 6, 8, 10],
	},
	"runner": {
		"title": "%s의 보물 고블린", "goal": "도망치는 보물 고블린 잡기",
		"monster": "goblin", "hp_scale": 3.0, "speed_scale": 1.6,
		"xp": [20, 35, 50, 65], "harvest_amount": [8, 12, 16, 20], "basic_amount": 10,
	},
	"vein": {
		"title": "%s의 운석 광맥", "goal": "광맥 캐기",
		"count": [6, 8, 10, 12], "radius": 3,
		"xp": [25, 40, 55, 70], "bonus_amount": [4, 6, 8, 10],
	},
}

## 바이옴마다 광맥으로 솟는 오브젝트 (그 바이옴에서 가장 귀한 것)
const VEIN_OBJECTS := {
	WorldData.Terrain.GRASS: WorldData.Obj.ROCK,
	WorldData.Terrain.FOREST: WorldData.Obj.HARDWOOD_TREE,
	WorldData.Terrain.DESERT: WorldData.Obj.COPPER_ORE,
	WorldData.Terrain.SNOW: WorldData.Obj.IRON_ORE,
	WorldData.Terrain.SWAMP: WorldData.Obj.MOSS,
	WorldData.Terrain.VOLCANO: WorldData.Obj.OBSIDIAN,
}


static func max_tier(day: int) -> int:
	return mini(3, 1 + (day - 1) / DAYS_PER_TIER)


static func tier_of(terrain: int) -> int:
	return WorldData.TERRAIN_TIER[terrain]


static func title(kind: String, terrain: int) -> String:
	var info: Dictionary = KINDS[kind]
	var place: String = WorldData.TERRAIN_NAMES[terrain]
	if kind == "elite":
		return info["title"] % [place, EnemyDB.TYPES[EnemyDB.wanderer_for(terrain)]["name"]]
	return info["title"] % place


static func goal(kind: String, terrain: int) -> String:
	var info: Dictionary = KINDS[kind]
	if kind == "elite":
		return info["goal"] % EnemyDB.TYPES[EnemyDB.wanderer_for(terrain)]["name"]
	return info["goal"]


static func xp(kind: String, terrain: int) -> int:
	return KINDS[kind]["xp"][tier_of(terrain)]


## 완료 보상 재료 (모두 같은 양을 받는다)
static func reward(kind: String, terrain: int) -> Dictionary:
	var info: Dictionary = KINDS[kind]
	var tier := tier_of(terrain)
	match kind:
		"elite":
			return {_monster_material(terrain): info["drop_amount"][tier]}
		"runner":
			var result := {"wood": info["basic_amount"], "stone": info["basic_amount"]}
			for kind_id: String in WorldData.OBJECT_DROPS[VEIN_OBJECTS[terrain]]:
				result[kind_id] = result.get(kind_id, 0) + info["harvest_amount"][tier]
			return result
		"vein":
			var bonus := {}
			for kind_id: String in WorldData.OBJECT_DROPS[VEIN_OBJECTS[terrain]]:
				bonus[kind_id] = info["bonus_amount"][tier]
			return bonus
	return {}


## 그 바이옴 몬스터의 희귀 재료. 초원 슬라임처럼 없으면 돌
static func _monster_material(terrain: int) -> String:
	var drop: Dictionary = EnemyDB.TYPES[EnemyDB.wanderer_for(terrain)].get("drop", {})
	var resources: Dictionary = drop.get("resources", {})
	return resources.keys()[0] if not resources.is_empty() else "stone"
