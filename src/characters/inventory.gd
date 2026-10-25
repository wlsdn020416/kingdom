class_name Inventory
extends RefCounted
## 플레이어가 들고 다니는 자원. 왕국 핵 근처에 가면 공용 창고로 옮겨지고, 죽으면 전부 사라진다 (D-014).
## 칸 하나에 같은 자원을 Balance.STACK_SIZE개까지 담는다.

var bonus_slots := 0  # 큰 가방 패시브 (D-015)
var _counts := {}  # 자원 id -> 개수


func capacity() -> int:
	return Balance.INVENTORY_SLOTS + bonus_slots


func count(kind: String) -> int:
	return _counts.get(kind, 0)


func amounts() -> Dictionary:
	return _counts.duplicate()


func is_empty() -> bool:
	return _counts.is_empty()


func used_slots() -> int:
	var slots := 0
	for kind in _counts:
		slots += ceili(float(_counts[kind]) / Balance.STACK_SIZE)
	return slots


## 담을 수 있는 만큼 담고, 칸이 모자라 못 담은 양을 돌려준다
func add(gained: Dictionary) -> Dictionary:
	var leftover := {}
	for kind: String in gained:
		var amount: int = gained[kind]
		var room := _room_for(kind)
		var taken := mini(amount, room)
		if taken > 0:
			_counts[kind] = count(kind) + taken
		if amount > taken:
			leftover[kind] = amount - taken
	return leftover


## 최대 amount개를 꺼내고 실제로 꺼낸 개수를 돌려준다
func take(kind: String, amount: int) -> int:
	var taken := mini(amount, count(kind))
	if taken <= 0:
		return 0
	_counts[kind] = count(kind) - taken
	if _counts[kind] == 0:
		_counts.erase(kind)
	return taken


func clear() -> void:
	_counts.clear()


func _room_for(kind: String) -> int:
	var free_slots := capacity() - used_slots()
	var partial := count(kind) % Balance.STACK_SIZE
	var room_in_partial := Balance.STACK_SIZE - partial if partial > 0 else 0
	return room_in_partial + free_slots * Balance.STACK_SIZE
