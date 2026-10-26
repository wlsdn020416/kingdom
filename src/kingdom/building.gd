class_name Building
extends StaticBody2D
## 플레이어가 지은 건물 (벽, 문, 화살탑, 장비 상자, 제작대). 종류별 수치는 BuildingDB.
## 장비 상자 내용(stored)과 제작대 단계(tier)는 Kingdom의 명령 메서드로만 바꾼다.
## 지은 사람의 건설 패시브(perks, D-020)가 체력·자가 보수·가시·탑 공격 속도를 정한다.

signal destroyed(building: Building)

const TOWER_LIGHT_RADIUS := 120.0
const LIGHT_RADIUS_SCALE := 0.65
const LIGHT_ENERGY_SCALE := 0.3
const SIEGE_ART_SCALE := 0.7
const UTILITY_ART_SCALE := 0.55
const SPRITE_TEXTURE := preload("res://assets/kingdom/buildings_expanded.png")
const SPRITE_SIZE := Vector2(64, 96)
const SPRITE_OFFSET := Vector2(-32, -80)
const ART_FRAME_SECONDS := 0.16
const ART_FRAMES := 4
const ANIMATED_ART := ["essence_wall", "frost_tower", "flame_tower", "thunder_tower", "teleport_tower", "campfire", "workbench"]

var type_id := ""
var info := {}
var cell := Vector2i.ZERO
var hp := 1.0
var max_hp := 1.0
var regen := 0.0  # 자가 보수: 초당 회복량
var thorns := 0.0  # 가시 벽: 때린 적에게 돌려주는 피해 비율
var tower_rate := 1.0  # 탑 훈련: 화살탑 공격 속도 배수
var tower_range := 1.0  # 매의 눈: 사거리 배수
var tower_damage := 1.0  # 강화 화살촉: 피해 배수
var tower_shots := 1  # 쌍궁 탑: 한 번에 쏘는 화살 수
var stored: Array[String] = []  # 장비 상자에 맡긴 장비 id
var tier := 0  # 제작대 단계. 부서지면 건물과 함께 사라진다 (D-014)
var _shot_cooldown := 0.0
var _art_time := 0.0
var _art_frame := 0
var _passive_fx_delay := 0.0


## perks: PassiveDB.build_perks() 결과. 비어 있으면 패시브 없음 (참가자 화면의 건물도 비운 채로 만든다)
func setup(id: String, at_cell: Vector2i, perks := {}) -> Building:
	type_id = id
	info = BuildingDB.TYPES[id]
	cell = at_cell
	max_hp = info["hp"] * perks.get("hp_scale", 1.0)
	hp = max_hp
	# 건물 자체 수치(정수 방벽·가시 목책)에 지은 사람의 패시브가 더해진다
	regen = info.get("regen", 0.0) + perks.get("regen", 0.0)
	thorns = info.get("thorns", 0.0) + perks.get("thorns", 0.0)
	tower_rate = perks.get("tower_rate", 1.0)
	tower_range = perks.get("tower_range", 1.0)
	tower_damage = perks.get("tower_damage", 1.0)
	tower_shots = perks.get("tower_shots", 1)
	return self


func _ready() -> void:
	collision_layer = PhysicsLayers.PASSABLE if BuildingDB.player_passable(type_id) else PhysicsLayers.BUILDINGS
	collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = Vector2(Balance.TILE, Balance.TILE)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)
	if info.has("light") or is_tower():
		Fx.add_light(self, info.get("light", TOWER_LIGHT_RADIUS) * LIGHT_RADIUS_SCALE, LIGHT_ENERGY_SCALE)
	set_physics_process(is_tower() or regen > 0.0)
	set_process(type_id in ANIMATED_ART)


func _process(delta: float) -> void:
	_art_time += delta
	var frame := int(_art_time / ART_FRAME_SECONDS) % ART_FRAMES
	if frame != _art_frame:
		_art_frame = frame
		queue_redraw()


func is_tower() -> bool:
	return info.has("tower")


func is_workbench() -> bool:
	return info.get("workbench", false)


func storage_capacity() -> int:
	return info.get("storage", 0)


## attacker: 때린 적 (가시 벽이 피해를 돌려준다). 탄·폭발처럼 모르면 null
func take_damage(amount: float, attacker: Enemy = null) -> void:
	if hp <= 0.0:
		return
	if thorns > 0.0 and attacker != null and is_instance_valid(attacker):
		attacker.take_damage(amount * thorns, Enemy.SOURCE_TOWER)
		Events.combat_effect_requested.emit("passive_thorns", attacker.global_position, 0.55, 0.0)
	hp -= amount
	Events.world_sound_requested.emit("demolish" if hp <= 0.0 else "hit_armor", global_position)
	queue_redraw()
	if hp <= 0.0:
		Fx.burst(get_tree(), global_position, info["color"], 10)
		destroyed.emit(self)
		queue_free()


func _physics_process(delta: float) -> void:
	_passive_fx_delay = maxf(0.0, _passive_fx_delay - delta)
	if regen > 0.0 and hp < max_hp:
		heal(regen * delta)
		if _passive_fx_delay <= 0.0:
			_passive_fx_delay = 1.0
			Events.combat_effect_requested.emit("passive_fortify", global_position, 0.55, 0.0)
	if not is_tower():
		return
	_shot_cooldown -= delta
	if _shot_cooldown > 0.0:
		return
	var tower: Dictionary = info["tower"]
	var target := _nearest_enemy(tower["range"] * tower_range)
	if target == null:
		return
	_shot_cooldown = tower["interval"] / tower_rate
	var aim := global_position.direction_to(target.global_position)
	# 탑 자체의 발 수(번개탑)에 쌍궁 탑 패시브가 더해진다
	var shots: int = tower.get("shots", 1) + tower_shots - 1
	var spread := deg_to_rad(tower.get("spread", PassiveDB.TWIN_SPREAD))
	var slow: Array = tower.get("slow", [1.0, 0.0])
	for i in shots:
		var turn := 0.0 if shots == 1 else (float(i) / (shots - 1) - 0.5) * spread
		Projectile.spawn(get_tree(), global_position, {
			"direction": aim.rotated(turn), "speed": tower["speed"],
			"damage": tower["damage"] * tower_damage, "lifetime": tower.get("lifetime", 0.6) * tower_range, "radius": 3.0,
			"color": info["color"].lightened(0.3), "team": Projectile.Team.TOWER, "pierce": tower.get("pierce", false),
			"splash_radius": tower.get("splash", 0.0), "slow_factor": slow[0], "slow_time": slow[1],
		})


func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)
	queue_redraw()


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
static func sprite_region(id: String, at_tier: int = 0, frame: int = 0) -> Rect2:
	var info: Dictionary = BuildingDB.TYPES[id]
	var column: int = info["sprite_column"]
	if info.get("workbench", false):
		column += clampi(at_tier, 0, RecipeDB.max_tier())
	return Rect2(Vector2(column * SPRITE_SIZE.x, posmod(frame, ART_FRAMES) * SPRITE_SIZE.y), SPRITE_SIZE)


## 재료·장치별 고유 외형을 실제 설치물과 미리보기에서 공유한다.
static func draw_art(canvas: CanvasItem, at: Vector2, id: String, at_tier: int = 0, tint: Color = Color.WHITE, frame: int = 0) -> void:
	var scale := art_scale(id)
	canvas.draw_texture_rect_region(SPRITE_TEXTURE, Rect2(at + SPRITE_OFFSET * scale, SPRITE_SIZE * scale), sprite_region(id, at_tier, frame), tint)


## 접지 기준점을 유지하며 설치물과 설치 미리보기의 그림만 줄인다.
static func art_scale(id: String) -> float:
	match BuildingDB.TYPES[id]["category"]:
		"siege": return SIEGE_ART_SCALE
		"utility": return UTILITY_ART_SCALE
	return 1.0


static func sprite_top(id: String, at_tier: int = 0) -> float:
	var data: Dictionary = BuildingDB.TYPES[id]
	if data.has("sprite_tops"):
		var tops: Array = data["sprite_tops"]
		return tops[clampi(at_tier, 0, tops.size() - 1)]
	return data["sprite_top"]


static func icon_texture(id: String) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = SPRITE_TEXTURE
	var region := sprite_region(id)
	var top := sprite_top(id)
	region.position.y += top
	region.size.y -= top
	texture.region = region
	return texture


func _draw() -> void:
	draw_art(self, Vector2.ZERO, type_id, tier, Color.WHITE, _art_frame)
	if hp < max_hp:
		var top := sprite_top(type_id, tier)
		var bar_y := (SPRITE_OFFSET.y + top) * art_scale(type_id) - HealthBarArt.HEIGHT - 2.0
		HealthBarArt.draw_bar(self, Vector2(-HealthBarArt.WIDTH / 2.0, bar_y), hp / max_hp, HealthBarArt.Tone.GREEN)
