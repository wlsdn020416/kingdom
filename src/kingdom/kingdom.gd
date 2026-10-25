class_name Kingdom
extends Node2D
## 왕국 운영: 공용 자원(창고), 건물, 장비 상자, 제작대, 핵 수리.
## 비용은 지불하는 플레이어의 개인 인벤토리에서 먼저, 모자라면 공용 창고에서 낸다 (D-014).
## 멀티플레이에서는 호스트의 Kingdom만 명령 메서드로 바뀌고, 참가자는 apply_snapshot()으로 같은 상태를 받는다 (D-017 3단계).

@onready var core: Core = $Core

var world: World
var stock: Dictionary = Balance.START_STOCK.duplicate()
var buildings := {}  # Vector2i -> Building
## 왕국 사람 누구든 한 번이라도 얻어 본 재료. 레시피 공개 조건 (D-014)
var known_materials := {}  # 자원 id -> true


func setup(target_world: World) -> void:
	world = target_world
	core.global_position = world.cell_center(world.data.core_cell)
	for kind: String in stock:
		if stock[kind] > 0:
			known_materials[kind] = true
	queue_redraw()


func core_cell() -> Vector2i:
	return world.data.core_cell


func in_territory(cell: Vector2i) -> bool:
	return Vector2(cell - core_cell()).length() <= Balance.TERRITORY_RADIUS


func is_core_cell(cell: Vector2i) -> bool:
	var offset := cell - core_cell()
	return absi(offset.x) <= 1 and absi(offset.y) <= 1


func is_occupied(cell: Vector2i) -> bool:
	return buildings.has(cell) or is_core_cell(cell)


## payer가 null이면 공용 창고만 본다
func can_afford(cost: Dictionary, payer: Inventory = null) -> bool:
	for kind in cost:
		var held := payer.count(kind) if payer != null else 0
		if held + stock.get(kind, 0) < cost[kind]:
			return false
	return true


func add_resources(amounts: Dictionary) -> void:
	for kind in amounts:
		stock[kind] = stock.get(kind, 0) + amounts[kind]


## 핵 근처에 있으면 개인 자원을 전부 공용 창고로 옮기고 옮긴 양을 돌려준다
func deposit(inventory: Inventory, carrier_position: Vector2) -> Dictionary:
	if inventory.is_empty() or carrier_position.distance_to(core.global_position) > Balance.DEPOSIT_RANGE:
		return {}
	var moved := inventory.amounts()
	inventory.clear()
	add_resources(moved)
	return moved


func _spend(cost: Dictionary, payer: Inventory) -> void:
	for kind in cost:
		var remaining: int = cost[kind]
		if payer != null:
			remaining -= payer.take(kind, remaining)
		stock[kind] -= remaining


## 성공하면 "", 실패하면 이유를 돌려준다.
## perks: 짓는 사람의 건설 패시브(PassiveDB.build_perks). 비용 할인·건설 거리·건물 체력·자가 보수·가시·탑 속도 (D-020)
func build(cell: Vector2i, type_id: String, builder_position: Vector2, payer: Inventory = null, perks := {}) -> String:
	var cost := BuildingDB.discounted(BuildingDB.TYPES[type_id]["cost"], perks.get("discount", 0.0))
	if not in_territory(cell):
		return "왕국 영토(점선 원) 안에만 지을 수 있습니다"
	if world.cell_center(cell).distance_to(builder_position) > Balance.BUILD_REACH + perks.get("reach", 0.0) * Balance.TILE:
		return "너무 멉니다"
	if not world.data.is_walkable(cell) or is_occupied(cell):
		return "그 자리에는 지을 수 없습니다"
	if _someone_standing_on(cell):
		return "누군가 서 있는 자리입니다"
	if BuildingDB.TYPES[type_id].get("unique", false) and _find_type(type_id) != World.NO_CELL:
		return "%s은(는) 하나만 지을 수 있습니다" % BuildingDB.TYPES[type_id]["name"]
	if not can_afford(cost, payer):
		return "자원이 부족합니다 (%s)" % Balance.format_cost(cost)
	_spend(cost, payer)
	var building := Building.new().setup(type_id, cell, perks)
	building.position = world.cell_center(cell)
	building.destroyed.connect(_on_building_destroyed)
	add_child(building)
	buildings[cell] = building
	Events.world_sound_requested.emit("build", building.global_position)
	Events.map_cells_changed.emit([cell])
	return ""


## 철거하면 건설 비용의 절반을 돌려받는다. 성공하면 "", 실패하면 이유를 돌려준다
func demolish(cell: Vector2i) -> String:
	var building: Building = buildings.get(cell)
	if building == null:
		return ""
	if not building.stored.is_empty():
		return "장비 상자를 비운 뒤에 철거할 수 있습니다"
	# 우클릭 실수 한 번으로 올린 단계를 잃지 않게 막는다 (임시)
	if building.tier > 0:
		return "단계를 올린 제작대는 철거할 수 없습니다"
	var cost: Dictionary = building.info["cost"]
	for kind in cost:
		stock[kind] += floori(cost[kind] * BuildingDB.REFUND_RATE)
	buildings.erase(cell)
	building.queue_free()
	Events.world_sound_requested.emit("demolish", world.cell_center(cell))
	Events.map_cells_changed.emit([cell])
	return ""


## actor_position에서 열 수 있는 가장 가까운 장비 상자 칸. 없으면 World.NO_CELL
func find_storage_near(actor_position: Vector2) -> Vector2i:
	return _find_near(actor_position, func(building: Building) -> bool: return building.storage_capacity() > 0)


func find_workbench_near(actor_position: Vector2) -> Vector2i:
	return _find_near(actor_position, func(building: Building) -> bool: return building.is_workbench())


## 제작대 단계. 제작대가 없으면 -1
func workbench_tier() -> int:
	var cell := _find_type("workbench")
	return buildings[cell].tier if cell != World.NO_CELL else -1


## 새로 얻은 재료를 기록하고, 그 덕분에 새로 공개된 레시피 id를 돌려준다
func discover(amounts: Dictionary) -> Array[String]:
	var before := {}
	for id: String in RecipeDB.RECIPES:
		before[id] = RecipeDB.is_revealed(id, known_materials)
	for kind: String in amounts:
		known_materials[kind] = true
	var revealed: Array[String] = []
	for id: String in RecipeDB.RECIPES:
		if not before[id] and RecipeDB.is_revealed(id, known_materials):
			revealed.append(id)
	return revealed


## 성공하면 "", 실패하면 이유를 돌려준다
func upgrade_workbench(actor_position: Vector2, payer: Inventory = null) -> String:
	var cell := find_workbench_near(actor_position)
	if cell == World.NO_CELL:
		return "제작대 근처에서만 할 수 있습니다"
	var building: Building = buildings[cell]
	if building.tier >= RecipeDB.max_tier():
		return "제작대가 이미 최고 단계입니다"
	var cost: Dictionary = RecipeDB.UPGRADES[building.tier]
	if not can_afford(cost, payer):
		return "업그레이드에는 %s 이(가) 필요합니다" % Balance.format_cost(cost)
	_spend(cost, payer)
	building.tier += 1
	Events.world_sound_requested.emit("upgrade", building.global_position)
	building.queue_redraw()
	return ""


## 장비를 만들어 equipment 가방에 넣는다. 성공하면 "", 실패하면 이유를 돌려준다. crafter = 경험치를 받을 peer id
func craft(recipe_id: String, actor_position: Vector2, payer: Inventory, equipment: Equipment, crafter := Enemy.SOURCE_LOCAL) -> String:
	var cell := find_workbench_near(actor_position)
	if cell == World.NO_CELL:
		return "제작대 근처에서만 만들 수 있습니다"
	if not RecipeDB.RECIPES.has(recipe_id) or not RecipeDB.is_revealed(recipe_id, known_materials):
		return "아직 모르는 레시피입니다"
	var recipe: Dictionary = RecipeDB.RECIPES[recipe_id]
	if buildings[cell].tier < recipe["tier"]:
		return "제작대 %d단계가 필요합니다" % recipe["tier"]
	if not can_afford(recipe["cost"], payer):
		return "자원이 부족합니다 (%s)" % Balance.format_cost(recipe["cost"])
	_spend(recipe["cost"], payer)
	equipment.add_to_bag(recipe_id)
	Events.world_sound_requested.emit("craft", world.cell_center(cell))
	Events.item_crafted.emit(recipe_id, crafter)
	return ""


func _find_near(actor_position: Vector2, accepts: Callable) -> Vector2i:
	var best := World.NO_CELL
	var best_distance := Balance.USE_REACH
	for cell: Vector2i in buildings:
		var building: Building = buildings[cell]
		var distance := building.global_position.distance_to(actor_position)
		if accepts.call(building) and distance <= best_distance:
			best = cell
			best_distance = distance
	return best


func _find_type(type_id: String) -> Vector2i:
	for cell: Vector2i in buildings:
		if buildings[cell].type_id == type_id:
			return cell
	return World.NO_CELL


## 가방의 장비를 장비 상자에 맡긴다. 성공하면 "", 실패하면 이유를 돌려준다
func store_item(cell: Vector2i, equipment: Equipment, id: String, actor_position: Vector2) -> String:
	var error := _check_storage(cell, actor_position)
	if error != "":
		return error
	var building: Building = buildings[cell]
	if building.stored.size() >= building.storage_capacity():
		return "장비 상자가 가득 찼습니다"
	if not equipment.remove_from_bag(id):
		return "가방에 없는 장비입니다"
	building.stored.append(id)
	Events.world_sound_requested.emit("deposit", building.global_position)
	return ""


## 장비 상자의 장비를 가방으로 꺼낸다. 성공하면 "", 실패하면 이유를 돌려준다
func take_item(cell: Vector2i, equipment: Equipment, id: String, actor_position: Vector2) -> String:
	var error := _check_storage(cell, actor_position)
	if error != "":
		return error
	var building: Building = buildings[cell]
	if not building.stored.has(id):
		return "상자에 없는 장비입니다"
	building.stored.erase(id)
	Events.world_sound_requested.emit("deposit", building.global_position)
	equipment.add_to_bag(id)
	return ""


func _check_storage(cell: Vector2i, actor_position: Vector2) -> String:
	var building: Building = buildings.get(cell)
	if building == null or building.storage_capacity() == 0:
		return "장비 상자가 없습니다"
	if building.global_position.distance_to(actor_position) > Balance.USE_REACH:
		return "장비 상자에서 너무 멉니다"
	return ""


## 성공하면 "", 실패하면 이유를 돌려준다. bonus: 보수 전문가 패시브 (0.5 = 수리량 +50%)
func repair(repairer_position: Vector2, payer: Inventory = null, bonus := 0.0) -> String:
	if repairer_position.distance_to(core.global_position) > Balance.REPAIR_RANGE:
		return "왕국 핵 근처에서만 수리할 수 있습니다"
	if core.hp >= core.max_hp:
		return "왕국이 멀쩡합니다"
	if not can_afford(Balance.REPAIR_COST, payer):
		return "수리에는 %s 이(가) 필요합니다" % Balance.format_cost(Balance.REPAIR_COST)
	_spend(Balance.REPAIR_COST, payer)
	var amount := Balance.REPAIR_AMOUNT * (1.0 + bonus)
	core.repair(amount)
	Events.world_sound_requested.emit("repair", core.global_position)
	Fx.float_text(get_tree(), core.global_position + Vector2(0, -40), "+%d" % amount, Color("6fcf6f"))
	return ""


## 긴급 요새화 패시브: 모든 건물과 핵을 최대 체력의 ratio만큼 회복한다 (밤이 시작될 때 호스트가 부른다)
func fortify(ratio: float) -> void:
	if ratio <= 0.0:
		return
	for building: Building in buildings.values():
		building.heal(building.max_hp * ratio)
	core.repair(core.max_hp * ratio)


## 참가자에게 보낼 상태. 직렬화할 수 있는 값만 담는다 (AGENTS 5절)
func snapshot() -> Dictionary:
	var list := []
	for cell: Vector2i in buildings:
		var building: Building = buildings[cell]
		list.append([cell, building.type_id, building.hp, building.tier, building.stored.duplicate(), building.max_hp])
	return {"stock": stock.duplicate(), "known": known_materials.duplicate(), "buildings": list}


## 참가자: 호스트의 상태를 그대로 따른다. 건물은 비용 없이 만들거나 없앤다. known은 KingdomSync가 discover()로 반영한다
func apply_snapshot(state: Dictionary) -> void:
	stock = state["stock"]
	var seen := {}
	var changed: Array[Vector2i] = []
	for entry: Array in state["buildings"]:
		var cell: Vector2i = entry[0]
		seen[cell] = true
		var building: Building = buildings.get(cell)
		if building != null and building.type_id != entry[1]:
			buildings.erase(cell)
			building.queue_free()
			building = null
		if building == null:
			building = Building.new().setup(entry[1], cell)
			building.position = world.cell_center(cell)
			add_child(building)
			buildings[cell] = building
			changed.append(cell)
		building.hp = entry[2]
		building.max_hp = entry[5]
		building.tier = entry[3]
		building.stored.assign(entry[4])
		building.queue_redraw()
	for cell: Vector2i in buildings.keys():
		if not seen.has(cell):
			buildings[cell].queue_free()
			buildings.erase(cell)
			changed.append(cell)
	if not changed.is_empty():
		Events.map_cells_changed.emit(changed)


func _someone_standing_on(cell: Vector2i) -> bool:
	var area := Rect2(world.cell_center(cell) - Vector2.ONE * Balance.TILE / 2.0, Vector2.ONE * Balance.TILE).grow(10.0)
	for actor: Node2D in get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("enemies"):
		if area.has_point(actor.global_position):
			return true
	return false


func _on_building_destroyed(building: Building) -> void:
	if not building.stored.is_empty():
		Events.message.emit("장비 상자가 부서져 맡겨 둔 장비 %d개를 잃었습니다" % building.stored.size())
	if building.is_workbench():
		Events.message.emit("제작대가 부서졌습니다. 다시 지으면 0단계부터 시작합니다")
	buildings.erase(building.cell)
	Events.map_cells_changed.emit([building.cell])


## 영토 경계 점선
func _draw() -> void:
	if world == null:
		return
	var radius := (Balance.TERRITORY_RADIUS + 0.5) * Balance.TILE
	var segments := 72
	for i in range(0, segments, 2):
		draw_arc(core.position, radius, TAU * i / segments, TAU * (i + 1) / segments, 4, Palette.TERRITORY, 2.0)
