class_name PassiveArtDB
extends RefCounted
## 패시브 아이콘 순서와 방사형 화면 배치. 선행 관계·비용·효과는 PassiveDB가 소유한다.

const ICON_SIZE := 32
const ICON_COLUMNS := 8
const NODE_SIZE := 56
const ICON_ORDER := [
	"sword_mastery", "sword_sweep", "bow_mastery", "piercing_arrows", "crossbow_mastery", "rapid_reload", "staff_mastery", "ember_burst",
	"keen_edge", "combo_finisher", "skill_power", "executioner", "vitality", "regeneration", "last_stand", "quick_return",
	"swift", "windstep", "bountiful", "wide_harvest", "deep_pockets", "scavenger", "treasure_hunter", "frugal_builder",
	"long_reach", "tower_drill", "repair_expert", "sturdy_build", "mending_walls", "thorn_walls", "fortify",
	# D-020 확장 노드 아이콘 (2026-10-26).
	"blade_reach", "whirlwind", "multishot", "twin_bolts", "overcharge", "first_strike", "berserker", "tactician",
	"iron_skin", "dawn_blessing", "field_medic", "sprint_dash", "evasive_dash", "herbalist", "prospector", "harvest_scholar",
	"salvage_expert", "builders_insight", "thrifty_repair", "core_resonance", "bulwark_aura", "hawk_eye", "sharp_bolts", "twin_bows",
]
## 각도(도), 중심에서의 시각적 단계. 게임의 선행 조건은 변경하지 않는다.
const LAYOUT := {
	"sword_mastery": Vector2(-174, 1), "sword_sweep": Vector2(-174, 2),
	"bow_mastery": Vector2(-150, 1), "piercing_arrows": Vector2(-150, 2),
	"crossbow_mastery": Vector2(-126, 1), "rapid_reload": Vector2(-126, 2),
	"staff_mastery": Vector2(-102, 1), "ember_burst": Vector2(-102, 2),
	"keen_edge": Vector2(-78, 1), "combo_finisher": Vector2(-85, 2), "skill_power": Vector2(-65, 2), "executioner": Vector2(-85, 3),
	"vitality": Vector2(-45, 1), "regeneration": Vector2(-46, 2), "last_stand": Vector2(-46, 3), "quick_return": Vector2(-27, 2),
	"swift": Vector2(-18, 1), "windstep": Vector2(-7, 2),
	"bountiful": Vector2(8, 1), "wide_harvest": Vector2(17, 2), "deep_pockets": Vector2(34, 1),
	"scavenger": Vector2(60, 1), "treasure_hunter": Vector2(58, 2),
	"frugal_builder": Vector2(93, 1), "long_reach": Vector2(77, 2), "tower_drill": Vector2(95, 2), "repair_expert": Vector2(115, 2),
	"sturdy_build": Vector2(147, 1), "mending_walls": Vector2(135, 2), "thorn_walls": Vector2(155, 2), "fortify": Vector2(124, 3),
	# 확장 경로는 바깥 고리를 사용한다.
	"blade_reach": Vector2(-180, 3), "whirlwind": Vector2(-164, 3), "multishot": Vector2(-150, 3), "twin_bolts": Vector2(-134, 3),
	"overcharge": Vector2(-118, 3), "first_strike": Vector2(-102, 3), "berserker": Vector2(-72, 3), "tactician": Vector2(-60, 3),
	"iron_skin": Vector2(37, 2), "field_medic": Vector2(-34, 3), "dawn_blessing": Vector2(-22, 3), "sprint_dash": Vector2(-9, 3),
	"evasive_dash": Vector2(5, 3), "herbalist": Vector2(19, 3), "prospector": Vector2(33, 3), "harvest_scholar": Vector2(47, 3),
	"salvage_expert": Vector2(64, 3), "builders_insight": Vector2(77, 3), "hawk_eye": Vector2(90, 3), "sharp_bolts": Vector2(103, 3),
	"twin_bows": Vector2(113, 3), "thrifty_repair": Vector2(136, 3), "core_resonance": Vector2(148, 3), "bulwark_aura": Vector2(160, 3),
}
const RADII := [Vector2.ZERO, Vector2(200, 125), Vector2(310, 190), Vector2(390, 250)]


static func icon_region(id: String) -> Rect2:
	var index := ICON_ORDER.find(id)
	if index < 0:
		index = ICON_ORDER.size()
	return Rect2(Vector2(index % ICON_COLUMNS, index / ICON_COLUMNS) * ICON_SIZE, Vector2.ONE * ICON_SIZE)


static func offset(id: String) -> Vector2:
	var polar: Vector2 = LAYOUT[id]
	var radius: Vector2 = RADII[int(polar.y)]
	var angle := deg_to_rad(polar.x)
	return Vector2(cos(angle), sin(angle)) * radius
