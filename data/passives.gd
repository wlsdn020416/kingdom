class_name PassiveDB
extends RefCounted
## 경험치로 찍는 캐릭터 패시브 트리 (D-015, 트리 구조는 D-020). 수치는 임시.
## 갈래(branch) 3개: 전투·생존·건설. 노드마다 "requires"의 노드를 1단계 이상 배워야 찍을 수 있다.
## "costs"[n] = n+1번째 단계를 배우는 경험치, "values"[n] = n+1단계일 때의 효과 값(누적). "desc"의 %s 자리에 효과 값이 들어간다.
## 노드 그래픽용 배치: "lane" = 갈래 안의 묶음 번호(LANES), "pos" = 갈래 격자 안의 (열, 행). 행 0이 뿌리. 같은 갈래 안에서 pos는 겹치지 않는다.

const BRANCHES := ["combat", "survival", "building"]
const BRANCH_NAMES := {"combat": "전투", "survival": "생존", "building": "건설"}
## 갈래 안의 묶음 이름 (lane 번호 순서)
const LANES := {
	"combat": ["무기 숙련", "화력"],
	"survival": ["신체", "채집"],
	"building": ["운영", "방벽"],
}

## 무기 종류(ItemDB weapon.family) -> 그 무기의 숙련 노드
const FAMILY_MASTERY := {
	"sword": "sword_mastery", "bow": "bow_mastery", "crossbow": "crossbow_mastery", "staff": "staff_mastery",
}

## 효과 규칙에 쓰는 고정 수치 (임시)
const COMBO_MULTIPLIER := 2.0  # 마무리 일격 피해 배수
const EXECUTE_HP_RATIO := 0.3  # 처형자가 적용되는 적 체력 비율
const EMBER_SPLASH_RATIO := 0.5  # 불씨 폭발이 주변 적에게 주는 피해 비율
const REGEN_DELAY := 3.0  # 재생이 시작되기까지 맞지 않아야 하는 시간(초)
const LAST_STAND_INVULN := 2.0  # 최후의 저항으로 버틴 뒤 무적 시간(초)

const PASSIVES := {
	# --- 전투: 무기 숙련 (무기 종류별로 숙련 → 특화) ---
	"sword_mastery": {
		"branch": "combat", "lane": 0, "pos": Vector2i(0, 0), "requires": [],
		"name": "검술", "desc": "검 기본 공격 피해 +%s%%",
		"costs": [8, 16, 28], "values": [10, 20, 35],
	},
	"sword_sweep": {
		"branch": "combat", "lane": 0, "pos": Vector2i(0, 1), "requires": ["sword_mastery"],
		"name": "휩쓸기", "desc": "검을 휘두르는 각도 +%s도",
		"costs": [14, 26], "values": [20, 40],
	},
	"bow_mastery": {
		"branch": "combat", "lane": 0, "pos": Vector2i(1, 0), "requires": [],
		"name": "궁술", "desc": "활 기본 공격 피해 +%s%%",
		"costs": [8, 16, 28], "values": [10, 20, 35],
	},
	"piercing_arrows": {
		"branch": "combat", "lane": 0, "pos": Vector2i(1, 1), "requires": ["bow_mastery"],
		"name": "꿰뚫는 화살", "desc": "활 기본 공격이 적을 꿰뚫고 계속 날아간다",
		"costs": [20], "values": [1],
	},
	"crossbow_mastery": {
		"branch": "combat", "lane": 0, "pos": Vector2i(2, 0), "requires": [],
		"name": "석궁술", "desc": "석궁 기본 공격 피해 +%s%%",
		"costs": [8, 16, 28], "values": [10, 20, 35],
	},
	"rapid_reload": {
		"branch": "combat", "lane": 0, "pos": Vector2i(2, 1), "requires": ["crossbow_mastery"],
		"name": "속사", "desc": "석궁 공격 속도 +%s%%",
		"costs": [14, 26], "values": [15, 30],
	},
	"staff_mastery": {
		"branch": "combat", "lane": 0, "pos": Vector2i(3, 0), "requires": [],
		"name": "마력 집중", "desc": "지팡이 기본 공격 피해 +%s%%",
		"costs": [8, 16, 28], "values": [10, 20, 35],
	},
	"ember_burst": {
		"branch": "combat", "lane": 0, "pos": Vector2i(3, 1), "requires": ["staff_mastery"],
		"name": "불씨 폭발", "desc": "지팡이 기본 공격이 맞힌 자리 %s픽셀 안의 다른 적에게 절반 피해",
		"costs": [14, 26], "values": [48, 72],
	},
	# --- 전투: 화력 (무기와 상관없는 순수 피해) ---
	"keen_edge": {
		"branch": "combat", "lane": 1, "pos": Vector2i(4, 0), "requires": [],
		"name": "날카로운 일격", "desc": "모든 기본 공격 피해 +%s%%",
		"costs": [10, 20, 34], "values": [10, 20, 35],
	},
	"combo_finisher": {
		"branch": "combat", "lane": 1, "pos": Vector2i(4, 1), "requires": ["keen_edge"],
		"name": "마무리 일격", "desc": "기본 공격 %s번마다 한 번은 피해 2배",
		"costs": [16, 28, 44], "values": [5, 4, 3],
	},
	"skill_power": {
		"branch": "combat", "lane": 1, "pos": Vector2i(5, 1), "requires": ["keen_edge"],
		"name": "스킬 위력", "desc": "장비 스킬 피해 +%s%%",
		"costs": [14, 28], "values": [15, 30],
	},
	"executioner": {
		"branch": "combat", "lane": 1, "pos": Vector2i(4, 2), "requires": ["combo_finisher"],
		"name": "처형자", "desc": "체력 30%% 이하인 적에게 기본 공격 피해 +%s%%",
		"costs": [20, 36], "values": [25, 50],
	},
	# --- 생존: 신체 ---
	"vitality": {
		"branch": "survival", "lane": 0, "pos": Vector2i(0, 0), "requires": [],
		"name": "강인함", "desc": "최대 체력 +%s",
		"costs": [8, 16, 28], "values": [15, 30, 50],
	},
	"regeneration": {
		"branch": "survival", "lane": 0, "pos": Vector2i(0, 1), "requires": ["vitality"],
		"name": "재생", "desc": "3초 동안 맞지 않으면 초당 체력 %s 회복",
		"costs": [12, 24, 38], "values": [1, 2, 4],
	},
	"last_stand": {
		"branch": "survival", "lane": 0, "pos": Vector2i(0, 2), "requires": ["regeneration"],
		"name": "최후의 저항", "desc": "쓰러질 피해를 받으면 체력 1로 버티고 2초 무적 (%s초에 한 번)",
		"costs": [30, 50], "values": [90, 60],
	},
	"quick_return": {
		"branch": "survival", "lane": 0, "pos": Vector2i(1, 1), "requires": ["vitality"],
		"name": "빠른 복귀", "desc": "부활 시간 -%s%%",
		"costs": [10, 22], "values": [25, 50],
	},
	"swift": {
		"branch": "survival", "lane": 0, "pos": Vector2i(2, 0), "requires": [],
		"name": "날렵함", "desc": "이동 속도 +%s%%",
		"costs": [10, 22], "values": [8, 16],
	},
	"windstep": {
		"branch": "survival", "lane": 0, "pos": Vector2i(2, 1), "requires": ["swift"],
		"name": "질풍", "desc": "대시 쿨타임 -%s%%",
		"costs": [12, 24], "values": [20, 40],
	},
	# --- 생존: 채집 ---
	"bountiful": {
		"branch": "survival", "lane": 1, "pos": Vector2i(3, 0), "requires": [],
		"name": "풍요로운 손", "desc": "채집할 때 재료를 %s개 더 얻는다",
		"costs": [8, 16, 28], "values": [1, 2, 3],
	},
	"wide_harvest": {
		"branch": "survival", "lane": 1, "pos": Vector2i(3, 1), "requires": ["bountiful"],
		"name": "광역 채집", "desc": "채집할 때 주변 %s칸 안의 나무·바위·광석도 함께 캔다",
		"costs": [15, 35], "values": [1.0, 1.5],
	},
	"deep_pockets": {
		"branch": "survival", "lane": 1, "pos": Vector2i(4, 0), "requires": [],
		"name": "큰 가방", "desc": "가방이 %s칸 늘어난다",
		"costs": [10, 22], "values": [2, 4],
	},
	"scavenger": {
		"branch": "survival", "lane": 1, "pos": Vector2i(5, 0), "requires": [],
		"name": "약탈자", "desc": "바이옴 몬스터의 희귀 재료 확률 +%s%%",
		"costs": [10, 22], "values": [15, 30],
	},
	"treasure_hunter": {
		"branch": "survival", "lane": 1, "pos": Vector2i(5, 1), "requires": ["scavenger"],
		"name": "보물 사냥꾼", "desc": "상자에서 장비가 나올 확률 +%s%%p",
		"costs": [14, 28], "values": [10, 20],
	},
	# --- 건설: 운영 (효과는 내가 짓거나 고칠 때 적용) ---
	"frugal_builder": {
		"branch": "building", "lane": 0, "pos": Vector2i(0, 0), "requires": [],
		"name": "알뜰한 건축", "desc": "건설 비용 -%s%%",
		"costs": [10, 22], "values": [15, 30],
	},
	"long_reach": {
		"branch": "building", "lane": 0, "pos": Vector2i(0, 1), "requires": ["frugal_builder"],
		"name": "긴 팔", "desc": "건설 거리 +%s칸",
		"costs": [8, 16], "values": [2, 4],
	},
	"tower_drill": {
		"branch": "building", "lane": 0, "pos": Vector2i(1, 1), "requires": ["frugal_builder"],
		"name": "탑 훈련", "desc": "내가 지은 화살탑 공격 속도 +%s%%",
		"costs": [14, 28], "values": [25, 50],
	},
	"repair_expert": {
		"branch": "building", "lane": 0, "pos": Vector2i(2, 1), "requires": ["frugal_builder"],
		"name": "보수 전문가", "desc": "핵 수리량 +%s%%",
		"costs": [10, 22], "values": [50, 100],
	},
	# --- 건설: 방벽 ---
	"sturdy_build": {
		"branch": "building", "lane": 1, "pos": Vector2i(3, 0), "requires": [],
		"name": "튼튼한 기초", "desc": "내가 지은 건물 체력 +%s%%",
		"costs": [10, 22, 36], "values": [25, 50, 80],
	},
	"mending_walls": {
		"branch": "building", "lane": 1, "pos": Vector2i(3, 1), "requires": ["sturdy_build"],
		"name": "자가 보수", "desc": "내가 지은 건물이 초당 체력 %s 회복",
		"costs": [14, 28], "values": [1, 2],
	},
	"thorn_walls": {
		"branch": "building", "lane": 1, "pos": Vector2i(4, 1), "requires": ["sturdy_build"],
		"name": "가시 벽", "desc": "내가 지은 건물을 때린 적이 피해의 %s%%를 돌려받는다",
		"costs": [14, 28], "values": [30, 60],
	},
	"fortify": {
		"branch": "building", "lane": 1, "pos": Vector2i(3, 2), "requires": ["mending_walls", "repair_expert"],
		"name": "긴급 요새화", "desc": "밤이 시작될 때 왕국의 건물과 핵 체력을 %s%% 회복 (한 명만 배워도 적용)",
		"costs": [30, 50], "values": [30, 60],
	},
}


static func max_rank(id: String) -> int:
	return PASSIVES[id]["costs"].size()


## rank단계일 때의 효과 값. 0단계면 0
static func value_at(id: String, rank: int) -> float:
	return 0.0 if rank <= 0 else float(PASSIVES[id]["values"][rank - 1])


## ranks(패시브 id -> 단계)에서 id의 효과 값. 다른 플레이어의 단계(RemotePlayer.ranks)에도 쓴다
static func value_in(ranks: Dictionary, id: String) -> float:
	return value_at(id, ranks.get(id, 0))


static func describe(id: String, rank: int) -> String:
	var desc: String = PASSIVES[id]["desc"]
	# 꿰뚫는 화살처럼 수치가 없는 설명도 있다
	if not desc.contains("%s"):
		return desc
	var value := value_at(id, rank)
	return desc % (str(int(value)) if is_equal_approx(value, roundf(value)) else str(value))


## 아직 배우지 않은 선행 노드 id. 비어 있으면 찍을 수 있다
static func missing_requirements(id: String, ranks: Dictionary) -> Array[String]:
	var missing: Array[String] = []
	for required: String in PASSIVES[id]["requires"]:
		if ranks.get(required, 0) <= 0:
			missing.append(required)
	return missing


## 갈래의 노드 id (행, 열 순서)
static func nodes_in(branch: String) -> Array[String]:
	var ids: Array[String] = []
	for id: String in PASSIVES:
		if PASSIVES[id]["branch"] == branch:
			ids.append(id)
	ids.sort_custom(func(a: String, b: String) -> bool:
		var pa: Vector2i = PASSIVES[a]["pos"]
		var pb: Vector2i = PASSIVES[b]["pos"]
		return pa.y < pb.y or (pa.y == pb.y and pa.x < pb.x))
	return ids


## 건물을 지을 때 짓는 사람의 패시브로 정해지는 효과. Kingdom.build()의 perks로 넘긴다 (직렬화할 수 있는 값만)
static func build_perks(ranks: Dictionary) -> Dictionary:
	return {
		"discount": value_in(ranks, "frugal_builder") / 100.0,
		"reach": value_in(ranks, "long_reach"),
		"hp_scale": 1.0 + value_in(ranks, "sturdy_build") / 100.0,
		"regen": value_in(ranks, "mending_walls"),
		"thorns": value_in(ranks, "thorn_walls") / 100.0,
		"tower_rate": 1.0 + value_in(ranks, "tower_drill") / 100.0,
	}
