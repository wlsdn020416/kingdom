extends SceneTree
## 노드 없이 돌아가는 규칙(월드 생성, 장비·스킬바)을 빠르게 확인한다.
## 실행: godot --headless --path . --script res://tests/logic_test.gd
## --script로 실행하면 오토로드(Events, Session)가 없다. 여기서는 오토로드를 쓰지 않는 코드만 검사한다.

var _failures := 0


func _initialize() -> void:
	_test_world_is_deterministic()
	_test_skill_bar()
	_test_cooldown()
	_test_inventory()
	_test_recipes()
	_test_chest_loot()
	_test_biome_rings()
	_test_material_sources()
	_test_progression()
	_test_health_bar_fill()
	print("LOGIC TEST %s (실패 %d)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


## 빈 체력·남은 한 픽셀·최대 체력이 테두리를 넘지 않아야 한다.
func _test_health_bar_fill() -> void:
	_check(HealthBarArt.fill_width(0.0) == 0 and HealthBarArt.fill_width(-0.5) == 0, "0 이하 체력은 채움 없이 표시")
	_check(HealthBarArt.fill_width(0.001) == 1, "아주 적은 양의 체력도 한 픽셀은 표시")
	_check(HealthBarArt.fill_width(1.0) == 26 and HealthBarArt.fill_width(2.0, 60) == 54, "전체·초과 체력은 바 안쪽 폭까지만 채움")


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
	_check(equipment.weapon().get("melee", false), "시작 무기는 근거리 무기")
	_check(equipment.skill_bar().is_empty(),
		"시작 장비에는 스킬이 없음 (스킬 없는 장비는 자리 차지 안 함) %s" % [equipment.skill_bar()])
	for id in ["fire_staff", "bomb_bag", "guardian_armor", "life_charm"]:
		equipment.add_to_bag(id)
		equipment.equip(id)
	_check(Array(equipment.skill_bar()) == ["fire_staff", "bomb_bag", "guardian_armor", "life_charm"],
		"스킬은 슬롯 순서대로 빈칸 없이 %s" % [equipment.skill_bar()])
	_check(equipment.hidden_skill_count() == 0, "4개까지는 숨김 없음")
	_check(equipment.bag.has("rusty_sword") and not equipment.bag.has("fire_staff"), "교체된 장비는 가방으로")
	equipment.unequip("weapon")
	_check(equipment.item_in("weapon") == "fire_staff", "무기는 해제할 수 없음")


func _test_cooldown() -> void:
	var equipment := Equipment.new()
	equipment.start_cooldown("life_charm")
	_check(not equipment.is_ready("life_charm"), "사용 직후 쿨타임")
	equipment.tick(ItemDB.ITEMS["life_charm"]["skill"]["cooldown"])
	_check(equipment.is_ready("life_charm"), "쿨타임만큼 지나면 다시 사용 가능")
	_check(not ItemDB.ITEMS.values().any(func(item: Dictionary) -> bool: return item.get("skill", {}).get("id") == "dash"),
		"대시는 장비 스킬이 아님 (기본 능력)")



## 개인 인벤토리: 칸 수와 칸당 개수 제한, 넘친 양은 돌려줌
func _test_inventory() -> void:
	var inventory := Inventory.new()
	var leftover := inventory.add({"wood": Balance.STACK_SIZE + 1})
	_check(leftover.is_empty() and inventory.used_slots() == 2, "칸당 %d개, 넘치면 다음 칸 (%d칸)" % [Balance.STACK_SIZE, inventory.used_slots()])
	var capacity := Balance.INVENTORY_SLOTS * Balance.STACK_SIZE
	leftover = inventory.add({"stone": capacity})
	var expected_stone := (Balance.INVENTORY_SLOTS - 2) * Balance.STACK_SIZE
	_check(inventory.count("stone") == expected_stone and leftover.get("stone", 0) == capacity - expected_stone,
		"가득 차면 못 담은 양을 돌려줌 (돌 %d, 남음 %s)" % [inventory.count("stone"), leftover])
	_check(inventory.add({"wood": Balance.STACK_SIZE - 1}).is_empty(), "덜 찬 칸에는 같은 자원을 더 담을 수 있음")
	_check(not inventory.add({"copper": 1}).is_empty(), "빈칸이 없으면 새 자원은 못 담음")
	inventory.bonus_slots = 2
	_check(inventory.capacity() == Balance.INVENTORY_SLOTS + 2 and inventory.add({"copper": 1}).is_empty(), "큰 가방 패시브만큼 칸이 늘어남")
	_check(inventory.take("wood", 9999) == Balance.STACK_SIZE * 2 and inventory.count("wood") == 0, "꺼낼 때는 가진 만큼만")



## 레시피 데이터가 올바르고, 재료를 모두 얻어 봐야 공개되는지
func _test_recipes() -> void:
	var broken := RecipeDB.RECIPES.keys().filter(func(id: String) -> bool:
		var recipe: Dictionary = RecipeDB.RECIPES[id]
		var unknown_kind: bool = recipe["cost"].keys().any(func(kind: String) -> bool: return not Balance.RESOURCE_NAMES.has(kind))
		return not ItemDB.ITEMS.has(id) or recipe["tier"] > RecipeDB.max_tier() or unknown_kind)
	_check(broken.is_empty(), "레시피는 있는 장비·자원만 쓰고 단계가 최고 단계 이하 %s" % [broken])
	_check(RecipeDB.is_revealed("old_bow", {"wood": true}), "재료(나무)를 알면 활 레시피 공개")
	_check(not RecipeDB.is_revealed("iron_helm", {"wood": true, "stone": true}), "철광석을 얻기 전에는 철 투구 레시피 비공개")



## 상자는 그 바이옴 자원을 주고, 장비는 낮은 확률로만 나온다(중복 허용)
func _test_chest_loot() -> void:
	seed(12345)
	var items := 0
	var forest_ok := true
	for i in 400:
		var reward := Loot.roll_chest(WorldData.Terrain.FOREST)
		var resources: Dictionary = reward["resources"]
		forest_ok = forest_ok and resources.get("hardwood", 0) >= 2 and not resources.has("copper")
		if reward.has("item"):
			items += 1
	_check(forest_ok, "숲 상자는 숲 재료(단단한 목재)를 주고 다른 바이옴 재료는 없음")
	_check(Loot.roll_chest(WorldData.Terrain.SNOW)["resources"].has("iron_ore"), "설원 상자에서는 철광석이 나옴")
	_check(items > 20 and items < 110, "장비는 낮은 확률로만 (400번 중 %d번)" % items)


## 바이옴 링(D-014): 왕국에서 멀수록 높은 단계 바이옴, 모든 바이옴이 실제로 생김
func _test_biome_rings() -> void:
	var data := WorldGenerator.generate("logic-test")
	var tier_sum := [0.0, 0.0, 0.0, 0.0]
	var land := [0, 0, 0, 0]
	var seen := {}
	for y in data.size.y:
		for x in data.size.x:
			var cell := Vector2i(x, y)
			var terrain := data.get_terrain(cell)
			seen[terrain] = true
			if terrain == WorldData.Terrain.WATER or terrain == WorldData.Terrain.SAND:
				continue
			var band := clampi(int(Vector2(cell - data.core_cell).length() / 20.0), 0, 3)
			tier_sum[band] += data.tier_at(cell)
			land[band] += 1
	var averages: Array[float] = []
	for band in 4:
		averages.append(tier_sum[band] / maxf(1.0, land[band]))
	_check(averages[0] < averages[1] and averages[1] < averages[2] and averages[2] < averages[3],
		"왕국에서 멀수록 평균 바이옴 단계가 높음 %s" % [averages])
	var all_biomes := [WorldData.Terrain.GRASS, WorldData.Terrain.FOREST, WorldData.Terrain.DESERT,
		WorldData.Terrain.SNOW, WorldData.Terrain.SWAMP, WorldData.Terrain.VOLCANO]
	_check(all_biomes.all(func(t: int) -> bool: return seen.has(t)), "바이옴 6종이 모두 생성됨")
	_check(data.tier_at(data.core_cell + Vector2i(0, 15)) == 0, "왕국 근처는 0단계(초원)")


## 바이옴 적 희귀 재료와 레시피가 실제로 이어지는지: 모든 업그레이드·레시피 재료는 어딘가에서 얻을 수 있다
func _test_material_sources() -> void:
	var sources := {}
	for drops: Dictionary in WorldData.OBJECT_DROPS.values():
		for kind in drops:
			sources[kind] = true
	for type_id: String in EnemyDB.TYPES:
		for kind in EnemyDB.TYPES[type_id].get("drop", {}).get("resources", {}):
			sources[kind] = true
	var needed := {}
	for cost: Dictionary in RecipeDB.UPGRADES:
		needed.merge(cost)
	for id: String in RecipeDB.RECIPES:
		needed.merge(RecipeDB.RECIPES[id]["cost"])
	var missing := needed.keys().filter(func(kind: String) -> bool: return not sources.has(kind))
	_check(missing.is_empty(), "레시피·업그레이드 재료는 모두 채집이나 몬스터에게서 얻을 수 있음 %s" % [missing])
	_check(not Balance.RESOURCE_NAMES.has("gold"), "금은 자원이 아님 (경험치로 바뀜, D-015)")



## 경험치·패시브(D-015): 비용만큼 쓰고 단계가 오르며, 죽으면 쓰지 않은 경험치만 사라진다
func _test_progression() -> void:
	var broken := PassiveDB.PASSIVES.keys().filter(func(id: String) -> bool:
		var info: Dictionary = PassiveDB.PASSIVES[id]
		return info["costs"].size() != info["values"].size() or not PassiveDB.ORDER.has(id))
	_check(broken.is_empty() and PassiveDB.ORDER.size() == PassiveDB.PASSIVES.size(), "패시브 데이터: 단계별 비용·효과 수가 같고 목록 순서에 모두 있음 %s" % [broken])
	var progression := Progression.new()
	var first_cost := progression.next_cost("vitality")
	_check(progression.learn("vitality") != "" and progression.rank("vitality") == 0, "경험치가 모자라면 배울 수 없음")
	progression.add_xp(first_cost + 5)
	_check(progression.learn("vitality") == "" and progression.rank("vitality") == 1 and progression.xp == 5,
		"경험치를 비용만큼 쓰고 1단계 (남은 경험치 %d)" % progression.xp)
	_check(progression.value("vitality") == PassiveDB.value_at("vitality", 1), "단계에 맞는 효과 값")
	progression.lose_unspent()
	_check(progression.xp == 0 and progression.rank("vitality") == 1, "죽으면 쓰지 않은 경험치만 사라지고 패시브는 남음")
	progression.add_xp(9999)
	for i in 10:
		progression.learn("swift")
	_check(progression.rank("swift") == PassiveDB.max_rank("swift") and progression.next_cost("swift") == -1, "최고 단계 이상은 못 올림")
	_check(Balance.tower_xp_share(9, 1) == 9 and Balance.tower_xp_share(9, 4) == 3 and Balance.tower_xp_share(2, 4) == 1,
		"탑 처치 경험치는 플레이어 수로 나눔(올림)")


func _check(ok: bool, label: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + label)
	if not ok:
		_failures += 1
