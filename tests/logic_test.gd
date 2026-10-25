extends SceneTree
## 노드 없이 돌아가는 규칙(월드 생성, 장비·스킬바)을 빠르게 확인한다.
## 실행: godot --headless --path . --script res://tests/logic_test.gd
## --script로 실행하면 오토로드(Events, Session)가 없다. 여기서는 오토로드를 쓰지 않는 코드만 검사한다.

var _failures := 0


func _initialize() -> void:
	_test_world_is_deterministic()
	_test_skill_bar()
	_test_cooldown()
	print("LOGIC TEST %s (실패 %d)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


## 멀티플레이에서 모든 참가자가 시드만으로 같은 월드를 만들 수 있어야 한다
func _test_world_is_deterministic() -> void:
	var a := WorldGenerator.generate("logic-test")
	var b := WorldGenerator.generate("logic-test")
	var other := WorldGenerator.generate("logic-test-2")
	_check(a.terrain == b.terrain and a.objects == b.objects, "같은 시드는 같은 월드")
	_check(a.terrain != other.terrain, "다른 시드는 다른 월드")
	_check(a.is_walkable(a.core_cell + Vector2i(0, 4)), "왕국 핵 아래(플레이어 시작 지점)는 걸을 수 있음")


## 스킬바: 스킬 있는 장비만, 슬롯 순서대로 빈칸 없이, 최대 4개
func _test_skill_bar() -> void:
	var equipment := Equipment.new()
	_check(Array(equipment.skill_bar()) == ["dash_boots", "life_charm"],
		"시작 장비 스킬바 = 대시, 치유 (스킬 없는 장비는 자리 차지 안 함) %s" % [equipment.skill_bar()])
	for id in ["fire_staff", "bomb_bag", "guardian_armor"]:
		equipment.add_to_bag(id)
		equipment.equip(id)
	_check(Array(equipment.skill_bar()) == ["fire_staff", "bomb_bag", "guardian_armor", "dash_boots"],
		"스킬 5개면 슬롯 순서로 앞의 4개 %s" % [equipment.skill_bar()])
	_check(equipment.hidden_skill_count() == 1, "넘친 스킬 1개는 숨김")
	_check(equipment.bag.has("old_bow") and not equipment.bag.has("fire_staff"), "교체된 장비는 가방으로")
	equipment.unequip("weapon")
	_check(equipment.item_in("weapon") == "fire_staff", "무기는 해제할 수 없음")


func _test_cooldown() -> void:
	var equipment := Equipment.new()
	equipment.start_cooldown("dash_boots")
	_check(not equipment.is_ready("dash_boots"), "사용 직후 쿨타임")
	equipment.tick(ItemDB.ITEMS["dash_boots"]["skill"]["cooldown"])
	_check(equipment.is_ready("dash_boots"), "쿨타임만큼 지나면 다시 사용 가능")


func _check(ok: bool, label: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + label)
	if not ok:
		_failures += 1
