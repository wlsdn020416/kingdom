class_name Skills
extends RefCounted
## 장비 액티브 스킬 효과. 수치는 ItemDB의 skill 항목에서 읽는다.
## 새 스킬: ItemDB에 skill.id를 정하고, 아래 match에 효과를 추가하고, COLORS에 색을 넣는다.

const COLORS := {
	"shotgun": Color("e0a040"), "fireball": Color("e5602e"), "bomb": Color("c0c0c0"),
	"shield": Color("5b8fd6"), "dash": Color("7fd0c0"), "heal": Color("6fcf6f"), "rally": Color("d0a0ff"),
}
const BOMB_MAX_RANGE := 8.0 * Balance.TILE


static func color(skill_id: String) -> Color:
	return COLORS.get(skill_id, Color.WHITE)


static func cast(skill: Dictionary, player: Player) -> void:
	var id: String = skill["id"]
	match id:
		"heal":
			player.heal(skill["amount"])
		"shield":
			player.activate_shield(skill["duration"])
		"shotgun":
			var count: int = skill["count"]
			for i in count:
				var angle := (float(i) / (count - 1) - 0.5) * 0.7
				player.fire({"direction": player.aim_direction.rotated(angle), "damage": skill["damage"],
					"speed": 560.0, "lifetime": 0.45, "color": color(id), "art": "bolt"})
		"fireball":
			player.fire({"direction": player.aim_direction, "damage": skill["damage"], "speed": 480.0,
				"lifetime": 1.4, "radius": 9.0, "pierce": true, "color": color(id), "art": "fireball"})
		"bomb":
			var distance := minf(player.global_position.distance_to(player.get_global_mouse_position()), BOMB_MAX_RANGE)
			player.fire({"direction": player.aim_direction, "damage": skill["damage"], "speed": 420.0,
				"lifetime": distance / 420.0, "radius": 6.0, "explode_radius": skill["radius"], "color": color(id), "art": "bomb"})
		"rally":
			player.blast(skill["radius"], skill["damage"])
			Fx.burst(player.get_tree(), player.global_position, color(id), 30, 300.0)
		_:
			push_warning("알 수 없는 스킬: %s" % id)
