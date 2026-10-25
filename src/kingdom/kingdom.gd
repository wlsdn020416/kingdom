class_name Kingdom
extends Node2D
## 왕국 운영: 공용 자원(창고), 건물, 핵 수리.
## 비용은 지불하는 플레이어의 개인 인벤토리에서 먼저, 모자라면 공용 창고에서 낸다 (D-014).
## 멀티플레이를 붙이면 이 상태(stock, buildings, core.hp)를 호스트가 소유하고 동기화한다.

@onready var core: Core = $Core

var world: World
var stock: Dictionary = Balance.START_STOCK.duplicate()
var buildings := {}  # Vector2i -> Building


func setup(target_world: World) -> void:
	world = target_world
	core.global_position = world.cell_center(world.data.core_cell)
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


## 성공하면 "", 실패하면 이유를 돌려준다
func build(cell: Vector2i, type_id: String, builder_position: Vector2, payer: Inventory = null) -> String:
	var cost: Dictionary = BuildingDB.TYPES[type_id]["cost"]
	if not in_territory(cell):
		return "왕국 영토(점선 원) 안에만 지을 수 있습니다"
	if world.cell_center(cell).distance_to(builder_position) > Balance.BUILD_REACH:
		return "너무 멉니다"
	if not world.data.is_walkable(cell) or is_occupied(cell):
		return "그 자리에는 지을 수 없습니다"
	if _someone_standing_on(cell):
		return "누군가 서 있는 자리입니다"
	if not can_afford(cost, payer):
		return "자원이 부족합니다 (%s)" % Balance.format_cost(cost)
	_spend(cost, payer)
	var building := Building.new().setup(type_id, cell)
	building.position = world.cell_center(cell)
	building.destroyed.connect(_on_building_destroyed)
	add_child(building)
	buildings[cell] = building
	Events.map_cells_changed.emit([cell])
	return ""


## 철거하면 건설 비용의 절반을 돌려받는다. 성공하면 "", 실패하면 이유를 돌려준다
func demolish(cell: Vector2i) -> String:
	var building: Building = buildings.get(cell)
	if building == null:
		return ""
	if not building.stored.is_empty():
		return "장비 상자를 비운 뒤에 철거할 수 있습니다"
	var cost: Dictionary = building.info["cost"]
	for kind in cost:
		stock[kind] += floori(cost[kind] * BuildingDB.REFUND_RATE)
	buildings.erase(cell)
	building.queue_free()
	Events.map_cells_changed.emit([cell])
	return ""


## actor_position에서 열 수 있는 가장 가까운 장비 상자 칸. 없으면 World.NO_CELL
func find_storage_near(actor_position: Vector2) -> Vector2i:
	var best := World.NO_CELL
	var best_distance := Balance.STORAGE_REACH
	for cell: Vector2i in buildings:
		var building: Building = buildings[cell]
		var distance := building.global_position.distance_to(actor_position)
		if building.storage_capacity() > 0 and distance <= best_distance:
			best = cell
			best_distance = distance
	return best


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
	equipment.add_to_bag(id)
	return ""


func _check_storage(cell: Vector2i, actor_position: Vector2) -> String:
	var building: Building = buildings.get(cell)
	if building == null or building.storage_capacity() == 0:
		return "장비 상자가 없습니다"
	if building.global_position.distance_to(actor_position) > Balance.STORAGE_REACH:
		return "장비 상자에서 너무 멉니다"
	return ""


## 성공하면 "", 실패하면 이유를 돌려준다
func repair(repairer_position: Vector2, payer: Inventory = null) -> String:
	if repairer_position.distance_to(core.global_position) > Balance.REPAIR_RANGE:
		return "왕국 핵 근처에서만 수리할 수 있습니다"
	if core.hp >= core.max_hp:
		return "왕국이 멀쩡합니다"
	if not can_afford(Balance.REPAIR_COST, payer):
		return "수리에는 %s 이(가) 필요합니다" % Balance.format_cost(Balance.REPAIR_COST)
	_spend(Balance.REPAIR_COST, payer)
	core.repair(Balance.REPAIR_AMOUNT)
	Fx.float_text(get_tree(), core.global_position + Vector2(0, -40), "+%d" % Balance.REPAIR_AMOUNT, Color("6fcf6f"))
	return ""


func _someone_standing_on(cell: Vector2i) -> bool:
	var area := Rect2(world.cell_center(cell) - Vector2.ONE * Balance.TILE / 2.0, Vector2.ONE * Balance.TILE).grow(10.0)
	for actor: Node2D in get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("enemies"):
		if area.has_point(actor.global_position):
			return true
	return false


func _on_building_destroyed(building: Building) -> void:
	if not building.stored.is_empty():
		Events.message.emit("장비 상자가 부서져 맡겨 둔 장비 %d개를 잃었습니다" % building.stored.size())
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
