class_name Balance
extends RefCounted
## 밸런스 수치 모음. 플레이 테스트하면서 여기 숫자만 고치면 된다.

const TILE := 32
const WORLD_SIZE := Vector2i(192, 192)
const REVEAL_RADIUS := 11

# 왕국
const TERRITORY_RADIUS := 13  # 핵 중심에서 칸 단위. 이 안에서만 건설 가능
const BUILD_REACH := 7.0 * TILE
const START_STOCK := {"wood": 20, "stone": 10}
## 자원 id -> 이름. 순서 = HUD 표시 순서. 바이옴 재료는 D-014 (이름은 가안)
const RESOURCE_NAMES := {
	"wood": "나무", "stone": "돌",
	"hardwood": "단단한 목재", "copper": "구리", "iron_ore": "철광석", "moss": "이끼", "obsidian": "흑요석",
	"tough_hide": "질긴 가죽", "venom_sting": "전갈 독침", "ice_crystal": "얼음 결정",
	"swamp_ooze": "늪 점액", "fire_core": "화염 핵",
	"coal": "석탄", "resin": "송진", "boss_essence": "보스의 정수",
}
const BOSS_ESSENCE_PER_BOSS := 1  # 보스를 잡으면 왕국 창고로 들어오는 보스의 정수 (D-022)
const CORE_MAX_HP := 1000.0
const REPAIR_COST := {"wood": 10, "stone": 5}
const REPAIR_AMOUNT := 80.0
const REPAIR_RANGE := 4.0 * TILE
const USE_REACH := 2.0 * TILE  # 장비 상자·제작대를 쓸 수 있는 거리
const DEPOSIT_RANGE := 4.0 * TILE  # 핵 중심에서 이 안에 들어오면 개인 자원이 공용 창고로 (D-014)

# 개인 인벤토리 (D-014, 수치 임시)
const INVENTORY_SLOTS := 8
const STACK_SIZE := 50  # 칸 하나에 같은 자원 최대 개수

# 시간 (초)
const DAY_LENGTH := 75.0
const NIGHT_LENGTH := 50.0
const DUSK_LENGTH := 12.0  # 낮이 끝나기 전 어두워지는 시간
const DAWN_LENGTH := 5.0

# 플레이어
const PLAYER_BASE_HP := 100.0
const PLAYER_SPEED := 190.0
const PLAYER_HIT_INVULN := 0.4
const DASH_COOLDOWN := 2.5  # 대시는 장비가 아닌 기본 능력 (Space)
const RESPAWN_TIME := 6.0
const RESPAWN_INVULN := 2.0

# 적
const WANDERER_MAX := 8
const WANDERER_SPAWN_INTERVAL := 2.0
const WANDERER_SPAWN_RING := Vector2(14, 22)  # 플레이어에서 칸 단위 최소/최대
const WANDERER_DESPAWN_DISTANCE := 40.0 * TILE
const INVADER_AGGRO := 6.0 * TILE
const WANDERER_AGGRO := 10.0 * TILE
const ENEMY_ATTACK_INTERVAL := 0.8
const WAVE_SPAWN_WINDOW := 22.0  # 밤이 시작되고 이 시간 안에 웨이브가 다 나온다
const WAVE_SPAWN_RING := Vector2(16, 22)  # 핵에서 칸 단위 최소/최대
const WAVE_SIZE_MAX := 110  # 한 밤 침공 적 수 상한 (성능). 그 뒤로는 체력·피해 배율로 어려워진다
const FINAL_DAY := 21  # 이 날 밤의 최종 보스를 잡으면 승리 (D-021, 임시)
const BOSS_HP_PER_EXTRA_PLAYER := 0.6  # 보스 체력: 플레이어가 한 명 늘 때마다 기본의 60%씩 더

# 경험치 (D-015, 수치 임시). 처치 경험치는 EnemyDB의 "xp"
const XP_HARVEST_BY_TIER := [1, 2, 3, 4]  # 부순 오브젝트가 있던 바이옴 단계별
const XP_CRAFT_BY_TIER := [3, 6, 10, 15]  # 레시피 단계별


## 화살탑이 잡은 적의 경험치는 플레이어 수로 나눠 모두에게 준다 (사용자 결정). 올림이라 최소 1
static func tower_xp_share(xp: int, players: int) -> int:
	return ceili(float(xp) / maxi(1, players))


## 난이도 곡선 (D-021, 가파르게, 수치 임시). 1일차 10마리 → 9일차 52 → 18일차부터 상한 110
static func wave_size(day: int) -> int:
	return mini(WAVE_SIZE_MAX, 6 + day * 4 + floori(day * day / 8.0))


## 침공 적 체력 배율: 6일차 약 2.4배, 12일차 약 4.9배, 21일차 약 10배
static func wave_hp_scale(day: int) -> float:
	var d := day - 1
	return 1.0 + d * 0.22 + d * d * 0.012


## 침공 적 피해 배율: 21일차 2.4배
static func wave_damage_scale(day: int) -> float:
	return 1.0 + (day - 1) * 0.07


## 낮에 돌아다니는 적도 날이 갈수록 강해진다 (침공보다 완만하게)
static func wanderer_hp_scale(day: int) -> float:
	return 1.0 + (day - 1) * 0.1


static func wanderer_damage_scale(day: int) -> float:
	return 1.0 + (day - 1) * 0.04


static func is_boss_night(day: int) -> bool:
	return day % 3 == 0


## 보스마다 기본 체력이 다르고(EnemyDB), 함께하는 플레이어 수만큼 더 단단해진다
static func boss_hp_scale(players: int) -> float:
	return 1.0 + maxi(0, players - 1) * BOSS_HP_PER_EXTRA_PLAYER


## {"wood": 3, "stone": 1} → "나무 +3 돌 +1"
static func format_gain(amounts: Dictionary) -> String:
	var parts := PackedStringArray()
	for kind in amounts:
		parts.append("%s +%d" % [RESOURCE_NAMES[kind], amounts[kind]])
	return " ".join(parts)


## {"wood": 10, "stone": 5} → "나무 10 돌 5"
static func format_cost(cost: Dictionary) -> String:
	var parts := PackedStringArray()
	for kind in cost:
		parts.append("%s %d" % [RESOURCE_NAMES[kind], cost[kind]])
	return " ".join(parts)
