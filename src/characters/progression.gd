class_name Progression
extends RefCounted
## 플레이어 개인의 레벨·경험치·패시브 단계 (D-015·D-024, 트리 D-020).
## 경험치가 차면 레벨이 오르고 패시브 포인트 1개를 받는다. 패시브는 단계마다 포인트 1개.
## 죽으면 이번 레벨에서 모은 경험치만 사라지고 레벨·쓰지 않은 포인트·찍은 패시브는 남는다.

signal changed

var level := 1
var xp := 0  # 이번 레벨에서 모은 경험치
var points := 0  # 쓰지 않은 패시브 포인트
var ranks := {}  # 패시브 id -> 단계


func rank(id: String) -> int:
	return ranks.get(id, 0)


## 지금 단계의 효과 값 (PassiveDB.values)
func value(id: String) -> float:
	return PassiveDB.value_at(id, rank(id))


## 다음 레벨까지 필요한 경험치
func xp_to_next() -> int:
	return Balance.xp_to_next_level(level)


## 다음 단계에 드는 포인트. 최고 단계면 -1
func next_cost(id: String) -> int:
	if rank(id) >= PassiveDB.max_rank(id):
		return -1
	return 1


## 오른 레벨 수를 돌려준다
func add_xp(amount: int) -> int:
	if amount <= 0:
		return 0
	xp += amount
	var gained := 0
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		gained += 1
	points += gained
	changed.emit()
	return gained


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
	if points < cost:
		return "패시브 포인트가 없습니다 (레벨업으로 얻습니다)"
	points -= cost
	ranks[id] = rank(id) + 1
	changed.emit()
	return ""


## 건물을 지을 때 쓰는 내 건설 패시브 효과 (Kingdom.build의 perks)
func build_perks() -> Dictionary:
	return PassiveDB.build_perks(ranks)


## 핵을 수리할 때 쓰는 내 패시브 효과 (Kingdom.repair의 perks)
func repair_perks() -> Dictionary:
	return PassiveDB.repair_perks(ranks)


func lose_level_progress() -> void:
	xp = 0
	changed.emit()
