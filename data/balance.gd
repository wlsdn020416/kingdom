class_name Balance
extends RefCounted
## 밸런스 수치 모음. 플레이 테스트하면서 여기 숫자만 고치면 된다.

const TILE := 32
const WORLD_SIZE := Vector2i(192, 192)
const REVEAL_RADIUS := 11

# 왕국
const TERRITORY_RADIUS := 13  # 핵 중심에서 칸 단위. 이 안에서만 건설 가능
const BUILD_REACH := 7.0 * TILE
const START_STOCK := {"wood": 20, "stone": 10, "gold": 0}
const RESOURCE_NAMES := {"wood": "나무", "stone": "돌", "gold": "금"}
const CORE_MAX_HP := 1000.0
const REPAIR_COST := {"wood": 10, "stone": 5}
const REPAIR_AMOUNT := 80.0
const REPAIR_RANGE := 4.0 * TILE
const STORAGE_REACH := 2.0 * TILE  # 장비 상자를 열 수 있는 거리
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
const KILL_GOLD_CHANCE := 0.3
const BOSS_GOLD := 20


static func wave_size(day: int) -> int:
	return 5 + day * 3


static func wave_hp_scale(day: int) -> float:
	return 1.0 + (day - 1) * 0.15


static func is_boss_night(day: int) -> bool:
	return day % 3 == 0


static func boss_hp_scale(day: int) -> float:
	return 1.0 + (floori(day / 3.0) - 1) * 0.35


## {"wood": 3, "gold": 1} → "나무 +3 금 +1"
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
