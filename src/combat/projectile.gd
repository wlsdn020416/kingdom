class_name Projectile
extends Node2D
## 모든 투사체. team에 따라 무엇에 맞는지(충돌 마스크)가 정해진다.
## explode_radius가 0보다 크면 폭탄: 아무것도 맞지 않고 날아가다 수명이 끝나면 폭발한다.
## Area2D 겹침 신호는 정적 바디(타일·벽·핵)를 감지하지 못해서, 매 물리 프레임 직접 충돌을 조회한다.

enum Team { PLAYER, ENEMY, TOWER }

const MASKS := {
	Team.PLAYER: PhysicsLayers.OBJECTS | PhysicsLayers.ENEMIES,
	Team.TOWER: PhysicsLayers.ENEMIES,
	Team.ENEMY: PhysicsLayers.OBJECTS | PhysicsLayers.BUILDINGS | PhysicsLayers.PASSABLE | PhysicsLayers.PLAYER,
}
const MAX_HITS_PER_STEP := 8
const CHAIN_RANGE := 110.0  # 번개가 다음 적으로 튈 수 있는 거리 (D-028)
const CHAIN_RATIO := 0.7
const SECOND_BLAST_DELAY := 0.4
const SECOND_BLAST_SCALE := 0.7  # 2차 폭발의 피해·반경 배수
const TEXTURE := preload("res://assets/combat/projectiles.png")

var team := Team.PLAYER
var velocity := Vector2.ZERO
var damage := 10.0
var lifetime := 1.0
var radius := 4.0
var pierce := false
var explode_radius := 0.0
var harvest_radius := 0.0  # 광역 채집 패시브 (플레이어 탄만)
var splash_radius := 0.0  # 불씨 폭발 패시브: 적을 맞히면 이 안의 다른 적에게도 일부 피해 (D-020)
var execute_bonus := 0.0  # 처형자 패시브: 체력이 낮은 적에게 추가 피해 비율
var opener_bonus := 0.0  # 선제공격 패시브: 체력이 가득 찬 적에게 추가 피해 비율
var harvest_power := 0.0  # 숙련 채집꾼 패시브: 나무·바위·광석에 주는 피해 비율
var emphasis := false  # 마무리 일격처럼 강해진 기본 공격 (피해 숫자 강조, D-023)
var slow_factor := 1.0  # 서리탑: 맞은 적의 이동 속도 배수와 지속 시간 (D-022)
var slow_time := 0.0
var knockback := 0.0  # 맞은 적을 날아가는 방향으로 미는 힘 (용린 산탄 석궁, D-028)
var pierce_ramp := 0.0  # 관통할 때마다 피해가 이 비율만큼 늘어난다 (용골 장궁)
var chain := 0  # 맞은 적에서 근처 적으로 튀는 횟수 (번개 지팡이)
var second_blast := false  # 폭발한 자리에서 한 번 더 터진다 (흑요석 공성 석궁)
var source := Enemy.SOURCE_LOCAL  # 쏜 플레이어의 peer id (처치 보상용)
## false면 나무·바위·건물·핵에 막히기만 하고 피해를 주지 않는다. 멀티플레이 참가자 화면의 탄 (월드·왕국은 호스트만 바꾼다, D-017)
var hits_world := true
var color := Color("fff4c0")
var art_id := "arrow"
## 다른 사람 탄의 표시 전용 복제본. 체력·월드·보상을 바꾸지 않는다.
var visual_only := false
var _elapsed := 0.0
var _flight_duration := 1.0
var _already_hit := {}
var _boosted_hit := false
var _query := PhysicsShapeQueryParameters2D.new()


## params: direction(필수), speed, damage, lifetime, radius, pierce, explode_radius, harvest_radius, splash_radius, execute_bonus, color, team, source, hits_world,
## knockback, pierce_ramp, chain, second_blast (D-028)
static func spawn(tree: SceneTree, at: Vector2, params: Dictionary) -> Projectile:
	var projectile := Projectile.new()
	projectile.team = params.get("team", Team.PLAYER)
	projectile.velocity = params["direction"] * params.get("speed", 600.0)
	projectile.damage = params.get("damage", 10.0)
	projectile.lifetime = params.get("lifetime", 0.9)
	projectile.radius = params.get("radius", 4.0)
	projectile.pierce = params.get("pierce", false)
	projectile.explode_radius = params.get("explode_radius", 0.0)
	projectile.harvest_radius = params.get("harvest_radius", 0.0)
	projectile.splash_radius = params.get("splash_radius", 0.0)
	projectile.execute_bonus = params.get("execute_bonus", 0.0)
	projectile.opener_bonus = params.get("opener_bonus", 0.0)
	projectile.harvest_power = params.get("harvest_power", 0.0)
	projectile.emphasis = params.get("emphasis", false)
	projectile.slow_factor = params.get("slow_factor", 1.0)
	projectile.slow_time = params.get("slow_time", 0.0)
	projectile.knockback = params.get("knockback", 0.0)
	projectile.pierce_ramp = params.get("pierce_ramp", 0.0)
	projectile.chain = params.get("chain", 0)
	projectile.second_blast = params.get("second_blast", false)
	projectile.source = Enemy.SOURCE_TOWER if projectile.team == Team.TOWER else params.get("source", Enemy.SOURCE_LOCAL)
	projectile.hits_world = params.get("hits_world", true)
	projectile.visual_only = params.get("visual_only", false)
	if projectile.visual_only:
		projectile.hits_world = false
	projectile.art_id = params.get("art", "enemy_orb" if projectile.team == Team.ENEMY else "arrow")
	if not WeaponArtDB.has_projectile(projectile.art_id):
		projectile.art_id = "arrow"
	projectile._flight_duration = maxf(projectile.lifetime, 0.001)
	if projectile.team == Team.TOWER:
		Events.world_sound_requested.emit("bow_shoot", at)
	if projectile.team == Team.ENEMY:
		Events.enemy_shot.emit(at, params)
	projectile.color = params.get("color", projectile.color)
	projectile.position = at
	projectile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# 물리 콜백 도중에 불려도 안전하도록 다음 틈에 추가
	tree.get_first_node_in_group("projectiles").add_child.call_deferred(projectile)
	return projectile


func _ready() -> void:
	var shape := CircleShape2D.new()
	shape.radius = radius
	_query.shape = shape
	_query.collision_mask = MASKS[team]


func _physics_process(delta: float) -> void:
	_elapsed += delta
	position += velocity * delta
	lifetime -= delta
	queue_redraw()
	if explode_radius > 0.0:
		if lifetime <= 0.0:
			_explode()
			queue_free()
		return
	_check_hits()
	if lifetime <= 0.0:
		queue_free()


func _draw() -> void:
	var angle := velocity.angle()
	var offset := Vector2.ZERO
	if art_id == "bomb":
		# 떠오르는 높이는 그림만 바꾼다. 지면의 경로·수명·폭발 범위는 유지한다.
		draw_rect(Rect2(-4, -1, 8, 2), Color(0.04, 0.06, 0.08, 0.3))
		offset.y = -sin(clampf(_elapsed / _flight_duration, 0.0, 1.0) * PI) * WeaponArtDB.BOMB_LIFT
		angle = _elapsed * WeaponArtDB.BOMB_SPIN
	draw_set_transform(offset, angle)
	var size := Vector2.ONE * WeaponArtDB.PROJECTILE_SIZE
	draw_texture_rect_region(WeaponArtDB.projectile_texture(art_id), Rect2(-size / 2.0, size), WeaponArtDB.projectile_region(art_id, _elapsed))
	draw_set_transform(Vector2.ZERO)


func _check_hits() -> void:
	_query.transform = Transform2D(0.0, global_position)
	for hit in get_world_2d().direct_space_state.intersect_shape(_query, MAX_HITS_PER_STEP):
		if is_queued_for_deletion():
			return
		_on_hit(hit["collider"])


func _on_hit(body: Object) -> void:
	_boosted_hit = false
	if body is TileMapLayer:
		var world := (body as TileMapLayer).get_parent() as World
		var cell := world.object_cell_near(global_position, radius)
		if not hits_world:
			pass
		elif cell != World.NO_CELL and harvest_radius > 0.0:
			world.damage_objects_around(cell, damage * (1.0 + harvest_power), harvest_radius, source)
		elif cell != World.NO_CELL:
			world.damage_object(cell, damage * (1.0 + harvest_power), source if team == Team.PLAYER else World.NOBODY)
		_show_impact()
		queue_free()
		return
	if _already_hit.has(body):
		return
	_already_hit[body] = true
	if visual_only:
		pass
	elif body is Enemy:
		var enemy := body as Enemy
		if splash_radius > 0.0:
			_splash(enemy)
		if slow_time > 0.0:
			enemy.slow(slow_factor, slow_time)
		if knockback > 0.0:
			enemy.knockback(velocity.normalized() * knockback)
		var dealt := enemy.damage_after_execute(damage, execute_bonus, opener_bonus)
		_boosted_hit = dealt > damage
		enemy.take_damage(dealt, source, emphasis or dealt > damage)
		if chain > 0:
			_chain_from(enemy)
		damage *= 1.0 + pierce_ramp
	elif hits_world or body is Player:
		# 참가자 화면에 따라 그린 적 탄은 내 캐릭터만 맞힌다. 건물·왕국 핵 피해는 호스트의 탄이 정한다 (D-017)
		if body.has_method("take_damage"):
			body.take_damage(damage)
	_show_impact()
	if not pierce:
		queue_free()


## 번개 연쇄: 맞힌 적에서 가장 가까운 다른 적으로 chain번 튄다. 한 번 튈 때마다 CHAIN_RATIO만큼 약해진다
func _chain_from(hit: Enemy) -> void:
	var visited := {hit: true}
	var current := hit
	var bolt := damage
	for i in chain:
		bolt *= CHAIN_RATIO
		var next: Enemy = null
		var best := CHAIN_RANGE
		for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
			var distance := enemy.global_position.distance_to(current.global_position)
			if not visited.has(enemy) and distance < best:
				next = enemy
				best = distance
		if next == null:
			return
		var link := next.global_position - current.global_position
		Events.combat_effect_requested.emit("lightning_link", (next.global_position + current.global_position) * 0.5, link.length() / WeaponArtDB.LINK_LENGTH, link.angle())
		visited[next] = true
		Fx.burst(get_tree(), next.global_position, Skills.color("lightning"), 6, 40.0)
		next.take_damage(bolt, source)
		current = next


## 맞힌 적 주변의 다른 적에게 절반 피해 (불씨 폭발)
func _splash(hit: Enemy) -> void:
	if not visual_only and hits_world and team == Team.PLAYER and art_id == "ember":
		Events.combat_effect_requested.emit("passive_ember", hit.global_position, splash_radius / PassiveEffectDB.RADIUS, 0.0)
	for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy != hit and enemy.global_position.distance_to(hit.global_position) <= splash_radius + enemy.radius:
			enemy.take_damage(damage * PassiveDB.EMBER_SPLASH_RATIO, source)
	Fx.burst(get_tree(), hit.global_position, color, 8, splash_radius * 2.0)
	if team == Team.TOWER:
		Events.screen_shake_requested.emit(hit.global_position, 2.5)


func _explode() -> void:
	# 참가자 화면의 예측 탄은 호스트가 확정해 보낸 폭발음과 겹쳐 울리지 않는다.
	if hits_world and not visual_only:
		Events.world_sound_requested.emit("explosion", global_position)
		Events.combat_effect_requested.emit(WeaponArtDB.explosion_effect(art_id), global_position, explode_radius / WeaponArtDB.EXPLOSION_RADIUS, 0.0)
		Events.screen_shake_requested.emit(global_position, 7.0)
	for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.global_position.distance_to(global_position) < explode_radius + enemy.radius:
			if not visual_only:
				enemy.take_damage(damage, source)
	if second_blast:
		# 같은 자리에 잠깐 뒤 터지는 탄을 하나 더 둔다. 호스트·참가자 화면 모두 원래 탄과 같은 규칙으로 만든다
		Projectile.spawn(get_tree(), global_position, {"direction": Vector2.RIGHT, "speed": 0.0, "lifetime": SECOND_BLAST_DELAY,
			"damage": damage * SECOND_BLAST_SCALE, "explode_radius": explode_radius * SECOND_BLAST_SCALE, "source": source,
			"hits_world": hits_world, "visual_only": visual_only, "team": team, "art": art_id, "color": color})
	if not hits_world:
		return
	var world := get_tree().get_first_node_in_group("world") as World
	var center := world.cell_at(global_position)
	var reach := ceili(explode_radius / Balance.TILE)
	for y in range(-reach, reach + 1):
		for x in range(-reach, reach + 1):
			var cell := center + Vector2i(x, y)
			if world.data.get_object(cell) in World.HARVESTABLE and world.cell_center(cell).distance_to(global_position) <= explode_radius:
				world.damage_object(cell, damage, source)


func _show_impact() -> void:
	if hits_world and not visual_only:
		var effect := WeaponArtDB.impact_effect(art_id)
		if emphasis or _boosted_hit:
			effect = "passive_strike"
		elif pierce and art_id == "arrow":
			effect = "passive_shot"
		Events.combat_effect_requested.emit(effect, global_position, 1.0, velocity.angle())
