class_name RemotePlayer
extends Node2D
## 다른 사람의 캐릭터 (D-017). PlayerSync가 받은 상태를 보여준다. 충돌 몸과 체력은 없다.
## "player" 그룹에 들어가 호스트의 적이 노릴 수 있다. 맞으면 hurt를 알리고, 실제 체력·무적·사망은 주인 화면이 정한다.

signal hurt(amount: float)

## 받은 위치로 바로 순간이동하지 않고 이 비율로 따라가 끊김을 숨긴다 (초당)
const FOLLOW_RATE := 18.0
## 이보다 멀면 따라가지 않고 바로 옮긴다 (부활·순간이동)
const SNAP_DISTANCE := 6.0 * Balance.TILE

var peer_id := 0
var is_dead := false
## 그 사람의 패시브 단계 (패시브 id -> 단계). 호스트가 그 사람의 건설·약탈자·보물 사냥꾼 효과를 정할 때 쓴다 (D-020)
var ranks := {}
var _target := Vector2.ZERO
var _aim := Vector2.RIGHT
var _sprite := Sprite2D.new()
var _name_label := Label.new()
var weapon_visual := WeaponVisual.new()
var equipment_visual := EquipmentVisual.new()


func setup(owner_peer: int, display_name: String, at: Vector2) -> RemotePlayer:
	peer_id = owner_peer
	position = at
	_target = at
	_name_label.text = display_name
	return self


func _ready() -> void:
	add_to_group("player")
	_sprite.texture = Player.SPRITE_SHEET
	_sprite.hframes = Player.SPRITE_FRAMES_PER_DIR * 3
	_sprite.position = Vector2(0, -4)
	add_child(weapon_visual)
	weapon_visual.setup(_sprite)
	add_child(_sprite)
	_sprite.add_child(equipment_visual)
	equipment_visual.setup(_sprite)
	_name_label.add_theme_font_size_override("font_size", 8)
	_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_name_label.add_theme_constant_override("outline_size", 3)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.size = Vector2(80, 12)
	_name_label.position = Vector2(-40, -28)
	add_child(_name_label)
	Fx.add_light(self, Player.LIGHT_RADIUS)


func apply_state(at: Vector2, aim: Vector2, frame: int, flip: bool, shown: bool, dead: bool, weapon: String = "rusty_sword", gear: Dictionary = {}) -> void:
	_target = at
	_aim = aim
	weapon_visual.set_weapon(weapon)
	weapon_visual.aim_direction = aim
	equipment_visual.set_items(gear)
	_sprite.frame = frame
	_sprite.flip_h = flip
	visible = shown
	is_dead = dead
	if position.distance_to(at) > SNAP_DISTANCE:
		position = at


func take_damage(amount: float) -> void:
	if not is_dead:
		hurt.emit(amount)


func _process(delta: float) -> void:
	position = position.lerp(_target, minf(1.0, FOLLOW_RATE * delta))
