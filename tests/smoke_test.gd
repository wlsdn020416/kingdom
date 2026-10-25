extends Node
## 게임 씬을 실제로 돌려서 핵심 흐름이 깨지지 않았는지 확인한다.
## 실행: godot --headless --path . res://tests/smoke_test.tscn
## 코드를 고친 뒤 이걸 돌려서 전부 OK면 기본 흐름은 살아 있다는 뜻이다.

var _failures := 0
var _heard: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _check_title()
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
	var artwork_ok := image.get_size() == Vector2i((BuildingDB.ORDER.size() + RecipeDB.max_tier()) * 32, 64)
	var regions: Dictionary = {}
	var rules_ok := true
	for id: String in BuildingDB.ORDER:
		var info: Dictionary = BuildingDB.TYPES[id]
		var count := RecipeDB.max_tier() + 1 if info.get("workbench", false) else 1
		for tier in count:
			var region := Building.sprite_region(id, tier)
			artwork_ok = artwork_ok and not regions.has(region)
			regions[region] = true
			var painted := false
			for y in int(region.size.y):
				for x in int(region.size.x):
					if image.get_pixel(int(region.position.x) + x, y).a > 0.0:
						painted = true
						artwork_ok = artwork_ok and y >= int(info["sprite_top"])
			artwork_ok = artwork_ok and painted
		var building := Building.new().setup(id, Vector2i.ZERO)
		main.add_child(building)
		building.set_physics_process(false)
		var collider := building.get_child(0) as CollisionShape2D
		rules_ok = rules_ok and (collider.shape as RectangleShape2D).size == Vector2(32, 32)
		building.take_damage(1.0)
		rules_ok = rules_ok and building.hp == float(info["hp"]) - 1.0
		building.queue_free()
	_check(artwork_ok and regions.size() == 8, "설치물 5종·제작대 4단계 그림과 체력바 높이가 유효")
	_check(rules_ok, "설치물 그래픽 교체 후 한 칸 충돌과 피해 판정 유지")


## 모든 적의 그림이 존재하고 움직임·피격 표시가 기존 충돌과 피해 판정을 유지해야 한다.
func _check_enemy_art(main: Main) -> void:
	var image := Enemy.SPRITE_TEXTURE.get_image()
	var atlas_ok := image.get_size() == Vector2i(Enemy.SPRITE_SIZE * Enemy.ANIMATION_FRAMES, Enemy.SPRITE_SIZE * EnemyDB.TYPES.size())
	var rows: Dictionary = {}
	var motion_ok := true
	var rules_ok := true
	for id: String in EnemyDB.TYPES:
		var stats: Dictionary = EnemyDB.TYPES[id]
		var row: int = stats["sprite_row"]
		var top: int = stats["sprite_top"]
		if row < 0 or row >= EnemyDB.TYPES.size() or rows.has(row):
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
		if id not in Enemy.IDLE_ANIMATED:
			motion_ok = motion_ok and enemy._animation_frame == 0
		var collider := enemy.get_child(0) as CollisionShape2D
		rules_ok = rules_ok and is_equal_approx((collider.shape as CircleShape2D).radius, stats["radius"])
		enemy.take_damage(1.0)
		rules_ok = rules_ok and is_equal_approx(enemy.hp, float(stats["hp"]) - 1.0) and enemy._flash > 0.0
		enemy.queue_free()
	_check(atlas_ok, "적 8종의 모든 프레임과 체력바용 그림 높이가 유효")
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
	var icons_ok := main.hud.build_menu._list.get_child_count() == BuildingDB.ORDER.size()
	for button: Button in main.hud.build_menu._list.get_children():
		icons_ok = icons_ok and button.icon is AtlasTexture and (button.icon as AtlasTexture).atlas == Building.SPRITE_TEXTURE
	_check(icons_ok, "B 메뉴는 실제 설치물과 같은 그림을 아이콘으로 사용")
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


## 시작 화면: 로고와 싱글플레이·멀티플레이 버튼만 보이고, 누르면 그 팝업이 열린다
func _check_title() -> void:
	var title: Control = load("res://scenes/title.tscn").instantiate()
	add_child(title)
	await _frames(2)
	var menu_buttons: Array[String] = []
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
	title._open(title._multi_popup)
	_check(title._multi_popup.visible and not title._single_popup.visible and title._multi_start.disabled,
		"멀티플레이 팝업이 열리고, 방에 들어가기 전에는 시작할 수 없음")
	title.queue_free()
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
