class_name WeaponVisual
extends Node2D
## 무기별 손·공격 자세·검 궤적과 몸의 짧은 반동만 그린다. 판정은 Player·Melee·Projectile이 맡는다.
## 로컬 Player와 RemotePlayer가 같은 원본과 재생 코드를 사용한다.

const TEXTURE := preload("res://assets/combat/weapons.png")
const EFFECT_TEXTURE := preload("res://assets/combat/attack_effects.png")
const BODY_ORIGIN := Vector2(0, -4)
const BODY_LEAN := 0.06
const HELD_SCALE := 0.5
const GRIP_OFFSET := Vector2(0, -3)
const GRIP_REACH := 4.0

var weapon_id := "rusty_sword"
var aim_direction := Vector2.RIGHT
var attack_item := ""
var attack_direction := Vector2.RIGHT
var _body: Sprite2D
var _remaining := 0.0
var _duration := 0.0
var _arc_bonus := 0.0
var _reach_scale := 1.0


func setup(body: Sprite2D) -> void:
	_body = body
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func set_weapon(id: String) -> void:
	if not WeaponArtDB.has_art(id):
		id = "rusty_sword"
	if weapon_id != id:
		weapon_id = id
		_remaining = 0.0
	queue_redraw()


func attack(id: String, direction: Vector2, arc_bonus := 0.0, reach_scale := 1.0) -> void:
	if not WeaponArtDB.has_art(id) or not direction.is_finite() or direction.length_squared() < 0.01:
		return
	attack_item = id
	attack_direction = direction.normalized()
	_arc_bonus = arc_bonus if is_finite(arc_bonus) else 0.0
	_reach_scale = clampf(reach_scale, 1.0, 3.0) if is_finite(reach_scale) else 1.0
	_duration = WeaponArtDB.art(id)["duration"]
	_remaining = _duration
	queue_redraw()


func is_attacking() -> bool:
	return _remaining > 0.0


func slash_visible() -> bool:
	return is_attacking() and WeaponArtDB.is_blade(attack_item) and _duration - _remaining < WeaponArtDB.SLASH_TIME


## 칼끝 사거리는 고정하고 궤적 양 끝을 확장한다. 그림을 늘려도 피해 판정은 바뀌지 않는다.
func slash_stretch() -> Vector2:
	if not WeaponArtDB.is_blade(attack_item):
		return Vector2.ONE
	var base_arc: float = ItemDB.ITEMS[attack_item]["weapon"]["arc"]
	var half := deg_to_rad(base_arc) / 2.0
	var expanded := deg_to_rad(clampf(base_arc + _arc_bonus, base_arc, WeaponArtDB.MAX_SLASH_ARC)) / 2.0
	return Vector2((1.0 - cos(expanded)) / (1.0 - cos(half)), sin(expanded) / sin(half))


func pose_frame() -> int:
	if not is_attacking():
		return 0
	return mini(1 + int((1.0 - _remaining / _duration) * (WeaponArtDB.WEAPON_FRAMES - 1)), WeaponArtDB.WEAPON_FRAMES - 1)


func _process(delta: float) -> void:
	_remaining = maxf(0.0, _remaining - delta)
	var pulse := sin((1.0 - _remaining / _duration) * PI) if is_attacking() else 0.0
	if is_instance_valid(_body):
		var recoil: float = WeaponArtDB.art(attack_item)["recoil"] if is_attacking() else 0.0
		_body.position = BODY_ORIGIN + attack_direction * recoil * pulse
		_body.rotation = attack_direction.x * BODY_LEAN * pulse
	queue_redraw()


func _draw() -> void:
	var id := attack_item if is_attacking() else weapon_id
	var direction := attack_direction if is_attacking() else aim_direction
	draw_set_transform(Vector2.ZERO, direction.angle())
	if slash_visible():
		var effect := WeaponArtDB.slash_effect(id)
		var reach: float = ItemDB.ITEMS[id]["weapon"]["range"] * _reach_scale
		var size := Vector2.ONE * WeaponArtDB.EFFECT_SIZE * reach / WeaponArtDB.SLASH_RADIUS
		var stretch := slash_stretch()
		draw_set_transform(direction * reach * (1.0 - stretch.x), direction.angle(), stretch)
		draw_texture_rect_region(WeaponArtDB.effect_texture(effect), Rect2(-size / 2.0, size), WeaponArtDB.effect_region(effect, (_duration - _remaining) / WeaponArtDB.SLASH_TIME))
		draw_set_transform(Vector2.ZERO, direction.angle())
	# 왼쪽 조준에서도 활·석궁의 윗면이 뒤집히지 않게 손 기준으로 반사한다.
	var facing := Vector2(1, -1 if direction.x < 0.0 else 1)
	draw_set_transform(GRIP_OFFSET + direction * GRIP_REACH, direction.angle(), facing)
	draw_texture_rect_region(WeaponArtDB.weapon_texture(id), Rect2(-WeaponArtDB.WEAPON_PIVOT * HELD_SCALE, WeaponArtDB.WEAPON_SIZE * HELD_SCALE), WeaponArtDB.weapon_region(id, pose_frame()))
	draw_set_transform(Vector2.ZERO)


static func icon(id: String) -> AtlasTexture:
	return WeaponArtDB.icon(id)
