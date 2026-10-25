class_name PassiveDB
extends RefCounted
## 경험치로 찍는 캐릭터 패시브 (D-015). 수치는 임시.
## "costs"[n] = n+1번째 단계를 배우는 경험치, "values"[n] = n+1단계일 때의 효과 값(누적).
## "desc"의 %s 자리에 효과 값이 들어간다. ORDER 순서대로 패시브 창에 나온다.

const ORDER := ["wide_harvest", "bountiful", "deep_pockets", "vitality", "keen_edge", "swift", "scavenger"]

const PASSIVES := {
	"wide_harvest": {
		"name": "광역 채집", "desc": "채집할 때 주변 %s칸 안의 나무·바위·광석도 함께 캔다",
		"costs": [15, 35], "values": [1.0, 1.5],
	},
	"bountiful": {
		"name": "풍요로운 손", "desc": "채집할 때 재료를 %s개 더 얻는다",
		"costs": [8, 16, 28], "values": [1, 2, 3],
	},
	"deep_pockets": {
		"name": "큰 가방", "desc": "가방이 %s칸 늘어난다",
		"costs": [10, 22], "values": [2, 4],
	},
	"vitality": {
		"name": "강인함", "desc": "최대 체력 +%s",
		"costs": [8, 16, 28], "values": [15, 30, 50],
	},
	"keen_edge": {
		"name": "날카로운 일격", "desc": "기본 공격 피해 +%s%%",
		"costs": [10, 20, 34], "values": [10, 20, 35],
	},
	"swift": {
		"name": "날렵함", "desc": "이동 속도 +%s%%",
		"costs": [10, 22], "values": [8, 16],
	},
	"scavenger": {
		"name": "약탈자", "desc": "바이옴 몬스터의 희귀 재료 확률 +%s%%",
		"costs": [10, 22], "values": [15, 30],
	},
}


static func max_rank(id: String) -> int:
	return PASSIVES[id]["costs"].size()


## rank단계일 때의 효과 값. 0단계면 0
static func value_at(id: String, rank: int) -> float:
	return 0.0 if rank <= 0 else float(PASSIVES[id]["values"][rank - 1])


static func describe(id: String, rank: int) -> String:
	var value := value_at(id, rank)
	return PASSIVES[id]["desc"] % (str(int(value)) if is_equal_approx(value, roundf(value)) else str(value))
