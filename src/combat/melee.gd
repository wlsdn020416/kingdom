class_name Melee
extends RefCounted
## 근거리 무기 휘두르기. 투사체 없이 즉시 판정한다.
## 조준 방향 부채꼴 안의 적을 모두 때리고, 앞에 있는 나무·바위·광석·상자 하나에 피해를 준다.

const KNOCKBACK := 260.0


## weapon: ItemDB의 weapon 항목 (damage, range, arc). "harvest_radius"가 있으면 광역 채집 (D-015)
static func swing(tree: SceneTree, origin: Vector2, direction: Vector2, weapon: Dictionary) -> void:
	var reach: float = weapon["range"]
	var half_arc := deg_to_rad(weapon["arc"]) / 2.0
	for enemy: Enemy in tree.get_nodes_in_group("enemies"):
		var offset := enemy.global_position - origin
		if offset.length() > reach + enemy.radius:
			continue
		# 몸이 겹칠 만큼 붙은 적은 방향과 상관없이 맞는다
		if offset.length() > enemy.radius and absf(direction.angle_to(offset)) > half_arc:
			continue
		enemy.take_damage(weapon["damage"])
		enemy.knockback(offset.normalized() * KNOCKBACK)
	var world := tree.get_first_node_in_group("world") as World
	var cell := world.object_cell_near(origin + direction * reach * 0.6, reach * 0.5)
	if cell != World.NO_CELL:
		world.damage_objects_around(cell, weapon["damage"], weapon.get("harvest_radius", 0.0))
