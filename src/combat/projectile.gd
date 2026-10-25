class_name Projectile
extends Node2D
## 모든 투사체. team에 따라 무엇에 맞는지(충돌 마스크)가 정해진다.
## explode_radius가 0보다 크면 폭탄: 아무것도 맞지 않고 날아가다 수명이 끝나면 폭발한다.
## Area2D 겹침 신호는 정적 바디(타일·벽·핵)를 감지하지 못해서, 매 물리 프레임 직접 충돌을 조회한다.

enum Team { PLAYER, ENEMY, TOWER }

const MASKS := {
	Team.PLAYER: PhysicsLayers.OBJECTS | PhysicsLayers.ENEMIES,
	Team.TOWER: PhysicsLayers.ENEMIES,
	Team.ENEMY: PhysicsLayers.OBJECTS | PhysicsLayers.BUILDINGS | PhysicsLayers.PLAYER,
}
const MAX_HITS_PER_STEP := 8

var team := Team.PLAYER
var velocity := Vector2.ZERO
var damage := 10.0
var lifetime := 1.0
var radius := 4.0
var pierce := false
var explode_radius := 0.0
var color := Color("fff4c0")
var _already_hit := {}
var _query := PhysicsShapeQueryParameters2D.new()


## params: direction(필수), speed, damage, lifetime, radius, pierce, explode_radius, color, team
static func spawn(tree: SceneTree, at: Vector2, params: Dictionary) -> Projectile:
	var projectile := Projectile.new()
	projectile.team = params.get("team", Team.PLAYER)
	projectile.velocity = params["direction"] * params.get("speed", 600.0)
	projectile.damage = params.get("damage", 10.0)
	projectile.lifetime = params.get("lifetime", 0.9)
	projectile.radius = params.get("radius", 4.0)
	projectile.pierce = params.get("pierce", false)
	projectile.explode_radius = params.get("explode_radius", 0.0)
	projectile.color = params.get("color", projectile.color)
	projectile.position = at
	# 물리 콜백 도중에 불려도 안전하도록 다음 틈에 추가
	tree.get_first_node_in_group("projectiles").add_child.call_deferred(projectile)
	return projectile


func _ready() -> void:
	var shape := CircleShape2D.new()
	shape.radius = radius
	_query.shape = shape
	_query.collision_mask = MASKS[team]


func _physics_process(delta: float) -> void:
	position += velocity * delta
	lifetime -= delta
	if explode_radius > 0.0:
		if lifetime <= 0.0:
			_explode()
			queue_free()
		return
	_check_hits()
	if lifetime <= 0.0:
		queue_free()


func _draw() -> void:
	draw_rect(Rect2(-radius, -radius, radius * 2.0, radius * 2.0), color)


func _check_hits() -> void:
	_query.transform = Transform2D(0.0, global_position)
	for hit in get_world_2d().direct_space_state.intersect_shape(_query, MAX_HITS_PER_STEP):
		if is_queued_for_deletion():
			return
		_on_hit(hit["collider"])


func _on_hit(body: Object) -> void:
	if body is TileMapLayer:
		var world := (body as TileMapLayer).get_parent() as World
		var cell := world.object_cell_near(global_position, radius)
		if cell != World.NO_CELL:
			world.damage_object(cell, damage, team != Team.ENEMY)
		queue_free()
		return
	if _already_hit.has(body):
		return
	_already_hit[body] = true
	if body.has_method("take_damage"):
		body.take_damage(damage)
	Fx.burst(get_tree(), global_position, color, 3, 80.0)
	if not pierce:
		queue_free()


func _explode() -> void:
	for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.global_position.distance_to(global_position) < explode_radius + enemy.radius:
			enemy.take_damage(damage)
	var world := get_tree().get_first_node_in_group("world") as World
	var center := world.cell_at(global_position)
	var reach := ceili(explode_radius / Balance.TILE)
	for y in range(-reach, reach + 1):
		for x in range(-reach, reach + 1):
			var cell := center + Vector2i(x, y)
			if world.data.get_object(cell) in World.HARVESTABLE and world.cell_center(cell).distance_to(global_position) <= explode_radius:
				world.damage_object(cell, damage, true)
	Fx.burst(get_tree(), global_position, Color("ffb050"), 40, 260.0)
