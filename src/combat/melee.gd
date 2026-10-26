class_name Melee
extends RefCounted
## 근거리 무기 휘두르기. 투사체 없이 즉시 판정한다.
## 조준 방향 부채꼴 안의 적을 모두 때리고, 앞에 있는 나무·바위·광석·상자 하나에 피해를 준다.

const KNOCKBACK := 260.0
const BLAST_KNOCKBACK := 420.0


## weapon: ItemDB의 weapon 항목 (damage, range, arc, knockback — 없으면 KNOCKBACK). "harvest_radius"가 있으면 광역 채집 (D-015).
## "source"(peer id)는 처치·채집 보상을 받을 사람, "hits_world"가 false면 나무·바위는 건드리지 않는다 (멀티플레이 참가자 화면).
## "execute_bonus"·"opener_bonus"는 처형자·선제공격, "harvest_power"는 숙련 채집꾼 패시브 (D-020)
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
		var dealt := enemy.damage_after_execute(weapon["damage"], weapon.get("execute_bonus", 0.0), weapon.get("opener_bonus", 0.0))
		enemy.take_damage(dealt, weapon.get("source", Enemy.SOURCE_LOCAL), weapon.get("emphasis", false) or dealt > weapon["damage"])
		var effect := "passive_strike" if weapon.get("emphasis", false) or dealt > weapon["damage"] else "impact"
		Events.combat_effect_requested.emit(effect, enemy.global_position, 1.0, direction.angle())
		enemy.knockback(offset.normalized() * weapon.get("knockback", KNOCKBACK))
	if not weapon.get("hits_world", true):
		return
	var world := tree.get_first_node_in_group("world") as World
	var cell := world.object_cell_near(origin + direction * reach * 0.6, reach * 0.5)
	if cell != World.NO_CELL:
		var harvest_damage: float = weapon["damage"] * (1.0 + weapon.get("harvest_power", 0.0))
		world.damage_objects_around(cell, harvest_damage, weapon.get("harvest_radius", 0.0), weapon.get("source", Enemy.SOURCE_LOCAL))


## 주변 적 모두에게 피해와 넉백 (함성·내려찍기·서리 고리·화살비·낙뢰 등). source는 처치 보상용 peer id.
## slow_time이 0보다 크면 맞은 적을 slow_factor 배속으로 늦춘다 (0이면 기절·빙결)
static func blast(tree: SceneTree, origin: Vector2, radius: float, damage: float, source := Enemy.SOURCE_LOCAL,
		slow_factor := 1.0, slow_time := 0.0) -> void:
	for enemy: Enemy in tree.get_nodes_in_group("enemies"):
		var offset := enemy.global_position - origin
		if offset.length() < radius:
			enemy.take_damage(damage, source)
			enemy.knockback(offset.normalized() * BLAST_KNOCKBACK)
			if slow_time > 0.0:
				enemy.slow(slow_factor, slow_time)

