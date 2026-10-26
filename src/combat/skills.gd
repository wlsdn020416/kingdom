class_name Skills
extends RefCounted
## 장비 액티브 스킬 효과. 수치는 ItemDB의 skill 항목에서 읽는다.
## 새 스킬: ItemDB에 skill.id를 정하고, 아래 match에 효과를 추가하고, COLORS에 색을 넣는다.

const COLORS := {
	"shotgun": Color("e0a040"), "fireball": Color("e5602e"), "bomb": Color("c0c0c0"),
	"shield": Color("5b8fd6"), "dash": Color("7fd0c0"), "heal": Color("6fcf6f"), "rally": Color("d0a0ff"),
	"slam": Color("c8a070"), "dash_slash": Color("b0c8e0"), "counter": Color("e8d070"), "snipe": Color("f0f0d0"),
	"arrow_rain": Color("d8c090"), "blast_bolt": Color("e08040"), "frost_ring": Color("8fd8ff"), "lightning": Color("f0e060"),
}
const BOMB_MAX_RANGE := 8.0 * Balance.TILE
## 조준 지점에 쓰는 스킬(화살비·낙뢰)과 돌진 베기 경로가 닿는 최대 거리. 호스트도 이 거리로 참가자 요청을 검사한다
const MAX_TARGET_RANGE := 7.0 * Balance.TILE
const WAVE_INTERVAL := 0.3  # 화살비·낙뢰가 여러 번 떨어지는 간격
const DASH_SLASH_POINTS := 3  # 돌진 베기 경로를 이 수만큼 나눠 벤다
const DASH_SLASH_RADIUS := 32.0
const SNIPE_SPEED := 1400.0
const BLAST_BOLT_SPEED := 700.0


static func color(skill_id: String) -> Color:
	return COLORS.get(skill_id, Color.WHITE)


static func cast(skill: Dictionary, player: Player) -> void:
	var id: String = skill["id"]
	var weapon := player.equipment.item_in("weapon")
	var art := WeaponArtDB.skill_projectile(weapon, id)
	match id:
		"heal":
			player.heal(skill["amount"])
		"shield":
			player.activate_shield(skill["duration"])
		"shotgun":
			player.show_weapon_effect("scatter_muzzle", player.global_position, 0.5, player.aim_direction.angle())
			var count: int = skill["count"]
			for i in count:
				var angle := (float(i) / (count - 1) - 0.5) * 0.7
				player.fire({"direction": player.aim_direction.rotated(angle), "damage": skill["damage"],
					"speed": 560.0, "lifetime": 0.45, "color": color(id), "art": art, "knockback": skill.get("knockback", 0.0)})
		"fireball":
			player.show_weapon_effect("fire_wave", player.global_position, 0.5, player.aim_direction.angle())
			player.fire({"direction": player.aim_direction, "damage": skill["damage"], "speed": 480.0,
				"lifetime": 1.4, "radius": 9.0, "pierce": true, "color": color(id), "art": art,
				"splash_radius": skill.get("splash_radius", 0.0)})
		"bomb":
			var distance := minf(player.global_position.distance_to(player.get_global_mouse_position()), BOMB_MAX_RANGE)
			player.fire({"direction": player.aim_direction, "damage": skill["damage"], "speed": 420.0,
				"lifetime": distance / 420.0, "radius": 6.0, "explode_radius": skill["radius"], "color": color(id), "art": "bomb"})
		"rally":
			player.blast(skill["radius"], skill["damage"])
			Fx.burst(player.get_tree(), player.global_position, color(id), 30, 300.0)
		# --- 무기 트리 스킬 (우클릭, D-028) ---
		"slam":
			player.show_weapon_effect("slam_wave", player.global_position, skill["radius"] / WeaponArtDB.EXPLOSION_RADIUS)
			var stun: float = skill.get("stun", 0.0)
			player.blast(skill["radius"], skill["damage"], {"slow_factor": 0.0, "slow_time": stun} if stun > 0.0 else {})
			Fx.burst(player.get_tree(), player.global_position, color(id), 24, skill["radius"] * 2.0)
			Events.screen_shake_requested.emit(player.global_position, 5.0)
		"dash_slash":
			var direction := player.aim_direction
			var start := player.global_position
			var distance := minf(skill["distance"], MAX_TARGET_RANGE)
			player.lunge(direction, distance)
			for hit in int(skill.get("hits", 1)):
				_later(player, hit * WAVE_INTERVAL, func() -> void:
					for i in DASH_SLASH_POINTS:
						var point := start + direction * distance * float(i + 1) / DASH_SLASH_POINTS
						player.show_weapon_effect("shadow_cut" if weapon == "shadow_blades" else "dash_cut", point, DASH_SLASH_RADIUS / WeaponArtDB.EXPLOSION_RADIUS, direction.angle())
						player.blast_at(point, DASH_SLASH_RADIUS, skill["damage"])
						Fx.burst(player.get_tree(), point, color(id), 6, 40.0))
		"counter":
			player.activate_counter(skill)
		"snipe":
			player.show_weapon_effect("focused_shot", player.global_position, 0.6, player.aim_direction.angle())
			player.fire({"direction": player.aim_direction, "damage": skill["damage"], "speed": SNIPE_SPEED,
				"lifetime": MAX_TARGET_RANGE * 1.5 / SNIPE_SPEED, "radius": 6.0, "pierce": true,
				"pierce_ramp": skill.get("pierce_ramp", 0.0), "color": color(id), "art": art})
		"arrow_rain", "lightning":
			var target := _target_point(player)
			var count := int(skill.get("waves", skill.get("strikes", 1)))
			for wave in count:
				_later(player, wave * WAVE_INTERVAL, func() -> void:
					player.show_weapon_effect("arrow_rain" if id == "arrow_rain" else "lightning_strike", target, skill["radius"] / WeaponArtDB.EXPLOSION_RADIUS)
					player.blast_at(target, skill["radius"], skill["damage"])
					Fx.burst(player.get_tree(), target, color(id), 14, skill["radius"] * 2.0))
		"blast_bolt":
			player.show_weapon_effect("siege_muzzle", player.global_position, 0.6, player.aim_direction.angle())
			var distance := minf(player.global_position.distance_to(player.get_global_mouse_position()), BOMB_MAX_RANGE)
			player.fire({"direction": player.aim_direction, "damage": skill["damage"], "speed": BLAST_BOLT_SPEED,
				"lifetime": distance / BLAST_BOLT_SPEED, "radius": 6.0, "explode_radius": skill["radius"], "color": color(id),
				"art": art, "second_blast": skill.get("second", false)})
		"frost_ring":
			player.show_weapon_effect("frost_ring", player.global_position, skill["radius"] / WeaponArtDB.EXPLOSION_RADIUS)
			player.blast(skill["radius"], skill["damage"], {"slow_factor": skill["slow"], "slow_time": skill["slow_time"]})
			Fx.burst(player.get_tree(), player.global_position, color(id), 30, skill["radius"] * 2.0)
		_:
			push_warning("알 수 없는 스킬: %s" % id)


## 조준한 곳. 너무 멀면 MAX_TARGET_RANGE까지만
static func _target_point(player: Player) -> Vector2:
	var offset := player.get_global_mouse_position() - player.global_position
	return player.global_position + offset.limit_length(MAX_TARGET_RANGE)


## delay초 뒤에 action을 실행한다. 그사이 플레이어가 사라지거나 쓰러지면 하지 않는다
static func _later(player: Player, delay: float, action: Callable) -> void:
	if delay <= 0.0:
		action.call()
		return
	player.get_tree().create_timer(delay, false).timeout.connect(func() -> void:
		if is_instance_valid(player) and not player.is_dead:
			action.call())
