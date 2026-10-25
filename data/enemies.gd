class_name EnemyDB
extends RefCounted
## 적 종류. 색과 크기는 Phase 2에서 스프라이트로 교체할 임시 값.

const TYPES := {
	"slime": {"name": "슬라임", "hp": 30.0, "speed": 70.0, "damage": 8.0, "radius": 11.0, "color": Color("6fbf4a")},
	"goblin": {"name": "고블린", "hp": 22.0, "speed": 125.0, "damage": 6.0, "radius": 10.0, "color": Color("c8743a")},
	"brute": {"name": "거인", "hp": 130.0, "speed": 55.0, "damage": 20.0, "radius": 15.0, "color": Color("8a8fa8")},
	"boss": {
		"name": "보스", "hp": 900.0, "speed": 48.0, "damage": 35.0, "radius": 26.0, "color": Color("9b4fd0"),
		"is_boss": true,
		"radial_shot": {"count": 16, "interval": 3.0, "damage": 15.0, "speed": 240.0},
	},
}


## 밤 침공에 섞여 나오는 적. 날이 갈수록 강한 적이 섞인다.
static func pick_invader(day: int) -> String:
	var roll := randf()
	if day >= 3 and roll < 0.2:
		return "brute"
	if day >= 2 and roll < 0.5:
		return "goblin"
	return "slime"


## 낮에 바이옴별로 돌아다니는 적
static func wanderer_for(terrain: int) -> String:
	match terrain:
		WorldData.Terrain.DESERT:
			return "goblin"
		WorldData.Terrain.SNOW:
			return "brute"
	return "slime"
