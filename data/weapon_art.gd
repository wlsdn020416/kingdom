class_name WeaponArtDB
extends RefCounted
## 무기·투사체·공격 효과의 그림 배치와 연출 시간. 피해·사거리·공격 속도는 ItemDB를 따른다.

const WEAPON_SIZE := Vector2(64, 64)
const WEAPON_PIVOT := Vector2(20, 32)
const WEAPON_FRAMES := 8
const WEAPONS := {
	"rusty_sword": {"row": 0, "duration": 0.18, "recoil": 1.5},
	"obsidian_blade": {"row": 1, "duration": 0.2, "recoil": 2.0},
	"old_bow": {"row": 2, "duration": 0.18, "recoil": -1.5},
	"scatter_crossbow": {"row": 3, "duration": 0.22, "recoil": -2.0},
	"fire_staff": {"row": 4, "duration": 0.22, "recoil": -1.0},
	"bomb_bag": {"row": 5, "duration": 0.28, "recoil": 2.0},
}
const BASIC_PROJECTILES := {"old_bow": "arrow", "scatter_crossbow": "bolt", "fire_staff": "ember"}
const PROJECTILE_SIZE := 32
const PROJECTILE_FRAMES := 4
const PROJECTILE_FRAME_TIME := 0.06
const PROJECTILES := {"arrow": 0, "bolt": 1, "ember": 2, "fireball": 3, "bomb": 4, "enemy_orb": 5}
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
}


static func weapon_region(id: String, frame: int) -> Rect2:
	var row: int = WEAPONS.get(id, WEAPONS["rusty_sword"])["row"]
	return Rect2(Vector2(clampi(frame, 0, WEAPON_FRAMES - 1) * WEAPON_SIZE.x, row * WEAPON_SIZE.y), WEAPON_SIZE)


static func projectile_region(id: String, elapsed: float) -> Rect2:
	var row: int = PROJECTILES.get(id, PROJECTILES["arrow"])
	var frame := int(elapsed / PROJECTILE_FRAME_TIME) % PROJECTILE_FRAMES
	return Rect2(Vector2(frame, row) * PROJECTILE_SIZE, Vector2.ONE * PROJECTILE_SIZE)


static func effect_region(id: String, progress: float) -> Rect2:
	var row: int = EFFECTS[id]["row"]
	var frame := clampi(int(progress * EFFECT_FRAMES), 0, EFFECT_FRAMES - 1)
	return Rect2(Vector2(frame, row) * EFFECT_SIZE, Vector2.ONE * EFFECT_SIZE)
