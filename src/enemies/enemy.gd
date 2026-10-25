class_name Enemy
extends CharacterBody2D
## 적. 침공(invader) 적은 왕국 핵으로 가면서 길을 막는 벽·나무를 부순다.
## 낮에 돌아다니는 적은 플레이어가 가까이 오면 쫓아온다.

var type_id := ""
var stats := {}
var hp := 1.0
var max_hp := 1.0
var radius := 10.0
var is_invader := false
var killed_by_tower := false

var _player: Player
var _core: Core
var _world: World
var _attack_cooldown := 0.0
var _shot_cooldown := 3.0
var _flash := 0.0
var _wander_direction := Vector2.RIGHT
var _knockback := Vector2.ZERO
var _dying := false


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
	_player = get_tree().get_first_node_in_group("player")
	_core = get_tree().get_first_node_in_group("core")
	_world = get_tree().get_first_node_in_group("world")
	_wander_direction = Vector2.from_angle(randf() * TAU)


func _physics_process(delta: float) -> void:
	_attack_cooldown -= delta
	_flash -= delta
	var chasing_player := _player_in_aggro()
	var target: Vector2
	if chasing_player:
		target = _player.global_position
	elif is_invader:
		target = _core.global_position
	else:
		if global_position.distance_to(_player.global_position) > Balance.WANDERER_DESPAWN_DISTANCE:
			queue_free()
			return
		if randf() < delta * 0.5:
			_wander_direction = Vector2.from_angle(randf() * TAU)
		target = global_position + _wander_direction * 50.0

	var speed: float = stats["speed"] * (1.0 if chasing_player or is_invader else 0.4)
	velocity = global_position.direction_to(target) * speed + _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, 1200.0 * delta)
	move_and_slide()

	if is_invader:
		_attack_blockers()
	_touch_player()
	if stats.has("radial_shot"):
		_radial_shot(delta)
	queue_redraw()


## by_tower: 화살탑 탄. 마지막 일격이 탑이면 처치 경험치를 모든 플레이어가 나눠 받는다 (D-015)
func take_damage(amount: float, by_tower := false) -> void:
	if _dying:
		return
	hp -= amount
	_flash = 0.08
	if hp <= 0.0:
		_dying = true
		killed_by_tower = by_tower
		Fx.burst(get_tree(), global_position, stats["color"], 12)
		Events.enemy_killed.emit(self)
		queue_free()


func knockback(impulse: Vector2) -> void:
	_knockback += impulse


## 아침이 되면 남은 침공 적은 사라진다
func burn_away() -> void:
	_dying = true
	Fx.burst(get_tree(), global_position, Color("ffcc66"), 10)
	queue_free()


func _player_in_aggro() -> bool:
	if _player.is_dead:
		return false
	var aggro := Balance.INVADER_AGGRO if is_invader else Balance.WANDERER_AGGRO
	return global_position.distance_to(_player.global_position) < aggro


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
			_world.damage_object(cell, stats["damage"], false)
		elif other != null and other.has_method("take_damage"):
			other.take_damage(stats["damage"])
		else:
			continue
		_attack_cooldown = Balance.ENEMY_ATTACK_INTERVAL
		return


func _touch_player() -> void:
	if _attack_cooldown > 0.0 or _player.is_dead:
		return
	if global_position.distance_to(_player.global_position) < radius + 14.0:
		_player.take_damage(stats["damage"])
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


## 임시 그림. Phase 2에서 스프라이트로 교체.
func _draw() -> void:
	var body := Rect2(-radius, -radius, radius * 2.0, radius * 2.0)
	draw_rect(body, Color.WHITE if _flash > 0.0 else stats["color"])
	var eye_y := -radius * 0.3
	draw_rect(Rect2(-radius * 0.4 - 2.0, eye_y, 3, 3), Color("111111"))
	draw_rect(Rect2(radius * 0.4 - 1.0, eye_y, 3, 3), Color("111111"))
	if hp < max_hp:
		var width := maxi(HealthBarArt.WIDTH, roundi(radius * 2.0 + 8.0))
		HealthBarArt.draw_bar(self, Vector2(-width / 2.0, -radius - 12.0), hp / max_hp, HealthBarArt.Tone.RED, width)
