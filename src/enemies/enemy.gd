class_name Enemy
extends CharacterBody2D
## 적. 침공(invader) 적은 왕국 핵으로 가면서 길을 막는 벽·나무를 부순다.
## 낮에 돌아다니는 적은 플레이어가 가까이 오면 쫓아온다. 낮에는 왕국 영토에 들어오지 않고 영토 안의 플레이어는 노리지 않는다(D-026).
## 멀티플레이에서는 호스트에만 있고(D-017)
## 대상은 "player" 그룹(로컬 Player와 다른 사람의 RemotePlayer) 중 가장 가까운 살아 있는 플레이어다.
## 보스는 EnemyDB의 "patterns"를 반복하고 체력이 줄면 "rage"로 빨라진다 (D-021). 패턴에는 무작위가 없다.

const SPRITE_TEXTURE := preload("res://assets/enemies/enemies.png")
const BOSS_TEXTURE := preload("res://assets/enemies/bosses.png")
const BOSS_SPRITE_SIZE := 128
const BOSS_SPRITE_OFFSET := Vector2(-64, -104)
const BOSS_ANIMATION_FRAMES := 8
const BOSS_RAGE_ANIMATION_LIMIT := 1.5
const BOSS_RAGE_GLOW := 0.12
const SPRITE_SIZE := 64
const SPRITE_OFFSET := Vector2(-32, -40)
const ANIMATION_FRAMES := 4
const ANIMATION_FPS := 8.0
const IDLE_ANIMATED := ["slime", "bog_slime", "fire_imp"]  # 보스는 모두 호흡한다
const SPIRAL_LIFETIME := 2.4
const SLEEP_CHECK_INTERVAL := 0.5
const FLEE_RANGE := 9.0 * Balance.TILE  # 도망자가 플레이어를 알아채고 달아나기 시작하는 거리
const ELITE_SCALE := 1.35  # 정예 몬스터 그림 크기
const ELITE_TINT := Color(1.25, 1.08, 0.72)  # 서식 몬스터가 깰지 확인하는 간격(초). 잠든 동안은 이것만 센다
const BULLET_COLOR := Color("d070ff")
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
var damage_scale := 1.0  # 날짜에 따른 피해 배율 (Balance.wave_damage_scale)
var minion_hp_scale := 1.0  # 보스가 부르는 부하의 체력·피해 배율 (WaveSpawner가 그날 침공 배율로 정한다)
var minion_damage_scale := 1.0
var net_id := 0
## 마지막 일격을 준 쪽 (SOURCE_TOWER 또는 peer id). 처치 보상을 누구에게 줄지 정한다
var killed_by := SOURCE_LOCAL
## 낮의 배회 적: 영토 밖에 머물고 영토 안의 플레이어를 무시한다 (D-026). WaveSpawner가 낮/밤에 맞춰 정한다
var avoids_kingdom := false
## 바이옴 서식 몬스터(D-035)의 집과 바이옴. 집이 있으면 사라지지 않고 집 근처를 돌아다닌다. INF·-1이면 서식지 없음
var home := Vector2.INF
var home_terrain := -1
## 낮 의뢰(D-037): 정예는 크고 금빛으로 보이고, 도망자는 플레이어를 피해 달아나며 공격하지 않는다
var elite := false
var flees := false
var speed_scale := 1.0
var _asleep := false
var _sleep_check := 0.0

var _target: Node2D  # 이번 프레임에 노리는 플레이어 (Player 또는 RemotePlayer)
var _core: Core
var _kingdom: Kingdom
var _world: World
var _attack_cooldown := 0.0
var _pattern_timers: Array[float] = []
var _radial_offset := false  # 원형 탄을 번갈아 반 칸씩 돌려 빈틈 위치를 바꾼다
var _spiral := {}  # 진행 중인 회전 연사 패턴 (비었으면 없음)
var _spiral_left := 0.0
var _spiral_tick := 0.0
var _spiral_angle := 0.0
var _charge := {}  # 진행 중인 돌진 패턴
var _charge_windup := 0.0
var _charge_left := 0.0
var _charge_direction := Vector2.ZERO
var _minions: Array[Enemy] = []
var _slow_factor := 1.0  # 서리탑에 맞으면 잠시 느려진다
var _slow_time := 0.0
var _flash := 0.0
var _wander_direction := Vector2.RIGHT
var _knockback := Vector2.ZERO
var _dying := false
var _animation_time := 0.0
var _animation_frame := 0
var _facing_left := false


func setup(id: String, invader: bool, hp_scale := 1.0, scale_damage := 1.0) -> Enemy:
	type_id = id
	stats = EnemyDB.TYPES[id]
	is_invader = invader
	max_hp = stats["hp"] * hp_scale
	hp = max_hp
	radius = stats["radius"]
	damage_scale = scale_damage
	# 패턴마다 첫 사용 시점을 엇갈려 한꺼번에 쏟아지지 않게 한다
	var patterns: Array = stats.get("patterns", [])
	for i in patterns.size():
		_pattern_timers.append(patterns[i]["interval"] * (0.4 + 0.2 * i))
	return self


func is_boss() -> bool:
	return stats.get("is_boss", false)


## 접촉·벽 공격 피해
func contact_damage() -> float:
	return stats["damage"] * damage_scale


func _ready() -> void:
	add_to_group("enemies")
	motion_mode = MOTION_MODE_FLOATING
	collision_layer = PhysicsLayers.ENEMIES
	collision_mask = PhysicsLayers.WATER | PhysicsLayers.OBJECTS | PhysicsLayers.BUILDINGS | PhysicsLayers.PASSABLE
	var shape := CircleShape2D.new()
	shape.radius = radius
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)
	net_id = _next_net_id
	_next_net_id += 1
	_core = get_tree().get_first_node_in_group("core")
	_kingdom = get_tree().get_first_node_in_group("kingdom")
	_world = get_tree().get_first_node_in_group("world")
	_wander_direction = Vector2.from_angle(randf() * TAU)


func _physics_process(delta: float) -> void:
	# 먼 서식 몬스터는 잠들어 아무것도 하지 않는다. 수백 마리를 매 프레임 움직이면 호스트가 느려진다 (D-035)
	if home.is_finite():
		_sleep_check -= delta
		if _sleep_check <= 0.0:
			_sleep_check = SLEEP_CHECK_INTERVAL
			var near := _nearest_player(false)
			_asleep = near == null or global_position.distance_to(near.global_position) > Balance.RESIDENT_WAKE_RANGE
		if _asleep:
			return
	_attack_cooldown -= delta
	_flash -= delta
	var nearest := _nearest_player(false)
	_target = _nearest_player(avoids_kingdom)
	var chasing_player := _player_in_aggro() and not flees
	# 서식 몬스터는 집에서 너무 멀리까지는 쫓아가지 않는다
	if chasing_player and home.is_finite() and global_position.distance_to(home) > Balance.RESIDENT_CHASE_LIMIT:
		chasing_player = false
	var target: Vector2
	if chasing_player:
		target = _target.global_position
	elif is_invader:
		target = _core.global_position
	elif flees and nearest != null and global_position.distance_to(nearest.global_position) < FLEE_RANGE:
		target = global_position + nearest.global_position.direction_to(global_position) * 50.0
	elif home.is_finite() and global_position.distance_to(home) > Balance.RESIDENT_LEASH:
		target = home
	else:
		# 서식지 없는 배회 적만: 사라질지는 영토 안 사람까지 포함한 가장 가까운 플레이어로 정한다
		if not home.is_finite() and (nearest == null or global_position.distance_to(nearest.global_position) > Balance.WANDERER_DESPAWN_DISTANCE):
			queue_free()
			return
		if randf() < delta * 0.5:
			_wander_direction = Vector2.from_angle(randf() * TAU)
		target = global_position + _wander_direction * 50.0

	_slow_time -= delta
	var slowed := _slow_factor if _slow_time > 0.0 else 1.0
	var running := flees and nearest != null and global_position.distance_to(nearest.global_position) < FLEE_RANGE
	var speed: float = stats["speed"] * (1.0 if chasing_player or is_invader or running else 0.4) * _rage("speed") * slowed * speed_scale
	velocity = global_position.direction_to(target) * speed + _knockback
	if _charge_windup > 0.0:
		velocity = Vector2.ZERO
	elif _charge_left > 0.0:
		velocity = _charge_direction * float(_charge["speed"])
	_knockback = _knockback.move_toward(Vector2.ZERO, 1200.0 * delta)
	if avoids_kingdom:
		_stay_out_of_kingdom()
	move_and_slide()
	_update_animation(delta)

	if is_invader:
		_attack_blockers()
	if not flees:
		_touch_player()
	if not _pattern_timers.is_empty():
		_run_patterns(delta)
	queue_redraw()


## source: 누가 때렸나 (SOURCE_TOWER 또는 peer id). 마지막 일격이 탑이면 처치 경험치를 모두 나눠 받는다 (D-015)
## emphasis: 패시브로 강해진 공격이면 피해 숫자를 강조한다 (D-023)
func take_damage(amount: float, source := SOURCE_LOCAL, emphasis := false) -> void:
	if _dying:
		return
	hp -= amount
	Events.damage_dealt.emit(global_position, amount, emphasis, source)
	Events.world_sound_requested.emit("enemy_death" if hp <= 0.0 else "hit_flesh", global_position)
	_flash = 0.08
	if hp <= 0.0:
		_dying = true
		killed_by = source
		Fx.burst(get_tree(), global_position, stats["color"], 12)
		if is_boss():
			Events.screen_shake_requested.emit(Vector2.INF, 12.0)
		Events.enemy_killed.emit(self)
		queue_free()


## 처형자(체력이 낮은 적)·선제공격(체력이 가득 찬 적) 패시브로 기본 공격 피해를 더한다. bonus = 0.25면 +25%
func damage_after_execute(amount: float, bonus: float, opener := 0.0) -> float:
	if bonus > 0.0 and hp <= max_hp * PassiveDB.EXECUTE_HP_RATIO:
		return amount * (1.0 + bonus)
	if opener > 0.0 and hp >= max_hp:
		return amount * (1.0 + opener)
	return amount


## 더 강한(낮은) 감속이 걸려 있으면 그쪽을 유지한다
func slow(factor: float, duration: float) -> void:
	if _slow_time <= 0.0 or factor <= _slow_factor:
		_slow_factor = factor
	_slow_time = maxf(_slow_time, duration)


func knockback(impulse: Vector2) -> void:
	_knockback += impulse


## 아침이 되면 남은 침공 적은 사라진다
func burn_away() -> void:
	_dying = true
	Fx.burst(get_tree(), global_position, Color("ffcc66"), 10)
	queue_free()


## 다른 사람 화면에 그릴 모습: [번호, 종류, 위치, 체력 비율, 애니메이션 칸, 왼쪽 보기, 맞아서 번쩍임, 정예]
func appearance() -> Array:
	return [net_id, type_id, global_position, hp / max_hp, _animation_frame, _facing_left, _flash > 0.0, elite]


## skip_kingdom: 영토 안의 플레이어는 없는 셈 친다 (낮의 배회 적)
func _nearest_player(skip_kingdom: bool) -> Node2D:
	var best: Node2D = null
	var best_distance := INF
	for candidate: Node2D in get_tree().get_nodes_in_group("player"):
		if candidate.is_dead or (skip_kingdom and in_kingdom(candidate.global_position)):
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best


## 그 위치가 왕국 영토(지도에 그린 경계, 영토 확장으로 넓어짐) 안인가
func in_kingdom(at: Vector2) -> bool:
	return _kingdom != null and _kingdom.in_territory_at(at)


## 영토 안이면 바깥으로 밀어내고, 경계 근처에서 안쪽으로 향하는 속도는 지워 경계를 따라 미끄러지게 한다
func _stay_out_of_kingdom() -> void:
	if _kingdom == null:
		return
	var from_core := global_position - _kingdom.core.global_position
	var outward := from_core.normalized() if from_core != Vector2.ZERO else Vector2.RIGHT
	var edge := _kingdom.territory_edge() + radius
	var inward := velocity.dot(outward)
	if from_core.length() < edge:
		velocity = outward * maxf(velocity.length(), float(stats["speed"]))
		_wander_direction = outward
	elif inward < 0.0 and from_core.length() < edge + Balance.TILE:
		velocity -= outward * inward
		_wander_direction = outward


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
			_world.damage_object(cell, contact_damage(), World.NOBODY)
		elif other is Building:
			# 가시 벽 패시브가 때린 적에게 피해를 돌려줄 수 있게 공격자를 넘긴다
			(other as Building).take_damage(contact_damage(), self)
		elif other != null and other.has_method("take_damage"):
			other.take_damage(contact_damage())
		else:
			continue
		_attack_cooldown = Balance.ENEMY_ATTACK_INTERVAL
		return


func _touch_player() -> void:
	if _attack_cooldown > 0.0 or _target == null:
		return
	if global_position.distance_to(_target.global_position) < radius + 14.0:
		# 돌진 중에 닿으면 돌진 피해
		var amount: float = _charge["damage"] * damage_scale if _charge_left > 0.0 else contact_damage()
		_target.take_damage(amount)
		_attack_cooldown = Balance.ENEMY_ATTACK_INTERVAL


## 지금 체력에 맞는 분노 배율 (rate: 패턴 속도, speed: 이동). 체력이 낮을수록 센 단계가 덮어쓴다
func _rage(key: String) -> float:
	var value := 1.0
	for phase: Dictionary in stats.get("rage", []):
		if hp <= max_hp * float(phase["at"]):
			value = phase[key]
	return value


func _run_patterns(delta: float) -> void:
	var patterns: Array = stats["patterns"]
	var rate := _rage("rate")
	for i in patterns.size():
		_pattern_timers[i] -= delta * rate
		if _pattern_timers[i] <= 0.0:
			_pattern_timers[i] = patterns[i]["interval"]
			_start_pattern(patterns[i])
	if _spiral_left > 0.0:
		_spiral_left -= delta
		_spiral_angle += float(_spiral["turn"]) * delta
		_spiral_tick -= delta
		if _spiral_tick <= 0.0:
			_spiral_tick = 1.0 / float(_spiral["rate"])
			var arms: int = _spiral["arms"]
			for arm in arms:
				_shoot(Vector2.from_angle(_spiral_angle + TAU * arm / arms), _spiral, SPIRAL_LIFETIME)
	if _charge_windup > 0.0:
		_charge_windup -= delta
		_flash = 0.05  # 돌진 직전 번쩍임 (참가자 화면에도 그대로 보인다)
		if _charge_windup <= 0.0:
			_charge_left = _charge["duration"]
			Events.screen_shake_requested.emit(global_position, 6.0)
			if _target != null:
				_charge_direction = global_position.direction_to(_target.global_position)
	elif _charge_left > 0.0:
		_charge_left -= delta


func _start_pattern(pattern: Dictionary) -> void:
	match pattern["type"]:
		"radial":
			var count: int = pattern["count"]
			var offset := PI / count if _radial_offset else 0.0
			_radial_offset = not _radial_offset
			for i in count:
				_shoot(Vector2.from_angle(offset + TAU * i / count), pattern, pattern.get("lifetime", 2.2))
		"spiral":
			_spiral = pattern
			_spiral_left = pattern["duration"]
			_spiral_tick = 0.0
		"fan":
			if _target == null:
				return
			var aim := global_position.direction_to(_target.global_position)
			var count: int = pattern["count"]
			var arc := deg_to_rad(pattern["arc"])
			for i in count:
				var t := 0.5 if count == 1 else float(i) / (count - 1)
				_shoot(aim.rotated((t - 0.5) * arc), pattern, 2.0)
		"charge":
			if _charge_windup <= 0.0 and _charge_left <= 0.0 and _target != null:
				_charge = pattern
				_charge_windup = pattern["windup"]
		"summon":
			_summon(pattern)
		_:
			push_warning("알 수 없는 보스 패턴: %s" % pattern["type"])


func _shoot(direction: Vector2, pattern: Dictionary, lifetime: float) -> void:
	Projectile.spawn(get_tree(), global_position, {
		"direction": direction, "speed": pattern["speed"], "damage": pattern["damage"] * damage_scale,
		"lifetime": lifetime, "radius": pattern.get("radius", 6.0), "color": BULLET_COLOR, "team": Projectile.Team.ENEMY,
	})


## 부하는 침공 적이라 핵으로 가고 아침에 사라진다. 너무 많이 쌓이지 않게 살아 있는 수를 센다
func _summon(pattern: Dictionary) -> void:
	# 매개변수에 타입을 적으면 해제된 부하를 넘기는 순간 호출 자체가 실패하므로 타입 없이 받는다
	_minions = _minions.filter(func(minion) -> bool: return is_instance_valid(minion) and not minion._dying)
	var count := mini(pattern["count"], int(pattern["max_alive"]) - _minions.size())
	for i in count:
		var minion := Enemy.new().setup(pattern["minion"], true, minion_hp_scale, minion_damage_scale)
		minion.position = global_position + Vector2.from_angle(TAU * i / maxi(count, 1)) * (radius + 24.0)
		get_parent().add_child.call_deferred(minion)
		_minions.append(minion)
	if count > 0:
		Fx.burst(get_tree(), global_position, stats["color"], 16, 200.0)


## 이동이 멈추면 걷기도 멈추고, 젤리·불꽃·보스의 호흡만 계속 움직인다.
func _update_animation(delta: float) -> void:
	if absf(velocity.x) > 1.0:
		_facing_left = velocity.x < 0.0
	if velocity.length() > 1.0 or type_id in IDLE_ANIMATED or is_boss():
		_animation_time += delta * (minf(_rage("rate"), BOSS_RAGE_ANIMATION_LIMIT) if is_boss() else 1.0)
	else:
		_animation_time = 0.0
	_animation_frame = int(_animation_time * ANIMATION_FPS) % animation_frames(type_id)


func _draw() -> void:
	draw_body(self, type_id, _animation_frame, _facing_left, _flash > 0.0, hp / max_hp, radius, elite)


## 일반 적과 보스는 크기가 다르지만 같은 위치·프레임 계약으로 로컬/원격에서 그린다.
static func animation_frames(id: String) -> int:
	return BOSS_ANIMATION_FRAMES if EnemyDB.TYPES[id].get("is_boss", false) else ANIMATION_FRAMES


static func sprite_texture(id: String) -> Texture2D:
	return BOSS_TEXTURE if EnemyDB.TYPES[id].get("is_boss", false) else SPRITE_TEXTURE


static func sprite_offset(id: String) -> Vector2:
	return BOSS_SPRITE_OFFSET if EnemyDB.TYPES[id].get("is_boss", false) else SPRITE_OFFSET


static func sprite_region(id: String, frame: int) -> Rect2:
	var info: Dictionary = EnemyDB.TYPES[id]
	var pixels := BOSS_SPRITE_SIZE if info.get("is_boss", false) else SPRITE_SIZE
	var row: int = info["sprite_row"]
	return Rect2(Vector2(posmod(frame, animation_frames(id)) * pixels, row * pixels), Vector2.ONE * pixels)


## 참가자 화면의 EnemyPuppet도 동일한 고유 외형·호흡·피격·분노 표시를 쓴다.
## elite: 낮 의뢰의 정예(D-037). 발밑 금빛 고리와 함께 크고 금빛으로 그린다
static func draw_body(canvas: CanvasItem, id: String, frame: int, facing_left: bool, flashing: bool, hp_ratio: float, body_radius: float, elite := false) -> void:
	var info: Dictionary = EnemyDB.TYPES[id]
	var region := sprite_region(id, frame)
	var offset := sprite_offset(id)
	var tint := Color(2.4, 2.4, 2.4) if flashing else (ELITE_TINT if elite else Color.WHITE)
	var size := ELITE_SCALE if elite else 1.0
	if elite:
		canvas.draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.4))
		canvas.draw_arc(Vector2.ZERO, body_radius * 1.6, 0.0, TAU, 32, MenuArt.GOLD, 2.0)
		canvas.draw_set_transform(Vector2.ZERO)
	# 분노는 기존 체력 조건을 읽는 연출이다. 서리·늪의 고유색이 사라지지 않게 밝기만 살짝 올린다.
	if not flashing and info.get("is_boss", false):
		var phases: Array = info.get("rage", [])
		if not phases.is_empty() and hp_ratio <= float(phases[0]["at"]):
			var pulse := 1.0 + BOSS_RAGE_GLOW * (0.5 + 0.5 * sin(frame * TAU / BOSS_ANIMATION_FRAMES))
			tint = Color(pulse, pulse, pulse)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1 if facing_left else 1, 1) * size)
	canvas.draw_texture_rect_region(sprite_texture(id), Rect2(offset, region.size), region, tint)
	canvas.draw_set_transform(Vector2.ZERO)
	if hp_ratio < 1.0:
		var width := maxi(HealthBarArt.WIDTH, roundi(body_radius * 2.0 + 8.0))
		var sprite_top: int = info["sprite_top"]
		var bar_y := minf(-body_radius - 12.0, sprite_top + offset.y - HealthBarArt.HEIGHT - 2.0)
		HealthBarArt.draw_bar(canvas, Vector2(-width / 2.0, bar_y), hp_ratio, HealthBarArt.Tone.RED, width)
