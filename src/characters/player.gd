class_name Player
extends CharacterBody2D
## 트윈스틱 조작 캐릭터. 이동(WASD)과 조준(마우스)은 서로 독립적이다.
## 대시(Space)는 모든 캐릭터의 기본 능력이고, 1~4 키는 장비에 달린 스킬을 쓴다.

## 적에게 닿는 공격을 할 때마다 알린다. 멀티플레이 참가자는 이걸 호스트에 보내 호스트의 적에게 다시 실행한다 (D-017).
## kind: "projectile"(Projectile 인자), "swing"(origin, direction, weapon), "blast"(origin, radius, damage)
signal attacked(kind: String, data: Dictionary)
## 이 캐릭터가 실제로 한 행동의 연출음. 판정·게임용 난수와 무관하며 다른 사람에게도 공유한다.
signal sound_requested(id: String, at: Vector2)
## 순수 공격 연출. PlayerSync가 다른 사람에게 같은 모션을 보여준다.
signal attack_visual_requested(id: String, direction: Vector2)

const DASH_SPEED := 950.0
const DASH_TIME := 0.18
const LIGHT_RADIUS := 230.0
## 가로 한 줄 시트: 정면 4칸, 뒷면 4칸, 오른쪽 측면 4칸(왼쪽은 좌우 반전). 각 방향 0·2번 칸이 서 있는 자세.
const SPRITE_SHEET := preload("res://assets/characters/player.png")
const SPRITE_FRAMES_PER_DIR := 4
const WALK_FPS := 8.0
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
## 멀티플레이 참가자는 Main이 끈다. 나무·바위·상자는 호스트가 attacked를 다시 실행해서 바꾼다 (D-017 3단계)
var hits_world := true

var _fire_cooldown := 0.0
var _invuln_time := 0.0
var _shield_time := 0.0
var _dash_time := 0.0
var _dash_velocity := Vector2.ZERO
var _dash_cooldown := 0.0
var _combo_count := 0  # 마무리 일격 패시브: 지난 2배 피해 뒤 기본 공격 횟수
var _whirl_count := 0  # 회오리 베기 패시브: 지난 회전 베기 뒤 휘두른 횟수
## 왕국 영토 안에 있는지 (성벽의 가호 패시브). Player는 Kingdom을 모르므로 Main이 매 프레임 알려 준다
var in_territory := false
var _since_hit := 0.0  # 재생 패시브: 마지막으로 맞은 뒤 지난 시간
var _last_stand_cooldown := 0.0
var _respawn_time := 0.0
var _shake := 0.0
var _sprite := Sprite2D.new()
var _walk_time := 0.0
var weapon_visual := WeaponVisual.new()
var equipment_visual := EquipmentVisual.new()


func _ready() -> void:
	hp = max_hp()
	_sprite.texture = SPRITE_SHEET
	_sprite.hframes = SPRITE_FRAMES_PER_DIR * 3
	# 발이 충돌 원 중심보다 조금 아래에 오도록 올린다
	_sprite.position = Vector2(0, -4)
	add_child(weapon_visual)
	weapon_visual.setup(_sprite)
	add_child(_sprite)
	_sprite.add_child(equipment_visual)
	equipment_visual.setup(_sprite)
	equipment_visual.set_items(equipment.equipped)
	equipment.changed.connect(func() -> void: equipment_visual.set_items(equipment.equipped))
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
	_last_stand_cooldown -= delta
	_regenerate(delta)
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
	weapon_visual.set_weapon(equipment.item_in("weapon"))
	weapon_visual.aim_direction = aim_direction
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
		Events.ui_sound_requested.emit("error")
		return
	var skill: Dictionary = ItemDB.ITEMS[bar[slot]]["skill"].duplicate()
	if skill.has("damage"):
		skill["damage"] *= 1.0 + progression.value("skill_power") / 100.0
	if skill.has("amount"):
		skill["amount"] *= 1.0 + progression.value("field_medic") / 100.0
	Skills.cast(skill, self)
	equipment.start_cooldown(bar[slot], 1.0 - progression.value("tactician") / 100.0)
	var id: String = ItemDB.ITEMS[bar[slot]]["skill"]["id"]
	if id in ["shotgun", "fireball", "bomb"]:
		_show_attack(bar[slot])
	# 폭탄은 던질 때가 아니라 실제 폭발했을 때 월드에서 울린다.
	if id != "bomb":
		sound_requested.emit(id, global_position)


func max_hp() -> float:
	return equipment.max_hp() + progression.value("vitality")


func fire(params: Dictionary) -> void:
	if not params.has("art"):
		params["art"] = WeaponArtDB.BASIC_PROJECTILES.get(equipment.item_in("weapon"), "arrow")
	params["harvest_radius"] = progression.value("wide_harvest")
	params["hits_world"] = hits_world
	var direction: Vector2 = params["direction"]
	var at := global_position + direction * 14.0
	Projectile.spawn(get_tree(), at, params)
	attacked.emit("projectile", {"at": at, "params": params})


## 주변 적 모두에게 피해 (함성)
func blast(radius: float, damage: float) -> void:
	Melee.blast(get_tree(), global_position, radius, damage)
	attacked.emit("blast", {"origin": global_position, "radius": radius, "damage": damage})


func dash() -> void:
	if _dash_cooldown > 0.0:
		Events.ui_sound_requested.emit("error")
		return
	_dash_cooldown = Balance.DASH_COOLDOWN * (1.0 - progression.value("windstep") / 100.0)
	var direction := _move_input()
	if direction == Vector2.ZERO:
		direction = aim_direction
	_dash_velocity = direction.normalized() * DASH_SPEED * (1.0 + progression.value("sprint_dash") / 100.0)
	_dash_time = DASH_TIME
	var afterimage := progression.value("evasive_dash")
	if afterimage > 0.0:
		_invuln_time = maxf(_invuln_time, DASH_TIME + afterimage)
	sound_requested.emit("dash", global_position)


func dash_cooldown_left() -> float:
	return maxf(0.0, _dash_cooldown)


## 모닥불처럼 조금씩 차오르는 회복 (떠오르는 글자 없음)
func restore(amount: float) -> void:
	if not is_dead:
		hp = minf(max_hp(), hp + amount)


## 순간이동 탑(D-022). 이동은 각자 정하므로 내 캐릭터를 바로 옮긴다 (D-017)
func teleport_to(at: Vector2) -> void:
	global_position = at
	velocity = Vector2.ZERO
	_dash_time = 0.0
	Fx.burst(get_tree(), at, Color("a070ff"), 18, 160.0)


func heal(amount: float) -> void:
	hp = minf(max_hp(), hp + amount)
	Fx.float_text(get_tree(), global_position, "+%d" % amount, Color("6fcf6f"))


func activate_shield(duration: float) -> void:
	_shield_time = duration


func take_damage(amount: float) -> void:
	if is_dead or _invuln_time > 0.0 or _shield_time > 0.0 or _dash_time > 0.0:
		return
	_since_hit = 0.0
	var reduction := progression.value("iron_skin") + (progression.value("bulwark_aura") if in_territory else 0.0)
	amount *= maxf(0.1, 1.0 - reduction / 100.0)
	var last_stand := progression.value("last_stand")
	if hp - amount <= 0.0 and last_stand > 0.0 and _last_stand_cooldown <= 0.0:
		# 최후의 저항: 쓰러질 피해를 한 번 버틴다
		hp = 1.0
		_invuln_time = PassiveDB.LAST_STAND_INVULN
		_last_stand_cooldown = last_stand
		Fx.float_text(get_tree(), global_position, "최후의 저항!", Color("ffd060"))
		return
	hp -= amount
	_invuln_time = Balance.PLAYER_HIT_INVULN
	_shake = 6.0
	Fx.float_text(get_tree(), global_position, "-%d" % amount, Color("ff7060"))
	if hp <= 0.0:
		_die()
	else:
		sound_requested.emit("player_hurt", global_position)


func _die() -> void:
	is_dead = true
	sound_requested.emit("player_death", global_position)
	inventory.clear()
	equipment.lose_bag()
	progression.lose_unspent()
	_respawn_time = Balance.RESPAWN_TIME * (1.0 - progression.value("quick_return") / 100.0)
	collision_layer = 0
	Fx.burst(get_tree(), global_position, Color("ff7060"), 20)
	_sprite.visible = false
	weapon_visual.hide()
	Events.player_died.emit()
	Events.message.emit("쓰러졌습니다. 들고 있던 자원, 가방 장비, 쓰지 않은 경험치를 모두 잃었습니다. %d초 뒤 왕국에서 부활합니다" % ceili(_respawn_time))
	queue_redraw()


func _respawn() -> void:
	is_dead = false
	hp = max_hp()
	global_position = spawn_point
	collision_layer = PhysicsLayers.PLAYER
	_invuln_time = Balance.RESPAWN_INVULN
	_sprite.visible = true
	weapon_visual.show()


## 다른 사람 화면에 보낼 겉모습 (멀티플레이 동기화용)
func appearance() -> Dictionary:
	return {"frame": _sprite.frame, "flip": _sprite.flip_h, "shown": _sprite.visible and not is_dead, "weapon": equipment.item_in("weapon"), "gear": equipment.equipped.duplicate()}


## 폭발·보스 같은 화면 흔들림 (D-023). 더 센 흔들림이 이긴다
func add_shake(strength: float) -> void:
	_shake = maxf(_shake, strength)


func respawn_time_left() -> float:
	return _respawn_time


func _fire_weapon() -> void:
	var weapon := _boosted_weapon()
	weapon["harvest_radius"] = progression.value("wide_harvest")
	weapon["hits_world"] = hits_world
	_show_attack(equipment.item_in("weapon"))
	_fire_cooldown = 1.0 / float(weapon["rate"])
	sound_requested.emit(SoundDB.weapon(equipment.item_in("weapon")), global_position)
	if weapon.get("melee", false):
		Melee.swing(get_tree(), global_position, aim_direction, weapon)
		attacked.emit("swing", {"origin": global_position, "direction": aim_direction, "weapon": weapon})
		return
	var shots: int = weapon.get("shots", 1)
	var spread: float = deg_to_rad(weapon.get("spread", 0.0))
	var aim := aim_direction.rotated(randf_range(-0.03, 0.03))
	for i in shots:
		var turn := 0.0 if shots == 1 else (float(i) / (shots - 1) - 0.5) * spread * (shots - 1)
		fire({"direction": aim.rotated(turn), "damage": weapon["damage"], "speed": weapon["speed"],
			"lifetime": weapon.get("lifetime", 0.9), "pierce": weapon.get("pierce", false),
			"splash_radius": weapon.get("splash_radius", 0.0), "execute_bonus": weapon["execute_bonus"],
			"opener_bonus": weapon["opener_bonus"], "harvest_power": weapon["harvest_power"], "emphasis": weapon.get("emphasis", false)})


## 장착한 무기에 전투 패시브를 더한 기본 공격 값 (D-020). 부를 때마다 마무리 일격 횟수를 센다
func _boosted_weapon() -> Dictionary:
	var weapon := equipment.weapon().duplicate()
	var family: String = weapon.get("family", "")
	var mastery: String = PassiveDB.FAMILY_MASTERY.get(family, "")
	var bonus := progression.value("keen_edge") + (progression.value(mastery) if mastery != "" else 0.0)
	if hp <= max_hp() * PassiveDB.BERSERK_HP_RATIO:
		bonus += progression.value("berserker")
	weapon["damage"] *= 1.0 + bonus / 100.0
	match family:
		"sword":
			weapon["arc"] += progression.value("sword_sweep")
			weapon["range"] *= 1.0 + progression.value("blade_reach") / 100.0
			var whirl := int(progression.value("whirlwind"))
			if whirl > 0:
				_whirl_count += 1
				if _whirl_count >= whirl:
					_whirl_count = 0
					weapon["arc"] = 360.0
					weapon["emphasis"] = true
		"bow":
			weapon["pierce"] = progression.value("piercing_arrows") > 0.0
			weapon["shots"] = maxi(1, int(progression.value("multishot")))
			weapon["spread"] = PassiveDB.MULTISHOT_SPREAD
		"crossbow":
			weapon["rate"] *= 1.0 + progression.value("rapid_reload") / 100.0
			weapon["shots"] = maxi(1, int(progression.value("twin_bolts")))
			weapon["spread"] = PassiveDB.TWIN_SPREAD
		"staff":
			weapon["splash_radius"] = progression.value("ember_burst")
			var charge := 1.0 + progression.value("overcharge") / 100.0
			weapon["speed"] *= charge
			weapon["lifetime"] = 0.9 * charge
	var finisher := int(progression.value("combo_finisher"))
	if finisher > 0:
		_combo_count += 1
		if _combo_count >= finisher:
			_combo_count = 0
			weapon["damage"] *= PassiveDB.COMBO_MULTIPLIER
			weapon["emphasis"] = true
	weapon["execute_bonus"] = progression.value("executioner") / 100.0
	weapon["opener_bonus"] = progression.value("first_strike") / 100.0
	weapon["harvest_power"] = progression.value("prospector") / 100.0
	return weapon


## 재생 패시브: 한동안 맞지 않으면 체력이 차오른다
func _regenerate(delta: float) -> void:
	_since_hit += delta
	var per_second := progression.value("regeneration")
	if per_second > 0.0 and _since_hit >= PassiveDB.REGEN_DELAY and hp < max_hp():
		hp = minf(max_hp(), hp + per_second * delta)


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


## 몸·무기는 자식 노드가 그리고 보호막은 기존 표시를 유지한다.
func _draw() -> void:
	if not is_dead and _shield_time > 0.0:
		draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 24, Skills.color("shield"), 2.0)


func _show_attack(id: String) -> void:
	weapon_visual.attack(id, aim_direction, progression.value("sword_sweep"))
	attack_visual_requested.emit(id, aim_direction)
