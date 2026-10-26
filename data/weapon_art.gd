class_name WeaponArtDB
extends RefCounted
## 무기·투사체·공격 효과의 그림 배치와 연출 시간. 피해·사거리·공격 속도는 ItemDB를 따른다.
## 무기 트리 34종은 고유 외형을 쓰며 폭탄 주머니만 최초 시트를 보존한다.

const TREE_WEAPONS := preload("res://assets/combat/weapon_tree.png")
const TREE_PROJECTILES := preload("res://assets/combat/weapon_tree_projectiles.png")
const TREE_EFFECTS := preload("res://assets/combat/weapon_tree_effects.png")
const LEGACY_WEAPONS := preload("res://assets/combat/weapons.png")
const LEGACY_PROJECTILES := preload("res://assets/combat/projectiles.png")
const LEGACY_EFFECTS := preload("res://assets/combat/attack_effects.png")
const WEAPON_SIZE := Vector2(64, 64)
const WEAPON_PIVOT := Vector2(20, 32)
const WEAPON_FRAMES := 8
const WEAPONS := {
	"rusty_sword": {"row": 0, "duration": 0.18, "recoil": 1.5, "tree": true, "branch": "basic_sword", "tier": 0, "slash": "steel_slash"},
	"greatsword": {"row": 1, "duration": 0.26, "recoil": 2.5, "tree": true, "branch": "great", "tier": 1, "slash": "great_slash"},
	"steel_greatsword": {"row": 2, "duration": 0.26, "recoil": 2.5, "tree": true, "branch": "great", "tier": 2, "slash": "great_slash"},
	"obsidian_blade": {"row": 3, "duration": 0.26, "recoil": 2.5, "tree": true, "branch": "great", "tier": 3, "slash": "obsidian_slash"},
	"twin_blades": {"row": 4, "duration": 0.12, "recoil": 1.5, "tree": true, "branch": "twin", "tier": 1, "slash": "twin_slash"},
	"steel_twin_blades": {"row": 5, "duration": 0.12, "recoil": 1.5, "tree": true, "branch": "twin", "tier": 2, "slash": "twin_slash"},
	"shadow_blades": {"row": 6, "duration": 0.12, "recoil": 1.5, "tree": true, "branch": "twin", "tier": 3, "slash": "shadow_slash"},
	"guard_sword": {"row": 7, "duration": 0.2, "recoil": 1.8, "tree": true, "branch": "guard", "tier": 1, "slash": "guard_slash"},
	"knight_sword": {"row": 8, "duration": 0.2, "recoil": 1.8, "tree": true, "branch": "guard", "tier": 2, "slash": "guard_slash"},
	"royal_guard_sword": {"row": 9, "duration": 0.2, "recoil": 1.8, "tree": true, "branch": "guard", "tier": 3, "slash": "royal_slash"},
	"old_bow": {"row": 10, "duration": 0.18, "recoil": 1.5, "tree": true, "branch": "basic_bow", "tier": 0, "slash": ""},
	"longbow": {"row": 11, "duration": 0.23, "recoil": -2.0, "tree": true, "branch": "long", "tier": 1, "slash": ""},
	"yew_longbow": {"row": 12, "duration": 0.23, "recoil": -2.0, "tree": true, "branch": "long", "tier": 2, "slash": ""},
	"dragonbone_longbow": {"row": 13, "duration": 0.23, "recoil": -2.0, "tree": true, "branch": "long", "tier": 3, "slash": ""},
	"rapid_bow": {"row": 14, "duration": 0.12, "recoil": -1.0, "tree": true, "branch": "rapid", "tier": 1, "slash": ""},
	"hunter_bow": {"row": 15, "duration": 0.12, "recoil": -1.0, "tree": true, "branch": "rapid", "tier": 2, "slash": ""},
	"storm_bow": {"row": 16, "duration": 0.12, "recoil": -1.0, "tree": true, "branch": "rapid", "tier": 3, "slash": ""},
	"wooden_crossbow": {"row": 17, "duration": 0.18, "recoil": 1.5, "tree": true, "branch": "basic_crossbow", "tier": 0, "slash": ""},
	"scatter_crossbow": {"row": 18, "duration": 0.2, "recoil": -2.5, "tree": true, "branch": "scatter", "tier": 1, "slash": ""},
	"heavy_scatter_crossbow": {"row": 19, "duration": 0.2, "recoil": -2.5, "tree": true, "branch": "scatter", "tier": 2, "slash": ""},
	"dragon_scatter_crossbow": {"row": 20, "duration": 0.2, "recoil": -2.5, "tree": true, "branch": "scatter", "tier": 3, "slash": ""},
	"siege_crossbow": {"row": 21, "duration": 0.25, "recoil": -3.0, "tree": true, "branch": "siege", "tier": 1, "slash": ""},
	"iron_siege_crossbow": {"row": 22, "duration": 0.25, "recoil": -3.0, "tree": true, "branch": "siege", "tier": 2, "slash": ""},
	"obsidian_siege_crossbow": {"row": 23, "duration": 0.25, "recoil": -3.0, "tree": true, "branch": "siege", "tier": 3, "slash": ""},
	"apprentice_staff": {"row": 24, "duration": 0.2, "recoil": -1.0, "tree": true, "branch": "basic_staff", "tier": 0, "slash": ""},
	"fire_staff": {"row": 25, "duration": 0.2, "recoil": -1.0, "tree": true, "branch": "fire", "tier": 1, "slash": ""},
	"blaze_staff": {"row": 26, "duration": 0.2, "recoil": -1.0, "tree": true, "branch": "fire", "tier": 2, "slash": ""},
	"inferno_staff": {"row": 27, "duration": 0.2, "recoil": -1.0, "tree": true, "branch": "fire", "tier": 3, "slash": ""},
	"frost_staff": {"row": 28, "duration": 0.2, "recoil": -1.0, "tree": true, "branch": "frost", "tier": 1, "slash": ""},
	"glacier_staff": {"row": 29, "duration": 0.2, "recoil": -1.0, "tree": true, "branch": "frost", "tier": 2, "slash": ""},
	"winter_staff": {"row": 30, "duration": 0.2, "recoil": -1.0, "tree": true, "branch": "frost", "tier": 3, "slash": ""},
	"thunder_staff": {"row": 31, "duration": 0.2, "recoil": -1.0, "tree": true, "branch": "thunder", "tier": 1, "slash": ""},
	"storm_staff": {"row": 32, "duration": 0.2, "recoil": -1.0, "tree": true, "branch": "thunder", "tier": 2, "slash": ""},
	"tempest_staff": {"row": 33, "duration": 0.2, "recoil": -1.0, "tree": true, "branch": "thunder", "tier": 3, "slash": ""},
	"bomb_bag": {"row": 5, "duration": 0.28, "recoil": 2.0},
}
## 계열별 대신 쓰는 그림과 기본 공격 탄
const FAMILY_ART := {"sword": "rusty_sword", "bow": "old_bow", "crossbow": "scatter_crossbow", "staff": "fire_staff"}
const FAMILY_PROJECTILES := {"bow": "arrow", "crossbow": "bolt", "staff": "ember"}
const PROJECTILE_SIZE := 32
const PROJECTILE_FRAMES := 4
const PROJECTILE_FRAME_TIME := 0.06
const PROJECTILES := {"arrow": 0, "bolt": 1, "ember": 2, "fireball": 3, "bomb": 4, "enemy_orb": 5}
const TREE_PROJECTILE_ROWS := {
	"long_arrow": 0,
	"yew_arrow": 1,
	"dragon_arrow": 2,
	"swift_arrow": 3,
	"hunter_arrow": 4,
	"storm_arrow": 5,
	"scatter_pellet": 6,
	"heavy_pellet": 7,
	"dragon_pellet": 8,
	"siege_bolt": 9,
	"iron_shell": 10,
	"obsidian_shell": 11,
	"arcane_spark": 12,
	"blaze_ember": 13,
	"inferno_ember": 14,
	"frost_shard": 15,
	"glacier_shard": 16,
	"winter_shard": 17,
	"thunder_spark": 18,
	"storm_spark": 19,
	"tempest_spark": 20,
	"dragon_snipe": 21,
	"charged_arrow": 22,
	"inferno_orb": 23,
	"blaze_orb": 24,
}
const LINK_LENGTH := 96.0
const BOMB_LIFT := 12.0
const BOMB_SPIN := 6.0
const EFFECT_SIZE := 128
const EFFECT_FRAMES := 6
const SLASH_TIME := 0.12
const SLASH_RADIUS := 60.0
const MAX_SLASH_ARC := 170.0
const EXPLOSION_RADIUS := 48.0
const EFFECTS := {
	"steel_slash": {"row": 0, "duration": SLASH_TIME},
	"obsidian_slash": {"row": 1, "duration": SLASH_TIME},
	"impact": {"row": 2, "duration": 0.18},
	"explosion": {"row": 3, "duration": 0.36},
	"fire_impact": {"row": 4, "duration": 0.24},
	"great_slash": {"row": 0, "duration": 0.12, "tree": true},
	"twin_slash": {"row": 1, "duration": 0.12, "tree": true},
	"shadow_slash": {"row": 2, "duration": 0.12, "tree": true},
	"guard_slash": {"row": 3, "duration": 0.12, "tree": true},
	"royal_slash": {"row": 4, "duration": 0.12, "tree": true},
	"slam_wave": {"row": 5, "duration": 0.32, "tree": true},
	"dash_cut": {"row": 6, "duration": 0.32, "tree": true},
	"shadow_cut": {"row": 7, "duration": 0.32, "tree": true},
	"counter_stance": {"row": 8, "duration": 0.65, "tree": true},
	"counter_wave": {"row": 9, "duration": 0.32, "tree": true},
	"focused_shot": {"row": 10, "duration": 0.24, "tree": true},
	"arrow_rain": {"row": 11, "duration": 0.65, "tree": true},
	"scatter_muzzle": {"row": 12, "duration": 0.24, "tree": true},
	"siege_burst": {"row": 13, "duration": 0.42, "tree": true},
	"obsidian_burst": {"row": 14, "duration": 0.42, "tree": true},
	"frost_ring": {"row": 15, "duration": 0.65, "tree": true},
	"frost_impact": {"row": 16, "duration": 0.32, "tree": true},
	"lightning_strike": {"row": 17, "duration": 0.42, "tree": true},
	"lightning_link": {"row": 18, "duration": 0.24, "tree": true},
	"arcane_impact": {"row": 19, "duration": 0.32, "tree": true},
	"piercing_impact": {"row": 20, "duration": 0.32, "tree": true},
	"inferno_impact": {"row": 21, "duration": 0.32, "tree": true},
	"charged_impact": {"row": 22, "duration": 0.32, "tree": true},
	"fire_wave": {"row": 23, "duration": 0.32, "tree": true},
	"siege_muzzle": {"row": 24, "duration": 0.24, "tree": true},
}


const BASIC_PROJECTILE_ART := {
	"old_bow": "arrow",
	"longbow": "long_arrow",
	"yew_longbow": "yew_arrow",
	"dragonbone_longbow": "dragon_arrow",
	"rapid_bow": "swift_arrow",
	"hunter_bow": "hunter_arrow",
	"storm_bow": "storm_arrow",
	"wooden_crossbow": "bolt",
	"scatter_crossbow": "scatter_pellet",
	"heavy_scatter_crossbow": "heavy_pellet",
	"dragon_scatter_crossbow": "dragon_pellet",
	"siege_crossbow": "siege_bolt",
	"iron_siege_crossbow": "iron_shell",
	"obsidian_siege_crossbow": "obsidian_shell",
	"apprentice_staff": "arcane_spark",
	"fire_staff": "ember",
	"blaze_staff": "blaze_ember",
	"inferno_staff": "inferno_ember",
	"frost_staff": "frost_shard",
	"glacier_staff": "glacier_shard",
	"winter_staff": "winter_shard",
	"thunder_staff": "thunder_spark",
	"storm_staff": "storm_spark",
	"tempest_staff": "tempest_spark",
}

## 무기·폭탄 주머니처럼 손에 드는 그림이 있는 장비인가
static func has_art(id: String) -> bool:
	return WEAPONS.has(id) or (ItemDB.ITEMS.has(id) and ItemDB.ITEMS[id].has("weapon"))


## 그 장비의 그림 항목 (row·duration·recoil). 없으면 계열 기본 그림
static func art(id: String) -> Dictionary:
	if WEAPONS.has(id):
		return WEAPONS[id]
	var family: String = ItemDB.ITEMS.get(id, {}).get("weapon", {}).get("family", "sword")
	return WEAPONS[FAMILY_ART.get(family, "rusty_sword")]


## 휘두르기 궤적을 그리는 검 계열인가
static func is_blade(id: String) -> bool:
	return ItemDB.ITEMS.get(id, {}).get("weapon", {}).get("family", "") == "sword"


static func basic_projectile(id: String) -> String:
	return BASIC_PROJECTILE_ART.get(id, "arrow")


static func weapon_texture(id: String) -> Texture2D:
	return TREE_WEAPONS if art(id).get("tree", false) else LEGACY_WEAPONS


static func icon(id: String) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = weapon_texture(id)
	texture.region = weapon_region(id, 0)
	texture.region = Rect2(texture.region.position + Vector2(4, 4), Vector2(56, 56)) if art(id).get("tree", false) else Rect2(texture.region.position + Vector2(12, 12), Vector2(48, 48))
	return texture


static func slash_effect(id: String) -> String:
	return art(id).get("slash", "steel_slash")


static func has_projectile(id: String) -> bool:
	return PROJECTILES.has(id) or TREE_PROJECTILE_ROWS.has(id)


static func projectile_ids() -> Array:
	return PROJECTILES.keys() + TREE_PROJECTILE_ROWS.keys()


static func projectile_texture(id: String) -> Texture2D:
	return TREE_PROJECTILES if TREE_PROJECTILE_ROWS.has(id) else LEGACY_PROJECTILES


static func effect_texture(id: String) -> Texture2D:
	return TREE_EFFECTS if EFFECTS[id].get("tree", false) else LEGACY_EFFECTS


static func impact_effect(id: String) -> String:
	if id.contains("shard"):
		return "frost_impact"
	if id.contains("spark") and id != "arcane_spark":
		return "charged_impact"
	if id == "arcane_spark":
		return "arcane_impact"
	if id.contains("inferno"):
		return "inferno_impact"
	if id.contains("ember") or id.contains("orb"):
		return "fire_impact"
	if id.contains("arrow") or id == "dragon_snipe":
		return "piercing_impact" if id != "arrow" else "impact"
	return "impact"


static func explosion_effect(id: String) -> String:
	return "obsidian_burst" if id == "obsidian_shell" else "siege_burst" if id in ["siege_bolt", "iron_shell"] else "explosion"


static func skill_projectile(weapon: String, skill: String) -> String:
	match skill:
		"snipe": return "dragon_snipe" if weapon == "dragonbone_longbow" else "charged_arrow"
		"shotgun", "blast_bolt": return basic_projectile(weapon)
		"fireball": return "inferno_orb" if weapon == "inferno_staff" else "blaze_orb" if weapon == "blaze_staff" else "fireball"
	return "arrow"


const PLAYER_EFFECTS := ["slam_wave", "dash_cut", "shadow_cut", "counter_stance", "counter_wave", "focused_shot", "arrow_rain", "scatter_muzzle", "siege_muzzle", "frost_ring", "lightning_strike", "fire_wave"]


## 갈래별 타격감 (D-029). 내 공격이 적을 맞혔을 때 멈칫(초, 혼자 플레이만)·화면 흔들림, 공격할 때 화면 반동(px).
## kick이 양수면 조준 방향으로(휘두르며 들어가는 느낌), 음수면 반대로(쏘는 반동) 화면이 밀린다. 수치는 임시
const FEEL := {
	"basic_sword": {"hitstop": 0.03, "shake": 1.2, "kick": 1.0},
	"great": {"hitstop": 0.07, "shake": 3.5, "kick": 2.5},
	"twin": {"hitstop": 0.015, "shake": 0.7, "kick": 0.6},
	"guard": {"hitstop": 0.04, "shake": 2.0, "kick": 1.5},
	"basic_bow": {"hitstop": 0.02, "shake": 0.8, "kick": -1.2},
	"long": {"hitstop": 0.05, "shake": 2.4, "kick": -3.0},
	"rapid": {"hitstop": 0.0, "shake": 0.5, "kick": -0.6},
	"basic_crossbow": {"hitstop": 0.03, "shake": 1.2, "kick": -2.5},
	"scatter": {"hitstop": 0.03, "shake": 1.6, "kick": -4.0},
	"siege": {"hitstop": 0.05, "shake": 3.0, "kick": -4.5},
	"basic_staff": {"hitstop": 0.02, "shake": 0.8, "kick": -1.0},
	"fire": {"hitstop": 0.03, "shake": 1.4, "kick": -1.5},
	"frost": {"hitstop": 0.035, "shake": 1.2, "kick": -1.2},
	"thunder": {"hitstop": 0.03, "shake": 1.8, "kick": -1.5},
}


## 그 무기의 타격감. 갈래가 없으면 낡은 검과 같다
static func feel(id: String) -> Dictionary:
	return FEEL.get(art(id).get("branch", "basic_sword"), FEEL["basic_sword"])


static func weapon_region(id: String, frame: int) -> Rect2:
	var row: int = art(id)["row"]
	return Rect2(Vector2(clampi(frame, 0, WEAPON_FRAMES - 1) * WEAPON_SIZE.x, row * WEAPON_SIZE.y), WEAPON_SIZE)


static func projectile_region(id: String, elapsed: float) -> Rect2:
	var row: int = TREE_PROJECTILE_ROWS.get(id, PROJECTILES.get(id, 0))
	var frame := int(elapsed / PROJECTILE_FRAME_TIME) % PROJECTILE_FRAMES
	return Rect2(Vector2(frame, row) * PROJECTILE_SIZE, Vector2.ONE * PROJECTILE_SIZE)


static func effect_region(id: String, progress: float) -> Rect2:
	var row: int = EFFECTS[id]["row"]
	var frame := clampi(int(progress * EFFECT_FRAMES), 0, EFFECT_FRAMES - 1)
	return Rect2(Vector2(frame, row) * EFFECT_SIZE, Vector2.ONE * EFFECT_SIZE)
