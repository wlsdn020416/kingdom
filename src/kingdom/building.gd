class_name Building
extends StaticBody2D
## 플레이어가 지은 건물 (벽, 화살탑, 장비 상자, 제작대). 종류별 수치는 BuildingDB.
## 장비 상자 내용(stored)과 제작대 단계(tier)는 Kingdom의 명령 메서드로만 바꾼다.

signal destroyed(building: Building)

const TOWER_LIGHT_RADIUS := 120.0

var type_id := ""
var info := {}
var cell := Vector2i.ZERO
var hp := 1.0
var stored: Array[String] = []  # 장비 상자에 맡긴 장비 id
var tier := 0  # 제작대 단계. 부서지면 건물과 함께 사라진다 (D-014)
var _shot_cooldown := 0.0


func setup(id: String, at_cell: Vector2i) -> Building:
	type_id = id
	info = BuildingDB.TYPES[id]
	cell = at_cell
	hp = info["hp"]
	return self


func _ready() -> void:
	collision_layer = PhysicsLayers.BUILDINGS
	collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = Vector2(Balance.TILE, Balance.TILE)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)
	if is_tower():
		Fx.add_light(self, TOWER_LIGHT_RADIUS)
	else:
		set_physics_process(false)


func is_tower() -> bool:
	return info.has("tower")


func is_workbench() -> bool:
	return info.get("workbench", false)


func storage_capacity() -> int:
	return info.get("storage", 0)


func take_damage(amount: float) -> void:
	if hp <= 0.0:
		return
	hp -= amount
	queue_redraw()
	if hp <= 0.0:
		Fx.burst(get_tree(), global_position, info["color"], 10)
		destroyed.emit(self)
		queue_free()


func _physics_process(delta: float) -> void:
	_shot_cooldown -= delta
	if _shot_cooldown > 0.0:
		return
	var tower: Dictionary = info["tower"]
	var target := _nearest_enemy(tower["range"])
	if target == null:
		return
	_shot_cooldown = tower["interval"]
	Projectile.spawn(get_tree(), global_position, {
		"direction": global_position.direction_to(target.global_position), "speed": tower["speed"],
		"damage": tower["damage"], "lifetime": 0.6, "radius": 3.0, "color": Color("b0e0ff"),
		"team": Projectile.Team.TOWER,
	})


func _nearest_enemy(max_range: float) -> Enemy:
	var best: Enemy = null
	var best_distance := max_range
	for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
		var d := global_position.distance_to(enemy.global_position)
		if d < best_distance:
			best_distance = d
			best = enemy
	return best


## 임시 그림. Phase 2에서 스프라이트로 교체.
func _draw() -> void:
	var half := Balance.TILE / 2.0
	var color: Color = info["color"]
	match type_id:
		"wood_wall":
			draw_rect(Rect2(-half + 1, -half + 1, 30, 30), color)
			draw_rect(Rect2(-half + 1, -6, 30, 3), color.darkened(0.25))
			draw_rect(Rect2(-half + 1, 5, 30, 3), color.darkened(0.25))
		"stone_wall":
			draw_rect(Rect2(-half + 1, -half + 1, 30, 30), color)
			draw_rect(Rect2(-half + 1, -1, 30, 2), color.darkened(0.2))
			draw_rect(Rect2(-1, -half + 1, 2, 15), color.darkened(0.2))
		"gear_chest":
			draw_rect(Rect2(-12, -9, 24, 19), color)
			draw_rect(Rect2(-12, -9, 24, 6), color.lightened(0.15))
			draw_rect(Rect2(-12, -3, 24, 2), color.darkened(0.35))
			draw_rect(Rect2(-3, -4, 6, 5), Color("c9c2b0"))
		"workbench":
			draw_rect(Rect2(-13, -8, 26, 7), color.lightened(0.2))
			draw_rect(Rect2(-12, -1, 4, 12), color.darkened(0.3))
			draw_rect(Rect2(8, -1, 4, 12), color.darkened(0.3))
			draw_rect(Rect2(-6, -12, 9, 4), Color("9a9ca0"))
			for i in tier:
				draw_rect(Rect2(-8 + i * 6, 3, 4, 4), Color("e3b341"))
		_:
			draw_rect(Rect2(-half + 3, -half + 3, 26, 26), color)
			draw_rect(Rect2(-5, -5, 10, 10), Color("5b8fd6"))
	var max_hp: float = info["hp"]
	if hp < max_hp:
		HealthBarArt.draw_bar(self, Vector2(-HealthBarArt.WIDTH / 2.0, -half - 12), hp / max_hp, HealthBarArt.Tone.GREEN)
