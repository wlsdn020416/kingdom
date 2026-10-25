class_name RecipeDB
extends RefCounted
## 제작대 레시피와 단계 업그레이드 비용 (D-014). 레시피 id = 만들어지는 장비 id.
## 레시피는 재료를 전부 한 번씩 얻어 본 뒤에 목록에 나타나고, 제작대 단계가 "tier" 이상이어야 만들 수 있다.
## 지금은 재료가 나무·돌·금뿐이라 비용이 임시다. 바이옴 재료가 생기면 단계별 재료로 바꾼다.

## UPGRADES[n] = 제작대 n단계 → n+1단계 비용. 최고 단계 = UPGRADES.size()
const UPGRADES := [
	{"stone": 20, "gold": 3},
	{"stone": 40, "gold": 10},
]

const RECIPES := {
	"old_bow": {"tier": 0, "cost": {"wood": 12}},
	"wooden_shield": {"tier": 0, "cost": {"wood": 10}},
	"cloth_shoes": {"tier": 0, "cost": {"wood": 8}},
	"iron_helm": {"tier": 1, "cost": {"stone": 15, "gold": 2}},
	"chain_mail": {"tier": 1, "cost": {"stone": 20, "gold": 3}},
	"scatter_crossbow": {"tier": 1, "cost": {"wood": 15, "stone": 10, "gold": 3}},
	"bomb_bag": {"tier": 2, "cost": {"stone": 20, "gold": 6}},
	"fire_staff": {"tier": 2, "cost": {"wood": 20, "gold": 8}},
	"guardian_armor": {"tier": 2, "cost": {"stone": 30, "gold": 8}},
	"life_charm": {"tier": 2, "cost": {"gold": 10}},
}


static func max_tier() -> int:
	return UPGRADES.size()


## known: 얻어 본 재료 id -> true
static func is_revealed(id: String, known: Dictionary) -> bool:
	for kind: String in RECIPES[id]["cost"]:
		if not known.has(kind):
			return false
	return true
