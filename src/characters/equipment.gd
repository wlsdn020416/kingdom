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


## 숫자키 1~4 스킬바. 무기 스킬은 우클릭으로 따로 쓰므로 빠진다 (D-027)
func skill_bar() -> Array[String]:
	var bar: Array[String] = []
	for id in _gear_skills():
		if bar.size() < MAX_SKILLS:
			bar.append(id)
	return bar


## 스킬이 5개 이상이라 스킬바에 못 올라간 개수
func hidden_skill_count() -> int:
	return maxi(0, _gear_skills().size() - MAX_SKILLS)


## 우클릭으로 쓰는 무기 스킬의 장비 id. 무기에 스킬이 없으면 ""
func weapon_skill_item() -> String:
	var id: String = equipped["weapon"]
	return id if ItemDB.ITEMS[id].has("skill") else ""


func _gear_skills() -> Array[String]:
	var ids: Array[String] = []
	for id in _worn_items():
		if id != equipped["weapon"] and ItemDB.ITEMS[id].has("skill"):
			ids.append(id)
	return ids


func owns(id: String) -> bool:
	return bag.has(id) or equipped.values().has(id)


func add_to_bag(id: String) -> void:
	bag.append(id)
	changed.emit()


## 무기 강화(D-028): from을 to로 바꾼다. 들고 있는 것을 먼저 바꾸고, 없으면 가방에서 바꾼다. 둘 다 없으면 false
func replace_item(from: String, to: String) -> bool:
	for slot: String in equipped:
		if equipped[slot] == from:
			equipped[slot] = to
			changed.emit()
			return true
	var index := bag.find(from)
	if index < 0:
		return false
	bag[index] = to
	changed.emit()
	return true


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
