class_name Player
extends CharacterBody2D
## 트윈스틱 조작 캐릭터. 이동(WASD)과 조준(마우스)은 서로 독립적이다.
## 대시(Space)는 모든 캐릭터의 기본 능력이고, 1~4 키는 장비에 달린 스킬을 쓴다.

const DASH_SPEED := 950.0
const DASH_TIME := 0.18
const LIGHT_RADIUS := 230.0
const SWING_SHOW_TIME := 0.12  # 근거리 공격 궤적이 보이는 시간
## 가로 한 줄 시트: 정면 4칸, 뒷면 4칸, 오른쪽 측면 4칸(왼쪽은 좌우 반전). 각 방향 0·2번 칸이 서 있는 자세.
const SPRITE_SHEET := preload("res://assets/characters/player.png")
const SPRITE_FRAMES_PER_DIR := 4
const WALK_FPS := 8.0
const SWORD_TEXTURE := preload("res://assets/combat/rusty_sword.png")
const SLASH_TEXTURE := preload("res://assets/combat/sword_slash.png")
const SLASH_FRAME_SIZE := 112
const SLASH_FRAMES := 4
const SWORD_OFFSET := Vector2(6, -8)

@onready var camera: Camera2D = $Camera

var equipment := Equipment.new()
var inventory := Inventory.new()
var progression := Progression.new()
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
var _swing_direction := Vector2.RIGHT
var _swing_item := ""
var _respawn_time := 0.0
var _shake := 0.0
var _sprite := Sprite2D.new()
var _walk_time := 0.0


func _ready() -> void:
	hp = max_hp()
	_sprite.texture = SPRITE_SHEET
	_sprite.hframes = SPRITE_FRAMES_PER_DIR * 3
	# 발이 충돌 원 중심보다 조금 아래에 오도록 올린다
	_sprite.position = Vector2(0, -4)
	add_child(_sprite)
	equipment.changed.connect(func() -> void: hp = minf(hp, max_hp()))
	progression.changed.connect(func() -> void: inventory.bonus_slots = int(progression.value("deep_pockets")))
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
		velocity = _move_input() * equipment.move_speed() * (1.0 + progression.value("swift") / 100.0)
	move_and_slide()

	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length() > 1.0:
		aim_direction = to_mouse.normalized()
	_update_sprite(delta)
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


func max_hp() -> float:
	return equipment.max_hp() + progression.value("vitality")


func fire(params: Dictionary) -> void:
	params["harvest_radius"] = progression.value("wide_harvest")
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
	hp = minf(max_hp(), hp + amount)
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
	inventory.clear()
	equipment.lose_bag()
	progression.lose_unspent()
	_respawn_time = Balance.RESPAWN_TIME
	collision_layer = 0
	Fx.burst(get_tree(), global_position, Color("ff7060"), 20)
	_sprite.visible = false
	Events.player_died.emit()
	Events.message.emit("쓰러졌습니다. 들고 있던 자원, 가방 장비, 쓰지 않은 경험치를 모두 잃었습니다. %d초 뒤 왕국에서 부활합니다" % Balance.RESPAWN_TIME)
	queue_redraw()


func _respawn() -> void:
	is_dead = false
	hp = max_hp()
	global_position = spawn_point
	collision_layer = PhysicsLayers.PLAYER
	_invuln_time = Balance.RESPAWN_INVULN
	_sprite.visible = true


func respawn_time_left() -> float:
	return _respawn_time


func _fire_weapon() -> void:
	var weapon := equipment.weapon().duplicate()
	weapon["damage"] *= 1.0 + progression.value("keen_edge") / 100.0
	weapon["harvest_radius"] = progression.value("wide_harvest")
	_fire_cooldown = 1.0 / float(weapon["rate"])
	if weapon.get("melee", false):
		Melee.swing(get_tree(), global_position, aim_direction, weapon)
		_swing_time = SWING_SHOW_TIME
		_swing_direction = aim_direction
		_swing_item = equipment.item_in("weapon")
		return
	fire({"direction": aim_direction.rotated(randf_range(-0.03, 0.03)), "damage": weapon["damage"], "speed": weapon["speed"]})


func _move_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


## 트윈스틱이라 이동 방향이 아니라 조준 방향을 바라본다. 걷기 칸은 움직일 때만 넘긴다.
func _update_sprite(delta: float) -> void:
	var direction := 2  # 측면
	if absf(aim_direction.y) > absf(aim_direction.x):
		direction = 0 if aim_direction.y > 0.0 else 1
	_sprite.flip_h = direction == 2 and aim_direction.x < 0.0
	if velocity.length() > 1.0:
		_walk_time += delta
	else:
		_walk_time = 0.0
	var step := int(_walk_time * WALK_FPS) % SPRITE_FRAMES_PER_DIR
	_sprite.frame = direction * SPRITE_FRAMES_PER_DIR + step
	_sprite.visible = not (_invuln_time > 0.0 and int(Time.get_ticks_msec() / 60.0) % 2 == 0)


## 몸은 _sprite가 그리고, 여기서는 무기·공격 궤적·보호막만 그린다.
func _draw() -> void:
	if is_dead:
		return
	var swinging := _swing_time > 0.0 and _swing_item == equipment.item_in("weapon")
	if equipment.item_in("weapon") == "rusty_sword":
		_draw_rusty_sword(swinging)
	else:
		draw_line(Vector2.ZERO, aim_direction * 20.0, Color("e8e0c8"), 3.0)
		if swinging:
			var weapon := equipment.weapon()
			var half_arc := deg_to_rad(weapon["arc"]) / 2.0
			draw_arc(Vector2.ZERO, weapon["range"], _swing_direction.angle() - half_arc, _swing_direction.angle() + half_arc, 16, Color("f4ecd0"), 4.0)
	if _shield_time > 0.0:
		draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 24, Skills.color("shield"), 2.0)


## 판정은 누른 순간 끝나므로 궤적도 첫 칸부터 범위 전체를 보인다.
## 공격 중 마우스를 돌려도 이미 판정한 방향으로 궤적을 남긴다.
func _draw_rusty_sword(swinging: bool) -> void:
	var angle := aim_direction.angle()
	if swinging:
		var progress := clampf(1.0 - _swing_time / SWING_SHOW_TIME, 0.0, 1.0)
		var frame := mini(int(progress * SLASH_FRAMES), SLASH_FRAMES - 1)
		var size := Vector2.ONE * SLASH_FRAME_SIZE
		draw_set_transform(Vector2.ZERO, _swing_direction.angle())
		draw_texture_rect_region(SLASH_TEXTURE, Rect2(-size / 2.0, size), Rect2(Vector2(frame * SLASH_FRAME_SIZE, 0), size))
		var half_arc := deg_to_rad(float(equipment.weapon()["arc"])) / 2.0
		angle = _swing_direction.angle() + lerpf(-half_arc, half_arc, progress)
	draw_set_transform(Vector2.ZERO, angle)
	draw_texture(SWORD_TEXTURE, SWORD_OFFSET)
	draw_set_transform(Vector2.ZERO)
