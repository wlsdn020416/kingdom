class_name KingdomSync
extends Node
## 왕국 동기화 (D-017 3단계). 창고·건물·장비 상자·제작대 단계·방어 단계·영토·알게 된 재료는 호스트의 Kingdom만 바꾼다.
## 입력·UI는 Kingdom 명령 메서드 대신 이 노드의 같은 이름 메서드를 부른다. 혼자 플레이·호스트는 바로 Kingdom을 부르고,
## 참가자는 호스트에 요청한다. 호스트는 같은 명령 메서드로 검증·적용하고 결과를 돌려준다.
## 개인 가방·장비 가방은 아직 각자 가지고 있어서, 참가자는 요청에 가방 내용을 실어 보내고 호스트가 뺄 양을 정해 준다 (임시).
## RPC 경로가 모두에게 같아야 해서 Main이 이름 "KingdomSync"로 붙인다.

const SNAPSHOT_INTERVAL := 0.2
## 호스트가 참가자 가방 내용을 임시 Inventory에 담을 때 칸 수 제한에 걸리지 않게 한다 (큰 가방 패시브는 호스트가 모른다)
const CLAIM_EXTRA_SLOTS := 1000
## 호스트가 아직 내가 핵 근처에 온 걸 모르면 빈 답이 온다. 그때 매 프레임 다시 묻지 않게 잠시 쉰다
const DEPOSIT_RETRY_MS := 500

var _net: NetSession
var _main: Main
var _kingdom: Kingdom
var _player: Player
var _timer := 0.0
var _last_sent := {}
var _deposit_pending := false
var _deposit_retry_at := 0


func setup(net: NetSession, main: Main) -> void:
	_net = net
	_main = main
	_kingdom = main.kingdom
	_player = main.player


## setup()은 트리에 붙기 전이라 거기서 끄면 Godot이 _ready 때 _physics_process를 다시 켠다. 그래서 여기서 정한다
func _ready() -> void:
	set_physics_process(_net.is_online() and _net.is_host())


func _is_client() -> bool:
	return _net.is_online() and not _net.is_host()


## 바뀐 경우에만 보낸다. 건물 체력이 깎이는 밤에도 초당 5번이면 충분하다
func _physics_process(delta: float) -> void:
	if not _main.player_sync.is_running():
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = SNAPSHOT_INTERVAL
	var state := _kingdom.snapshot()
	if state != _last_sent:
		_last_sent = state
		_state.rpc(state)


# --- 입력·UI가 부르는 것 (결과 문구는 여기서 알린다) ---

func build(cell: Vector2i, type_id: String) -> void:
	if _is_client():
		_request_build.rpc_id(1, cell, type_id, _player.inventory.amounts())
	else:
		var error := _kingdom.build(cell, type_id, _player.global_position, _player.inventory, _player.progression.build_perks())
		_report(error)
		if error == "":
			_reward_builder(multiplayer.get_unique_id(), _player.progression.ranks, _kingdom.world.cell_center(cell))


func demolish(cell: Vector2i) -> void:
	if _is_client():
		_request_demolish.rpc_id(1, cell)
	else:
		_report(_kingdom.demolish(cell, _player.progression.value("salvage_expert") / 100.0))


func store_item(cell: Vector2i, id: String) -> void:
	if _is_client():
		if _player.equipment.bag.has(id):
			_request_store.rpc_id(1, cell, id)
	else:
		_report(_kingdom.store_item(cell, _player.equipment, id, _player.global_position))


func take_item(cell: Vector2i, id: String) -> void:
	if _is_client():
		_request_take.rpc_id(1, cell, id)
	else:
		_report(_kingdom.take_item(cell, _player.equipment, id, _player.global_position))


func craft(recipe_id: String) -> void:
	if _is_client():
		var from: String = RecipeDB.RECIPES.get(recipe_id, {}).get("from", "")
		if from != "" and not _player.equipment.owns(from):
			_report("강화할 %s이(가) 있어야 합니다" % ItemDB.ITEMS[from]["name"])
			return
		_request_craft.rpc_id(1, recipe_id, _player.inventory.amounts())
		return
	var error := _kingdom.craft(recipe_id, _player.global_position, _player.inventory, _player.equipment)
	_report(error, _craft_note(recipe_id))


func upgrade_workbench() -> void:
	if _is_client():
		_request_upgrade.rpc_id(1, _player.inventory.amounts())
		return
	var error := _kingdom.upgrade_workbench(_player.global_position, _player.inventory)
	_report(error, _upgrade_note())


func upgrade_defense() -> void:
	if _is_client():
		_request_defense.rpc_id(1, _player.inventory.amounts())
		return
	_report(_kingdom.upgrade_defense(_player.global_position, _player.inventory), _defense_note())


func expand_territory() -> void:
	if _is_client():
		_request_territory.rpc_id(1, _player.inventory.amounts())
		return
	_report(_kingdom.expand_territory(_player.global_position, _player.inventory), _territory_note())


func repair() -> void:
	if _is_client():
		_request_repair.rpc_id(1, _player.inventory.amounts())
	else:
		_report(_kingdom.repair(_player.global_position, _player.inventory, _player.progression.repair_perks()))


## 핵 근처에 있으면 개인 자원을 창고로 옮긴다. 옮긴 양을 돌려준다 (참가자는 호스트 답을 받은 뒤 Main.show_deposit으로 알린다)
func deposit() -> Dictionary:
	if not _is_client():
		return _kingdom.deposit(_player.inventory, _player.global_position)
	var near := _kingdom.can_deposit_at(_player.global_position)
	if near and not _deposit_pending and not _player.inventory.is_empty() and Time.get_ticks_msec() >= _deposit_retry_at:
		_deposit_pending = true
		_request_deposit.rpc_id(1, _player.inventory.amounts())
	return {}


func _report(error: String, note := "") -> void:
	if error != "":
		Events.ui_sound_requested.emit("error")
		Events.message.emit(error)
	elif note != "":
		Events.message.emit(note)


func _craft_note(recipe_id: String) -> String:
	if RecipeDB.RECIPES[recipe_id].has("from"):
		return "%s(으)로 강화!" % ItemDB.ITEMS[recipe_id]["name"]
	return "%s 제작! (I로 착용)" % ItemDB.ITEMS[recipe_id]["name"]


func _upgrade_note() -> String:
	return "제작대가 %d단계가 되었습니다" % _kingdom.workbench_tier()


func _defense_note() -> String:
	return "방어 %d단계! 새 벽·공성탑을 지을 수 있습니다 (B)" % _kingdom.defense_tier


func _territory_note() -> String:
	return "영토가 %d칸으로 넓어졌습니다" % _kingdom.territory_radius()


# --- 호스트: 참가자 요청 처리 ---

## 요청한 사람. 호스트가 아니거나 모르는 사람·죽은 사람이면 null
func _requester() -> RemotePlayer:
	if not _net.is_host():
		return null
	var actor := _main.player_sync.remote(multiplayer.get_remote_sender_id())
	return actor if actor != null and not actor.is_dead else null


## 참가자가 보낸 가방 내용을 담은 임시 Inventory. 명령 메서드가 여기서 먼저 꺼내 쓰고, 꺼낸 양을 돌려보낸다
func _claimed(held: Dictionary) -> Inventory:
	var payer := Inventory.new()
	payer.bonus_slots = CLAIM_EXTRA_SLOTS
	payer.add(held)
	return payer


func _spent(held: Dictionary, payer: Inventory) -> Dictionary:
	var taken := {}
	for kind: String in held:
		var used: int = held[kind] - payer.count(kind)
		if used > 0:
			taken[kind] = used
	return taken


## RPC로 오가는 배열은 타입 없는 Array로 도착하므로 removed·added는 Array로 받는다
func _reply(error: String, note := "", taken := {}, removed := [], added := []) -> void:
	_result.rpc_id(multiplayer.get_remote_sender_id(), error, note if error == "" else "", taken, removed, added)


@rpc("any_peer", "reliable")
func _request_build(cell: Vector2i, type_id: String, held: Dictionary) -> void:
	var actor := _requester()
	if actor == null or not BuildingDB.TYPES.has(type_id):
		return
	var payer := _claimed(held)
	var error := _kingdom.build(cell, type_id, actor.global_position, payer, PassiveDB.build_perks(actor.ranks))
	_reply(error, "", _spent(held, payer))
	if error == "":
		_reward_builder(actor.peer_id, actor.ranks, _kingdom.world.cell_center(cell))


## 건축가의 깨달음 패시브: 지은 사람에게 경험치 (호스트가 정한다)
func _reward_builder(peer_id: int, ranks: Dictionary, at: Vector2) -> void:
	var xp := int(PassiveDB.value_in(ranks, "builders_insight"))
	if xp <= 0:
		return
	if peer_id == multiplayer.get_unique_id():
		_main.grant_reward(xp, {}, at)
	else:
		_main.combat_sync.send_reward(peer_id, xp, {}, at)


@rpc("any_peer", "reliable")
func _request_demolish(cell: Vector2i) -> void:
	var actor := _requester()
	if actor != null:
		_reply(_kingdom.demolish(cell, PassiveDB.value_in(actor.ranks, "salvage_expert") / 100.0))


@rpc("any_peer", "reliable")
func _request_store(cell: Vector2i, id: String) -> void:
	var actor := _requester()
	if actor == null or not ItemDB.ITEMS.has(id):
		return
	var bag := Equipment.new()
	bag.add_to_bag(id)
	var error := _kingdom.store_item(cell, bag, id, actor.global_position)
	_reply(error, "", {}, [id] if error == "" else [])


@rpc("any_peer", "reliable")
func _request_take(cell: Vector2i, id: String) -> void:
	var actor := _requester()
	if actor == null:
		return
	var error := _kingdom.take_item(cell, Equipment.new(), id, actor.global_position)
	_reply(error, "", {}, [], [id] if error == "" else [])


@rpc("any_peer", "reliable")
func _request_craft(recipe_id: String, held: Dictionary) -> void:
	var actor := _requester()
	if actor == null:
		return
	var payer := _claimed(held)
	# 장비 가방은 참가자가 가진다(임시). 강화 레시피면 참가자가 이전 무기를 가졌다고 믿고 그 자리를 바꾸게 한다 (D-028)
	var bag := Equipment.new()
	var from: String = RecipeDB.RECIPES.get(recipe_id, {}).get("from", "")
	if from != "":
		bag.add_to_bag(from)
	var error := _kingdom.craft(recipe_id, actor.global_position, payer, bag, actor.peer_id)
	_reply(error, _craft_note(recipe_id) if error == "" else "", _spent(held, payer),
		[from] if error == "" and from != "" else [], [recipe_id] if error == "" else [])


@rpc("any_peer", "reliable")
func _request_upgrade(held: Dictionary) -> void:
	var actor := _requester()
	if actor == null:
		return
	var payer := _claimed(held)
	var error := _kingdom.upgrade_workbench(actor.global_position, payer)
	_reply(error, _upgrade_note() if error == "" else "", _spent(held, payer))


@rpc("any_peer", "reliable")
func _request_defense(held: Dictionary) -> void:
	var actor := _requester()
	if actor == null:
		return
	var payer := _claimed(held)
	var error := _kingdom.upgrade_defense(actor.global_position, payer)
	_reply(error, _defense_note() if error == "" else "", _spent(held, payer))


@rpc("any_peer", "reliable")
func _request_territory(held: Dictionary) -> void:
	var actor := _requester()
	if actor == null:
		return
	var payer := _claimed(held)
	var error := _kingdom.expand_territory(actor.global_position, payer)
	_reply(error, _territory_note() if error == "" else "", _spent(held, payer))


@rpc("any_peer", "reliable")
func _request_repair(held: Dictionary) -> void:
	var actor := _requester()
	if actor == null:
		return
	var payer := _claimed(held)
	var error := _kingdom.repair(actor.global_position, payer, PassiveDB.repair_perks(actor.ranks))
	_reply(error, "", _spent(held, payer))


@rpc("any_peer", "reliable")
func _request_deposit(held: Dictionary) -> void:
	var sender := multiplayer.get_remote_sender_id()
	var actor := _requester()
	var moved := _kingdom.deposit(_claimed(held), actor.global_position) if actor != null else {}
	_deposited.rpc_id(sender, moved)


# --- 참가자: 호스트의 답과 상태 ---

@rpc("authority", "reliable")
func _result(error: String, note: String, taken: Dictionary, removed: Array, added: Array) -> void:
	for kind: String in taken:
		_player.inventory.take(kind, taken[kind])
	# 무기 강화: 이전 무기 하나가 빠지고 새 무기 하나가 그 자리에 들어온다 (들고 있었으면 손에 그대로)
	if removed.size() == 1 and added.size() == 1:
		_player.equipment.replace_item(removed[0], added[0])
		_report(error, note)
		return
	for id: String in removed:
		_player.equipment.remove_from_bag(id)
	for id: String in added:
		_player.equipment.add_to_bag(id)
	_report(error, note)


@rpc("authority", "reliable")
func _deposited(moved: Dictionary) -> void:
	_deposit_pending = false
	if moved.is_empty():
		_deposit_retry_at = Time.get_ticks_msec() + DEPOSIT_RETRY_MS
	for kind: String in moved:
		_player.inventory.take(kind, moved[kind])
	if not moved.is_empty():
		_main.show_deposit(moved)


@rpc("authority", "reliable")
func _state(state: Dictionary) -> void:
	_kingdom.apply_snapshot(state)
	for recipe_id in _kingdom.discover(state["known"]):
		Events.message.emit("새 레시피: %s (제작대)" % ItemDB.ITEMS[recipe_id]["name"])
