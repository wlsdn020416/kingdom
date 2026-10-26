class_name EnemyDB
extends RefCounted
## 적 종류와 수치. color는 처치 이펙트용이며 실제 그림은 일반 적 enemies.png·보스 bosses.png가 맡는다.
## sprite_row는 각 아틀라스 행, sprite_top은 모든 프레임의 그림 최상단(체력바 배치용).
## "drop": 낮에 바이옴을 돌아다니다 죽으면 떨어뜨리는 희귀 재료 {"chance", "resources": {id: [최소, 최대]}} (D-014).
## 밤 침공으로 온 적은 떨어뜨리지 않는다. 희귀 재료를 얻으려면 그 바이옴에 가야 한다.
## "xp": 처치 경험치 (D-015).
## 보스(D-021): "is_boss", "patterns"(아래 종류를 각자 interval마다 반복), "rage"(체력 비율 at 이하에서 패턴 rate배·이동 speed배, 낮은 것부터 덮어씀),
## "final"(처치하면 승리). 보스는 아침이 와도 사라지지 않는다.
## 패턴: radial(count발 원형), spiral(duration초 동안 arms갈래 회전 연사), fan(가장 가까운 플레이어에게 arc도 부채꼴 count발),
## charge(windup초 멈춰 번쩍인 뒤 speed로 duration초 돌진, 닿으면 damage), summon(부하 minion을 count마리, 살아 있는 부하 max_alive까지).

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
	# --- 보스 (D-021): 보스 밤마다 BOSS_ORDER 순서로 다른 보스. bosses.png의 고유 실루엣·8프레임을 쓴다 ---
	"boss": {
		"name": "타락한 수호자", "sprite_row": 0, "sprite_top": 15, "xp": 40, "hp": 1100.0, "speed": 50.0, "damage": 35.0, "radius": 26.0,
		"color": Color("9b4fd0"), "is_boss": true,
		"patterns": [
			{"type": "radial", "interval": 3.0, "count": 16, "damage": 15.0, "speed": 240.0},
			{"type": "summon", "interval": 9.0, "minion": "slime", "count": 4, "max_alive": 8},
		],
		"rage": [{"at": 0.5, "rate": 1.5, "speed": 1.2}],
	},
	"alpha_wolf": {
		"name": "늑대 군주", "sprite_row": 1, "sprite_top": 22, "xp": 70, "hp": 1900.0, "speed": 95.0, "damage": 40.0, "radius": 24.0,
		"color": Color("8a7a6a"), "is_boss": true,
		"patterns": [
			{"type": "charge", "interval": 4.5, "windup": 0.7, "duration": 0.7, "speed": 560.0, "damage": 45.0},
			{"type": "fan", "interval": 3.5, "count": 5, "arc": 50.0, "damage": 16.0, "speed": 320.0},
			{"type": "summon", "interval": 10.0, "minion": "wolf", "count": 3, "max_alive": 6},
		],
		"rage": [{"at": 0.4, "rate": 1.6, "speed": 1.35}],
	},
	"venom_tyrant": {
		"name": "독침 폭군", "sprite_row": 2, "sprite_top": 18, "xp": 100, "hp": 3000.0, "speed": 60.0, "damage": 42.0, "radius": 26.0,
		"color": Color("c89a3a"), "is_boss": true,
		"patterns": [
			{"type": "spiral", "interval": 6.0, "duration": 3.0, "rate": 10.0, "arms": 3, "turn": 2.4, "damage": 14.0, "speed": 230.0},
			{"type": "fan", "interval": 2.8, "count": 7, "arc": 70.0, "damage": 18.0, "speed": 300.0},
			{"type": "summon", "interval": 11.0, "minion": "scorpion", "count": 3, "max_alive": 6},
		],
		"rage": [{"at": 0.5, "rate": 1.5, "speed": 1.2}],
	},
	"frost_colossus": {
		"name": "서리 거신", "sprite_row": 3, "sprite_top": 6, "xp": 130, "hp": 5200.0, "speed": 38.0, "damage": 70.0, "radius": 32.0,
		"color": Color("9ad0ff"), "is_boss": true,
		"patterns": [
			{"type": "radial", "interval": 3.5, "count": 32, "damage": 22.0, "speed": 150.0, "lifetime": 3.5, "radius": 9.0},
			{"type": "charge", "interval": 8.0, "windup": 1.2, "duration": 1.0, "speed": 420.0, "damage": 80.0},
			{"type": "summon", "interval": 12.0, "minion": "brute", "count": 2, "max_alive": 4},
		],
		"rage": [{"at": 0.5, "rate": 1.4, "speed": 1.5}],
	},
	"bog_mother": {
		"name": "늪의 어머니", "sprite_row": 4, "sprite_top": 9, "xp": 160, "hp": 6000.0, "speed": 45.0, "damage": 60.0, "radius": 30.0,
		"color": Color("5a7a3a"), "is_boss": true,
		"patterns": [
			{"type": "summon", "interval": 6.0, "minion": "bog_slime", "count": 3, "max_alive": 9},
			{"type": "spiral", "interval": 7.0, "duration": 4.0, "rate": 12.0, "arms": 4, "turn": -1.8, "damage": 18.0, "speed": 200.0},
			{"type": "radial", "interval": 4.0, "count": 20, "damage": 20.0, "speed": 210.0},
		],
		"rage": [{"at": 0.5, "rate": 1.5, "speed": 1.3}, {"at": 0.2, "rate": 2.0, "speed": 1.5}],
	},
	"flame_lord": {
		"name": "화염 군주", "sprite_row": 5, "sprite_top": 4, "xp": 200, "hp": 8000.0, "speed": 70.0, "damage": 80.0, "radius": 28.0,
		"color": Color("e0603a"), "is_boss": true,
		"patterns": [
			{"type": "spiral", "interval": 5.0, "duration": 3.0, "rate": 14.0, "arms": 2, "turn": 3.2, "damage": 24.0, "speed": 280.0},
			{"type": "fan", "interval": 2.2, "count": 9, "arc": 80.0, "damage": 24.0, "speed": 360.0},
			{"type": "charge", "interval": 6.0, "windup": 0.6, "duration": 0.8, "speed": 600.0, "damage": 90.0},
			{"type": "summon", "interval": 12.0, "minion": "fire_imp", "count": 2, "max_alive": 5},
		],
		"rage": [{"at": 0.5, "rate": 1.6, "speed": 1.3}],
	},
	"kingdom_breaker": {
		"name": "왕국 파괴자", "sprite_row": 6, "sprite_top": 3, "xp": 500, "hp": 16000.0, "speed": 55.0, "damage": 110.0, "radius": 36.0,
		"color": Color("ff3050"), "is_boss": true, "final": true,
		"patterns": [
			{"type": "radial", "interval": 3.0, "count": 28, "damage": 28.0, "speed": 220.0},
			{"type": "spiral", "interval": 6.0, "duration": 3.5, "rate": 16.0, "arms": 4, "turn": 2.8, "damage": 26.0, "speed": 250.0},
			{"type": "fan", "interval": 2.5, "count": 11, "arc": 90.0, "damage": 30.0, "speed": 340.0},
			{"type": "charge", "interval": 7.0, "windup": 0.8, "duration": 0.9, "speed": 640.0, "damage": 130.0},
			{"type": "summon", "interval": 9.0, "minion": "fire_imp", "count": 3, "max_alive": 8},
		],
		"rage": [{"at": 0.6, "rate": 1.4, "speed": 1.2}, {"at": 0.3, "rate": 1.9, "speed": 1.4}, {"at": 0.1, "rate": 2.5, "speed": 1.6}],
	},
}

## 보스 밤(3일마다)에 나오는 순서. 21일차가 마지막(최종 보스) 밤이다. 그 뒤로 보스 밤이 오면 최종 보스 직전 보스들을 다시 돌린다
const BOSS_ORDER := ["boss", "alpha_wolf", "venom_tyrant", "frost_colossus", "bog_mother", "flame_lord", "kingdom_breaker"]


## day일차 보스 밤의 보스 id
static func boss_for(day: int) -> String:
	var index := floori(day / 3.0) - 1
	if index < BOSS_ORDER.size():
		return BOSS_ORDER[maxi(index, 0)]
	return BOSS_ORDER[index % (BOSS_ORDER.size() - 1)]


## 밤 침공에 섞여 나오는 적. 날이 갈수록 강한 적이 많이 섞이고 슬라임은 줄어든다 (D-021, 가중치 임시)
static func pick_invader(day: int, rng: RandomNumberGenerator) -> String:
	var weights := invader_weights(day)
	var total := 0.0
	for id: String in weights:
		total += weights[id]
	var roll := rng.randf() * total
	for id: String in weights:
		roll -= weights[id]
		if roll < 0.0:
			return id
	return "slime"


## day일차 침공 적 종류별 가중치
static func invader_weights(day: int) -> Dictionary:
	var weights := {"slime": maxf(1.0, 10.0 - day)}
	if day >= 2:
		weights["goblin"] = 4.0
	if day >= 3:
		weights["brute"] = 1.0 + day / 3.0
	if day >= 5:
		weights["wolf"] = 3.0
	if day >= 6:
		weights["scorpion"] = 3.0
	if day >= 8:
		weights["bog_slime"] = 2.0 + (day - 8) / 3.0
	if day >= 11:
		weights["fire_imp"] = 1.0 + (day - 11) / 2.0
	return weights


## 낮에 바이옴별로 돌아다니는 적. 단계가 높은 바이옴일수록 강하다
## 서식 몬스터가 사는 바이옴 (D-035). 해변·왕국 바닥·물에는 살지 않는다
const RESIDENT_TERRAINS := [
	WorldData.Terrain.GRASS, WorldData.Terrain.FOREST, WorldData.Terrain.DESERT,
	WorldData.Terrain.SNOW, WorldData.Terrain.SWAMP, WorldData.Terrain.VOLCANO,
]


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
