class_name EnemyDB
extends RefCounted
## 적 종류와 수치. color는 처치 이펙트용이며 실제 그림은 assets/enemies/enemies.png가 맡는다.
## sprite_row는 아틀라스 행, sprite_top은 4프레임 전체에서 그림이 시작되는 y좌표(체력바 배치용).
## "drop": 낮에 바이옴을 돌아다니다 죽으면 떨어뜨리는 희귀 재료 {"chance", "resources": {id: [최소, 최대]}} (D-014).
## 밤 침공으로 온 적은 떨어뜨리지 않는다. 희귀 재료를 얻으려면 그 바이옴에 가야 한다.
## "xp": 처치 경험치 (D-015).

const TYPES := {
	"slime": {"name": "슬라임", "sprite_row": 0, "sprite_top": 26, "xp": 2, "hp": 30.0, "speed": 70.0, "damage": 8.0, "radius": 11.0, "color": Color("6fbf4a")},
	"goblin": {"name": "고블린", "sprite_row": 1, "sprite_top": 11, "xp": 2, "hp": 22.0, "speed": 125.0, "damage": 6.0, "radius": 10.0, "color": Color("c8743a")},
	"brute": {
		"name": "거인", "sprite_row": 2, "sprite_top": 11, "xp": 6, "hp": 130.0, "speed": 55.0, "damage": 20.0, "radius": 15.0, "color": Color("8a8fa8"),
		"drop": {"chance": 0.5, "resources": {"ice_crystal": [1, 2]}},
	},
	"wolf": {
		"name": "늑대", "sprite_row": 3, "sprite_top": 23, "xp": 3, "hp": 45.0, "speed": 140.0, "damage": 9.0, "radius": 11.0, "color": Color("7a6a5a"),
		"drop": {"chance": 0.5, "resources": {"tough_hide": [1, 2]}},
	},
	"scorpion": {
		"name": "전갈", "sprite_row": 4, "sprite_top": 14, "xp": 4, "hp": 55.0, "speed": 95.0, "damage": 11.0, "radius": 11.0, "color": Color("c89a3a"),
		"drop": {"chance": 0.5, "resources": {"venom_sting": [1, 2]}},
	},
	"bog_slime": {
		"name": "늪 슬라임", "sprite_row": 5, "sprite_top": 15, "xp": 6, "hp": 110.0, "speed": 60.0, "damage": 16.0, "radius": 14.0, "color": Color("5a7a3a"),
		"drop": {"chance": 0.5, "resources": {"swamp_ooze": [1, 2]}},
	},
	"fire_imp": {
		"name": "화염 정령", "sprite_row": 6, "sprite_top": 8, "xp": 9, "hp": 170.0, "speed": 115.0, "damage": 24.0, "radius": 13.0, "color": Color("e0603a"),
		"drop": {"chance": 0.5, "resources": {"fire_core": [1, 2]}},
	},
	"boss": {
		"name": "보스", "sprite_row": 7, "sprite_top": 3, "xp": 40, "hp": 900.0, "speed": 48.0, "damage": 35.0, "radius": 26.0, "color": Color("9b4fd0"),
		"is_boss": true,
		"radial_shot": {"count": 16, "interval": 3.0, "damage": 15.0, "speed": 240.0},
	},
}


## 밤 침공에 섞여 나오는 적. 날이 갈수록 강한 적이 섞인다.
static func pick_invader(day: int, rng: RandomNumberGenerator) -> String:
	var roll := rng.randf()
	if day >= 3 and roll < 0.2:
		return "brute"
	if day >= 2 and roll < 0.5:
		return "goblin"
	return "slime"


## 낮에 바이옴별로 돌아다니는 적. 단계가 높은 바이옴일수록 강하다
static func wanderer_for(terrain: int) -> String:
	match terrain:
		WorldData.Terrain.FOREST:
			return "wolf"
		WorldData.Terrain.DESERT:
			return "scorpion"
		WorldData.Terrain.SNOW:
			return "brute"
		WorldData.Terrain.SWAMP:
			return "bog_slime"
		WorldData.Terrain.VOLCANO:
			return "fire_imp"
	return "slime"


## 바이옴 적이 죽을 때 떨어뜨릴 희귀 재료. 없으면 {}
## bonus_chance: 약탈자 패시브로 더해지는 확률(0~1)
static func roll_drop(type_id: String, rng: RandomNumberGenerator, bonus_chance := 0.0) -> Dictionary:
	var drop: Dictionary = TYPES[type_id].get("drop", {})
	if drop.is_empty() or rng.randf() >= drop["chance"] + bonus_chance:
		return {}
	var resources := {}
	for kind: String in drop["resources"]:
		var range_: Array = drop["resources"][kind]
		resources[kind] = rng.randi_range(range_[0], range_[1])
	return resources
