class_name Loot
extends RefCounted
## 상자 보상. 아직 없는 장비가 우선 나오고, 아니면 자원이 나온다.

const ITEM_CHANCE := 0.75


## {"item": id} 또는 {"resources": {...}}
static func roll_chest(equipment: Equipment) -> Dictionary:
	var missing := ItemDB.ITEMS.keys().filter(func(id: String) -> bool: return not equipment.owns(id))
	if not missing.is_empty() and randf() < ITEM_CHANCE:
		return {"item": missing.pick_random()}
	return {"resources": {
		"wood": randi_range(5, 10), "stone": randi_range(5, 10), "gold": randi_range(2, 4),
	}}
