class_name Enemy
extends CharacterBody2D
## 적. 침공(invader) 적은 왕국 핵으로 가면서 길을 막는 벽·나무를 부순다.
## 낮에 돌아다니는 적은 플레이어가 가까이 오면 쫓아온다. 멀티플레이에서는 호스트에만 있고(D-017)
## 대상은 "player" 그룹(로컬 Player와 다른 사람의 RemotePlayer) 중 가장 가까운 살아 있는 플레이어다.

const SPRITE_TEXTURE := preload("res://assets/enemies/enemies.png")
const SPRITE_SIZE := 64
const SPRITE_OFFSET := Vector2(-32, -40)
const ANIMATION_FRAMES := 4
const ANIMATION_FPS := 8.0
const IDLE_ANIMATED := ["slime", "bog_slime", "fire_imp", "boss"]
## take_damage의 source: 플레이어는 멀티플레이 peer id(혼자·호스트 = 1), 화살탑은 이 값
const SOURCE_TOWER := -1
const SOURCE_LOCAL := 1

## 참가자 화면에 같은 적을 그리기 위한 번호 (호스트에서만 매긴다)
static var _next_net_id := 1

var type_id := ""
var stats := {}
var hp := 1.0
var max_hp := 1.0
var radius := 10.0
var is_invader := false
var net_id := 0
## 마지막 일격을 준 쪽 (SOURCE_TOWER 또는 peer id). 처치 보상을 누구에게 줄지 정한다
var killed_by := SOURCE_LOCAL

var _target: Node2D  # 이번 프레임에 노리는 플레이어 (Player 또는 RemotePlayer)
var _core: Core
var _world: World
var _attack_cooldown := 0.0
var _shot_cooldown := 3.0
var _flash := 0.0
var _wander_direction := Vector2.RIGHT
var _knockback := Vector2.ZERO
var _dying := false
var _animation_time := 0.0
var _animation_frame := 0
var _facing_left := false


func setup(id: String, invader: bool, hp_scale := 1.0) -> Enemy:
	type_id = id
	stats = EnemyDB.TYPES[id]
	is_invader = invader
	max_hp = stats["hp"] * hp_scale
	hp = max_hp
	radius = stats["radius"]
	return self


func _ready() -> void:
	add_to_group("enemies")
	motion_mode = MOTION_MODE_FLOATING
	collision_layer = PhysicsLayers.ENEMIES
	collision_mask = PhysicsLayers.WATER | PhysicsLayers.OBJECTS | PhysicsLayers.BUILDINGS
	var shape := CircleShape2D.new()
	shape.radius = radius
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)
	net_id = _next_net_id
	_next_net_id += 1
	_core = get_tree().get_first_node_in_group("core")
	_world = get_tree().get_first_node_in_group("world")
	_wander_direction = Vector2.from_angle(randf() * TAU)


func _physics_process(delta: float) -> void:
	_attack_cooldown -= delta
	_flash -= delta
	_target = _nearest_player()
	var chasing_player := _player_in_aggro()
	var target: Vector2
	if chasing_player:
		target = _target.global_position
	elif is_invader:
		target = _core.global_position
	else:
		if _target == null or global_position.distance_to(_target.global_position) > Balance.WANDERER_DESPAWN_DISTANCE:
			queue_free()
			return
		if randf() < delta * 0.5:
			_wander_direction = Vector2.from_angle(randf() * TAU)
		target = global_position + _wander_direction * 50.0

	var speed: float = stats["speed"] * (1.0 if chasing_player or is_invader else 0.4)
	velocity = global_position.direction_to(target) * speed + _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, 1200.0 * delta)
	move_and_slide()
	_update_animation(delta)

	if is_invader:
		_attack_blockers()
	_touch_player()
	if stats.has("radial_shot"):
		_radial_shot(delta)
	queue_redraw()


## source: 누가 때렸나 (SOURCE_TOWER 또는 peer id). 마지막 일격이 탑이면 처치 경험치를 모두 나눠 받는다 (D-015)
func take_damage(amount: float, source := SOURCE_LOCAL) -> void:
	if _dying:
		return
	hp -= amount
	Events.world_sound_requested.emit("enemy_death" if hp <= 0.0 else "hit_flesh", global_position)
	_flash = 0.08
	if hp <= 0.0:
		_dying = true
		killed_by = source
		Fx.burst(get_tree(), global_position, stats["color"], 12)
		Events.enemy_killed.emit(self)
		queue_free()


## 처형자 패시브: 체력이 낮은 적에게 기본 공격 피해를 더한다. bonus = 0.25면 +25%
func damage_after_execute(amount: float, bonus: float) -> float:
	return amount * (1.0 + bonus) if bonus > 0.0 and hp <= max_hp * PassiveDB.EXECUTE_HP_RATIO else amount


func knockback(impulse: Vector2) -> void:
	_knockback += impulse


## 아침이 되면 남은 침공 적은 사라진다
func burn_away() -> void:
	_dying = true
	Fx.burst(get_tree(), global_position, Color("ffcc66"), 10)
	queue_free()


## 다른 사람 화면에 그릴 모습: [번호, 종류, 위치, 체력 비율, 애니메이션 칸, 왼쪽 보기, 맞아서 번쩍임]
func appearance() -> Array:
	return [net_id, type_id, global_position, hp / max_hp, _animation_frame, _facing_left, _flash > 0.0]


func _nearest_player() -> Node2D:
	var best: Node2D = null
	var best_distance := INF
	for candidate: Node2D in get_tree().get_nodes_in_group("player"):
		if candidate.is_dead:
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best


func _player_in_aggro() -> bool:
	if _target == null:
		return false
	var aggro := Balance.INVADER_AGGRO if is_invader else Balance.WANDERER_AGGRO
	return global_position.distance_to(_target.global_position) < aggro


## 부딪힌 벽·핵·나무를 공격한다
func _attack_blockers() -> void:
	if _attack_cooldown > 0.0:
		return
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var other := collision.get_collider()
		if other == _world.object_layer:
			var cell := _world.object_cell_near(collision.get_position() - collision.get_normal() * 2.0, 4.0)
			if cell == World.NO_CELL:
				continue
			_world.damage_object(cell, stats["damage"], World.NOBODY)
		elif other is Building:
			# 가시 벽 패시브가 때린 적에게 피해를 돌려줄 수 있게 공격자를 넘긴다
			(other as Building).take_damage(stats["damage"], self)
		elif other != null and other.has_method("take_damage"):
			other.take_damage(stats["damage"])
		else:
			continue
		_attack_cooldown = Balance.ENEMY_ATTACK_INTERVAL
		return


func _touch_player() -> void:
	if _attack_cooldown > 0.0 or _target == null:
		return
	if global_position.distance_to(_target.global_position) < radius + 14.0:
		_target.take_damage(stats["damage"])
		_attack_cooldown = Balance.ENEMY_ATTACK_INTERVAL


func _radial_shot(delta: float) -> void:
	var shot: Dictionary = stats["radial_shot"]
	_shot_cooldown -= delta
	if _shot_cooldown > 0.0:
		return
	_shot_cooldown = shot["interval"]
	var count: int = shot["count"]
	for i in count:
		Projectile.spawn(get_tree(), global_position, {
			"direction": Vector2.from_angle(TAU * i / count), "speed": shot["speed"], "damage": shot["damage"],
			"lifetime": 2.2, "radius": 6.0, "color": Color("d070ff"), "team": Projectile.Team.ENEMY,
		})


## 이동이 멈추면 걷기도 멈추고, 젤리·불꽃·보스의 호흡만 계속 움직인다.
func _update_animation(delta: float) -> void:
	if absf(velocity.x) > 1.0:
		_facing_left = velocity.x < 0.0
	if velocity.length() > 1.0 or type_id in IDLE_ANIMATED:
		_animation_time += delta
	else:
		_animation_time = 0.0
	_animation_frame = int(_animation_time * ANIMATION_FPS) % ANIMATION_FRAMES


func _draw() -> void:
	draw_body(self, type_id, _animation_frame, _facing_left, _flash > 0.0, hp / max_hp, radius)


## 참가자 화면의 EnemyPuppet도 같은 그림을 쓴다
static func draw_body(canvas: CanvasItem, id: String, frame: int, facing_left: bool, flashing: bool, hp_ratio: float, body_radius: float) -> void:
	var info: Dictionary = EnemyDB.TYPES[id]
	var row: int = info["sprite_row"]
	var region := Rect2(Vector2(frame * SPRITE_SIZE, row * SPRITE_SIZE), Vector2.ONE * SPRITE_SIZE)
	var tint := Color(2.4, 2.4, 2.4) if flashing else Color.WHITE
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1 if facing_left else 1, 1))
	canvas.draw_texture_rect_region(SPRITE_TEXTURE, Rect2(SPRITE_OFFSET, Vector2.ONE * SPRITE_SIZE), region, tint)
	canvas.draw_set_transform(Vector2.ZERO)
	if hp_ratio < 1.0:
		var width := maxi(HealthBarArt.WIDTH, roundi(body_radius * 2.0 + 8.0))
		var sprite_top: int = info["sprite_top"]
		var bar_y := minf(-body_radius - 12.0, sprite_top + SPRITE_OFFSET.y - HealthBarArt.HEIGHT - 2.0)
		HealthBarArt.draw_bar(canvas, Vector2(-width / 2.0, bar_y), hp_ratio, HealthBarArt.Tone.RED, width)
