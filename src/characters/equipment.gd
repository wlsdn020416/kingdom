class_name Equipment
extends RefCounted
## 착용 장비, 가방, 스킬 쿨타임.
## 스킬바 = 착용 장비 중 스킬이 있는 것만 슬롯 순서대로 빈칸 없이 최대 4개.

signal changed

const MAX_SKILLS := 4

var equipped := {}  # slot -> item id ("" = 비어 있음)
var bag: Array[String] = []
var _cooldowns := {}  # item id -> 남은 초


func _init() -> void:
	for slot in ItemDB.SLOTS:
		equipped[slot] = ItemDB.STARTING_EQUIPMENT.get(slot, "")


func item_in(slot: String) -> String:
	return equipped[slot]


func max_hp() -> float:
	var total := Balance.PLAYER_BASE_HP
	for id in _worn_items():
		total += ItemDB.ITEMS[id].get("hp", 0.0)
	return total


func move_speed() -> float:
	var bonus := 0.0
	for id in _worn_items():
		bonus += ItemDB.ITEMS[id].get("speed_bonus", 0.0)
	return Balance.PLAYER_SPEED * (1.0 + bonus)


func weapon() -> Dictionary:
	return ItemDB.ITEMS[equipped["weapon"]]["weapon"]


func skill_bar() -> Array[String]:
	var bar: Array[String] = []
	for id in _worn_items():
		if ItemDB.ITEMS[id].has("skill") and bar.size() < MAX_SKILLS:
			bar.append(id)
	return bar


## 스킬이 5개 이상이라 스킬바에 못 올라간 개수
func hidden_skill_count() -> int:
	var count := 0
	for id in _worn_items():
		if ItemDB.ITEMS[id].has("skill"):
			count += 1
	return maxi(0, count - MAX_SKILLS)


func owns(id: String) -> bool:
	return bag.has(id) or equipped.values().has(id)


func add_to_bag(id: String) -> void:
	bag.append(id)
	changed.emit()


func remove_from_bag(id: String) -> bool:
	if not bag.has(id):
		return false
	bag.erase(id)
	changed.emit()
	return true


## 죽으면 가방 장비를 전부 잃는다. 착용 중인 장비는 남는다 (D-014)
func lose_bag() -> void:
	bag.clear()
	changed.emit()


func equip(id: String) -> void:
	var slot: String = ItemDB.ITEMS[id]["slot"]
	var previous: String = equipped[slot]
	bag.erase(id)
	if previous != "":
		bag.append(previous)
	equipped[slot] = id
	changed.emit()


## 무기는 항상 하나 들고 있어야 해서 해제할 수 없다
func unequip(slot: String) -> void:
	if slot == "weapon" or equipped[slot] == "":
		return
	bag.append(equipped[slot])
	equipped[slot] = ""
	changed.emit()


func tick(delta: float) -> void:
	for id in _cooldowns:
		_cooldowns[id] = maxf(0.0, _cooldowns[id] - delta)


func cooldown_left(id: String) -> float:
	return _cooldowns.get(id, 0.0)


func is_ready(id: String) -> bool:
	return cooldown_left(id) <= 0.0


## scale: 전술가 패시브처럼 쿨타임을 줄이는 배수 (0.9 = 10% 짧게)
func start_cooldown(id: String, scale := 1.0) -> void:
	_cooldowns[id] = ItemDB.ITEMS[id]["skill"]["cooldown"] * scale


func _worn_items() -> Array[String]:
	var items: Array[String] = []
	for slot in ItemDB.SLOTS:
		if equipped[slot] != "":
			items.append(equipped[slot])
	return items
