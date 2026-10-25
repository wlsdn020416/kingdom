extends Node
## 게임 씬을 실제로 돌려서 핵심 흐름이 깨지지 않았는지 확인한다.
## 실행: godot --headless --path . res://tests/smoke_test.tscn
## 코드를 고친 뒤 이걸 돌려서 전부 OK면 기본 흐름은 살아 있다는 뜻이다.

var _failures := 0
var _heard: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _check_title()
	await _check_passive_graphics()
	Session.seed_text = "smoke-test"
	var main: Main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(5)
	await _check_audio(main)
	_check_terrain_tiles(main.world)
	_check_object_tiles(main.world)
	_check_health_bars(main)
	await _check_status_hud(main)
	_check_action_bar(main)
	await _check_weapon_art(main)
	_check_enemy_art(main)
	_check_building_art(main)
	_check_item_art(main)

	_check(main.world.data.is_explored(main.world.data.core_cell), "시작 지점 주변이 지도에 탐험됨")

	var wall_cell := main.kingdom.core_cell() + Vector2i(3, 0)
	var error := main.kingdom.build(wall_cell, "wood_wall", main.player.global_position)
	_check(error == "" and main.kingdom.buildings.has(wall_cell), "나무벽 건설 %s" % error)
	_check(main.kingdom.build(main.kingdom.core_cell() + Vector2i(30, 0), "wood_wall", main.player.global_position) != "", "영토 밖 건설은 거부됨")

	var dash_event := InputEventAction.new()
	dash_event.action = "dash"
	dash_event.pressed = true
	Input.parse_input_event(dash_event)
	await _frames(2)
	_check(main.player.dash_cooldown_left() > 0.0, "Space 대시는 장비 없이 사용 가능, 사용 후 쿨타임")
	_check(_heard.has("dash"), "실제로 성공한 대시가 효과음을 재생")
	main.player.equipment.add_to_bag("life_charm")
	main.player.equipment.equip("life_charm")
	main.player.use_skill(0)
	_check(not main.player.equipment.is_ready("life_charm"), "장착한 치유 부적이 스킬바 1번, 사용 후 쿨타임")
	_check(_heard.has("heal"), "치유 스킬은 탄 개수와 무관하게 한 번 재생")

	var resources_before := _total_resources(main)
	Events.chest_opened.emit(main.player.global_position, Enemy.SOURCE_LOCAL)
	_check(_total_resources(main) > resources_before, "상자 보상으로 자원 지급")

	await _check_harvest(main)
	await _check_melee(main)
	await _check_equipment_panel(main)
	await _check_build_menu(main)
	await _check_storage(main)
	await _check_workbench(main)
	await _check_progression(main)
	await _check_inventory(main)
	await _check_meeting(main)
	await _check_passive_tree(main)
	await _check_passive_expansion(main)
	await _check_building_catalog(main)
	await _check_feedback(main)
	await _check_bosses(main)

	main.day_night.skip_to_night()
	Engine.time_scale = 3.0
	await get_tree().create_timer(8.0 * 3.0).timeout
	_check(main.day_night.is_night(), "밤으로 전환")
	_check(main.spawner.invader_count() > 0, "침공 적 등장 (%d마리)" % main.spawner.invader_count())
	await get_tree().create_timer(14.0 * 3.0).timeout
	Engine.time_scale = 1.0
	_check(main.kingdom.core.hp < main.kingdom.core.max_hp or main.kills > 0 or main.kingdom.buildings.size() < 1,
		"침공 적이 왕국에 도달 (핵 %d, 처치 %d)" % [main.kingdom.core.hp, main.kills])

	main.kingdom.core.take_damage(999999.0)
	await _frames(3)
	_check(get_tree().paused and main.hud.game_over_panel.visible, "왕국 멸망 → 일시정지 + 멸망 화면")
	_check(_heard.has("core_destroyed"), "왕국 멸망음은 일시정지 뒤에도 재생 경로가 살아 있음")

	print("SMOKE TEST %s (실패 %d)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _check_audio(main: Main) -> void:
	var catalog := SoundDB.catalog()
	var count := 0
	var files_valid := true
	for id: String in catalog:
		for path: String in catalog[id]["paths"]:
			var stream := load(path) as AudioStreamWAV
			files_valid = files_valid and stream != null and stream.get_length() > 0.0 and not stream.stereo
			count += 1
	_check(catalog.size() == 43 and count == 168 and files_valid, "효과음 43종·168개 WAV가 전부 실제 오디오 스트림으로 로딩")
	var audio := main.sound_effects
	audio.played.connect(func(id: String, _at: Vector2) -> void: _heard.append(id))
	var at := main.player.global_position
	# 재생 요청만 성공하고 실제 출력은 무음인 경우도 잡는다. Dummy 드라이버도 믹서는 돈다.
	for voice in audio._ui_voices:
		voice.stop()
	var audio_capture := AudioEffectCapture.new()
	audio_capture.buffer_length = 1.0
	var effect_index := AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, audio_capture)
	audio.play("explosion", at)
	await get_tree().create_timer(0.3).timeout
	var buffer := audio_capture.get_buffer(audio_capture.get_frames_available())
	var peak := 0.0
	for sample in buffer:
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	AudioServer.remove_bus_effect(0, effect_index)
	_check(not buffer.is_empty() and peak > 0.001, "플레이어 위치의 2D 효과음은 실제 오디오 믹서에서 무음이 아닌 샘플을 출력")
	var rng_before := main.rng.state
	_check(not audio.play("없는_효과음") and not audio.play("stone_hit", at + Vector2(SoundEffects.AUDIBLE_DISTANCE + 1.0, 0)), "없는 효과음과 화면에서 너무 먼 위치음은 재생하지 않음")
	_check(audio.play("stone_hit", at) and not audio.play("stone_hit", at), "동일 효과음의 한 프레임 중복을 제한")
	_check(main.rng.state == rng_before, "효과음 변형 선택은 게임 결과용 난수를 소비하지 않음")
	for id: String in catalog:
		audio.play(id, at)
	_check(audio._world_voices.size() <= SoundEffects.MAX_WORLD_VOICES, "광역 공격에도 월드 음원 노드는 상한 안에서 재사용")
	await get_tree().create_timer(0.25).timeout
	get_tree().paused = true
	_check(audio.play("map_ping") and not audio.play("sword_swing", at), "일시정지 중 지도 핑·UI는 울리고 월드 효과음은 추가되지 않음")
	get_tree().paused = false
	await get_tree().create_timer(0.1).timeout
	_heard.clear()
	main.hud.equipment_panel.toggle()
	_check(_heard.has("open"), "I 장비창 열기는 표시 변화에 맞춰 효과음")
	main.hud.equipment_panel.hide()
	_check(_heard.has("close"), "Esc·닫기 경로도 같은 창 닫기 효과음")
	var requests: Array[String] = []
	var capture := func(id: String, _where: Vector2) -> void: requests.append(id)
	Events.world_sound_requested.connect(capture)
	var error := main.kingdom.build(main.kingdom.core_cell() + Vector2i(30, 0), "wood_wall", at)
	_check(error != "" and not requests.has("build"), "실패한 건설에는 설치 성공음이 없음")
	var cell := _find_tree_cluster(main.world)[0] as Vector2i
	main.world.apply_object_state(cell, main.world.data.object_hp[main.world.data.index(cell)] - 1.0)
	_check(requests.is_empty(), "동기화된 월드 체력을 적용할 때 결과음을 다시 내지 않음")
	Events.world_sound_requested.disconnect(capture)
	_heard.clear()
	main._update_footsteps(1.0)
	main._update_footsteps(1.0)
	_check(not _heard.any(func(id: String) -> bool: return id.begins_with("footstep_")), "정지·벽에 막혀 이동 거리가 없으면 발소리가 없음")
	main.player.global_position += Vector2(SoundDB.STEP_DISTANCE + 1.0, 0)
	main._update_footsteps(1.0)
	_check(_heard.any(func(id: String) -> bool: return id.begins_with("footstep_")), "실제 이동 거리가 쌓이면 지형에 맞는 발소리")
	_heard.clear()
	main.player.global_position = at
	main._update_footsteps(0.01)
	_check(_heard.is_empty(), "대시·부활처럼 빠른 위치 변화는 발소리로 세지 않음")


func _check_weapon_art(main: Main) -> void:
	var weapons := WeaponVisual.TEXTURE.get_image()
	var projectile_art := Projectile.TEXTURE.get_image()
	var effects := CombatEffect.TEXTURE.get_image()
	var weapon_rows: Array[int] = []
	for id: String in ItemDB.ITEMS:
		if not ItemDB.ITEMS[id].has("weapon") and id != "bomb_bag":
			continue
		_check(WeaponArtDB.WEAPONS.has(id), "%s 장비에는 무기 그림·모션이 정의됨" % id)
		if not WeaponArtDB.WEAPONS.has(id):
			continue
		var row: int = WeaponArtDB.WEAPONS[id]["row"]
		var complete := not weapon_rows.has(row)
		weapon_rows.append(row)
		for frame in WeaponArtDB.WEAPON_FRAMES:
			var region := WeaponArtDB.weapon_region(id, frame)
			var art := weapons.get_region(Rect2i(region))
			var bounds := art.get_used_rect()
			complete = complete and not art.is_invisible() and bounds.end.x < WeaponArtDB.WEAPON_SIZE.x and bounds.end.y < WeaponArtDB.WEAPON_SIZE.y
		var first := weapons.get_region(Rect2i(WeaponArtDB.weapon_region(id, 1))).get_data()
		var recovery := weapons.get_region(Rect2i(WeaponArtDB.weapon_region(id, 5))).get_data()
		_check(complete and first != recovery, "%s의 8프레임은 고유 행에 있고 무기 끝이 잘리지 않으며 공격·회복 자세가 다름" % id)
	for id: String in WeaponArtDB.PROJECTILES:
		var complete := true
		for frame in WeaponArtDB.PROJECTILE_FRAMES:
			complete = complete and not projectile_art.get_region(Rect2i(WeaponArtDB.projectile_region(id, frame * WeaponArtDB.PROJECTILE_FRAME_TIME + 0.001))).is_invisible()
		_check(complete, "%s 투사체의 모든 움직임 칸이 존재" % id)
	for id: String in WeaponArtDB.EFFECTS:
		var complete := true
		for frame in WeaponArtDB.EFFECT_FRAMES:
			complete = complete and not effects.get_region(Rect2i(WeaponArtDB.effect_region(id, float(frame) / WeaponArtDB.EFFECT_FRAMES))).is_invisible()
		_check(complete, "%s 공격 효과의 모든 프레임이 존재" % id)
	var visual := main.player.weapon_visual
	visual.attack("old_bow", Vector2.RIGHT)
	var frame := visual.pose_frame()
	visual._process(0.06)
	_check(visual.pose_frame() != frame and main.player._sprite.position != WeaponVisual.BODY_ORIGIN, "활 발사 뒤에는 무기 자세와 몸 반동이 함께 진행됨")
	visual.aim_direction = Vector2.UP
	_check(visual.attack_direction == Vector2.RIGHT, "공격 후 조준을 바꿔도 이미 시작한 모션 방향은 유지됨")
	visual.set_weapon("fire_staff")
	_check(not visual.is_attacking(), "무기를 바꾸면 이전 무기의 공격 모션을 끝냄")
	visual.set_weapon(main.player.equipment.item_in("weapon"))
	visual.attack("rusty_sword", Vector2.RIGHT, 40.0)
	_check(visual.slash_stretch().x > 1.0 and visual.slash_stretch().y > 1.0, "휩쓸기 패시브의 확장 각도를 검 궤적에 반영")
	visual._process(float(WeaponArtDB.WEAPONS["rusty_sword"]["duration"]))
	var target := Enemy.new().setup("brute", false)
	target.position = main.player.global_position + Vector2(160, 0)
	main.get_node("Enemies").add_child(target)
	var hp_before := target.hp
	var copy := Projectile.spawn(get_tree(), main.player.global_position, {"direction": Vector2.ZERO, "damage": 99999.0, "art": "fireball", "visual_only": true})
	await _frames(1)
	copy._on_hit(target)
	_check(target.hp == hp_before and not copy.hits_world, "다른 사람 탄의 표시 복제본은 적·월드 피해를 중복으로 주지 않음")
	copy.queue_free()
	target.queue_free()
	var old_hp := main.player.hp
	var effect := CombatEffect.spawn(get_tree(), "explosion", main.player.global_position, 1.0)
	await get_tree().create_timer(float(WeaponArtDB.EFFECTS["explosion"]["duration"]) + 0.1).timeout
	_check(not is_instance_valid(effect) and main.player.hp == old_hp, "폭발 그림은 피해를 직접 주지 않고 재생 후 제거됨")


func _check_action_bar(main: Main) -> void:
	var bar := main.hud._action_bar
	var atlas := ActionBar.TEXTURE.get_image()
	_check(atlas.get_size() == Vector2i(224, 72), "스킬바 아틀라스는 7종 아이콘과 4종 슬롯 상태를 포함")
	var regions: Array[Rect2] = []
	for skill_id: String in ActionBar.ICON_ORDER:
		var region := ActionBar.icon_region(skill_id)
		var picture := atlas.get_region(Rect2i(region))
		_check(not picture.is_invisible() and not regions.has(region), "%s 스킬은 고유한 픽셀 아이콘을 표시" % skill_id)
		regions.append(region)
	_check(bar._get_tooltip(bar.skill_slot_rect(0).get_center()).contains("Space")
		and bar._get_tooltip(bar.skill_slot_rect(1).get_center()).contains("자동 등록"),
		"기본 대시와 미장착 슬롯은 각각 단축키·장비 자동 등록 방법을 안내")
	var equipment := main.player.equipment
	var original_bag := equipment.bag.duplicate()
	var slots := ["weapon", "offhand", "armor", "charm"]
	var original_items: Array[String] = []
	for slot: String in slots:
		original_items.append(equipment.item_in(slot))
	for id: String in ["fire_staff", "bomb_bag", "guardian_armor", "life_charm"]:
		equipment.add_to_bag(id)
		equipment.equip(id)
	_check(equipment.skill_bar().size() == 4
		and bar._get_tooltip(bar.skill_slot_rect(1).get_center()).contains("화염구")
		and bar._get_tooltip(bar.skill_slot_rect(4).get_center()).contains("치유"),
		"장비 착용 시 하단 1~4칸 설명은 실제 자동 등록 순서를 따름")
	_check(bar.skill_slot_rect(1).position.x - bar.skill_slot_rect(0).end.x > ActionBar.GAP
		and bar.skill_slot_rect(4).end.x <= bar.size.x, "대시를 장비 스킬과 구분하고 마지막 슬롯도 HUD 안에 배치")
	for i in slots.size():
		if original_items[i].is_empty():
			equipment.unequip(slots[i])
		else:
			equipment.equip(original_items[i])
	equipment.bag.clear()
	for id: String in original_bag:
		equipment.add_to_bag(id)


func _check_status_hud(main: Main) -> void:
	var hud := main.hud
	_check(not hud._resource_drawer.visible and not hud._resource_toggle.button_pressed,
		"HUD 재화는 기본 접힘이며 성·내 체력과 시계를 상시 표시")
	var closed_height := hud._status_panel.size.y
	hud._resource_toggle.button_pressed = true
	await _frames(3)
	_check(hud._resource_drawer.visible and hud._status_panel.size.y > closed_height,
		"재화 버튼을 누르면 가방·창고 아이콘 영역을 아래로 펼침")
	var previous_materials := main.player.inventory.amounts()
	main.player.inventory.clear()
	main.player.inventory.add({"wood": 3})
	hud._process(0.0)
	var wood: Label = hud._resource_counts["bag"]["wood"]
	var stock_wood: Label = hud._resource_counts["stock"]["wood"]
	_check(wood.text == "3" and stock_wood.text == str(main.kingdom.stock.get("wood", 0)),
		"펼친 재화는 개인 가방과 공용 창고의 실제 수량을 구분해 갱신")
	var icon := wood.get_parent().get_child(0) as TextureRect
	_check(icon.texture is AtlasTexture and wood.get_parent().tooltip_text == "나무",
		"재료는 기존 픽셀 아이콘과 이름 툴팁을 사용")
	main.player.inventory.clear()
	main.player.inventory.add(previous_materials)
	hud._resource_toggle.button_pressed = false
	await _frames(3)
	_check(not hud._resource_drawer.visible and is_equal_approx(hud._status_panel.size.y, closed_height),
		"재화를 다시 접으면 패널 높이도 줄어들어 월드를 가리지 않음")
	var previous_time := main.day_night.time
	main.day_night.time = Balance.DAY_LENGTH * 0.5
	hud._process(0.0)
	_check(is_equal_approx(hud._clock_face.cycle, 0.25), "낮 절반에 시계 바늘은 낮 구간의 가운데를 가리킴")
	main.day_night.phase = DayNight.Phase.NIGHT
	main.day_night.time = Balance.NIGHT_LENGTH * 0.5
	hud._process(0.0)
	_check(hud._clock_face.night and is_equal_approx(hud._clock_face.cycle, 0.75),
		"밤 절반에 시계 바늘은 밤 구간의 가운데를 가리킴")
	main.day_night.phase = DayNight.Phase.DAY
	main.day_night.time = previous_time
	hud._process(0.0)


## 실제 I 창에서 장착·해제·재료 스택·호버 설명·닫기가 함께 동작해야 한다.
func _check_equipment_panel(main: Main) -> void:
	var player := main.player
	var panel := main.hud.equipment_panel
	var previous_position := player.global_position
	var previous_materials := player.inventory.amounts()
	var previous_armor := player.equipment.item_in("armor")
	main.spawner.set_physics_process(false)
	player.global_position = main.kingdom.core.global_position + Vector2(0, 9 * Balance.TILE)
	player.inventory.clear()
	player.inventory.add({"wood": Balance.STACK_SIZE + 3})
	player.equipment.add_to_bag("chain_mail")
	player.equipment.add_to_bag("iron_helm")
	var press := InputEventAction.new()
	press.action = "equipment"
	press.pressed = true
	Input.parse_input_event(press)
	await _frames(3)
	_check(panel.visible and not player.attack_enabled and not get_tree().paused
		and panel._slot_buttons.size() == ItemDB.SLOTS.size(), "I 창은 부위별 6칸으로 열리고 공격만 차단")
	_check(panel._bag.columns == EquipmentPanel.GRID_COLUMNS and panel._bag.get_child_count() >= EquipmentPanel.MIN_GEAR_CELLS,
		"장비 가방은 여섯 열 격자로 표시하고 빈칸은 용량 제한을 만들지 않음")
	var armor_button: Button
	var helm_button: Button
	for button: Button in panel._bag.get_children():
		var label := button.get_node_or_null("Name") as Label
		if label != null and label.text == ItemDB.ITEMS["chain_mail"]["name"]:
			armor_button = button
		if label != null and label.text == ItemDB.ITEMS["iron_helm"]["name"]:
			helm_button = button
	if helm_button != null:
		helm_button.mouse_entered.emit()
	_check(panel._tooltip.visible and panel._highlighted_slot == "head" and panel._tooltip_name.text == "철 투구",
		"장비 호버는 설명창과 장착될 부위를 함께 표시")
	if armor_button != null:
		armor_button.pressed.emit()
	_check(player.equipment.item_in("armor") == "chain_mail"
		and panel._slot_buttons["armor"].get_node("Name").text == "사슬 갑옷", "가방 칸 클릭은 장착 명령과 마네킹 표시를 갱신")
	panel._slot_buttons["armor"].pressed.emit()
	_check(player.equipment.item_in("armor") == "" and player.equipment.bag.has("chain_mail")
		and panel._slot_buttons["weapon"].disabled, "착용 칸 클릭으로 해제하고 무기는 해제할 수 없음")
	panel._tabs.current_tab = 1
	await _frames(2)
	_check(not panel._tooltip.visible and panel._materials.get_child_count() == player.inventory.capacity()
		and panel._last_materials.get("wood", 0) == Balance.STACK_SIZE + 3 and player.inventory.used_slots() == 2,
		"재료 탭은 실제 가방 용량과 50개씩 나눈 스택을 표시")
	player.inventory.take("wood", Balance.STACK_SIZE)
	panel._process(EquipmentPanel.MATERIAL_POLL_TIME)
	_check(panel._last_materials.get("wood", 0) == 3 and panel._material_count.text.begins_with("1 /"),
		"재료 소비·입고 변화는 열린 창에 즉시 반영")
	panel._show_material_tooltip("wood", 3)
	await _frames(3)
	var viewport := panel.get_viewport_rect()
	_check(panel._tooltip.visible and panel._tooltip_kind.text.contains("3개")
		and viewport.encloses(panel._tooltip.get_rect()), "재료 설명은 수량을 표시하고 화면 밖으로 나가지 않음")
	press = InputEventAction.new()
	press.action = "ui_cancel"
	press.pressed = true
	Input.parse_input_event(press)
	await _frames(2)
	_check(not panel.visible and not panel._tooltip.visible and player.attack_enabled, "Esc는 장비창과 설명창을 닫고 공격을 복구")
	player.inventory.clear()
	player.inventory.add(previous_materials)
	if previous_armor != "":
		player.equipment.equip(previous_armor)
	player.equipment.remove_from_bag("chain_mail")
	player.equipment.remove_from_bag("iron_helm")
	player.global_position = previous_position
	main.spawner.set_physics_process(true)


## 설치물과 제작대 모든 단계가 같은 한 칸 충돌 안에 그려져야 한다.
func _check_building_art(main: Main) -> void:
	var image := Building.SPRITE_TEXTURE.get_image()
	var expected := BuildingDB.ORDER.size() + RecipeDB.max_tier()
	var artwork_ok := image.get_size() == Vector2i(expected * 64, Building.ART_FRAMES * 96)
	var regions: Dictionary = {}
	var pixels: Array[PackedByteArray] = []
	var rules_ok := true
	for id: String in BuildingDB.ORDER:
		var info: Dictionary = BuildingDB.TYPES[id]
		var count := RecipeDB.max_tier() + 1 if info.get("workbench", false) else 1
		artwork_ok = artwork_ok and not info.has("tint")
		for tier in count:
			var region := Building.sprite_region(id, tier)
			artwork_ok = artwork_ok and not regions.has(region)
			regions[region] = true
			var base := image.get_region(Rect2i(region)).get_data()
			artwork_ok = artwork_ok and not pixels.has(base)
			pixels.append(base)
			for frame in Building.ART_FRAMES:
				var art := image.get_region(Rect2i(Building.sprite_region(id, tier, frame)))
				var bounds := art.get_used_rect()
				artwork_ok = artwork_ok and bounds.has_area() and bounds.position.y >= int(Building.sprite_top(id, tier)) and bounds.end.x <= 64 and bounds.end.y <= 96
			if id in Building.ANIMATED_ART and (id != "workbench" or tier == RecipeDB.max_tier()):
				artwork_ok = artwork_ok and base != image.get_region(Rect2i(Building.sprite_region(id, tier, 1))).get_data()
		var building := Building.new().setup(id, Vector2i.ZERO)
		main.add_child(building)
		building.set_physics_process(false)
		var collider := building.get_child(0) as CollisionShape2D
		rules_ok = rules_ok and (collider.shape as RectangleShape2D).size == Vector2(32, 32)
		building.take_damage(1.0)
		rules_ok = rules_ok and building.hp == float(info["hp"]) - 1.0
		building.queue_free()
	_check(artwork_ok and regions.size() == expected, "건물 19종·제작대 4단계의 고유 외형·4프레임·체력바 높이가 유효")
	_check(rules_ok, "설치물 그래픽 교체 후 한 칸 충돌과 피해 판정 유지")


func _check_item_art(main: Main) -> void:
	var art := ItemArtDB.ICONS.get_image()
	var used: Array[Rect2] = []
	var complete := ItemArtDB.ORDER.size() == ItemDB.ITEMS.size()
	for id: String in ItemDB.ITEMS:
		var icon := ItemArtDB.icon(id)
		complete = complete and icon != null
		if icon != null:
			complete = complete and not used.has(icon.region) and not art.get_region(Rect2i(icon.region)).is_invisible()
			used.append(icon.region)
	_check(complete, "장비 15종 전체에 고유 아이콘이 있음")
	var worn := EquipmentVisual.TEXTURE.get_image()
	var poses_ok := true
	for row in ItemArtDB.WORN_ORDER.size():
		for frame in ItemArtDB.WORN_FRAMES:
			poses_ok = poses_ok and not worn.get_region(Rect2i(frame * 24, row * 24, 24, 24)).is_invisible()
	_check(poses_ok, "착용 장비 10종 모두 정면·뒷면·측면 걷기 12자세를 지원")
	for kind: String in Balance.RESOURCE_NAMES:
		var icon := ItemArtDB.material_icon(kind)
		_check(icon != null and not icon.atlas.get_image().get_region(Rect2i(icon.region)).is_invisible(), "건설 재료 아이콘 %s" % kind)
	var previous := main.player.equipment.equipped.duplicate()
	var previous_hp := main.player.hp
	main.player.equipment.add_to_bag("iron_helm")
	main.player.equipment.equip("iron_helm")
	_check(main.player.equipment_visual._items.get("head") == "iron_helm", "장착 명령이 캐릭터 머리 외형을 갱신")
	main.player.equipment.unequip("head")
	_check(not main.player.equipment_visual._items.has("head"), "장비 해제 시 착용 오버레이 제거")
	if previous["head"] != "":
		main.player.equipment.equip(previous["head"])
	main.player.hp = previous_hp
	var remote := RemotePlayer.new().setup(999, "외형 검사", Vector2.ZERO)
	main.add_child(remote)
	remote.apply_state(Vector2.ZERO, Vector2.RIGHT, 5, true, true, false, "old_bow", {"head": "iron_helm", "armor": "flame_armor", "charm": "unknown"})
	_check(remote.equipment_visual._items.get("head") == "iron_helm" and remote.equipment_visual._items.get("armor") == "flame_armor" and not remote.equipment_visual._items.has("charm"), "원격 캐릭터는 같은 착용 원본을 쓰고 잘못된 장비 ID는 무시")
	remote.queue_free()


## 모든 적의 그림이 존재하고 움직임·피격 표시가 기존 충돌과 피해 판정을 유지해야 한다.
func _check_enemy_art(main: Main) -> void:
	var image := Enemy.SPRITE_TEXTURE.get_image()
	# 보스 7종은 보스 행 하나를 색(tint)만 바꿔 함께 쓴다 (D-021, 임시). 일반 적은 종류마다 자기 행이 있어야 한다
	var boss_row: int = EnemyDB.TYPES["boss"]["sprite_row"]
	var row_count := 0
	for id: String in EnemyDB.TYPES:
		if not EnemyDB.TYPES[id].get("is_boss", false) or id == "boss":
			row_count += 1
	var atlas_ok := image.get_size() == Vector2i(Enemy.SPRITE_SIZE * Enemy.ANIMATION_FRAMES, Enemy.SPRITE_SIZE * row_count)
	var rows: Dictionary = {}
	var motion_ok := true
	var rules_ok := true
	for id: String in EnemyDB.TYPES:
		var stats: Dictionary = EnemyDB.TYPES[id]
		var row: int = stats["sprite_row"]
		var top: int = stats["sprite_top"]
		var shared_boss_art: bool = stats.get("is_boss", false) and id != "boss"
		if shared_boss_art:
			atlas_ok = atlas_ok and row == boss_row
		elif row < 0 or row >= row_count or rows.has(row):
			atlas_ok = false
			continue
		rows[row] = true
		for frame in Enemy.ANIMATION_FRAMES:
			var painted := false
			for y in Enemy.SPRITE_SIZE:
				for x in Enemy.SPRITE_SIZE:
					if image.get_pixel(frame * Enemy.SPRITE_SIZE + x, row * Enemy.SPRITE_SIZE + y).a > 0.0:
						painted = true
						atlas_ok = atlas_ok and y >= top
			atlas_ok = atlas_ok and painted
		var enemy := Enemy.new().setup(id, true)
		main.get_node("Enemies").add_child(enemy)
		enemy.set_physics_process(false)
		enemy.velocity = Vector2.LEFT * 10.0
		enemy._update_animation(0.13)
		motion_ok = motion_ok and enemy._facing_left and enemy._animation_frame == 1
		enemy.velocity = Vector2.RIGHT * 10.0
		enemy._update_animation(0.13)
		motion_ok = motion_ok and not enemy._facing_left
		enemy.velocity = Vector2.ZERO
		enemy._update_animation(0.13)
		if id not in Enemy.IDLE_ANIMATED and not enemy.is_boss():
			motion_ok = motion_ok and enemy._animation_frame == 0
		var collider := enemy.get_child(0) as CollisionShape2D
		rules_ok = rules_ok and is_equal_approx((collider.shape as CircleShape2D).radius, stats["radius"])
		enemy.take_damage(1.0)
		rules_ok = rules_ok and is_equal_approx(enemy.hp, float(stats["hp"]) - 1.0) and enemy._flash > 0.0
		enemy.queue_free()
	_check(atlas_ok, "적 그림 %d행의 모든 프레임과 체력바용 그림 높이가 유효 (보스는 한 행 공유)" % row_count)
	_check(motion_ok, "적은 이동 시 프레임·좌우 방향이 바뀌고 정지 시 걷기를 멈춤")
	_check(rules_ok, "적 그래픽 교체 후에도 종류별 충돌·피해·피격 표시가 유지")


## 체력바 그림 교체가 표시 수명이나 실제 체력을 바꾸면 안 된다.
func _check_health_bars(main: Main) -> void:
	var world := main.world
	var cell := _find_tree(world)
	if cell == World.NO_CELL:
		_check(false, "체력바 검사에 쓸 나무를 찾음")
		return
	world.damage_object(cell, 1.0, World.NOBODY)
	var hp := world.data.object_hp[world.data.index(cell)]
	_check(world._hp_bar_time.has(cell) and world._hp_overlay.z_index > world.object_layer.z_index,
		"손상된 채집물의 체력바가 오브젝트 위에 표시됨")
	world._process(World.HP_BAR_TIME + 0.01)
	_check(not world._hp_bar_time.has(cell) and world.data.object_hp[world.data.index(cell)] == hp,
		"4초 뒤 체력바만 숨고 채집물 체력은 그대로 유지")
	world.damage_object(cell, 1.0, World.NOBODY)
	world.damage_object(cell, hp, World.NOBODY)
	_check(not world._hp_bar_time.has(cell) and world.data.get_object(cell) == WorldData.Obj.NONE,
		"채집물이 부서지면 체력바도 함께 제거")
	_check(main.hud._hp_bar.get_theme_stylebox("fill") is StyleBoxTexture
		and main.hud._core_bar.get_theme_stylebox("background") is StyleBoxTexture,
		"플레이어·왕국 HUD에도 같은 픽셀아트 체력바 사용")


## 키가 큰 나무도 기존 채집 칸과 충돌을 유지하고, 없는 생성물 칸은 투명해야 한다.
func _check_object_tiles(world: World) -> void:
	var source: TileSetAtlasSource = world.object_layer.tile_set.get_source(TilesetBuilder.OBJECT_SOURCE)
	var image := source.texture.get_image()
	var artwork_ok := image.get_size() == Vector2i(WorldData.Obj.size() * Balance.TILE, TilesetBuilder.OBJECT_HEIGHT)
	var collision_ok := true
	var alignment_ok := true
	for obj in WorldData.Obj.size():
		var coords := Vector2i(obj, 0)
		if not source.has_tile(coords):
			artwork_ok = false
			continue
		var tile := source.get_tile_data(coords, 0)
		var expected := 0 if obj == WorldData.Obj.NONE else 1
		collision_ok = collision_ok and tile.get_collision_polygons_count(TilesetBuilder.OBJECT_PHYSICS_LAYER) == expected
		if expected == 1:
			var points := tile.get_collision_polygon_points(TilesetBuilder.OBJECT_PHYSICS_LAYER, 0)
			collision_ok = collision_ok and points.size() == 4 and points[0] == Vector2(-14, -14) and points[2] == Vector2(14, 14)
		alignment_ok = alignment_ok and tile.texture_origin == Vector2i(0, -8)
		var painted := false
		for y in image.get_height():
			for x in Balance.TILE:
				painted = painted or image.get_pixel(obj * Balance.TILE + x, y).a > 0.0
		artwork_ok = artwork_ok and painted == (obj != WorldData.Obj.NONE)
	_check(artwork_ok, "생성물 그림은 모두 존재하고 NONE 칸은 투명")
	_check(collision_ok, "생성물 충돌은 기존 28×28을 유지하고 NONE에는 없음")
	_check(alignment_ok, "48픽셀 생성물의 바닥은 기존 32픽셀 칸에 정렬")


## 바닥 변형을 늘려도 빈 아틀라스 칸이나 충돌 없는 물이 생기지 않아야 한다.
func _check_terrain_tiles(world: World) -> void:
	var tile_set := world.terrain_layer.tile_set
	var source: TileSetAtlasSource = tile_set.get_source(TilesetBuilder.TERRAIN_SOURCE)
	var complete := source.texture.get_size() == Vector2(WorldData.Terrain.size() * Balance.TILE, TilesetBuilder.TERRAIN_VARIANTS * Balance.TILE)
	var collision_ok := true
	for terrain in WorldData.Terrain.size():
		for variant in TilesetBuilder.TERRAIN_VARIANTS:
			var coords := Vector2i(terrain, variant)
			if not source.has_tile(coords):
				complete = false
				continue
			var tile := source.get_tile_data(coords, 0)
			var expected := 1 if terrain == WorldData.Terrain.WATER else 0
			collision_ok = collision_ok and tile.get_collision_polygons_count(TilesetBuilder.WATER_PHYSICS_LAYER) == expected
	_check(complete, "모든 지형·변형의 32×32 바닥 그림이 존재")
	_check(collision_ok, "모든 물 변형에 충돌이 있고 육지 바닥에는 없음")
	var used_variants: Dictionary = {}
	var cells_ok := true
	for cell in world.terrain_layer.get_used_cells():
		var coords := world.terrain_layer.get_cell_atlas_coords(cell)
		cells_ok = cells_ok and coords.x == world.data.get_terrain(cell) and source.has_tile(coords)
		used_variants[coords.y] = true
	_check(cells_ok and used_variants.size() == TilesetBuilder.TERRAIN_VARIANTS, "월드는 지형에 맞는 그림을 쓰고 모든 바닥 변형을 섞음")


## 왼쪽 두 칸이 비어 있는 나무 (왼쪽에서 오른쪽으로 공격하기 위해)
func _find_tree(world: World) -> Vector2i:
	for radius in range(Balance.TERRITORY_RADIUS + 1, 60):
		for x in range(-radius, radius + 1):
			var cell := world.data.core_cell + Vector2i(x, radius)
			if world.data.get_object(cell) == WorldData.Obj.TREE and world.data.is_walkable(cell + Vector2i.LEFT) and world.data.is_walkable(cell + Vector2i(-2, 0)):
				return cell
	return World.NO_CELL


## 나무 옆에서 투사체를 쏴서 채집이 되는지 확인
func _check_harvest(main: Main) -> void:
	var world := main.world
	var tree_cell := _find_tree(world)
	if tree_cell == World.NO_CELL:
		_check(false, "채집 테스트용 나무를 찾지 못함")
		return
	# 돌아다니는 적이 탄을 막지 않게 잠시 치운다
	main.spawner.set_physics_process(false)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	await _frames(2)
	var wood_before := _wood(main)
	for shot in 5:
		Projectile.spawn(get_tree(), world.cell_center(tree_cell) - Vector2(56, 0), {"direction": Vector2.RIGHT, "damage": 10.0})
		await get_tree().create_timer(0.15).timeout
	await _frames(5)
	_check(world.data.get_object(tree_cell) == WorldData.Obj.NONE and _wood(main) > wood_before,
		"투사체로 나무 채집 (나무 %d → %d)" % [wood_before, _wood(main)])
	main.spawner.set_physics_process(true)


## 시작 무기(근거리)로 좌클릭하면 앞의 적이 맞고, 휘두르기로 나무도 채집되는지 확인
func _check_melee(main: Main) -> void:
	var player := main.player
	main.spawner.set_physics_process(false)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	await _frames(2)
	var target := Enemy.new().setup("brute", false)
	target.position = player.global_position + player.aim_direction * 30.0
	main.get_node("Enemies").add_child(target)
	await _frames(2)
	Input.action_press("attack")
	await _frames(3)
	Input.action_release("attack")
	_check(target.hp < target.max_hp, "근거리 기본 공격이 앞의 적에게 맞음 (체력 %d/%d)" % [target.hp, target.max_hp])
	_check(player.weapon_visual.slash_visible() and player.weapon_visual.attack_item == "rusty_sword" and player.weapon_visual.attack_direction.is_normalized(),
		"기본 검 타격과 함께 공격 방향·궤적 재생이 시작됨")
	_check(WeaponVisual.TEXTURE.get_size() == Vector2(512, 384) and WeaponVisual.EFFECT_TEXTURE.get_size() == Vector2(768, 640),
		"무기 6종·8프레임과 공격 효과 5종·6프레임 그림이 로드됨")
	await get_tree().create_timer(WeaponArtDB.SLASH_TIME + 0.02).timeout
	_check(not player.weapon_visual.slash_visible(), "버튼을 놓으면 공격 궤적이 재생 시간 뒤 종료됨")
	target.queue_free()

	var world := main.world
	var tree_cell := _find_tree(world)
	var wood_before := _wood(main)
	for swing in 3:
		Melee.swing(get_tree(), world.cell_center(tree_cell) - Vector2(40, 0), Vector2.RIGHT, player.equipment.weapon())
	await _frames(2)
	_check(tree_cell != World.NO_CELL and world.data.get_object(tree_cell) == WorldData.Obj.NONE and _wood(main) > wood_before,
		"근거리 공격으로 나무 채집")
	main.spawner.set_physics_process(true)


## 개인 인벤토리(D-014): 보상은 가방으로, 비용은 가방 먼저, 핵 근처에서 창고로 입고, 죽으면 가방 비움
func _check_inventory(main: Main) -> void:
	var player := main.player
	var kingdom := main.kingdom
	player.global_position = kingdom.core.global_position + Vector2(0, 9 * Balance.TILE)
	await _frames(2)
	player.inventory.clear()
	var stock_before: Dictionary = kingdom.stock.duplicate()
	Events.resources_gained.emit({"wood": 3, "stone": 2}, player.global_position)
	await _frames(2)
	_check(player.inventory.count("wood") == 3 and kingdom.stock["wood"] == stock_before["wood"],
		"핵에서 먼 곳의 보상은 개인 인벤토리로 (가방 나무 %d)" % player.inventory.count("wood"))

	var cell := World.NO_CELL
	for offset in [Vector2i(-2, 9), Vector2i(2, 9), Vector2i(-2, 7), Vector2i(2, 7), Vector2i(0, 11)]:
		var candidate: Vector2i = kingdom.core_cell() + offset
		if main.world.data.is_walkable(candidate) and not kingdom.is_occupied(candidate):
			cell = candidate
			break
	var error := kingdom.build(cell, "wood_wall", player.global_position, player.inventory)
	_check(error == "" and player.inventory.count("wood") == 0 and kingdom.stock["wood"] == stock_before["wood"] - 2,
		"건설 비용은 가방 먼저, 모자란 만큼 창고에서 (%s, 창고 나무 %d)" % [error, kingdom.stock["wood"]])

	player.global_position = player.spawn_point
	await _frames(3)
	_check(player.inventory.is_empty() and kingdom.stock["stone"] == stock_before["stone"] + 2,
		"핵 근처에 오면 가방 자원이 창고로 자동 입고")

	player.global_position = kingdom.core.global_position + Vector2(0, 9 * Balance.TILE)
	player.inventory.add({"copper": 5})
	player.equipment.add_to_bag("iron_helm")
	await _kill_player(player)
	_check(player.is_dead and player.inventory.is_empty() and player.equipment.bag.is_empty(), "죽으면 가방 자원과 가방 장비가 모두 사라짐 (사망 %s, 가방 %s, 장비 %s)" % [player.is_dead, player.inventory.amounts(), player.equipment.bag])


## B는 건설 메뉴(게임은 계속 진행), 고르면 그 건물의 설치 모드, 설치 중 B는 메뉴로 돌아감
func _check_build_menu(main: Main) -> void:
	var press := func(action: String) -> void:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = true
		Input.parse_input_event(event)
	press.call("build_toggle")
	await _frames(2)
	_check(main.hud.build_menu.visible and not main.build_mode.active and not get_tree().paused and not main.player.attack_enabled,
		"B로 건설 메뉴가 열리고 게임은 멈추지 않음")
	var listed := 0
	var icons_ok := true
	for category: String in BuildingDB.CATEGORIES:
		main.hud.build_menu.show_category(category)
		await _frames(1)
		var buttons := main.hud.build_menu._list.get_children().filter(func(node: Node) -> bool: return not node.is_queued_for_deletion())
		listed += buttons.size()
		for button: Button in buttons:
			icons_ok = icons_ok and button.icon is AtlasTexture and (button.icon as AtlasTexture).atlas == Building.SPRITE_TEXTURE
	_check(icons_ok and listed == BuildingDB.ORDER.size(), "B 메뉴는 벽·공성탑·생활 탭에 모든 건물(%d)을 실제 설치물 그림으로 보여줌" % listed)
	main.hud.build_menu.show_category("siege")
	await _frames(1)
	var locked_card: BuildCard = main.hud.build_menu._list.get_child(3)
	locked_card.pressed.emit()
	_check(main.hud.build_menu._selected == "frost_tower" and main.hud.build_menu._choose.disabled and not main.build_mode.active, "잠긴 건물 카드도 상세를 볼 수 있고 설치는 잠김")
	main.hud.build_menu.choose("frost_tower")
	_check(main.hud.build_menu.visible and not main.build_mode.active, "해금 전 건물은 메뉴에서 설치 모드 진입 거부")
	main.hud.build_menu.show_category("wall")
	main.hud.build_menu.choose("stone_wall")
	await _frames(1)
	_check(not main.hud.build_menu.visible and main.build_mode.active and main.build_mode.selected_type() == "stone_wall",
		"메뉴에서 고르면 그 건물의 설치 모드")
	press.call("build_toggle")
	await _frames(2)
	_check(main.hud.build_menu.visible and not main.build_mode.active, "설치 중 B는 건설 메뉴로 돌아감")
	press.call("ui_cancel")
	await _frames(2)
	_check(not main.hud.build_menu.visible and not main.build_mode.active, "Esc로 건설 메뉴 닫힘")


## 장비 상자(D-014): 맡기기·꺼내기, 비어 있지 않으면 철거 불가, E로 창 열기
func _check_storage(main: Main) -> void:
	var player := main.player
	var kingdom := main.kingdom
	player.global_position = player.spawn_point
	await _frames(2)
	kingdom.add_resources({"wood": 15})
	var cell := World.NO_CELL
	for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1)]:
		var candidate: Vector2i = main.world.cell_at(player.spawn_point) + offset
		if main.world.data.is_walkable(candidate) and not kingdom.is_occupied(candidate):
			cell = candidate
			break
	var error := kingdom.build(cell, "gear_chest", player.global_position, player.inventory)
	_check(error == "" and kingdom.find_storage_near(player.global_position) == cell, "장비 상자 건설 %s" % error)
	if error != "":
		return
	# 앞의 상자 보상이 무작위로 같은 장비를 넣었을 수 있어 가방을 비우고 시작한다
	player.equipment.lose_bag()
	player.equipment.add_to_bag("chain_mail")
	error = kingdom.store_item(cell, player.equipment, "chain_mail", player.global_position)
	var building: Building = kingdom.buildings[cell]
	_check(error == "" and building.stored == ["chain_mail"] and not player.equipment.bag.has("chain_mail"),
		"가방 장비를 장비 상자에 맡김 %s" % error)
	_check(kingdom.store_item(cell, player.equipment, "chain_mail", player.global_position) != "", "가방에 없는 장비는 맡길 수 없음")
	_check(kingdom.take_item(cell, player.equipment, "chain_mail", player.global_position + Vector2(0, 10 * Balance.TILE)) != "",
		"멀리서는 꺼낼 수 없음")
	_check(kingdom.demolish(cell) != "" and kingdom.buildings.has(cell), "장비가 든 상자는 철거할 수 없음")

	var interact := InputEventAction.new()
	interact.action = "interact"
	interact.pressed = true
	Input.parse_input_event(interact)
	await _frames(2)
	_check(main.hud.storage_panel.visible and not player.attack_enabled, "E로 장비 상자 창이 열리고 공격이 꺼짐")
	main.hud.storage_panel.hide()

	error = kingdom.take_item(cell, player.equipment, "chain_mail", player.global_position)
	_check(error == "" and building.stored.is_empty() and player.equipment.bag.has("chain_mail"), "장비 상자에서 가방으로 꺼냄 %s" % error)
	_check(kingdom.demolish(cell) == "" and not kingdom.buildings.has(cell), "빈 장비 상자는 철거 가능")


## 제작대(D-014): 하나만, 공개된 레시피·단계 조건으로 제작, 업그레이드, 단계 오른 제작대는 철거 불가
func _check_workbench(main: Main) -> void:
	var player := main.player
	var kingdom := main.kingdom
	player.global_position = player.spawn_point
	player.equipment.lose_bag()
	await _frames(2)
	kingdom.add_resources({"wood": 100, "stone": 100})
	var cells: Array[Vector2i] = []
	for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 1)]:
		var candidate: Vector2i = main.world.cell_at(player.spawn_point) + offset
		if main.world.data.is_walkable(candidate) and not kingdom.is_occupied(candidate):
			cells.append(candidate)
	var error := kingdom.build(cells[0], "workbench", player.global_position, player.inventory)
	_check(error == "" and kingdom.workbench_tier() == 0, "제작대 건설, 0단계 %s" % error)
	_check(kingdom.build(cells[1], "workbench", player.global_position, player.inventory) != "", "제작대는 하나만 지을 수 있음")

	_check(kingdom.craft("old_bow", player.global_position, player.inventory, player.equipment) == "" and player.equipment.bag.has("old_bow"),
		"0단계 레시피(낡은 활) 제작 → 가방")
	_check(kingdom.craft("old_bow", player.global_position + Vector2(0, 10 * Balance.TILE), player.inventory, player.equipment) != "",
		"제작대에서 멀면 제작 불가")
	_check(kingdom.craft("chain_mail", player.global_position, player.inventory, player.equipment) == "아직 모르는 레시피입니다",
		"구리·질긴 가죽을 얻기 전에는 사슬 갑옷 레시피를 모름")
	var revealed := kingdom.discover({"copper": 1, "tough_hide": 1})
	_check(revealed.has("chain_mail"), "바이옴 재료를 처음 얻으면 사슬 갑옷 레시피 공개 %s" % [revealed])
	kingdom.add_resources({"copper": 20, "tough_hide": 10, "venom_sting": 10})
	_check(kingdom.craft("chain_mail", player.global_position, player.inventory, player.equipment).contains("1단계"), "단계가 모자라면 제작 불가")

	error = kingdom.upgrade_workbench(player.global_position, player.inventory)
	_check(error == "" and kingdom.workbench_tier() == 1, "희귀 재료로 제작대 1단계 업그레이드 %s" % error)
	var upgraded_region := Building.sprite_region("workbench", kingdom.workbench_tier())
	_check(upgraded_region != Building.sprite_region("workbench", 0), "제작대 업그레이드 후 단계별 그림으로 전환")
	_check(kingdom.craft("chain_mail", player.global_position, player.inventory, player.equipment) == "", "1단계가 되면 사슬 갑옷 제작")
	_check(kingdom.demolish(cells[0]) != "" and kingdom.workbench_tier() == 1, "단계를 올린 제작대는 철거할 수 없음")

	var interact := InputEventAction.new()
	interact.action = "interact"
	interact.pressed = true
	Input.parse_input_event(interact)
	await _frames(2)
	_check(main.hud.crafting_panel.visible, "E로 제작대 창이 열림")
	main.hud.crafting_panel.hide()

	kingdom.buildings[cells[0]].take_damage(99999.0)
	await _frames(2)
	_check(kingdom.workbench_tier() == -1, "제작대가 부서지면 단계도 사라짐")


## 경험치(D-015): 처치·채집·제작으로 얻고, 패시브가 실제 효과를 내며, 죽으면 쓰지 않은 경험치만 사라짐
func _check_progression(main: Main) -> void:
	var player := main.player
	var progression := player.progression
	var world := main.world
	player.global_position = player.spawn_point
	await _frames(2)
	progression.lose_unspent()

	var tree_cell := _find_tree(world)
	Melee.swing(get_tree(), world.cell_center(tree_cell) - Vector2(40, 0), Vector2.RIGHT, {"damage": 999.0, "range": 52.0, "arc": 120.0})
	await _frames(2)
	_check(progression.xp > 0, "채집하면 경험치 (경험치 %d)" % progression.xp)

	var xp_before := progression.xp
	var slime := Enemy.new().setup("slime", false)
	slime.position = player.global_position + Vector2(200, 0)
	main.get_node("Enemies").add_child(slime)
	await _frames(1)
	slime.take_damage(9999.0)
	await _frames(2)
	_check(progression.xp == xp_before + int(EnemyDB.TYPES["slime"]["xp"]), "적을 처치하면 경험치")

	xp_before = progression.xp
	var wolf := Enemy.new().setup("wolf", false)
	wolf.position = player.global_position + Vector2(200, 0)
	main.get_node("Enemies").add_child(wolf)
	await _frames(1)
	wolf.take_damage(9999.0, Enemy.SOURCE_TOWER)
	await _frames(2)
	_check(progression.xp == xp_before + Balance.tower_xp_share(EnemyDB.TYPES["wolf"]["xp"], 1), "탑이 잡은 적의 경험치도 플레이어 수로 나눠 받음 (1인)")

	xp_before = progression.xp
	Events.item_crafted.emit("old_bow", Enemy.SOURCE_LOCAL)
	_check(progression.xp == xp_before + Balance.XP_CRAFT_BY_TIER[0], "제작하면 경험치")

	progression.add_xp(500)
	var hp_before := player.max_hp()
	progression.learn("vitality")
	progression.learn("deep_pockets")
	_check(player.max_hp() > hp_before and player.inventory.capacity() > Balance.INVENTORY_SLOTS, "강인함·큰 가방 패시브가 체력·가방에 적용")

	progression.learn("bountiful")  # 광역 채집의 선행 노드 (D-020)
	progression.learn("wide_harvest")
	progression.learn("wide_harvest")
	var cluster := _find_tree_cluster(world)
	if cluster.is_empty():
		_check(false, "광역 채집 테스트용 나무 무리를 찾지 못함")
	else:
		var center: Vector2i = cluster[0]
		player.global_position = world.cell_center(center) - Vector2(56, 0)
		await _frames(2)
		world.damage_objects_around(center, 999.0, progression.value("wide_harvest"), Enemy.SOURCE_LOCAL)
		var broken: Array = cluster.filter(func(c: Vector2i) -> bool: return world.data.get_object(c) == WorldData.Obj.NONE)
		_check(broken.size() == cluster.size(), "광역 채집: 주변 나무까지 한 번에 채집 (%d/%d)" % [broken.size(), cluster.size()])

	var interact := InputEventAction.new()
	interact.action = "passives"
	interact.pressed = true
	Input.parse_input_event(interact)
	await _frames(2)
	_check(main.hud.passive_panel.visible, "K로 패시브 창이 열림")
	main.hud.passive_panel.hide()

	var vitality_rank := progression.rank("vitality")
	progression.add_xp(7)
	await _kill_player(player)
	_check(player.is_dead and progression.xp == 0 and progression.rank("vitality") == vitality_rank,
		"죽으면 쓰지 않은 경험치는 사라지고 배운 패시브는 남음")
	_check(not player.weapon_visual.visible, "플레이어가 쓰러지면 무기와 손 그림도 함께 숨김")
	await get_tree().create_timer(Balance.RESPAWN_TIME + 0.5).timeout
	_check(player.weapon_visual.visible, "부활하면 장착 무기 그림도 다시 표시")


## 주변(대각선 포함 1칸)에 나무가 하나 이상 있는 나무. [중심, 주변 나무들...]
func _find_tree_cluster(world: World) -> Array:
	for y in world.data.size.y:
		for x in world.data.size.x:
			var cell := Vector2i(x, y)
			if world.data.get_object(cell) != WorldData.Obj.TREE:
				continue
			var cluster: Array = [cell]
			for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
				if world.data.get_object(cell + offset) in World.HARVESTABLE:
					cluster.append(cell + offset)
			if cluster.size() >= 3:
				return cluster
	return []


## 직전 피격·대시·부활 무적이 남아 있을 수 있어 풀릴 때까지(최대 4초) 시도한다
func _kill_player(player: Player) -> void:
	var deadline := Time.get_ticks_msec() + 4000
	while not player.is_dead and Time.get_ticks_msec() < deadline:
		player.take_damage(999999.0)
		await _frames(1)


func _wood(main: Main) -> int:
	return main.kingdom.stock["wood"] + main.player.inventory.count("wood")


func _total_resources(main: Main) -> int:
	var total := 0
	for kind in main.kingdom.stock:
		total += main.kingdom.stock[kind] + main.player.inventory.count(kind)
	return total


func _check(ok: bool, label: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + label)
	if not ok:
		_failures += 1


## 패시브 트리(D-020): 선행 노드 잠금과 전투·생존·건설 노드 효과가 실제 게임에 적용되는지
func _check_passive_tree(main: Main) -> void:
	var player := main.player
	var progression := player.progression
	var kingdom := main.kingdom
	if player.is_dead:
		player._respawn()  # 앞 검사(인벤토리)가 쓰러진 채로 끝난다
	progression.add_xp(5000)
	_check(progression.learn("executioner") != "" and progression.rank("executioner") == 0, "선행 노드를 배우지 않으면 아래 노드는 잠김")

	var base_damage: float = player.equipment.weapon()["damage"]
	progression.learn("keen_edge")
	_check(player._boosted_weapon()["damage"] > base_damage, "날카로운 일격이 기본 공격 피해를 올림")
	progression.learn("combo_finisher")
	var finisher := int(progression.value("combo_finisher"))
	player._combo_count = 0
	var damages: Array[float] = []
	for i in finisher:
		damages.append(player._boosted_weapon()["damage"])
	_check(is_equal_approx(damages[finisher - 1], damages[0] * PassiveDB.COMBO_MULTIPLIER), "마무리 일격: %d번째 기본 공격만 피해 2배" % finisher)

	progression.learn("vitality")
	progression.learn("regeneration")
	progression.learn("last_stand")
	player.heal(9999.0)
	player._invuln_time = 0.0
	player.take_damage(99999.0)
	_check(not player.is_dead and is_equal_approx(player.hp, 1.0), "최후의 저항: 쓰러질 피해를 체력 1로 버팀")
	progression.learn("swift")
	progression.learn("windstep")
	player._dash_cooldown = 0.0
	player.dash()
	_check(player.dash_cooldown_left() < Balance.DASH_COOLDOWN, "질풍이 대시 쿨타임을 줄임 (%.2f초)" % player.dash_cooldown_left())
	player.heal(9999.0)

	for id in ["frugal_builder", "sturdy_build", "mending_walls", "thorn_walls"]:
		progression.learn(id)
	player.global_position = player.spawn_point
	await _frames(2)
	var cell := World.NO_CELL
	for offset in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(2, 1), Vector2i(-2, 1)]:
		var candidate: Vector2i = main.world.cell_at(player.spawn_point) + offset
		if main.world.data.is_walkable(candidate) and not kingdom.is_occupied(candidate):
			cell = candidate
			break
	var wood_before: int = kingdom.stock.get("wood", 0) + player.inventory.count("wood")
	var error := kingdom.build(cell, "wood_wall", player.global_position, player.inventory, progression.build_perks())
	var paid: int = wood_before - kingdom.stock.get("wood", 0) - player.inventory.count("wood")
	var base_cost: int = BuildingDB.TYPES["wood_wall"]["cost"]["wood"]
	_check(error == "" and paid < base_cost, "알뜰한 건축이 건설 비용을 깎음 (나무 %d → %d) %s" % [base_cost, paid, error])
	if error != "":
		return
	var wall: Building = kingdom.buildings[cell]
	_check(wall.max_hp > BuildingDB.TYPES["wood_wall"]["hp"], "튼튼한 기초가 내가 지은 건물 체력을 올림 (%d)" % wall.max_hp)
	var biter := Enemy.new().setup("brute", false)
	biter.position = player.spawn_point + Vector2(0, 12 * Balance.TILE)
	main.get_node("Enemies").add_child(biter)
	await _frames(1)
	var biter_hp := biter.hp
	wall.take_damage(20.0, biter)
	_check(biter.hp < biter_hp, "가시 벽: 벽을 때린 적이 피해를 돌려받음")
	biter.queue_free()
	var hurt_hp := wall.hp
	await get_tree().create_timer(0.5).timeout
	_check(wall.hp > hurt_hp, "자가 보수: 내가 지은 건물이 스스로 회복")
	wall.hp = 1.0
	kingdom.fortify(0.3)
	_check(wall.hp > 1.0, "긴급 요새화가 건물 체력을 회복")
	kingdom.demolish(cell)


## 확장 패시브 노드(D-020): 다중 사격·긴 칼날·회오리 베기·철갑 피부·전술가·화살탑 강화·해체·수리 노드가 실제로 적용되는지
func _check_passive_expansion(main: Main) -> void:
	var player := main.player
	var progression := player.progression
	var kingdom := main.kingdom
	if player.is_dead:
		player._respawn()
	progression.add_xp(9000)
	for id in ["bow_mastery", "multishot", "sword_mastery", "sword_sweep", "blade_reach", "whirlwind", "iron_skin",
			"keen_edge", "skill_power", "tactician", "frugal_builder", "long_reach", "salvage_expert", "tower_drill",
			"hawk_eye", "sharp_bolts", "twin_bows", "repair_expert", "thrifty_repair", "core_resonance"]:
		progression.learn(id)
	var weapon_before := player.equipment.item_in("weapon")
	player.equipment.add_to_bag("old_bow")
	player.equipment.equip("old_bow")
	var projectiles := get_tree().get_first_node_in_group("projectiles")
	var before := projectiles.get_child_count()
	player._fire_weapon()
	await _frames(2)
	_check(projectiles.get_child_count() - before >= int(progression.value("multishot")),
		"다중 사격: 활 한 번에 %d발" % (projectiles.get_child_count() - before))
	player.equipment.add_to_bag("rusty_sword")
	player.equipment.equip("rusty_sword")
	var base_range: float = player.equipment.weapon()["range"]
	player._whirl_count = 0
	var arcs: Array[float] = []
	var ranges: Array[float] = []
	for i in int(progression.value("whirlwind")):
		var boosted := player._boosted_weapon()
		arcs.append(boosted["arc"])
		ranges.append(boosted["range"])
	_check(ranges[0] > base_range, "긴 칼날: 검 사거리 증가 (%.0f → %.0f)" % [base_range, ranges[0]])
	_check(arcs[-1] == 360.0 and arcs[0] < 360.0, "회오리 베기: %d번째 휘두르기는 한 바퀴 (%s)" % [arcs.size(), arcs])
	if weapon_before != "" and weapon_before != "rusty_sword" and player.equipment.bag.has(weapon_before):
		player.equipment.equip(weapon_before)

	player.heal(9999.0)
	player._invuln_time = 0.0
	var hp_before := player.hp
	player.take_damage(20.0)
	_check(player.hp > hp_before - 20.0, "철갑 피부: 받는 피해 감소 (%.1f)" % (hp_before - player.hp))
	player.heal(9999.0)
	player.equipment.add_to_bag("war_horn")
	player.equipment.equip("war_horn")
	var bar := player.equipment.skill_bar()
	var slot := bar.find("war_horn")
	player.use_skill(slot)
	_check(player.equipment.cooldown_left("war_horn") < ItemDB.ITEMS["war_horn"]["skill"]["cooldown"], "전술가: 장비 스킬 쿨타임 감소")

	player.global_position = player.spawn_point
	await _frames(2)
	var cell := World.NO_CELL
	for offset in [Vector2i(3, 0), Vector2i(-3, 0), Vector2i(3, 1), Vector2i(-3, 1), Vector2i(3, -1)]:
		var candidate: Vector2i = main.world.cell_at(player.spawn_point) + offset
		if main.world.data.is_walkable(candidate) and not kingdom.is_occupied(candidate):
			cell = candidate
			break
	kingdom.add_resources({"wood": 200, "stone": 200})
	var error := kingdom.build(cell, "arrow_tower", player.global_position, player.inventory, progression.build_perks())
	_check(error == "", "확장 검사용 화살탑 건설 %s" % error)
	if error != "":
		return
	var tower: Building = kingdom.buildings[cell]
	_check(tower.tower_shots >= 2 and tower.tower_range > 1.0 and tower.tower_damage > 1.0, "매의 눈·강화 화살촉·쌍궁 탑이 내 화살탑에 적용")
	tower.hp = 1.0
	kingdom.core.hp = kingdom.core.max_hp - 200.0
	var stock_before: Dictionary = kingdom.stock.duplicate()
	error = kingdom.repair(player.global_position, null, progression.repair_perks())
	var wood_paid: int = stock_before.get("wood", 0) - kingdom.stock.get("wood", 0)
	_check(error == "" and wood_paid < Balance.REPAIR_COST["wood"] and tower.hp > 1.0,
		"자재 절약·핵 공명: 수리 비용 감소(나무 %d), 영토 건물도 회복 %s" % [wood_paid, error])
	var tower_cost: Dictionary = BuildingDB.discounted(BuildingDB.TYPES["arrow_tower"]["cost"], progression.build_perks()["discount"])
	var wood_before: int = kingdom.stock.get("wood", 0)
	tower.hp = tower.max_hp
	kingdom.demolish(cell, progression.value("salvage_expert") / 100.0)
	var refunded: int = kingdom.stock.get("wood", 0) - wood_before
	_check(refunded > floori(BuildingDB.TYPES["arrow_tower"]["cost"]["wood"] * BuildingDB.REFUND_RATE) or refunded >= tower_cost.get("wood", 0),
		"해체 전문가: 철거 환불 증가 (나무 %d)" % refunded)


## 건설 확장(D-022): 테크 잠금, 왕국 밖 건설, 순간이동, 보급소 입고, 감시탑, 모닥불, 서리탑 감속, 대포 범위 피해, 보스의 정수
func _check_building_catalog(main: Main) -> void:
	var player := main.player
	var kingdom := main.kingdom
	var world := main.world
	if player.is_dead:
		player._respawn()
	kingdom.add_resources({"wood": 500, "stone": 500, "copper": 100, "iron_ore": 100, "coal": 100, "hardwood": 100, "resin": 50,
		"moss": 50, "ice_crystal": 20, "obsidian": 50, "fire_core": 20, "boss_essence": 5})
	var bench := kingdom._find_type("workbench")
	if bench != World.NO_CELL:
		kingdom.buildings[bench].tier = 0
	player.global_position = player.spawn_point
	await _frames(2)
	var near := _free_cell_near(main, world.cell_at(player.spawn_point), 2)
	var error := kingdom.build(near, "iron_wall", player.global_position, null)
	_check(error.contains("제작대") and not kingdom.buildings.has(near), "제작대 단계가 모자라면 철벽을 못 지음 (%s)" % error)
	if bench == World.NO_CELL:
		bench = _free_cell_near(main, world.cell_at(player.spawn_point), 3)
		kingdom.build(bench, "workbench", player.global_position, null)
	kingdom.buildings[bench].tier = RecipeDB.max_tier()
	_check(kingdom.build(near, "iron_wall", player.global_position, null) == "", "제작대 단계가 오르면 철벽을 지을 수 있음")
	_check(kingdom.build(_free_cell_near(main, world.cell_at(player.spawn_point), 2), "workbench", player.global_position, null) != "",
		"제작대는 왕국에 하나만")

	# E는 장비 상자·제작대를 먼저 열므로 그것들과 떨어진 칸에 짓는다
	var home := _free_cell_near(main, world.cell_at(player.spawn_point), 6)
	player.global_position = world.cell_center(home) + Vector2(0, Balance.TILE)
	await _frames(1)
	main.hud.teleport_panel.travel(home)
	_check(player.global_position.distance_to(world.cell_center(home)) < 2.0 * Balance.TILE, "탑 창을 열지 않고는 이동할 수 없음")
	_check(kingdom.build(home, "teleport_tower", player.global_position, null) == "", "왕국 안 순간이동 탑")
	var lane := _open_lane(main, 14)
	player.global_position = world.cell_center(lane)
	await _frames(2)
	_check(kingdom.build(lane + Vector2i(2, 0), "stone_wall", player.global_position, null) != "", "벽은 왕국 밖에 지을 수 없음")
	var away := lane + Vector2i(2, 0)
	error = kingdom.build(away, "teleport_tower", player.global_position, null)
	_check(error == "" and not kingdom.in_territory(away), "순간이동 탑은 왕국 밖에도 지음 %s" % error)
	player.global_position = world.cell_center(home) + Vector2(0, Balance.TILE)
	await _frames(2)
	main._interact()
	_check(main.hud.teleport_panel.visible, "순간이동 탑 옆에서 E를 누르면 이동 창(지도)이 열림")
	main.hud.teleport_panel.travel(away)
	await _frames(2)
	_check(not main.hud.teleport_panel.visible and player.global_position.distance_to(world.cell_center(away)) < 2.0 * Balance.TILE,
		"연결된 왕국 밖 순간이동 탑으로 이동")

	var depot := lane + Vector2i(6, 0)
	_check(kingdom.build(depot, "supply_depot", player.global_position, null) == "", "보급소는 왕국 밖에도 지음")
	player.inventory.clear()
	player.inventory.add({"stone": 7})
	var stone_before: int = kingdom.stock.get("stone", 0)
	player.global_position = world.cell_center(depot) + Vector2(0, Balance.TILE)
	await _frames(3)
	_check(player.inventory.is_empty() and kingdom.stock.get("stone", 0) == stone_before + 7, "보급소 근처에서도 가방 자원이 창고로 입고")

	var far := lane + Vector2i(10, 0) + Vector2i(0, 15)
	var was_explored := world.data.is_explored(far)
	player.global_position = world.cell_center(lane + Vector2i(9, 0))
	await _frames(1)
	_check(kingdom.build(lane + Vector2i(10, 0), "watchtower", player.global_position, null) == "" and world.data.is_explored(far),
		"감시탑을 지으면 주변 넓은 땅이 지도에 밝혀짐 (전에 탐험 %s)" % was_explored)

	player.global_position = world.cell_center(lane + Vector2i(12, 0))
	await _frames(1)
	kingdom.build(lane + Vector2i(13, 0), "campfire", player.global_position, null)
	player.hp = 10.0
	await get_tree().create_timer(0.5).timeout
	_check(player.hp > 10.0, "모닥불 근처에서 체력이 차오름 (%.1f)" % player.hp)
	player.heal(9999.0)

	var enemies := main.get_node("Enemies")
	var target := Enemy.new().setup("brute", false)
	var bystander := Enemy.new().setup("brute", false)
	target.position = world.cell_center(lane + Vector2i(6, 3))
	bystander.position = target.position + Vector2(30, 0)
	enemies.add_child(target)
	enemies.add_child(bystander)
	await _frames(1)
	var bystander_hp := bystander.hp
	Projectile.spawn(get_tree(), target.position - Vector2(40, 0), {"direction": Vector2.RIGHT, "speed": 400.0, "damage": 20.0,
		"team": Projectile.Team.TOWER, "splash_radius": 72.0, "slow_factor": 0.45, "slow_time": 2.0})
	await get_tree().create_timer(0.3).timeout
	_check(is_instance_valid(target) and target._slow_time > 0.0 and is_equal_approx(target._slow_factor, 0.45), "서리탑 탄에 맞은 적은 느려짐")
	_check(is_instance_valid(bystander) and bystander.hp < bystander_hp, "대포탑 탄은 맞은 자리 주변 적에게도 피해")
	for enemy in [target, bystander]:
		if is_instance_valid(enemy):
			enemy.queue_free()

	var essence_before: int = kingdom.stock.get("boss_essence", 0)
	var boss := Enemy.new().setup("alpha_wolf", true)
	boss.position = world.cell_center(lane + Vector2i(0, 4))
	enemies.add_child(boss)
	await _frames(1)
	boss.take_damage(999999.0)
	await _frames(2)
	_check(kingdom.stock.get("boss_essence", 0) == essence_before + Balance.BOSS_ESSENCE_PER_BOSS, "보스를 잡으면 보스의 정수가 왕국 창고로")
	for cell in [near, home, away, depot, lane + Vector2i(10, 0), lane + Vector2i(13, 0)]:
		kingdom.demolish(cell)
	player.global_position = player.spawn_point
	await _frames(2)


## start 주변 ring칸 안에서 지을 수 있는 칸
func _free_cell_near(main: Main, start: Vector2i, ring: int) -> Vector2i:
	for y in range(-ring, ring + 1):
		for x in range(-ring, ring + 1):
			var cell := start + Vector2i(x, y)
			if maxi(absi(x), absi(y)) == ring and main.world.data.is_walkable(cell) and not main.kingdom.is_occupied(cell):
				return cell
	return World.NO_CELL


## 손맛·연출(D-023): 피해 숫자(강조), 폭발 흔들림, 보스 체력바·등장 배너, 해 질 녘 침공 예고
func _check_feedback(main: Main) -> void:
	var player := main.player
	if player.is_dead:
		player._respawn()
	var fx := get_tree().get_first_node_in_group("fx_layer")
	var enemies := main.get_node("Enemies")
	var dummy := Enemy.new().setup("brute", false)
	dummy.position = player.global_position + Vector2(6 * Balance.TILE, 0)
	enemies.add_child(dummy)
	await _frames(1)
	var labels_before := fx.get_children().filter(func(node: Node) -> bool: return node is Label).size()
	dummy.take_damage(5.0)
	dummy.take_damage(7.0, Enemy.SOURCE_LOCAL, true)
	var labels := fx.get_children().filter(func(node: Node) -> bool: return node is Label)
	var big: Array = labels.filter(func(label: Label) -> bool: return label.text == "7!")
	_check(labels.size() >= labels_before + 2 and big.size() == 1 and big[0].get_theme_font_size("font_size") > 12,
		"적을 때리면 피해 숫자, 패시브로 강해진 공격은 크게 강조")
	dummy.queue_free()
	await get_tree().create_timer(0.2, true, false, true).timeout  # 앞의 강조 멈칫이 끝나기를 기다린다
	main.show_damage(player.global_position, 10.0, true)
	var slowed := Engine.time_scale
	await get_tree().create_timer(Main.HITSTOP_EMPHASIS + 0.1, true, false, true).timeout
	_check(slowed < 0.5 and is_equal_approx(Engine.time_scale, 1.0), "혼자 플레이에서 강조 공격은 잠깐 멈칫한 뒤 원래 속도로 (%.2f → %.2f)" % [slowed, Engine.time_scale])
	player._shake = 0.0
	Events.screen_shake_requested.emit(player.global_position + Vector2(40, 0), 7.0)
	var near_shake := player._shake
	player._shake = 0.0
	Events.screen_shake_requested.emit(player.global_position + Vector2(5000, 0), 7.0)
	_check(near_shake > 5.0 and player._shake == 0.0, "가까운 폭발은 화면을 흔들고 먼 폭발은 흔들지 않음 (%.1f)" % near_shake)
	player._shake = 0.0

	var banner := main.hud.threat_banner
	var boss := Enemy.new().setup("venom_tyrant", true)
	boss.position = player.global_position + Vector2(14 * Balance.TILE, 0)
	enemies.add_child(boss)
	await _frames(2)
	boss.hp = boss.max_hp * 0.5
	await _frames(2)
	_check(banner._name_label.visible and banner._name_label.text.contains("독침 폭군") and banner.banner_text().contains("보스 등장")
		and is_equal_approx(main.boss_status()["ratio"], 0.5), "보스가 나오면 등장 배너와 화면 위 보스 체력바")
	boss.queue_free()
	await _frames(2)
	_check(not banner._name_label.visible, "보스가 사라지면 체력바도 사라짐")

	var clock := main.day_night
	var phase_before := clock.phase
	var time_before := clock.time
	var day_before := clock.day
	clock.phase = DayNight.Phase.DAY
	clock.day = 6
	clock.time = Balance.DAY_LENGTH - 10.0
	_check(banner.night_warning().contains("침공까지") and banner.night_warning().contains(EnemyDB.TYPES[EnemyDB.boss_for(6)]["name"]),
		"해 질 녘에 침공 예고와 오늘 밤 보스 이름 (%s)" % banner.night_warning())
	clock.time = 5.0
	_check(banner.night_warning() == "", "낮 초반에는 침공 예고 없음")
	clock.phase = phase_before
	clock.time = time_before
	clock.day = day_before


## 보스(D-021): 패턴(원형·회전·부채꼴·돌진·소환)이 실제로 나오고, 아침에도 남고, 최종 보스를 잡으면 승리 화면
func _check_bosses(main: Main) -> void:
	var player := main.player
	if player.is_dead:
		player._respawn()
	var enemies := main.get_node("Enemies")
	var projectiles := get_tree().get_first_node_in_group("projectiles")
	# 돌진 거리를 재려면 플레이어와 보스 사이에 나무·건물이 없어야 한다
	var lane := _open_lane(main, 14)
	_check(lane != World.NO_CELL, "보스 검사용 빈 땅을 찾음")
	if lane == World.NO_CELL:
		return
	player.global_position = main.world.cell_center(lane)
	var boss := Enemy.new().setup("kingdom_breaker", true)
	boss.position = main.world.cell_center(lane + Vector2i(12, 0))
	enemies.add_child(boss)
	await _frames(1)
	player._invuln_time = 999.0  # 이 검사 동안 플레이어가 쓰러지지 않게
	var before := projectiles.get_child_count()
	var patterns: Array = boss.stats["patterns"]
	for pattern: Dictionary in patterns:
		if pattern["type"] in ["radial", "fan"]:
			boss._start_pattern(pattern)
	await _frames(2)
	_check(projectiles.get_child_count() > before, "보스 원형·부채꼴 탄이 나옴 (%d발)" % (projectiles.get_child_count() - before))
	var enemy_count := enemies.get_child_count()
	for pattern: Dictionary in patterns:
		if pattern["type"] == "summon":
			boss._start_pattern(pattern)
	await _frames(2)
	_check(enemies.get_child_count() > enemy_count, "보스가 부하를 부름")
	for pattern: Dictionary in patterns:
		if pattern["type"] == "charge":
			boss._start_pattern(pattern)
	_check(boss._charge_windup > 0.0, "돌진 전에 멈춰서 번쩍이며 예고함")
	var start := boss.global_position
	var charge: Dictionary = boss._charge
	await get_tree().create_timer(charge["windup"] + charge["duration"] + 0.2).timeout
	_check(boss.global_position.distance_to(start) > 4.0 * Balance.TILE, "예고 뒤 빠르게 돌진 (%.0fpx)" % boss.global_position.distance_to(start))
	boss.hp = boss.max_hp * 0.05
	_check(boss._rage("rate") >= 2.0, "체력이 낮아지면 분노해서 패턴이 빨라짐 (%.1f배)" % boss._rage("rate"))
	main.spawner._on_day_started(main.day_night.day)
	await _frames(1)
	_check(is_instance_valid(boss) and not boss._dying, "보스는 아침이 와도 사라지지 않음")
	boss.take_damage(999999.0)
	await _frames(2)
	_check(get_tree().paused and main.hud.game_over_panel.visible and main.hud.game_over_panel._title.text == "승리!",
		"최종 보스를 쓰러뜨리면 승리 화면")
	main.hud.game_over_panel.hide()
	get_tree().paused = false
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	player._invuln_time = 0.0
	await _frames(2)


## 가로로 length칸 연속으로 걸을 수 있고 건물이 없는 줄의 왼쪽 끝 (위아래 1칸도 비어 있어야 함)
func _open_lane(main: Main, length: int) -> Vector2i:
	var data := main.world.data
	var core := data.core_cell
	for y in range(core.y + 20, core.y + 60):
		for x in range(core.x - 40, core.x + 40):
			var clear := true
			for dx in length:
				for dy in [-1, 0, 1]:
					var cell := Vector2i(x + dx, y + dy)
					if not data.is_walkable(cell) or main.kingdom.is_occupied(cell):
						clear = false
						break
				if not clear:
					break
			if clear:
				return Vector2i(x, y)
	return World.NO_CELL


## 시작 화면: 로고와 싱글플레이·멀티플레이 버튼만 보이고, 누르면 그 팝업이 열린다
func _check_title() -> void:
	var title: Control = load("res://scenes/title.tscn").instantiate()
	add_child(title)
	await _frames(2)
	var menu_buttons: Array[String] = []
	_check(title._menu_music.playing and title._menu_music.stream.loop and title._menu_music.stream.get_length() > 60.0, "시작 화면 음악은 긴 스테레오 루프로 재생")
	var music: WeakRef = weakref(title._menu_music)
	var hangul_complete := true
	for codepoint in range(0xac00, 0xd7a4):
		if not UiKit.GAME_FONT.has_char(codepoint):
			hangul_complete = false
	_check(hangul_complete and UiKit.GAME_FONT.has_char(0xe000), "게임용 글꼴은 한글 11172자와 자체 왕관 기호를 지원")
	_check(title.get_theme_default_font().get_font_name() == "Kingdom Dot", "시작 화면에 게임용 한국어 글꼴 적용")
	title._menu_music.seek(title._menu_music.stream.get_length() - 0.03)
	await get_tree().create_timer(0.25).timeout
	_check(title._menu_music.playing and title._menu_music.get_playback_position() < 1.0, "곡 끝을 지나도 메뉴 음악이 반복됨")
	for node in title.find_children("*", "Button", true, false):
		var button := node as Button
		if button.is_visible_in_tree():
			menu_buttons.append(button.text)
	_check(menu_buttons == ["싱글플레이", "멀티플레이"] and not title._single_popup.visible and not title._multi_popup.visible,
		"시작 화면에는 싱글플레이·멀티플레이 버튼만 보임 %s" % [menu_buttons])
	_check(title.find_children("*", "TextureRect", true, false).any(func(node: Node) -> bool: return (node as TextureRect).texture == title.LOGO),
		"시작 화면에 로고가 보임")
	title._open(title._single_popup)
	_check(title._single_popup.visible and not title._multi_popup.visible and title._single_seed.text != "", "싱글플레이를 누르면 시드 입력 팝업이 열림")
	_check(title._background.texture == title.BACKGROUND, "시작 화면 왕국 배경이 연결됨")
	for node in title._menu.get_children():
		if node is TextureRect:
			_check(node.size == title.LOGO_SIZE, "로고 원본 크기가 메뉴 영역을 넘지 않음")
		if node is Button:
			_check(node.focus_mode == Control.FOCUS_NONE, "팝업 뒤 메뉴는 키보드 포커스에서 제외")
	title._open(title._multi_popup)
	_check(title._menu_music == music.get_ref() and title._menu_music.playing, "싱글·멀티 팝업 전환은 음악을 끊거나 중복 재생하지 않음")
	_check(title._multi_popup.visible and not title._single_popup.visible and title._multi_start.disabled,
		"멀티플레이 팝업이 열리고, 방에 들어가기 전에는 시작할 수 없음")
	title.queue_free()
	await _frames(1)
	_check(music.get_ref() == null, "시작 화면 종료 시 음악 재생기도 함께 해제")


func _check_passive_graphics() -> void:
	var progression := Progression.new()
	var panel := PassivePanel.new()
	add_child(panel)
	panel.setup(progression)
	panel.toggle()
	await _frames(2)
	_check(panel._tree.buttons.size() == PassiveDB.PASSIVES.size(), "모든 패시브에 노드 아이콘이 연결됨")
	var regions: Array[Rect2] = []
	var icons := PassiveNode.ICONS.get_image()
	for id: String in PassiveDB.PASSIVES:
		var region := PassiveArtDB.icon_region(id)
		_check(PassiveArtDB.LAYOUT.has(id) and not regions.has(region) and not icons.get_region(Rect2i(region)).is_invisible(), "패시브 고유 아이콘·방사형 배치 %s" % id)
		regions.append(region)
	panel._tree.buttons["fortify"].pressed.emit()
	_check(panel._selected_id == "fortify" and panel._learn_button.disabled and progression.ranks.is_empty(), "잠긴 노드 선택은 상세만 열고 경험치를 쓰지 않음")
	panel._tree.buttons["sword_mastery"].pressed.emit()
	_check(panel._learn_button.disabled and panel._tree.buttons["sword_mastery"].state == PassiveNode.State.LOCKED, "경험치 부족은 배울 수 없는 상태로 표시")
	progression.add_xp(200)
	var before := progression.xp
	var cost := progression.next_cost("sword_mastery")
	panel._learn_button.pressed.emit()
	_check(progression.rank("sword_mastery") == 1 and progression.xp == before - cost and panel._tree.buttons["sword_sweep"].state == PassiveNode.State.AVAILABLE, "배우기 버튼은 학습 명령을 호출하고 다음 노드를 열음")
	while progression.rank("sword_mastery") < PassiveDB.max_rank("sword_mastery"):
		panel._learn_button.pressed.emit()
	_check(panel._learn_button.disabled and panel._tree.buttons["sword_mastery"].state == PassiveNode.State.COMPLETE, "최고 단계 노드는 완료 표시하고 추가 학습을 막음")
	panel.show_branch("survival")
	_check(PassiveDB.PASSIVES[panel._selected_id]["branch"] == "survival" and panel._tree.buttons["sword_mastery"].modulate.a < 1.0, "갈래 선택은 해당 경로를 강조")
	panel.queue_free()
	await _frames(1)


## 혼자 플레이: T로 회의를 열면 멈추고, 내가 준비 완료하면 바로 재개한다 (D-019)
func _check_meeting(main: Main) -> void:
	var panel := main.hud.meeting_panel
	main.meeting_sync.request_open()
	_check(panel.visible and get_tree().paused, "전략회의를 열면 게임이 멈추고 회의 창이 보임")
	panel.confirm()
	await get_tree().create_timer(MeetingPanel.RESUME_DELAY + 0.1).timeout
	_check(not panel.visible and not get_tree().paused, "혼자일 때는 준비 완료하면 바로 재개")


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
