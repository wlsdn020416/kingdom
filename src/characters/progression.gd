class_name Progression
extends RefCounted
## 플레이어 개인의 경험치와 패시브 단계 (D-015, 트리 D-020).
## 경험치는 가방 칸을 쓰지 않는다. 죽으면 쓰지 않은 경험치만 사라지고 찍은 패시브는 남는다.

signal changed

var xp := 0
var ranks := {}  # 패시브 id -> 단계


func rank(id: String) -> int:
	return ranks.get(id, 0)


## 지금 단계의 효과 값 (PassiveDB.values)
func value(id: String) -> float:
	return PassiveDB.value_at(id, rank(id))


## 다음 단계 비용. 최고 단계면 -1
func next_cost(id: String) -> int:
	if rank(id) >= PassiveDB.max_rank(id):
		return -1
	return PassiveDB.PASSIVES[id]["costs"][rank(id)]


func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	xp += amount
	changed.emit()


## 성공하면 "", 실패하면 이유를 돌려준다
func learn(id: String) -> String:
	if not PassiveDB.PASSIVES.has(id):
		return "없는 패시브입니다"
	var cost := next_cost(id)
	if cost < 0:
		return "이미 최고 단계입니다"
	var missing := PassiveDB.missing_requirements(id, ranks)
	if not missing.is_empty():
		var names := PackedStringArray()
		for required in missing:
			names.append(PassiveDB.PASSIVES[required]["name"])
		return "먼저 배워야 합니다: %s" % ", ".join(names)
	if xp < cost:
		return "경험치가 부족합니다 (%d 필요)" % cost
	xp -= cost
	ranks[id] = rank(id) + 1
	changed.emit()
	return ""


## 건물을 지을 때 쓰는 내 건설 패시브 효과 (Kingdom.build의 perks)
func build_perks() -> Dictionary:
	return PassiveDB.build_perks(ranks)


func lose_unspent() -> void:
	xp = 0
	changed.emit()
