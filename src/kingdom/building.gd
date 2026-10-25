class_name Building
extends StaticBody2D
## 플레이어가 지은 건물 (벽, 화살탑, 장비 상자, 제작대). 종류별 수치는 BuildingDB.
## 장비 상자 내용(stored)과 제작대 단계(tier)는 Kingdom의 명령 메서드로만 바꾼다.

signal destroyed(building: Building)

const TOWER_LIGHT_RADIUS := 120.0
const SPRITE_TEXTURE := preload("res://assets/kingdom/buildings.png")
const SPRITE_SIZE := Vector2(32, 64)
const SPRITE_OFFSET := Vector2(-16, -48)

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


## 설치물·설치 미리보기·메뉴에서 같은 원본 칸을 사용한다.
static func sprite_region(id: String, at_tier: int = 0) -> Rect2:
	var info: Dictionary = BuildingDB.TYPES[id]
	var column: int = info["sprite_column"]
	if info.get("workbench", false):
		column += clampi(at_tier, 0, RecipeDB.max_tier())
	return Rect2(Vector2(column * SPRITE_SIZE.x, 0), SPRITE_SIZE)


static func draw_art(canvas: CanvasItem, at: Vector2, id: String, at_tier: int = 0, tint: Color = Color.WHITE) -> void:
	canvas.draw_texture_rect_region(SPRITE_TEXTURE, Rect2(at + SPRITE_OFFSET, SPRITE_SIZE), sprite_region(id, at_tier), tint)


static func icon_texture(id: String) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = SPRITE_TEXTURE
	var region := sprite_region(id)
	var top: float = BuildingDB.TYPES[id]["sprite_top"]
	region.position.y += top
	region.size.y -= top
	texture.region = region
	return texture


func _draw() -> void:
	draw_art(self, Vector2.ZERO, type_id, tier)
	var max_hp: float = info["hp"]
	if hp < max_hp:
		var top: float = info["sprite_top"]
		var bar_y := SPRITE_OFFSET.y + top - HealthBarArt.HEIGHT - 2.0
		HealthBarArt.draw_bar(self, Vector2(-HealthBarArt.WIDTH / 2.0, bar_y), hp / max_hp, HealthBarArt.Tone.GREEN)
