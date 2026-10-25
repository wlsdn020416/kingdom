class_name RecipeDB
extends RefCounted
## 제작대 레시피와 단계 업그레이드 비용 (D-014). 레시피 id = 만들어지는 장비 id.
## 레시피는 재료를 전부 한 번씩 얻어 본 뒤에 목록에 나타나고, 제작대 단계가 "tier" 이상이어야 만들 수 있다.
## 업그레이드에는 다음 단계 바이옴 몬스터의 희귀 재료가, 레시피에는 그 단계 바이옴의 재료가 든다. 수치는 임시.

## UPGRADES[n] = 제작대 n단계 → n+1단계 비용. 최고 단계 = UPGRADES.size()
const UPGRADES := [
	{"stone": 20, "tough_hide": 3, "venom_sting": 3},
	{"iron_ore": 10, "ice_crystal": 3, "swamp_ooze": 3},
	{"obsidian": 10, "fire_core": 4},
]

const RECIPES := {
	"old_bow": {"tier": 0, "cost": {"wood": 12}},
	"wooden_shield": {"tier": 0, "cost": {"wood": 10}},
	"cloth_shoes": {"tier": 0, "cost": {"wood": 8}},
	"scatter_crossbow": {"tier": 1, "cost": {"hardwood": 8, "copper": 4}},
	"chain_mail": {"tier": 1, "cost": {"copper": 10, "tough_hide": 2}},
	"bomb_bag": {"tier": 1, "cost": {"copper": 6, "venom_sting": 2}},
	"iron_helm": {"tier": 2, "cost": {"iron_ore": 8}},
	"guardian_armor": {"tier": 2, "cost": {"iron_ore": 10, "ice_crystal": 2}},
	"fire_staff": {"tier": 2, "cost": {"hardwood": 10, "swamp_ooze": 3}},
	"life_charm": {"tier": 2, "cost": {"moss": 8, "swamp_ooze": 2}},
	"obsidian_blade": {"tier": 3, "cost": {"obsidian": 10, "fire_core": 2}},
	"flame_armor": {"tier": 3, "cost": {"obsidian": 12, "fire_core": 3, "iron_ore": 6}},
}


static func max_tier() -> int:
	return UPGRADES.size()


## known: 얻어 본 재료 id -> true
static func is_revealed(id: String, known: Dictionary) -> bool:
	for kind: String in RECIPES[id]["cost"]:
		if not known.has(kind):
			return false
	return true
