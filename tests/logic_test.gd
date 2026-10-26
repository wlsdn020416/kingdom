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
	_test_settings()
	_test_weapon_tree()
	_test_chest_loot()
	_test_outcome_rolls_use_given_rng()
	_test_bosses_and_difficulty()
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
	var total := 0
	for key: Vector2i in a.resource_targets:
		total += a.resource_targets[key]
	_check(a.resource_targets == WorldGenerator.count_resources(a) and total > 0,
		"아침 재생 목표(D-035)는 처음 생성된 바이옴·종류별 자원 수 (총 %d개)" % total)
	var b := WorldGenerator.generate("logic-test")
	var other := WorldGenerator.generate("logic-test-2")
	_check(a.terrain == b.terrain and a.objects == b.objects, "같은 시드는 같은 월드")
	_check(a.terrain != other.terrain, "다른 시드는 다른 월드")
	_check(a.is_walkable(a.core_cell + Vector2i(0, 4)), "왕국 핵 아래(플레이어 시작 지점)는 걸을 수 있음")


## 환경 설정(D-030): 범위 밖 값은 잘리고, 저장한 값을 다시 읽는다
func _test_settings() -> void:
	var settings := GameSettings.new()
	settings.path = "user://settings_logic_test.cfg"
	settings.set_value("ui_scale", 9.0)
	settings.set_value("sfx_volume", -1.0)
	settings.set_value("unknown", 1)
	_check(is_equal_approx(settings.get_value("ui_scale"), GameSettings.UI_SCALE_MAX) and settings.get_value("sfx_volume") == 0.0
		and not settings.values.has("unknown"), "설정 값은 범위로 잘리고 모르는 키는 무시")
	settings.set_value("hitstop", false)
	settings.save_file()
	var loaded := GameSettings.new()
	loaded.path = settings.path
	loaded.load_file()
	_check(not loaded.get_value("hitstop") and is_equal_approx(loaded.get_value("ui_scale"), GameSettings.UI_SCALE_MAX),
		"저장한 설정을 다시 읽음")
	_check(GameSettings.volume_db(0.0) <= -79.0 and is_equal_approx(GameSettings.volume_db(1.0), 0.0), "볼륨 0은 끔, 1은 0dB")


## 무기 트리(D-028): 0단계 4계열은 처음부터, 1단계에서 갈래 2~3개, 2·3단계는 같은 갈래를 한 단계씩 강화(이전 무기 소모)
func _test_weapon_tree() -> void:
	var problems: Array[String] = []
	var families := {}
	for id: String in ItemDB.ITEMS:
		var item: Dictionary = ItemDB.ITEMS[id]
		if not item.has("weapon"):
			continue
		if not RecipeDB.RECIPES.has(id):
			problems.append("%s: 레시피 없음" % id)
			continue
		var recipe: Dictionary = RecipeDB.RECIPES[id]
		var from: String = recipe.get("from", "")
		var tier: int = recipe["tier"]
		if from == "":
			families[item["weapon"]["family"]] = true
			if tier != 0 or item.has("skill"):
				problems.append("%s: 기본 무기는 0단계·스킬 없음" % id)
			var branches := RecipeDB.upgrades_of(id).size()
			if branches < 2 or branches > 3:
				problems.append("%s: 갈래 %d개" % [id, branches])
			continue
		if RecipeDB.RECIPES[from]["tier"] != tier - 1 or ItemDB.ITEMS[from]["weapon"]["family"] != item["weapon"]["family"]:
			problems.append("%s: %s의 한 단계 위 같은 계열이 아님" % [id, from])
		if not item.has("skill"):
			problems.append("%s: 우클릭 스킬 없음" % id)
		var next := RecipeDB.upgrades_of(id).size()
		if (tier < RecipeDB.max_tier() and next != 1) or (tier == RecipeDB.max_tier() and next != 0):
			problems.append("%s: 갈래 안에서 다음 단계가 %d개" % [id, next])
	_check(problems.is_empty() and families.size() == 4, "무기 트리: 4계열 기본 → 갈래 2~3개 → 같은 갈래 2·3단계 강화 %s" % [problems])
	var upgrade_drops := Loot.chest_items().filter(func(id: String) -> bool: return RecipeDB.RECIPES.get(id, {}).has("from"))
	_check(upgrade_drops.is_empty() and Loot.chest_items().has("old_bow"), "상자에서는 강화 무기가 나오지 않음 (기본 무기·장비만)")
	var equipment := Equipment.new()
	equipment.add_to_bag("old_bow")
	_check(equipment.replace_item("rusty_sword", "greatsword") and equipment.item_in("weapon") == "greatsword"
		and equipment.replace_item("old_bow", "longbow") and equipment.bag.has("longbow") and not equipment.bag.has("old_bow")
		and not equipment.replace_item("rusty_sword", "twin_blades"),
		"강화는 들고 있는 무기를 먼저, 없으면 가방의 무기를 바꾸고, 없으면 실패")


## 스킬바: 스킬 있는 장비만, 슬롯 순서대로 빈칸 없이, 최대 4개
func _test_skill_bar() -> void:
	var equipment := Equipment.new()
	_check(equipment.weapon().get("melee", false), "시작 무기는 근거리 무기")
	_check(equipment.skill_bar().is_empty(),
		"시작 장비에는 스킬이 없음 (스킬 없는 장비는 자리 차지 안 함) %s" % [equipment.skill_bar()])
	for id in ["fire_staff", "bomb_bag", "guardian_armor", "life_charm"]:
		equipment.add_to_bag(id)
		equipment.equip(id)
	_check(Array(equipment.skill_bar()) == ["bomb_bag", "guardian_armor", "life_charm"] and equipment.weapon_skill_item() == "fire_staff",
		"무기 스킬은 우클릭, 나머지 장비 스킬은 슬롯 순서대로 빈칸 없이 %s (D-027)" % [equipment.skill_bar()])
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
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var items := 0
	var forest_ok := true
	for i in 400:
		var reward := Loot.roll_chest(WorldData.Terrain.FOREST, rng)
		var resources: Dictionary = reward["resources"]
		forest_ok = forest_ok and resources.get("hardwood", 0) >= 2 and not resources.has("copper")
		if reward.has("item"):
			items += 1
	_check(forest_ok, "숲 상자는 숲 재료(단단한 목재)를 주고 다른 바이옴 재료는 없음")
	_check(Loot.roll_chest(WorldData.Terrain.SNOW, rng)["resources"].has("iron_ore"), "설원 상자에서는 철광석이 나옴")
	_check(items > 20 and items < 110, "장비는 낮은 확률로만 (400번 중 %d번)" % items)



## 결과용 무작위는 넘겨받은 rng로만 굴린다 (호스트의 Main.rng 하나). 같은 시드면 같은 결과, 전역 시드에는 영향받지 않음
func _test_outcome_rolls_use_given_rng() -> void:
	var results := []
	for global_seed in [1, 2]:
		seed(global_seed)
		var rng := RandomNumberGenerator.new()
		rng.seed = 777
		var rolls := []
		for i in 30:
			rolls.append(Loot.roll_chest(WorldData.Terrain.DESERT, rng))
			rolls.append(EnemyDB.roll_drop("fire_imp", rng))
			rolls.append(EnemyDB.pick_invader(5, rng))
		results.append(rolls)
	_check(results[0] == results[1], "상자·희귀 재료·침공 구성은 rng 시드로만 정해짐 (전역 randf 미사용)")

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
	# 건물 재료(D-022): 보스의 정수는 보스를 잡으면 창고로 들어온다
	sources["boss_essence"] = true
	var building_needs := {}
	var building_problems: Array[String] = []
	for id: String in BuildingDB.ORDER:
		var info: Dictionary = BuildingDB.TYPES[id]
		building_needs.merge(info["cost"])
		if not BuildingDB.CATEGORIES.has(info.get("category", "")) or info.get("tier", 0) > RecipeDB.max_tier():
			building_problems.append(id)
	for kind: String in building_needs:
		if not sources.has(kind) or not Balance.RESOURCE_NAMES.has(kind):
			building_problems.append(kind)
	_check(building_problems.is_empty() and BuildingDB.ORDER.size() == BuildingDB.TYPES.size(),
		"건물 데이터: 분류·제작대 단계가 맞고 모든 재료를 얻을 수 있음 %s" % [building_problems])
	for category: String in BuildingDB.CATEGORIES:
		_check(BuildingDB.in_category(category).size() >= 6, "%s 탭에 건물이 6종 이상 (%d)" % [BuildingDB.CATEGORY_NAMES[category], BuildingDB.in_category(category).size()])
	_check(InputBindings.MOUSE_BUTTONS["attack"] == MOUSE_BUTTON_LEFT and InputBindings.MOUSE_BUTTONS["weapon_skill"] == MOUSE_BUTTON_RIGHT,
		"기본 공격은 좌클릭, 무기 스킬은 우클릭 (D-027)")
	# 핵 창 비용 구분 (D-027): 제작대 = 몬스터 재료, 방어 = 채집 재료, 영토 = 둘 다
	var harvested := {}
	for drops: Dictionary in WorldData.OBJECT_DROPS.values():
		for kind: String in drops:
			harvested[kind] = true
	var hunted := {}
	for info: Dictionary in EnemyDB.TYPES.values():
		for kind: String in info.get("drop", {}).get("resources", {}):
			hunted[kind] = true
	var only := func(costs: Array, pool: Dictionary) -> bool:
		return costs.all(func(cost: Dictionary) -> bool: return cost.keys().all(func(kind: String) -> bool: return pool.has(kind)))
	var widest := Balance.TERRITORY_RADIUS + Balance.TERRITORY_STEP * Balance.TERRITORY_UPGRADES.size()
	_check(widest < WorldGenerator.RING_EDGES[0], "영토를 끝까지 넓혀도(%d칸) 초원 링(%d칸) 안에 머묾 (D-033)" % [widest, WorldGenerator.RING_EDGES[0]])
	var mixed := Balance.TERRITORY_UPGRADES.all(func(cost: Dictionary) -> bool:
		return cost.keys().any(func(kind: String) -> bool: return harvested.has(kind)) and cost.keys().any(func(kind: String) -> bool: return hunted.has(kind)))
	_check(only.call(RecipeDB.UPGRADES, hunted) and only.call(BuildingDB.DEFENSE_UPGRADES, harvested) and mixed,
		"핵 창 비용: 제작대는 몬스터 재료, 방어는 채집 재료, 영토는 둘 다")
	var max_tier := 0
	for info: Dictionary in BuildingDB.TYPES.values():
		max_tier = maxi(max_tier, info.get("tier", 0))
	_check(max_tier <= BuildingDB.max_defense_tier(), "모든 건물을 방어 단계로 열 수 있음 (최고 %d단계)" % max_tier)
	_check(BuildingDB.player_passable("wood_door") and BuildingDB.player_passable("campfire") and BuildingDB.player_passable("gear_chest")
			and BuildingDB.player_passable("arrow_tower") and BuildingDB.player_passable("thunder_tower")
			and not BuildingDB.player_passable("wood_wall") and not BuildingDB.player_passable("essence_wall"),
		"벽만 플레이어를 막고 문·공성탑·생활 건물은 통과 (D-036)")
	_check(BuildingDB.TYPES["teleport_tower"].get("outside", false) and not BuildingDB.TYPES["stone_wall"].get("outside", false)
		and BuildingDB.TYPES["workbench"].get("unique", false), "순간이동 탑은 왕국 밖 가능, 벽은 안에만, 제작대는 하나만")
	_check(not Balance.RESOURCE_NAMES.has("gold"), "금은 자원이 아님 (경험치로 바뀜, D-015)")



## 보스(D-021): 보스 밤마다 다른 보스, 21일차는 최종 보스, 패턴 데이터가 맞고, 난이도는 가파르게 오른다
func _test_bosses_and_difficulty() -> void:
	var nights: Array[String] = []
	for day in range(3, Balance.FINAL_DAY + 1, 3):
		nights.append(EnemyDB.boss_for(day))
	var distinct := {}
	for id in nights:
		distinct[id] = true
	_check(distinct.size() == nights.size() and nights.size() == 7, "3~21일차 보스 밤마다 다른 보스 %s" % [nights])
	_check(EnemyDB.TYPES[EnemyDB.boss_for(Balance.FINAL_DAY)].get("final", false) and EnemyDB.boss_for(24) != EnemyDB.boss_for(21),
		"21일차는 최종 보스, 그 뒤 보스 밤에는 최종 보스가 반복되지 않음")
	var problems: Array[String] = []
	for id: String in EnemyDB.TYPES:
		var info: Dictionary = EnemyDB.TYPES[id]
		if not info.get("is_boss", false):
			continue
		if not EnemyDB.BOSS_ORDER.has(id):
			problems.append("%s 순서에 없음" % id)
		for pattern: Dictionary in info.get("patterns", []):
			if not pattern["type"] in ["radial", "spiral", "fan", "charge", "summon"] or pattern["interval"] <= 0.0:
				problems.append("%s 패턴 %s" % [id, pattern["type"]])
			if pattern["type"] == "summon" and not EnemyDB.TYPES.has(pattern["minion"]):
				problems.append("%s 부하 %s" % [id, pattern["minion"]])
		var last_at := 1.0
		for phase: Dictionary in info.get("rage", []):
			if phase["at"] >= last_at:
				problems.append("%s 분노 순서" % id)
			last_at = phase["at"]
	_check(problems.is_empty(), "보스 패턴·부하·분노 데이터가 맞음 %s" % [problems])
	var rising := true
	for day in range(2, Balance.FINAL_DAY + 1):
		rising = rising and Balance.wave_size(day) >= Balance.wave_size(day - 1) and Balance.wave_hp_scale(day) > Balance.wave_hp_scale(day - 1)
	_check(rising and Balance.wave_size(Balance.FINAL_DAY) == Balance.WAVE_SIZE_MAX and Balance.wave_hp_scale(Balance.FINAL_DAY) >= 9.0
		and Balance.wave_damage_scale(Balance.FINAL_DAY) >= 2.0,
		"난이도: 날마다 오르고 21일차 침공은 %d마리·체력 %.1f배·피해 %.1f배" % [Balance.wave_size(21), Balance.wave_hp_scale(21), Balance.wave_damage_scale(21)])
	_check(EnemyDB.invader_weights(1).keys() == ["slime"] and EnemyDB.invader_weights(11).has("fire_imp"),
		"침공 구성: 1일차는 슬라임만, 11일차부터 화염 정령까지 섞임")
	_check(is_equal_approx(Balance.boss_hp_scale(1), 1.0) and Balance.boss_hp_scale(4) > Balance.boss_hp_scale(2), "보스 체력은 플레이어 수만큼 늘어남")


## 패시브 트리(D-020) 데이터: 선행 노드가 같은 갈래에 있고, 노드 그래픽용 칸이 겹치지 않고, 무기 종류마다 숙련 노드가 있다
func _test_passive_tree() -> void:
	var problems: Array[String] = []
	var taken := {}
	for id: String in PassiveDB.PASSIVES:
		var info: Dictionary = PassiveDB.PASSIVES[id]
		var branch: String = info["branch"]
		if not PassiveDB.BRANCHES.has(branch) or info["lane"] >= PassiveDB.LANES[branch].size():
			problems.append("%s 갈래·묶음" % id)
		var key := "%s %s" % [branch, info["pos"]]
		if taken.has(key):
			problems.append("%s 칸 겹침(%s)" % [id, taken[key]])
		taken[key] = id
		for required: String in info["requires"]:
			if not PassiveDB.PASSIVES.has(required) or PassiveDB.PASSIVES[required]["branch"] != branch:
				problems.append("%s 선행 %s" % [id, required])
			elif PassiveDB.PASSIVES[required]["pos"].y >= info["pos"].y:
				problems.append("%s 선행이 위 행이 아님" % id)
	for item_id: String in ItemDB.ITEMS:
		var weapon: Dictionary = ItemDB.ITEMS[item_id].get("weapon", {})
		if not weapon.is_empty() and not PassiveDB.FAMILY_MASTERY.has(weapon.get("family", "")):
			problems.append("%s 무기 종류" % item_id)
	for family: String in PassiveDB.FAMILY_MASTERY:
		if not PassiveDB.PASSIVES.has(PassiveDB.FAMILY_MASTERY[family]):
			problems.append("%s 숙련 노드" % family)
	for branch: String in PassiveDB.BRANCHES:
		if PassiveDB.nodes_in(branch).is_empty():
			problems.append("%s 비어 있음" % branch)
	_check(problems.is_empty(), "패시브 트리: 선행·칸·무기 종류가 맞음 %s" % [problems])
	var unplaced := PassiveDB.PASSIVES.keys().filter(func(id: String) -> bool:
		return not PassiveArtDB.LAYOUT.has(id) or not PassiveArtDB.ICON_ORDER.has(id))
	_check(unplaced.is_empty() and PassiveDB.PASSIVES.size() >= 55, "모든 패시브 노드(%d개)가 패시브 창 배치에 있음 %s" % [PassiveDB.PASSIVES.size(), unplaced])


## 레벨·패시브(D-015, D-024): 레벨업마다 포인트 1개, 단계마다 1포인트, 죽으면 이번 레벨의 경험치만 사라진다
func _test_progression() -> void:
	var empty := PassiveDB.PASSIVES.keys().filter(func(id: String) -> bool: return PassiveDB.max_rank(id) < 1)
	_check(empty.is_empty(), "패시브 데이터: 모든 노드에 단계별 효과가 있음 %s" % [empty])
	_test_passive_tree()
	var progression := Progression.new()
	_check(progression.learn("vitality") != "" and progression.rank("vitality") == 0, "포인트가 없으면 배울 수 없음")
	var first := Balance.xp_to_next_level(1)
	_check(progression.add_xp(first - 1) == 0 and progression.level == 1 and progression.points == 0, "경험치가 덜 차면 레벨 그대로")
	_check(progression.add_xp(1 + 5) == 1 and progression.level == 2 and progression.points == 1 and progression.xp == 5,
		"경험치가 차면 레벨업, 포인트 1개, 넘친 경험치는 이어짐 (남은 %d)" % progression.xp)
	_check(Balance.xp_to_next_level(2) > first, "다음 레벨일수록 필요한 경험치가 늘어남")
	_check(progression.learn("vitality") == "" and progression.rank("vitality") == 1 and progression.points == 0,
		"포인트 1개로 1단계")
	_check(progression.value("vitality") == PassiveDB.value_at("vitality", 1), "단계에 맞는 효과 값")
	var several := Progression.new()
	_check(several.add_xp(Balance.xp_to_next_level(1) + Balance.xp_to_next_level(2)) == 2 and several.points == 2,
		"한 번에 많이 받으면 여러 레벨이 오름")
	progression.lose_level_progress()
	_check(progression.xp == 0 and progression.level == 2 and progression.rank("vitality") == 1, "죽으면 이번 레벨의 경험치만 사라지고 레벨·패시브는 남음")
	progression.add_xp(9999)
	for i in 10:
		progression.learn("swift")
	_check(progression.rank("swift") == PassiveDB.max_rank("swift") and progression.next_cost("swift") == -1, "최고 단계 이상은 못 올림")
	var tree := Progression.new()
	tree.add_xp(9999)
	_check(tree.learn("piercing_arrows").begins_with("먼저 배워야") and tree.rank("piercing_arrows") == 0, "선행 노드(궁술) 없이는 꿰뚫는 화살을 못 배움")
	tree.learn("bow_mastery")
	_check(tree.learn("piercing_arrows") == "", "선행 노드를 배우면 아래 노드가 열림")
	tree.learn("mending_walls")
	_check(tree.rank("mending_walls") == 0 and tree.learn("fortify") != "", "선행이 둘인 긴급 요새화는 둘 다 배워야 함")
	tree.learn("frugal_builder")
	var perks := tree.build_perks()
	_check(is_equal_approx(perks["discount"], 0.15) and is_equal_approx(perks["hp_scale"], 1.0), "건설 패시브 효과 값 (할인 %s)" % perks["discount"])
	_check(BuildingDB.discounted({"wood": 10, "stone": 1}, 0.3) == {"wood": 7, "stone": 1}, "건설 비용 할인은 반올림하고 최소 1개")
	_check(Balance.tower_xp_share(9, 1) == 9 and Balance.tower_xp_share(9, 4) == 3 and Balance.tower_xp_share(2, 4) == 1,
		"탑 처치 경험치는 플레이어 수로 나눔(올림)")
	var harvest_rng := RandomNumberGenerator.new()
	harvest_rng.seed = 7
	var harvest_hits := 0
	var harvest_wrong := false
	for i in 1000:
		var harvest_xp := Balance.roll_harvest_xp(2, harvest_rng)
		if harvest_xp > 0:
			harvest_hits += 1
		harvest_wrong = harvest_wrong or harvest_xp not in [0, Balance.XP_HARVEST_BY_TIER[2]]
	_check(not harvest_wrong and harvest_hits > 150 and harvest_hits < 250,
		"채집 경험치는 약 20%% 확률로만 나옴 (1000번 중 %d번)" % harvest_hits)


func _check(ok: bool, label: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + label)
	if not ok:
		_failures += 1
