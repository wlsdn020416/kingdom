class_name Player
extends CharacterBody2D
## 트윈스틱 조작 캐릭터. 이동(WASD)과 조준(마우스)은 서로 독립적이다.
## 대시(Space)는 모든 캐릭터의 기본 능력이고, 1~4 키는 장비에 달린 스킬을 쓴다.

const DASH_SPEED := 950.0
const DASH_TIME := 0.18
const LIGHT_RADIUS := 230.0
const SWING_SHOW_TIME := 0.12  # 근거리 공격 궤적이 보이는 시간

@onready var camera: Camera2D = $Camera

var equipment := Equipment.new()
var hp := 0.0
var aim_direction := Vector2.RIGHT
var is_dead := false
var spawn_point := Vector2.ZERO
## 건설 모드나 장비창이 열려 있으면 Main이 끈다
var attack_enabled := true
var skills_enabled := true

var _fire_cooldown := 0.0
var _invuln_time := 0.0
var _shield_time := 0.0
var _dash_time := 0.0
var _dash_velocity := Vector2.ZERO
var _dash_cooldown := 0.0
var _swing_time := 0.0
var _respawn_time := 0.0
var _shake := 0.0


func _ready() -> void:
	hp = equipment.max_hp()
	equipment.changed.connect(func() -> void: hp = minf(hp, equipment.max_hp()))
	Fx.add_light(self, LIGHT_RADIUS)


func set_camera_limits(rect: Rect2) -> void:
	camera.limit_left = int(rect.position.x)
	camera.limit_top = int(rect.position.y)
	camera.limit_right = int(rect.end.x)
	camera.limit_bottom = int(rect.end.y)


func _physics_process(delta: float) -> void:
	equipment.tick(delta)
	if is_dead:
		_respawn_time -= delta
		if _respawn_time <= 0.0:
			_respawn()
		return
	_invuln_time -= delta
	_shield_time -= delta
	_fire_cooldown -= delta
	_dash_cooldown -= delta
	_swing_time -= delta
	if _dash_time > 0.0:
		_dash_time -= delta
		velocity = _dash_velocity
	else:
		velocity = _move_input() * equipment.move_speed()
	move_and_slide()

	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length() > 1.0:
		aim_direction = to_mouse.normalized()
	if attack_enabled and Input.is_action_pressed("attack") and _fire_cooldown <= 0.0:
		_fire_weapon()
	queue_redraw()


func _process(delta: float) -> void:
	_shake = move_toward(_shake, 0.0, 30.0 * delta)
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake


func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
	if event.is_action_pressed("dash"):
		dash()
		get_viewport().set_input_as_handled()
		return
	if not skills_enabled:
		return
	for slot in Equipment.MAX_SKILLS:
		if event.is_action_pressed("skill_%d" % (slot + 1)):
			use_skill(slot)
			get_viewport().set_input_as_handled()
			return


func use_skill(slot: int) -> void:
	var bar := equipment.skill_bar()
	if slot >= bar.size() or not equipment.is_ready(bar[slot]):
		return
	Skills.cast(ItemDB.ITEMS[bar[slot]]["skill"], self)
	equipment.start_cooldown(bar[slot])


func fire(params: Dictionary) -> void:
	var direction: Vector2 = params["direction"]
	Projectile.spawn(get_tree(), global_position + direction * 14.0, params)


func dash() -> void:
	if _dash_cooldown > 0.0:
		return
	_dash_cooldown = Balance.DASH_COOLDOWN
	var direction := _move_input()
	if direction == Vector2.ZERO:
		direction = aim_direction
	_dash_velocity = direction.normalized() * DASH_SPEED
	_dash_time = DASH_TIME


func dash_cooldown_left() -> float:
	return maxf(0.0, _dash_cooldown)


func heal(amount: float) -> void:
	hp = minf(equipment.max_hp(), hp + amount)
	Fx.float_text(get_tree(), global_position, "+%d" % amount, Color("6fcf6f"))


func activate_shield(duration: float) -> void:
	_shield_time = duration


func take_damage(amount: float) -> void:
	if is_dead or _invuln_time > 0.0 or _shield_time > 0.0 or _dash_time > 0.0:
		return
	hp -= amount
	_invuln_time = Balance.PLAYER_HIT_INVULN
	_shake = 6.0
	Fx.float_text(get_tree(), global_position, "-%d" % amount, Color("ff7060"))
	if hp <= 0.0:
		_die()


func _die() -> void:
	is_dead = true
	_respawn_time = Balance.RESPAWN_TIME
	collision_layer = 0
	Fx.burst(get_tree(), global_position, Color("ff7060"), 20)
	Events.player_died.emit()
	Events.message.emit("쓰러졌습니다. %d초 뒤 왕국에서 부활합니다" % Balance.RESPAWN_TIME)
	queue_redraw()


func _respawn() -> void:
	is_dead = false
	hp = equipment.max_hp()
	global_position = spawn_point
	collision_layer = PhysicsLayers.PLAYER
	_invuln_time = Balance.RESPAWN_INVULN


func respawn_time_left() -> float:
	return _respawn_time


func _fire_weapon() -> void:
	var weapon := equipment.weapon()
	_fire_cooldown = 1.0 / float(weapon["rate"])
	if weapon.get("melee", false):
		Melee.swing(get_tree(), global_position, aim_direction, weapon)
		_swing_time = SWING_SHOW_TIME
		return
	fire({"direction": aim_direction.rotated(randf_range(-0.03, 0.03)), "damage": weapon["damage"], "speed": weapon["speed"]})


func _move_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


## 임시 그림. Phase 2에서 AnimatedSprite2D로 교체.
func _draw() -> void:
	if is_dead:
		return
	if _invuln_time > 0.0 and int(Time.get_ticks_msec() / 60.0) % 2 == 0:
		return
	draw_rect(Rect2(-9, -10, 18, 20), Color("2b5fa8"))
	draw_rect(Rect2(-6, -14, 12, 9), Color("f0d0a0"))
	draw_line(Vector2.ZERO, aim_direction * 20.0, Color("e8e0c8"), 3.0)
	if _swing_time > 0.0:
		var weapon := equipment.weapon()
		var half_arc := deg_to_rad(weapon["arc"]) / 2.0
		draw_arc(Vector2.ZERO, weapon["range"], aim_direction.angle() - half_arc, aim_direction.angle() + half_arc, 16, Color("f4ecd0"), 4.0)
	if _shield_time > 0.0:
		draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 24, Skills.color("shield"), 2.0)
