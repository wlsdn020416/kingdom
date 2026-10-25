class_name PassiveEffectDB
extends RefCounted
## K 패시브의 습득·발동 연출 분류와 그림 시간. 피해·비용·회복량은 PassiveDB를 따른다.

const TEXTURE := preload("res://assets/combat/passive_effects.png")
const SIZE := 128
const FRAMES := 8
const RADIUS := 48.0
const MAX_VISIBLE := 48
const LOCAL_INTERVAL := 0.6
const EFFECTS := {
	"passive_learn": {"row": 0, "duration": 0.55},
	"passive_strike": {"row": 1, "duration": 0.28},
	"passive_whirlwind": {"row": 2, "duration": 0.32},
	"passive_shot": {"row": 3, "duration": 0.28},
	"passive_ember": {"row": 4, "duration": 0.4},
	"passive_heal": {"row": 5, "duration": 0.7},
	"passive_guard": {"row": 6, "duration": 0.55},
	"passive_wind": {"row": 7, "duration": 0.35},
	"passive_harvest": {"row": 8, "duration": 0.5},
	"passive_treasure": {"row": 9, "duration": 0.6},
	"passive_build": {"row": 10, "duration": 0.55},
	"passive_fortify": {"row": 11, "duration": 0.7},
	"passive_thorns": {"row": 12, "duration": 0.3},
	"passive_return": {"row": 13, "duration": 0.6},
}
const NODES := {
	"strike": ["sword_mastery", "crossbow_mastery", "bow_mastery", "keen_edge", "combo_finisher", "skill_power", "executioner", "first_strike", "berserker", "tactician", "sword_sweep", "blade_reach"],
	"whirlwind": ["whirlwind"],
	"shot": ["piercing_arrows", "rapid_reload", "multishot", "twin_bolts", "tower_drill", "hawk_eye", "sharp_bolts", "twin_bows"],
	"ember": ["staff_mastery", "ember_burst", "overcharge"],
	"heal": ["vitality", "regeneration", "dawn_blessing", "field_medic", "herbalist"],
	"guard": ["last_stand", "iron_skin", "bulwark_aura"],
	"wind": ["swift", "windstep", "sprint_dash", "evasive_dash"],
	"harvest": ["bountiful", "wide_harvest", "prospector", "harvest_scholar"],
	"treasure": ["deep_pockets", "scavenger", "treasure_hunter"],
	"build": ["frugal_builder", "long_reach", "sturdy_build", "builders_insight", "salvage_expert"],
	"fortify": ["repair_expert", "mending_walls", "fortify", "thrifty_repair", "core_resonance"],
	"thorns": ["thorn_walls"],
	"return": ["quick_return"],
}


static func effect_for(node_id: String) -> String:
	for family: String in NODES:
		if NODES[family].has(node_id):
			return "passive_" + family
	return ""


static func region(id: String, progress: float) -> Rect2:
	var row: int = EFFECTS[id]["row"]
	return Rect2(clampi(int(progress * FRAMES), 0, FRAMES - 1) * SIZE, row * SIZE, SIZE, SIZE)
