class_name RecipeDB
extends RefCounted
## 제작대 레시피와 단계 업그레이드 비용 (D-014, 무기 트리 D-028). 레시피 id = 만들어지는 장비 id.
## 레시피는 재료를 전부 한 번씩 얻어 본 뒤에 목록에 나타나고, 제작대 단계가 "tier" 이상이어야 만들 수 있다.
## 제작대 단계는 장비 레시피만 연다(건물은 왕국의 방어 단계, D-027). 업그레이드는 왕국 핵 창에서 하고
## 몬스터를 잡아 얻는 희귀 재료만 든다(D-027). 레시피에는 그 단계 바이옴의 재료가 든다. 수치는 임시.

## UPGRADES[n] = 제작대 n단계 → n+1단계 비용. 최고 단계 = UPGRADES.size()
const UPGRADES := [
	{"tough_hide": 4, "venom_sting": 4},
	{"ice_crystal": 5, "swamp_ooze": 5, "tough_hide": 3},
	{"fire_core": 6, "ice_crystal": 3, "venom_sting": 3},
]

## "from": 강화할 이전 단계 무기. 만들면 그 무기가 사라지고 새 무기로 바뀐다(가방에 있든 들고 있든, D-028).
const RECIPES := {
	# --- 무기 0단계: 네 계열 모두 처음부터 ---
	"rusty_sword": {"tier": 0, "cost": {"wood": 8, "stone": 4}},
	"old_bow": {"tier": 0, "cost": {"wood": 12}},
	"wooden_crossbow": {"tier": 0, "cost": {"wood": 14, "stone": 4}},
	"apprentice_staff": {"tier": 0, "cost": {"wood": 10, "stone": 6}},
	# --- 무기 1단계: 갈래 고르기 ---
	"greatsword": {"tier": 1, "from": "rusty_sword", "cost": {"hardwood": 6, "copper": 6, "tough_hide": 2}},
	"twin_blades": {"tier": 1, "from": "rusty_sword", "cost": {"hardwood": 4, "copper": 8, "venom_sting": 2}},
	"guard_sword": {"tier": 1, "from": "rusty_sword", "cost": {"hardwood": 6, "copper": 6, "tough_hide": 3}},
	"longbow": {"tier": 1, "from": "old_bow", "cost": {"hardwood": 10, "tough_hide": 2}},
	"rapid_bow": {"tier": 1, "from": "old_bow", "cost": {"hardwood": 8, "copper": 4, "venom_sting": 2}},
	"scatter_crossbow": {"tier": 1, "from": "wooden_crossbow", "cost": {"hardwood": 8, "copper": 4}},
	"siege_crossbow": {"tier": 1, "from": "wooden_crossbow", "cost": {"hardwood": 6, "copper": 8, "venom_sting": 2}},
	"fire_staff": {"tier": 1, "from": "apprentice_staff", "cost": {"hardwood": 8, "coal": 6}},
	"frost_staff": {"tier": 1, "from": "apprentice_staff", "cost": {"hardwood": 8, "copper": 6, "tough_hide": 2}},
	"thunder_staff": {"tier": 1, "from": "apprentice_staff", "cost": {"copper": 10, "hardwood": 6, "venom_sting": 2}},
	# --- 무기 2단계: 갈래 강화 ---
	"steel_greatsword": {"tier": 2, "from": "greatsword", "cost": {"iron_ore": 10, "coal": 4, "ice_crystal": 2}},
	"steel_twin_blades": {"tier": 2, "from": "twin_blades", "cost": {"iron_ore": 10, "swamp_ooze": 2}},
	"knight_sword": {"tier": 2, "from": "guard_sword", "cost": {"iron_ore": 12, "ice_crystal": 2}},
	"yew_longbow": {"tier": 2, "from": "longbow", "cost": {"hardwood": 12, "moss": 6, "swamp_ooze": 2}},
	"hunter_bow": {"tier": 2, "from": "rapid_bow", "cost": {"hardwood": 10, "iron_ore": 4, "ice_crystal": 2}},
	"heavy_scatter_crossbow": {"tier": 2, "from": "scatter_crossbow", "cost": {"iron_ore": 10, "hardwood": 6, "swamp_ooze": 2}},
	"iron_siege_crossbow": {"tier": 2, "from": "siege_crossbow", "cost": {"iron_ore": 12, "coal": 6, "ice_crystal": 2}},
	"blaze_staff": {"tier": 2, "from": "fire_staff", "cost": {"hardwood": 10, "coal": 8, "swamp_ooze": 3}},
	"glacier_staff": {"tier": 2, "from": "frost_staff", "cost": {"iron_ore": 6, "moss": 6, "ice_crystal": 3}},
	"storm_staff": {"tier": 2, "from": "thunder_staff", "cost": {"iron_ore": 8, "copper": 8, "swamp_ooze": 2}},
	# --- 무기 3단계: 갈래 특성 ---
	"obsidian_blade": {"tier": 3, "from": "steel_greatsword", "cost": {"obsidian": 10, "fire_core": 2}},
	"shadow_blades": {"tier": 3, "from": "steel_twin_blades", "cost": {"obsidian": 10, "fire_core": 2, "venom_sting": 4}},
	"royal_guard_sword": {"tier": 3, "from": "knight_sword", "cost": {"obsidian": 8, "iron_ore": 8, "fire_core": 2}},
	"dragonbone_longbow": {"tier": 3, "from": "yew_longbow", "cost": {"obsidian": 8, "hardwood": 10, "fire_core": 2}},
	"storm_bow": {"tier": 3, "from": "hunter_bow", "cost": {"obsidian": 6, "hardwood": 10, "fire_core": 3}},
	"dragon_scatter_crossbow": {"tier": 3, "from": "heavy_scatter_crossbow", "cost": {"obsidian": 10, "fire_core": 3}},
	"obsidian_siege_crossbow": {"tier": 3, "from": "iron_siege_crossbow", "cost": {"obsidian": 12, "coal": 8, "fire_core": 2}},
	"inferno_staff": {"tier": 3, "from": "blaze_staff", "cost": {"obsidian": 8, "fire_core": 4}},
	"winter_staff": {"tier": 3, "from": "glacier_staff", "cost": {"obsidian": 8, "ice_crystal": 4, "fire_core": 2}},
	"tempest_staff": {"tier": 3, "from": "storm_staff", "cost": {"obsidian": 8, "copper": 10, "fire_core": 3}},
	# --- 무기 외 장비 ---
	"wooden_shield": {"tier": 0, "cost": {"wood": 10}},
	"cloth_shoes": {"tier": 0, "cost": {"wood": 8}},
	"chain_mail": {"tier": 1, "cost": {"copper": 10, "tough_hide": 2}},
	"bomb_bag": {"tier": 1, "cost": {"copper": 6, "venom_sting": 2}},
	"iron_helm": {"tier": 2, "cost": {"iron_ore": 8}},
	"guardian_armor": {"tier": 2, "cost": {"iron_ore": 10, "ice_crystal": 2}},
	"life_charm": {"tier": 2, "cost": {"moss": 8, "swamp_ooze": 2}},
	"flame_armor": {"tier": 3, "cost": {"obsidian": 12, "fire_core": 3, "iron_ore": 6}},
}


## 이 무기를 강화해서 만드는 다음 단계 무기들 (갈래)
static func upgrades_of(id: String) -> Array[String]:
	var result: Array[String] = []
	for recipe_id: String in RECIPES:
		if RECIPES[recipe_id].get("from", "") == id:
			result.append(recipe_id)
	return result


static func max_tier() -> int:
	return UPGRADES.size()


## known: 얻어 본 재료 id -> true
static func is_revealed(id: String, known: Dictionary) -> bool:
	for kind: String in RECIPES[id]["cost"]:
		if not known.has(kind):
			return false
	return true
