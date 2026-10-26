extends Node
## 게임 씬을 실제로 돌려서 핵심 흐름이 깨지지 않았는지 확인한다.
## 실행: godot --headless --path . res://tests/smoke_test.tscn
## 코드를 고친 뒤 이걸 돌려서 전부 OK면 기본 흐름은 살아 있다는 뜻이다.

const TEST_SETTINGS := "user://settings_smoke_test.cfg"

var _failures := 0
var _heard: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 이 기기의 실제 환경 설정과 상관없이 기본값으로 검사하고, 바꾼 값은 테스트 파일에만 쓴다 (D-030)
	Session.settings.path = TEST_SETTINGS
	Session.settings.reset()
	await _check_cursor_lifecycle()
	await _check_title()
	await _check_passive_graphics()
	Session.seed_text = "smoke-test"
	var main: Main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(5)
	await _check_audio(main)
	await _check_boss_music(main)
	_check_terrain_tiles(main.world)
	_check_object_tiles(main.world)
	_check_depth_sort(main)
	_check_health_bars(main)
	await _check_status_hud(main)
	await _check_map_bag_art(main)
	await _check_progression_hud(main)
	_check_action_bar(main)
	await _check_weapon_art(main)
	_check_enemy_art(main)
	_check_building_art(main)
	await _check_building_lighting(main)
	_check_item_art(main)
	await _check_passive_effects(main)

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
	await _check_passable_buildings(main)
	await _check_daytime_kingdom(main)
	await _check_kingdom_panel(main)
	await _check_interact_choice(main)
	await _check_daily_regrowth(main)
	await _check_melee(main)
	_check_worn_alignment()
	await _check_equipment_panel(main)
	await _check_build_menu(main)
	await _check_storage(main)
	await _check_workbench(main)
	await _check_weapon_skills(main)
	# 의뢰 보상이 재료를 알려 주므로 레시피 공개 검사(제작대) 뒤에 둔다
	await _check_quests(main)
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
	await get_tree().create_timer(SoundDB.BOSS_MUSIC_FADE_SECONDS + 0.1).timeout
	_check(not main.boss_music._player.playing, "멸망 화면에서 보스 음악이 남지 않음")

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


func _check_boss_music(main: Main) -> void:
	# 낮 배회 적 생성의 정상적인 난수 소비를 음악 검사와 분리한다.
	var spawner_processing := main.spawner.is_physics_processing()
	main.spawner.set_physics_process(false)
	var music := main.boss_music
	var voice := music._player
	_check(not voice.playing and voice.stream.get_length() > 90.0 and voice.stream.loop,
		"일반 플레이에는 보스 BGM이 없고 90초 이상 반복 스트림을 준비")
	var rng_before := main.rng.state
	var boss := Enemy.new().setup("venom_tyrant", true)
	boss.position = main.player.global_position + Vector2(2000, 0)
	main.get_node("Enemies").add_child(boss)
	boss.set_physics_process(false)
	await _frames(3)
	_check(voice.playing and music._active, "보스가 등장하면 전투 BGM 재생 시작")
	await get_tree().create_timer(SoundDB.BOSS_MUSIC_FADE_SECONDS + 0.1).timeout
	_check(is_equal_approx(voice.volume_db, SoundDB.BOSS_MUSIC_VOLUME_DB), "보스 BGM은 설정 음량까지 페이드인")
	voice.seek(voice.stream.get_length() - 0.1)
	await get_tree().create_timer(0.35).timeout
	_check(voice.playing and voice.get_playback_position() < 2.0, "보스 BGM 곡 끝에서 처음으로 반복")
	var at := voice.get_playback_position()
	await _frames(2)
	_check(voice.get_playback_position() >= at, "같은 보스가 살아 있으면 곡을 매 프레임 다시 시작하지 않음")
	get_tree().paused = true
	await _frames(3)
	var paused_at := voice.get_playback_position()
	await get_tree().create_timer(0.2).timeout
	_check(voice.stream_paused and absf(voice.get_playback_position() - paused_at) < 0.1,
		"전략회의 일시정지 중 보스 BGM 재생 위치 유지")
	get_tree().paused = false
	await _frames(3)
	_check(not voice.stream_paused and voice.playing, "전략회의 종료 후 같은 곡 재개")
	main.spawner._on_day_started(main.day_night.day)
	await _frames(2)
	_check(voice.playing and music._active, "아침에도 보스가 남아 있으면 전투 음악 유지")
	boss.queue_free()
	await _frames(3)
	_check(not music._active and voice.playing, "보스가 사라지면 음악을 바로 끊지 않고 페이드아웃")
	# 페이드아웃 도중 다음 보스가 생겨도 이전 stop 콜백이 새 음악을 끊으면 안 된다.
	var puppet := EnemyPuppet.new().setup("venom_tyrant", Vector2(2000, 0))
	main.get_node("Enemies").add_child(puppet)
	await _frames(3)
	await get_tree().create_timer(SoundDB.BOSS_MUSIC_FADE_SECONDS + 0.1).timeout
	_check(voice.playing and music._active, "참가자용 보스 표시도 음악을 재개하고 이전 종료 페이드는 취소")
	puppet.queue_free()
	await _frames(3)
	await get_tree().create_timer(SoundDB.BOSS_MUSIC_FADE_SECONDS + 0.1).timeout
	_check(not voice.playing and not music._active, "마지막 보스가 사라지면 페이드 뒤 실제 재생 정지")
	_check(main.rng.state == rng_before, "보스 음악·반복·회의·전환은 게임 결과용 난수를 소비하지 않음")
	var temporary := MusicPlayer.new()
	main.add_child(temporary)
	temporary.setup(SoundDB.BOSS_MUSIC, SoundDB.BOSS_MUSIC_VOLUME_DB, SoundDB.BOSS_MUSIC_FADE_SECONDS)
	temporary.set_active(true)
	var weak_voice: WeakRef = weakref(temporary._player)
	temporary.queue_free()
	await _frames(2)
	_check(weak_voice.get_ref() == null, "음악 소유 노드 해제 시 재생기도 함께 해제")
	main.spawner.set_physics_process(spawner_processing)


func _check_weapon_art(main: Main) -> void:
	var weapons := WeaponVisual.TEXTURE.get_image()
	var projectile_art := Projectile.TEXTURE.get_image()
	var effects := CombatEffect.TEXTURE.get_image()
	var weapon_rows: Array[String] = []
	var placeholders := 0
	for id: String in ItemDB.ITEMS:
		if not ItemDB.ITEMS[id].has("weapon") and id != "bomb_bag":
			continue
		_check(WeaponArtDB.has_art(id), "%s 장비에는 무기 그림·모션이 정의됨 (그림이 없으면 계열 기본 그림)" % id)
		if not WeaponArtDB.WEAPONS.has(id):
			placeholders += 1
			continue
		var row := WeaponArtDB.weapon_texture(id).resource_path + str(WeaponArtDB.WEAPONS[id]["row"])
		weapons = WeaponArtDB.weapon_texture(id).get_image()
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
	_check(placeholders == 0 and WeaponArtDB.WEAPONS.size() == 35, "무기 34종과 폭탄 주머니가 모두 자체 원본을 사용")
	for id: String in WeaponArtDB.projectile_ids():
		projectile_art = WeaponArtDB.projectile_texture(id).get_image()
		var complete := true
		for frame in WeaponArtDB.PROJECTILE_FRAMES:
			complete = complete and not projectile_art.get_region(Rect2i(WeaponArtDB.projectile_region(id, frame * WeaponArtDB.PROJECTILE_FRAME_TIME + 0.001))).is_invisible()
		_check(complete, "%s 투사체의 모든 움직임 칸이 존재" % id)
	for id: String in WeaponArtDB.EFFECTS:
		effects = WeaponArtDB.effect_texture(id).get_image()
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
	var regions: Array[String] = []
	for skill_id: String in ActionBar.ICON_ORDER:
		var region := ActionBar.icon_region(skill_id)
		var picture := ActionBar.icon_texture(skill_id).get_image().get_region(Rect2i(region))
		var key := ActionBar.icon_texture(skill_id).resource_path + str(region)
		_check(not picture.is_invisible() and not regions.has(key), "%s 스킬은 고유한 픽셀 아이콘을 표시" % skill_id)
		regions.append(key)
	_check(bar._get_tooltip(bar.skill_slot_rect(0).get_center()).contains("Space")
		and bar._get_tooltip(bar.skill_slot_rect(1).get_center()).contains("우클릭")
		and bar._get_tooltip(bar.skill_slot_rect(ActionBar.FIXED_SLOTS).get_center()).contains("자동 등록"),
		"대시·무기 스킬(우클릭)·미장착 슬롯은 각각 단축키·장비 자동 등록 방법을 안내")
	var equipment := main.player.equipment
	var original_bag := equipment.bag.duplicate()
	var slots := ["weapon", "offhand", "armor", "charm"]
	var original_items: Array[String] = []
	for slot: String in slots:
		original_items.append(equipment.item_in(slot))
	for id: String in ["fire_staff", "bomb_bag", "guardian_armor", "life_charm"]:
		equipment.add_to_bag(id)
		equipment.equip(id)
	var last := ActionBar.FIXED_SLOTS + Equipment.MAX_SKILLS - 1
	_check(equipment.skill_bar().size() == 3
		and bar._get_tooltip(bar.skill_slot_rect(1).get_center()).contains("화염구")
		and bar._get_tooltip(bar.skill_slot_rect(ActionBar.FIXED_SLOTS).get_center()).contains("폭탄")
		and bar._get_tooltip(bar.skill_slot_rect(ActionBar.FIXED_SLOTS + 2).get_center()).contains("치유"),
		"무기 스킬은 우클릭 칸, 나머지 장비 스킬은 1~3칸에 실제 자동 등록 순서대로")
	_check(bar.skill_slot_rect(ActionBar.FIXED_SLOTS).position.x - bar.skill_slot_rect(1).end.x > ActionBar.GAP
		and bar.skill_slot_rect(last).end.x <= bar.size.x, "대시·무기 스킬을 장비 스킬과 구분하고 마지막 슬롯도 HUD 안에 배치")
	# 우클릭 무기 스킬 (D-027): 화염 지팡이의 화염구만 쿨타임에 들어간다.
	# 날아간 화염구가 나무를 맞혀 채집 경험치(20% 확률)를 주면 뒤 검사가 흔들리므로 월드는 건드리지 않게 쏜다
	main.player.hits_world = false
	main.player.use_weapon_skill()
	main.player.hits_world = true
	_check(not equipment.is_ready("fire_staff") and equipment.is_ready("bomb_bag"), "우클릭으로 무기 스킬(화염구)만 시전")
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


func _check_progression_hud(main: Main) -> void:
	var hud := main.hud._progression_hud
	var progression := main.player.progression
	var before := [progression.level, progression.xp, progression.points, progression.ranks.duplicate()]
	var art := ProgressionHud.TEXTURE.get_image()
	var regions_valid := art.get_size() == Vector2i(128, 64)
	for region: Rect2 in [ProgressionHud.BADGE, ProgressionHud.BADGE_LIT, ProgressionHud.BAR, ProgressionHud.FILL]:
		regions_valid = regions_valid and not art.get_region(Rect2i(region)).is_invisible()
	_check(regions_valid, "레벨 배지·성장 강조·경험치바 픽셀 아틀라스가 존재")
	progression.lose_level_progress()
	progression.add_xp(progression.xp_to_next() - 1)
	await get_tree().create_timer(ProgressionHud.GAIN_SECONDS + 0.05).timeout
	_check(hud._xp == progression.xp and is_equal_approx(hud._ratio, float(progression.xp) / progression.xp_to_next()),
		"경험치 획득 후 HUD 수치·진행바가 실제 이번 레벨 비율까지 채워짐")
	var level_before := progression.level
	var points_before := progression.points
	progression.add_xp(1)
	_check(hud._level == level_before + 1 and hud._points == points_before + 1 and hud._flash > 0.0 and hud._target_ratio == 0.0,
		"레벨업 시 배지·포인트·다음 레벨의 경험치바를 함께 갱신하고 강조")
	progression.add_xp(progression.xp_to_next() + Balance.xp_to_next_level(progression.level + 1) + 3)
	_check(hud._level == progression.level and hud._xp == 3 and hud._points == progression.points,
		"한 번에 여러 레벨이 올라도 최종 레벨·남은 경험치·포인트가 정확")
	var preserved_level := progression.level
	var preserved_points := progression.points
	progression.lose_level_progress()
	_check(hud._ratio == 0.0 and hud._xp == 0 and hud._level == preserved_level and hud._points == preserved_points,
		"사망 시 이번 경험치바만 즉시 비우고 레벨·포인트 표시는 유지")
	var learned := progression.learn("sword_mastery")
	_check(learned == "" and hud._points == preserved_points - 1 and hud._points_button.text.contains("%d점" % progression.points),
		"패시브 포인트 소비도 HUD 버튼 수량에 즉시 반영")
	hud._points_button.pressed.emit()
	_check(main.hud.passive_panel.visible, "HUD 포인트 버튼이 기존 K 패시브 창을 엶")
	main.hud.passive_panel.hide()
	# headless의 가상 마우스 위치는 입력 이벤트로 이동하지 않으므로 같은 히트테스트에 좌표를 주입한다.
	_check(main.hud.is_pointer_over_status(hud.get_global_rect().get_center()),
		"경험치 HUD 위의 클릭은 월드 기본 공격을 차단")
	var bounds := hud.get_global_rect()
	_check(bounds.position.x >= 0.0 and bounds.end.x <= get_viewport().get_visible_rect().size.x
		and main.hud._status_panel.get_global_rect().encloses(bounds) and bounds.end.y < 300.0,
		"축소된 경험치 패널은 화면 상단 상태창 안에 배치")
	progression.level = before[0]
	progression.xp = before[1]
	progression.points = before[2]
	progression.ranks = before[3]
	progression.changed.emit()
	await get_tree().create_timer(ProgressionHud.LEVEL_FLASH_SECONDS + 0.05).timeout
	_check(hud._flash == 0.0, "레벨업 강조는 잠시 후 사라져 상시 번쩍이지 않음")


## 실제 I 창에서 장착·해제·재료 스택·호버 설명·닫기가 함께 동작해야 한다.
## 몸이 올라가는 걸음에서 장비가 반대로 내려가던 원본 회귀를 확인한다.
func _check_worn_alignment() -> void:
	var image := EquipmentVisual.TEXTURE.get_image()
	var aligned := true
	for row in ItemArtDB.WORN_ORDER.size():
		if ItemArtDB.WORN_ORDER[row] == "cloth_shoes":
			continue  # 발은 몸통 흔들림이 아니라 각 발의 디딤 자세를 따른다.
		for direction in 3:
			for step in [0, 2]:
				var frame: int = direction * 4 + step
				var still := image.get_region(Rect2i(frame * 24, row * 24, 24, 24)).get_used_rect()
				var raised := image.get_region(Rect2i((frame + 1) * 24, row * 24, 24, 24)).get_used_rect()
				aligned = aligned and raised.position.y == still.position.y - 1
	_check(aligned, "착용 장비 9종·3방향은 몸이 올라가는 걸음에서 함께 1픽셀 상승")


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
	var used: Array[String] = []
	var complete := true
	for id: String in ItemDB.ITEMS:
		var icon := ItemArtDB.icon(id)
		if icon == null:
			complete = false
			continue
		var key := icon.atlas.resource_path + str(icon.region)
		complete = complete and not used.has(key) and not icon.atlas.get_image().get_region(Rect2i(icon.region)).is_invisible()
		used.append(key)
	_check(complete and used.size() == ItemDB.ITEMS.size(), "장비 %d종 전체에 서로 다른 실제 외형 아이콘이 있음" % used.size())
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


func _check_passive_effects(main: Main) -> void:
	var image := PassiveEffectDB.TEXTURE.get_image()
	var mapped := true
	for id: String in PassiveDB.PASSIVES:
		mapped = mapped and PassiveEffectDB.EFFECTS.has(PassiveEffectDB.effect_for(id))
	_check(mapped, "K 패시브 55종 모두 습득/발동 연출 분류가 있음")
	var complete := true
	var effects: Array[CombatEffect] = []
	var hp_before := main.player.hp
	var xp_before := main.player.progression.xp
	for id: String in PassiveEffectDB.EFFECTS:
		var first := image.get_region(Rect2i(PassiveEffectDB.region(id, 0.0))).get_data()
		for frame in PassiveEffectDB.FRAMES:
			var art := image.get_region(Rect2i(PassiveEffectDB.region(id, float(frame) / PassiveEffectDB.FRAMES)))
			var bounds := art.get_used_rect()
			complete = complete and bounds.has_area() and bounds.position.x > 0 and bounds.position.y > 0 and bounds.end.x < 128 and bounds.end.y < 128
		complete = complete and first != image.get_region(Rect2i(PassiveEffectDB.region(id, 0.99))).get_data()
		var effect := CombatEffect.spawn(get_tree(), id, main.player.global_position + Vector2(180, 0), 1.0)
		if effect != null:
			effects.append(effect)
	_check(complete and effects.size() == PassiveEffectDB.EFFECTS.size(), "패시브 연출 14종의 8프레임이 존재하고 가장자리 잘림 없이 변화")
	await get_tree().create_timer(0.85).timeout
	var expired := true
	for effect in effects:
		if is_instance_valid(effect):
			expired = false
	_check(expired and main.player.hp == hp_before and main.player.progression.xp == xp_before,
		"패시브 그림은 수명 뒤 제거되고 체력·경험치를 바꾸지 않음 (남은 그림 %s, 체력 %s → %s, 경험치 %d → %d)" % [not expired, hp_before, main.player.hp, xp_before, main.player.progression.xp])
	var admitted := 0
	for i in PassiveEffectDB.MAX_VISIBLE + 12:
		if CombatEffect.spawn(get_tree(), "passive_fortify", main.player.global_position, 1.0) != null:
			admitted += 1
	_check(admitted <= PassiveEffectDB.MAX_VISIBLE and admitted > 0, "같은 프레임에 요청한 대규모 요새화도 표시 수 한도를 넘지 않음")
	await get_tree().create_timer(0.85).timeout
	var actor := Player.new()
	var camera := Camera2D.new()
	camera.name = "Camera"
	camera.enabled = false
	actor.add_child(camera)
	main.add_child(actor)
	actor.set_physics_process(false)
	actor.hits_world = false
	actor.global_position = main.player.global_position + Vector2(400, 0)
	actor.progression.add_xp(1000)
	for id: String in ["vitality", "regeneration", "last_stand", "swift", "windstep", "sword_mastery", "sword_sweep", "whirlwind"]:
		actor.progression.learn(id)
	var seen: Array[String] = []
	actor.passive_visual_requested.connect(func(id: String, _at: Vector2, _radius: float, _angle: float) -> void: seen.append(id))
	actor.hp = 50.0
	actor._since_hit = PassiveDB.REGEN_DELAY
	actor._regenerate(1.0)
	_check(seen.has("regeneration") and actor.hp > 50.0, "재생 패시브의 실제 회복에 초록 연출이 연결됨")
	actor._invuln_time = 0.0
	actor.hp = 2.0
	actor.take_damage(9999.0)
	_check(seen.has("last_stand") and actor.hp == 1.0 and not actor.is_dead, "최후의 저항은 치명타를 버틴 순간 방어 문양 표시")
	actor.dash()
	_check(seen.has("windstep"), "배운 대시 패시브가 실제 대시에 바람 궤적 표시")
	for i in 4:
		actor._fire_weapon()
	_check(seen.has("whirlwind"), "회오리 베기는 횟수를 채워 360도 공격이 되는 순간 표시")
	var world_effects: Array[String] = []
	var heard_effect := func(id: String, _at: Vector2, _scale: float, _angle: float) -> void: world_effects.append(id)
	Events.combat_effect_requested.connect(heard_effect)
	var enemy := Enemy.new().setup("slime", false)
	enemy.position = actor.position + Vector2(100, 0)
	main.add_child(enemy)
	enemy.set_physics_process(false)
	var shot := Projectile.spawn(get_tree(), actor.global_position, {"direction": Vector2.ZERO, "art": "ember", "splash_radius": 48.0})
	shot.set_physics_process(false)
	await _frames(1)
	shot._splash(enemy)
	_check(world_effects.has("passive_ember"), "불씨 폭발 패시브의 실제 범위 피해에 화염 고리 표시")
	world_effects.clear()
	shot.team = Projectile.Team.TOWER
	shot._splash(enemy)
	_check(not world_effects.has("passive_ember"), "기본 대포탑의 범위 공격을 K 패시브 발동으로 표시하지 않음")
	Events.combat_effect_requested.disconnect(heard_effect)
	shot.queue_free()
	enemy.queue_free()
	actor.queue_free()
	await _frames(1)


## 모든 적의 그림이 존재하고 움직임·피격 표시가 기존 충돌과 피해 판정을 유지해야 한다.
func _check_enemy_art(main: Main) -> void:
	var normal := Enemy.SPRITE_TEXTURE.get_image()
	var bosses := Enemy.BOSS_TEXTURE.get_image()
	var atlas_ok := normal.get_size() == Vector2i(256, 512) and bosses.get_size() == Vector2i(1024, 896)
	var rows := {}
	var boss_shapes: Array[PackedByteArray] = []
	var motion_ok := true
	var rules_ok := true
	var boss_frames_ok := true
	for id: String in EnemyDB.TYPES:
		var stats: Dictionary = EnemyDB.TYPES[id]
		var is_boss: bool = stats.get("is_boss", false)
		var image := bosses if is_boss else normal
		var row_key := "%s:%d" % ["boss" if is_boss else "normal", stats["sprite_row"]]
		atlas_ok = atlas_ok and not rows.has(row_key)
		rows[row_key] = true
		var poses: Array[PackedByteArray] = []
		for frame in Enemy.animation_frames(id):
			var art := image.get_region(Rect2i(Enemy.sprite_region(id, frame)))
			var bounds := art.get_used_rect()
			atlas_ok = atlas_ok and bounds.has_area() and bounds.position.y >= int(stats["sprite_top"])
			if is_boss:
				boss_frames_ok = boss_frames_ok and bounds.position.x > 0 and bounds.position.y > 0 and bounds.end.x < Enemy.BOSS_SPRITE_SIZE and bounds.end.y < Enemy.BOSS_SPRITE_SIZE
				boss_frames_ok = boss_frames_ok and not poses.has(art.get_data())
			poses.append(art.get_data())
		if is_boss:
			atlas_ok = atlas_ok and not stats.has("tint") and not boss_shapes.has(poses[0])
			boss_shapes.append(poses[0])
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
		if id not in Enemy.IDLE_ANIMATED and not is_boss:
			motion_ok = motion_ok and enemy._animation_frame == 0
		var collider := enemy.get_child(0) as CollisionShape2D
		rules_ok = rules_ok and is_equal_approx((collider.shape as CircleShape2D).radius, stats["radius"])
		enemy.take_damage(1.0)
		rules_ok = rules_ok and is_equal_approx(enemy.hp, float(stats["hp"]) - 1.0) and enemy._flash > 0.0
		if is_boss:
			enemy._animation_time = 0.0
			enemy.hp = enemy.max_hp * 0.1
			enemy._update_animation(0.4)
			motion_ok = motion_ok and enemy._animation_frame > int(0.4 * Enemy.ANIMATION_FPS)
			var puppet := EnemyPuppet.new().setup(id, enemy.position)
			main.get_node("Enemies").add_child(puppet)
			puppet.apply(enemy.position, 0.1, 7, true, true)
			boss_frames_ok = boss_frames_ok and puppet._frame == 7 and puppet._flashing and puppet._facing_left
			boss_frames_ok = boss_frames_ok and Enemy.sprite_texture(id) == Enemy.BOSS_TEXTURE and Enemy.sprite_region(id, puppet._frame).size == Vector2.ONE * 128
			puppet.queue_free()
		enemy.queue_free()
	_check(atlas_ok and boss_shapes.size() == 7, "일반 적 7종·보스 7종 고유 행/실루엣과 체력바 높이가 유효")
	_check(boss_frames_ok, "보스별 8프레임은 서로 다르고 가장자리 잘림 없으며 원격 7번 프레임·반전·피격도 유효")
	_check(motion_ok, "적 이동·좌우·정지와 보스 호흡·분노 시 빠른 움직임이 반영")
	_check(rules_ok, "적 그래픽 교체 후에도 종류별 충돌·피해·피격 표시가 유지")


## 체력바 그림 교체가 표시 수명이나 실제 체력을 바꾸면 안 된다.
## Y 정렬은 같은 Z 안에서만 동작하고, 중간 컨테이너가 끊기면 그 아래가 한 덩어리가 된다.
func _check_depth_sort(main: Main) -> void:
	var enemies := main.get_node("Enemies") as Node2D
	_check(main.y_sort_enabled and main.world.y_sort_enabled and main.world.object_layer.y_sort_enabled
		and main.kingdom.y_sort_enabled and enemies.y_sort_enabled,
		"생성물 타일·건물·적·플레이어를 공통 Y 정렬로 연결")
	_check(main.player.z_index == main.world.object_layer.z_index and main.kingdom.core.z_index == main.player.z_index
		and not main.player.y_sort_enabled and not main.kingdom.core.y_sort_enabled,
		"몸·무기·장비는 기준점 하나로 묶고 성·생성물과 같은 Z에서 비교")
	_check(main.player.weapon_visual.get_index() > main.player._sprite.get_index()
		and main.player.weapon_visual.z_index == main.player._sprite.z_index, "무기는 몸·착용 장비 앞에 그리되 물체 간 Y 정렬을 유지")
	var first := Building.new().setup("arrow_tower", Vector2i.ZERO)
	var second := Building.new().setup("flame_tower", Vector2i.ZERO)
	main.kingdom.add_child(first)
	main.kingdom.add_child(second)
	first.position = main.kingdom.core.position + Vector2(500, 16)
	second.position = first.position - Vector2(0, 32)
	_check(first.get_parent() == second.get_parent() and (first.get_parent() as Node2D).y_sort_enabled
		and first.z_index == second.z_index and first.z_index == main.kingdom.core.z_index
		and not first.y_sort_enabled and not second.y_sort_enabled,
		"추가 순서와 무관하게 건물끼리·건물과 성도 같은 Y 정렬 사용")
	first.queue_free()
	second.queue_free()
	_check(main.world.terrain_layer.z_index < main.player.z_index
		and (main.get_node("Projectiles") as Node2D).z_index > main.player.z_index
		and (main.get_node("Effects") as Node2D).z_index > main.player.z_index
		and main.build_mode.z_index > main.player.z_index,
		"바닥은 뒤에, 공격 연출·설치 미리보기는 물체 위에 유지")


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


## 벽을 뺀 건물(문·공성탑·생활 건물)은 플레이어만 지나가고 적은 막힌다 (D-025·D-036). 왼쪽 칸에서 건물 칸 가운데로 움직여 본다
func _check_passable_buildings(main: Main) -> void:
	var kingdom := main.kingdom
	var world := main.world
	var enemy := Enemy.new().setup("slime", false)
	enemy.position = main.player.global_position + Vector2(0, 400)
	enemy.set_physics_process(false)
	main.get_node("Enemies").add_child(enemy)
	var built: Array[Vector2i] = []
	kingdom.add_resources({"wood": 40, "stone": 40})  # 앞 검사에서 창고를 썼어도 네 건물을 지을 수 있게
	for id: String in ["wood_door", "campfire", "arrow_tower", "stone_wall"]:
		var cell := World.NO_CELL
		for y in range(-4, 5):
			for x in range(-4, 5):
				var candidate := kingdom.core_cell() + Vector2i(x, y)
				if cell == World.NO_CELL and not kingdom.is_occupied(candidate) and not kingdom.is_occupied(candidate + Vector2i.LEFT) \
						and world.data.is_walkable(candidate + Vector2i.LEFT) and kingdom.build(candidate, id, main.player.global_position) == "":
					cell = candidate
		if cell == World.NO_CELL:
			_check(false, "%s 통과 검사용 칸을 찾지 못함" % id)
			continue
		built.append(cell)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var start := Transform2D(0.0, world.cell_center(cell) - Vector2(Balance.TILE, 0))
		var motion := Vector2(Balance.TILE, 0)
		var player_blocked := main.player.test_move(start, motion)
		var enemy_blocked := enemy.test_move(start, motion)
		if id == "stone_wall":
			_check(player_blocked and enemy_blocked, "벽은 플레이어와 적 모두 막음")
		else:
			_check(not player_blocked and enemy_blocked, "%s: 플레이어는 지나가고 적은 막힘" % BuildingDB.TYPES[id]["name"])
	for cell in built:
		kingdom.demolish(cell)
	enemy.queue_free()
	await _frames(1)


## 낮의 배회 적은 왕국 영토에 들어오지 않고 영토 안의 플레이어를 노리지 않는다. 밤에는 풀린다 (D-026)
func _check_daytime_kingdom(main: Main) -> void:
	var player := main.player
	var spawner := main.spawner
	var core := main.kingdom.core.global_position
	var edge := (Balance.TERRITORY_RADIUS + 0.5) * Balance.TILE
	spawner.set_physics_process(false)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	await _frames(2)
	# 경계 안팎 몇 칸이 모두 걸을 수 있는 방향을 고른다 (물·나무에 막혀 결과가 흐려지지 않게)
	var direction := Vector2.ZERO
	for i in 16:
		var candidate := Vector2.from_angle(TAU * i / 16.0)
		var clear := true
		for step in range(-3, 4):
			var cell := main.world.cell_at(core + candidate * (edge + step * Balance.TILE))
			clear = clear and main.world.data.is_walkable(cell) and main.world.data.get_object(cell) == WorldData.Obj.NONE and not main.kingdom.is_occupied(cell)
		if clear:
			direction = candidate
			break
	if direction == Vector2.ZERO:
		_check(false, "낮 왕국 검사용 빈 경계를 찾지 못함")
		spawner.set_physics_process(true)
		return
	var position_before := player.global_position
	player.global_position = core + direction * (edge - 2.0 * Balance.TILE)
	var hp_before := player.hp
	var outside := Enemy.new().setup("slime", false)
	var inside := Enemy.new().setup("slime", false)
	spawner._spawn("slime", core + direction * (edge + 2.0 * Balance.TILE), false, 1.0)
	var spawned: Enemy = main.get_node("Enemies").get_child(-1)
	_check(spawned.avoids_kingdom, "낮에 생긴 배회 적은 왕국을 피함")
	spawned.queue_free()
	outside.avoids_kingdom = true
	inside.avoids_kingdom = true
	outside.position = core + direction * (edge + 2.0 * Balance.TILE)
	inside.position = core + direction * (edge - 1.0 * Balance.TILE)
	main.get_node("Enemies").add_child(outside)
	main.get_node("Enemies").add_child(inside)
	var entered := false
	for i in 60:
		await get_tree().physics_frame
		entered = entered or outside.in_kingdom(outside.global_position)
	_check(not entered and outside._target == null and player.hp == hp_before,
		"낮에는 영토 안 플레이어를 노리지 않고 경계 밖에 머묾 (체력 %d → %d)" % [hp_before, player.hp])
	_check(not inside.in_kingdom(inside.global_position), "낮에 영토 안에 있던 배회 적은 밖으로 밀려남")
	spawner._on_night_started(main.day_night.day)
	_check(not outside.avoids_kingdom, "밤이 되면 배회 적도 영토 안까지 쫓아옴")
	await get_tree().physics_frame
	_check(outside._target == player, "밤에는 영토 안 플레이어를 다시 노림")
	spawner._on_day_started(main.day_night.day)
	_check(outside.avoids_kingdom, "아침이 되면 다시 왕국을 피함")
	outside.queue_free()
	inside.queue_free()
	player.global_position = position_before
	spawner.set_physics_process(true)
	await _frames(1)


## 낮 의뢰(D-037): 아침에 의뢰가 생기고, 정예·보물 고블린·광맥을 끝내면 보상, 해가 지면 실패
func _check_quests(main: Main) -> void:
	var board := main.quest_board
	var player := main.player
	var world := main.world
	if player.is_dead:
		player._respawn()
	board.roll(1)
	var kinds := {}
	var placed_ok := true
	for quest in board.quests:
		kinds[quest["kind"]] = true
		placed_ok = placed_ok and QuestDB.tier_of(quest["terrain"]) <= 1 and Vector2(quest["at"]).distance_to(player.global_position) >= QuestDB.MIN_DISTANCE * Balance.TILE
	_check(board.active().size() == QuestDB.PER_DAY and kinds.size() == QuestDB.PER_DAY and placed_ok and main.map_state.quest_markers.size() == QuestDB.PER_DAY,
		"아침에 서로 다른 의뢰 %d개가 가까운 바이옴·플레이어와 떨어진 곳에 생기고 지도에 표시됨" % QuestDB.PER_DAY)
	await _frames(2)
	var tracker := main.hud.quest_tracker
	_check(tracker.visible and tracker._rows.get_child_count() == 1 + QuestDB.PER_DAY * 2, "미니맵 아래 오늘의 의뢰 창에 의뢰가 보임")
	var gained := []
	var listen := func(amounts: Dictionary, _at: Vector2) -> void: gained.append(amounts)
	Events.resources_gained.connect(listen)
	board.quests.clear()
	board._start("elite", WorldData.Terrain.FOREST)
	var elite: Enemy = board._target(board.quests[0]["id"])
	_check(elite != null and elite.elite and elite.max_hp > EnemyDB.TYPES["wolf"]["hp"] * 3.0, "정예 사냥: 크고 강한 정예 늑대가 나타남")
	await _frames(1)
	elite.take_damage(999999.0, Enemy.SOURCE_LOCAL)
	await _frames(2)
	_check(board.quests[0]["state"] == "done" and gained.any(func(amounts: Dictionary) -> bool: return amounts.get("tough_hide", 0) >= QuestDB.KINDS["elite"]["drop_amount"][1]),
		"정예를 잡으면 의뢰 완료, 숲 몬스터 재료(질긴 가죽) 보상")
	board.quests.clear()
	board._start("runner", WorldData.Terrain.DESERT)
	var runner: Enemy = board._target(board.quests[0]["id"])
	var position_before := player.global_position
	player.global_position = runner.global_position + Vector2(-4.0 * Balance.TILE, 0)
	runner._sleep_check = 0.0
	for i in 3:
		await get_tree().physics_frame
	_check(runner.flees and runner.velocity.x > 0.0, "보물 고블린은 다가가면 반대쪽으로 도망감")
	runner.take_damage(999999.0, Enemy.SOURCE_LOCAL)
	await _frames(2)
	_check(board.quests[0]["state"] == "done", "보물 고블린을 잡으면 의뢰 완료")
	player.global_position = position_before
	board.quests.clear()
	board._start("vein", WorldData.Terrain.SNOW)
	var cells: Array = board._vein_cells[board.quests[0]["id"]]
	var all_iron := cells.all(func(cell: Vector2i) -> bool: return world.data.get_object(cell) == WorldData.Obj.IRON_ORE)
	_check(cells.size() == board.quests[0]["total"] and cells.size() >= 4 and all_iron, "운석 광맥: 설원에 철광석 %d개가 솟음" % cells.size())
	world.damage_object(cells[0], 99999.0, Enemy.SOURCE_LOCAL)
	_check(board.quests[0]["progress"] == 1 and board.quests[0]["state"] == "active", "광맥을 하나 캐면 진행도 1")
	for cell: Vector2i in cells:
		world.damage_object(cell, 99999.0, Enemy.SOURCE_LOCAL)
	_check(board.quests[0]["state"] == "done", "광맥을 다 캐면 의뢰 완료")
	Events.resources_gained.disconnect(listen)
	board.quests.clear()
	board._start("elite", WorldData.Terrain.GRASS)
	var leftover: Enemy = board._target(board.quests[0]["id"])
	board._on_night_started(1)
	await _frames(1)
	_check(board.quests[0]["state"] == "failed" and (not is_instance_valid(leftover) or leftover.is_queued_for_deletion()) and main.map_state.quest_markers.is_empty(),
		"해가 지면 끝내지 못한 의뢰는 실패하고 정예는 사라짐")
	board.quests.clear()
	board._publish()


## 아침 재생(D-035): 부서진 나무·바위·광석은 아침에 처음 총량까지 다시 자라고, 바이옴 서식 몬스터도 모자란 만큼 채워진다
func _check_daily_regrowth(main: Main) -> void:
	var world := main.world
	var data := world.data
	var targets := data.resource_targets
	var broken := 0
	for i in data.objects.size():
		if broken >= 30:
			break
		var obj := data.objects[i]
		if obj in World.HARVESTABLE:
			var cell := Vector2i(i % data.size.x, i / data.size.x)
			if not main.kingdom.in_territory(cell):
				world.damage_object(cell, 99999.0, World.NOBODY)
				broken += 1
	var before := WorldGenerator.count_resources(data)
	var short := 0
	for key: Vector2i in targets:
		short += maxi(0, targets[key] - before.get(key, 0))
	var grown := main.regrow_resources()
	var after := WorldGenerator.count_resources(data)
	# 낮 의뢰 광맥(D-037)은 목표보다 많을 수 있으므로 "목표 이상"으로 본다
	var full := targets.keys().all(func(key: Vector2i) -> bool: return after.get(key, 0) >= targets[key])
	_check(broken == 30 and short >= 30 and grown == short and full,
		"아침 재생: 부서진 %d개만큼 같은 바이옴에 다시 자라 처음 총량으로 (%d개 자람)" % [short, grown])
	var spawner := main.spawner
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	await _frames(2)
	var refilled := spawner.refill_residents()
	await _frames(2)
	var counts := spawner.resident_counts()
	var expected := 0
	for terrain: int in spawner.resident_targets():
		expected += spawner.resident_targets()[terrain]
	var placed_ok := true
	for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
		placed_ok = placed_ok and enemy.home.is_finite() and data.get_terrain(world.cell_at(enemy.home)) == enemy.home_terrain \
			and not main.kingdom.in_territory(world.cell_at(enemy.global_position)) \
			and enemy.global_position.distance_to(main.player.global_position) >= Balance.RESIDENT_PLAYER_GAP
	_check(refilled == expected and counts == spawner.resident_targets() and placed_ok and spawner.resident_targets().size() == 6,
		"바이옴 6곳에 서식 몬스터 %d마리: 자기 바이옴·영토 밖·플레이어와 떨어진 곳" % refilled)
	_check(spawner.refill_residents() == 0, "이미 다 차 있으면 아침에도 더 생기지 않음")
	var resident: Enemy = get_tree().get_nodes_in_group("enemies")[0]
	resident.global_position = resident.home + Vector2(Balance.RESIDENT_LEASH + 6.0 * Balance.TILE, 0)
	# 먼 서식 몬스터는 잠들므로, 플레이어를 깨어나는 거리 안·쫓기는 거리 밖에 둔다
	var player_before := main.player.global_position
	main.player.global_position = resident.global_position + Vector2(0, 20.0 * Balance.TILE)
	resident._sleep_check = 0.0
	# 옮긴 자리가 물·바위에 막혔을 수 있으므로 실제 이동 거리 대신 집 쪽으로 가려는지를 본다
	for i in 3:
		await get_tree().physics_frame
	main.player.global_position = player_before
	_check(is_instance_valid(resident) and resident.velocity.dot(resident.home - resident.global_position) > 0.0,
		"서식지에서 멀어진 몬스터는 사라지지 않고 집 쪽으로 돌아감")
	main.player.global_position = resident.home + Vector2(0, Balance.RESIDENT_WAKE_RANGE + 10.0 * Balance.TILE)
	resident._sleep_check = 0.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(resident._asleep, "플레이어가 멀면 서식 몬스터는 잠들어 움직이지 않음 (성능)")
	main.player.global_position = player_before
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	await _frames(2)


## E 상호작용(D-031): 주변에 하나면 그것, 여럿이면 마우스에 가까운 것. 열릴 대상 위에 E 안내가 뜬다
func _check_interact_choice(main: Main) -> void:
	var kingdom := main.kingdom
	var player := main.player
	var position_before := player.global_position
	var far := kingdom.core.global_position + Vector2(0, 40 * Balance.TILE)
	player.global_position = kingdom.core.global_position + Vector2(0, 3 * Balance.TILE)
	main.mouse_override = far
	await _frames(1)
	var only := main.interact_target(far)
	_check(main.interactables().size() == 1 and only.get("kind", "") == "core", "주변에 왕국 핵 하나뿐이면 마우스가 멀어도 핵이 열림")
	_check(main._prompt.visible and main._prompt._target.get("kind", "") == "core", "열릴 대상 위에 E 안내가 보임")
	var cell := _free_cell_near(main, main.world.cell_at(player.global_position), 1)
	kingdom.add_resources({"wood": 30})
	_check(kingdom.build(cell, "gear_chest", player.global_position) == "", "E 선택 검사용 장비 상자")
	await _frames(1)
	var chest_at := main.world.cell_center(cell)
	var near_chest := main.interact_target(chest_at)
	var near_core := main.interact_target(kingdom.core.global_position)
	_check(main.interactables().size() == 2 and near_chest.get("kind", "") == "storage" and near_core.get("kind", "") == "core",
		"여럿이면 마우스를 올린 쪽(상자·핵)이 열림")
	main.hud.kingdom_panel.hide()
	main.mouse_override = chest_at
	main._interact()
	_check(main.hud.storage_panel.visible and not main.hud.kingdom_panel.visible, "E를 누르면 마우스를 올린 장비 상자가 열림")
	main.hud.storage_panel.hide()
	kingdom.demolish(cell)
	main.mouse_override = Vector2.INF
	player.global_position = position_before
	await _frames(1)


## 왕국 핵 창(D-027): 핵 옆 E로 열리고, 영토 확장은 비용을 내고 건설 범위·적의 낮 경계를 함께 넓힌다
func _check_kingdom_panel(main: Main) -> void:
	var kingdom := main.kingdom
	var player := main.player
	var stock_before := kingdom.stock.duplicate()
	var position_before := player.global_position
	player.global_position = kingdom.core.global_position + Vector2(0, 2.5 * Balance.TILE)
	await _frames(1)
	var interact := InputEventAction.new()
	interact.action = "interact"
	interact.pressed = true
	Input.parse_input_event(interact)
	await _frames(2)
	var panel := main.hud.kingdom_panel
	_check(panel.visible and not player.attack_enabled, "핵 옆에서 E로 왕국 핵 창이 열리고 공격이 멈춤")
	var art := KingdomPanel.ICONS.get_image()
	var icons_ok := art.get_size() == Vector2i(256, 64)
	for i in 4:
		icons_ok = icons_ok and not art.get_region(Rect2i(i * 48, 0, 48, 48)).is_invisible()
	_check(icons_ok and panel._rows.size() == 4 and panel._health.get_theme_stylebox("fill") is StyleBoxTexture,
		"왕국 집무실은 네 전용 픽셀 아이콘·성채 체력 그래픽·네 운영 카드를 표시")
	_check((panel._rows["repair"]["button"] as Button).disabled and panel._preview.radius == kingdom.territory_radius(),
		"성채가 멀쩡하면 수리 비활성·영토 그림은 실제 반지름을 반영")
	var outside := kingdom.core_cell() + Vector2i(Balance.TERRITORY_RADIUS + 2, 0)
	kingdom.stock = {}
	player.inventory.clear()
	panel._refresh()
	var territory: Dictionary = panel._rows["territory"]
	_check((territory["button"] as Button).disabled and kingdom.expand_territory(player.global_position, player.inventory).contains("필요"),
		"재료가 없으면 영토 확장 불가")
	kingdom.add_resources(Balance.TERRITORY_UPGRADES[0])
	panel._refresh()
	(territory["button"] as Button).pressed.emit()
	_check(kingdom.territory_level == 1 and kingdom.in_territory(outside) and kingdom.in_territory_at(kingdom.world.cell_center(outside))
			and kingdom.stock.get("tough_hide", 0) == 0,
		"영토 확장: 비용을 내고 반지름 %d칸, 건설 범위와 적의 경계가 함께 넓어짐" % kingdom.territory_radius())
	_check((territory["cost"] as GridContainer).get_child_count() == Balance.TERRITORY_UPGRADES[1].size()
		and panel._preview.level == 1, "확장 후 다음 단계 재료 아이콘과 성채의 영토 그림을 갱신")
	kingdom.core.take_damage(100.0)
	kingdom.add_resources(Balance.REPAIR_COST)
	panel._refresh()
	var hp_before := kingdom.core.hp
	(panel._rows["repair"]["button"] as Button).pressed.emit()
	_check(kingdom.core.hp > hp_before and is_equal_approx(panel._health.value, kingdom.core.hp),
		"왕국 수리 카드도 기존 명령으로 체력을 회복하고 그래픽을 갱신")
	kingdom.core.repair(kingdom.core.max_hp)
	_check(kingdom.expand_territory(kingdom.core.global_position + Vector2(0, 10 * Balance.TILE), null).contains("핵"),
		"핵에서 멀면 영토 확장 불가")
	panel.hide()
	# 다른 검사는 기본 영토를 가정하므로 되돌린다
	kingdom.territory_level = 0
	kingdom.queue_redraw()
	kingdom.stock = stock_before
	player.global_position = position_before
	await _frames(1)


## 무기 트리 스킬·효과 (D-028): 기절, 반격 자세, 번개 연쇄, 2차 폭발, 관통 강화
func _check_weapon_skills(main: Main) -> void:
	var player := main.player
	if player.is_dead:
		player._respawn()
	player.global_position = player.spawn_point
	main.spawner.set_physics_process(false)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	await _frames(2)
	var spawn := func(offset: Vector2) -> Enemy:
		var enemy := Enemy.new().setup("brute", false)
		enemy.position = player.global_position + offset
		main.get_node("Enemies").add_child(enemy)
		enemy.set_physics_process(false)  # 움직이거나 때리지 않게 세워 둔다
		return enemy
	var near: Enemy = spawn.call(Vector2(60, 0))
	await _frames(1)
	player.blast(100.0, 1.0, {"slow_factor": 0.0, "slow_time": 1.0})
	_check(near._slow_time > 0.0 and near._slow_factor == 0.0, "흑요석 대검의 내려찍기: 맞은 적이 기절(속도 0)")

	var counter: Dictionary = ItemDB.ITEMS["guard_sword"]["skill"]
	var hp_before := near.hp
	var player_hp := player.hp
	player._invuln_time = 0.0  # 부활 직후 무적이면 막은 횟수로 세지 않는다
	player.activate_counter(counter)
	player.take_damage(10.0)
	player.take_damage(10.0)
	await get_tree().create_timer(counter["duration"] + 0.2).timeout
	var expected: float = counter["damage"] + counter["per_block"] * 2
	_check(player.hp == player_hp and is_equal_approx(hp_before - near.hp, expected),
		"수호검의 반격 자세: 막은 2번만큼 강해진 충격파 (%d 피해)" % (hp_before - near.hp))
	near.queue_free()

	var first: Enemy = spawn.call(Vector2(80, 0))
	var second: Enemy = spawn.call(Vector2(80, 70))
	var third: Enemy = spawn.call(Vector2(80, 140))
	await _frames(2)
	var full := first.max_hp
	player.hits_world = false
	player.fire({"direction": Vector2.RIGHT, "damage": 10.0, "speed": 900.0, "lifetime": 0.3, "chain": 2})
	await get_tree().create_timer(0.25).timeout
	_check(first.hp < full and second.hp < full and third.hp < full, "번개 지팡이: 맞은 적에서 근처 적 2마리로 연쇄")
	for enemy: Enemy in [first, second, third]:
		enemy.queue_free()

	var target: Enemy = spawn.call(Vector2(0, 50))
	await _frames(2)
	var target_full := target.max_hp
	player.fire({"direction": Vector2.DOWN, "damage": 20.0, "speed": 0.0, "lifetime": 0.01, "explode_radius": 50.0, "second_blast": true})
	await get_tree().create_timer(0.15).timeout
	var after_first := target.hp
	await get_tree().create_timer(Projectile.SECOND_BLAST_DELAY + 0.2).timeout
	_check(after_first < target_full and target.hp < after_first, "흑요석 공성 석궁: 폭발 볼트가 잠깐 뒤 한 번 더 터짐")
	target.queue_free()
	player.hits_world = true
	main.spawner.set_physics_process(true)
	await _frames(1)


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

	main.mouse_override = main.world.cell_center(cell)  # 핵·제작대도 가까우면 마우스를 올린 상자가 열린다 (D-031)
	var interact := InputEventAction.new()
	interact.action = "interact"
	interact.pressed = true
	Input.parse_input_event(interact)
	await _frames(2)
	_check(main.hud.storage_panel.visible and not player.attack_enabled, "E로 장비 상자 창이 열리고 공격이 꺼짐")
	main.mouse_override = Vector2.INF
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

	_check(kingdom.upgrade_workbench(kingdom.core.global_position + Vector2(0, 10 * Balance.TILE), player.inventory).contains("핵"),
		"제작대 강화는 왕국 핵 근처에서만 (D-027)")
	error = kingdom.upgrade_workbench(player.global_position, player.inventory)
	_check(error == "" and kingdom.workbench_tier() == 1, "몬스터 재료로 핵에서 제작대 1단계 강화 %s" % error)
	var upgraded_region := Building.sprite_region("workbench", kingdom.workbench_tier())
	_check(upgraded_region != Building.sprite_region("workbench", 0), "제작대 업그레이드 후 단계별 그림으로 전환")
	_check(kingdom.craft("chain_mail", player.global_position, player.inventory, player.equipment) == "", "1단계가 되면 사슬 갑옷 제작")
	# 무기 강화 (D-028): 이전 무기를 소모하고, 들고 있었으면 손에 든 채로 바뀐다
	if player.equipment.item_in("weapon") != "rusty_sword":
		player.equipment.add_to_bag("rusty_sword")
		player.equipment.equip("rusty_sword")
	kingdom.add_resources({"hardwood": 20, "copper": 20, "tough_hide": 10, "venom_sting": 10})
	kingdom.discover({"hardwood": 1, "copper": 1, "tough_hide": 1, "venom_sting": 1})
	_check(kingdom.craft("siege_crossbow", player.global_position, player.inventory, player.equipment).contains("나무 석궁"),
		"강화할 이전 무기(나무 석궁)가 없으면 공성 석궁을 만들 수 없음")
	var bag_size := player.equipment.bag.size()
	error = kingdom.craft("greatsword", player.global_position, player.inventory, player.equipment)
	_check(error == "" and player.equipment.item_in("weapon") == "greatsword" and not player.equipment.owns("rusty_sword")
			and player.equipment.bag.size() == bag_size,
		"들고 있던 낡은 검을 소모해 대검으로 강화 (손에 그대로) %s" % error)
	_check(kingdom.demolish(cells[0]) != "" and kingdom.workbench_tier() == 1, "단계를 올린 제작대는 철거할 수 없음")

	main.mouse_override = main.world.cell_center(cells[0])  # 핵도 가까우면 마우스를 올린 제작대가 열린다 (D-031)
	var interact := InputEventAction.new()
	interact.action = "interact"
	interact.pressed = true
	Input.parse_input_event(interact)
	await _frames(2)
	_check(main.hud.crafting_panel.visible, "E로 제작대 창이 열림")
	main.mouse_override = Vector2.INF
	var panel := main.hud.crafting_panel
	var bag_before := player.equipment.bag.size()
	panel.select_recipe("old_bow")
	_check(player.equipment.bag.size() == bag_before and panel._item_icon.texture != null,
		"제작 설계도 선택은 아이콘·상세만 표시하고 장비를 만들지 않음")
	panel._craft.pressed.emit()
	_check(player.equipment.bag.size() == bag_before + 1 and player.equipment.bag.back() == "old_bow",
		"제작 버튼이 기존 명령 경로로 선택 장비 1개를 가방에 추가")
	panel.show_tier(3)
	_check(panel._empty.visible and panel._craft.disabled, "미발견 단계는 빈 목록 안내·제작 비활성")
	panel.show_tier(-1)
	panel.select_recipe("iron_helm")
	_check(panel._selected != "iron_helm", "아직 공개되지 않은 설계도는 선택 불가")
	kingdom.add_resources({"iron_ore": 8})
	kingdom.discover({"iron_ore": 8})
	panel._refresh()
	panel.select_recipe("iron_helm")
	_check(panel._craft.disabled and panel._status.text.contains("강화"), "재료가 있어도 제작대 단계가 낮으면 상세 확인만 가능")
	panel.select_recipe("old_bow")
	var wood_before := player.inventory.count("wood") + int(kingdom.stock.get("wood", 0))
	player.inventory.take("wood", player.inventory.count("wood"))
	kingdom.stock["wood"] = 0
	await get_tree().create_timer(0.25).timeout
	_check(panel._craft.disabled and panel._status.text == "재료 부족", "열린 제작 창에서 자원 감소를 자동 반영")
	kingdom.add_resources({"wood": wood_before})
	await get_tree().create_timer(0.25).timeout
	_check(not panel._craft.disabled, "자원이 늘면 설계도 선택을 유지하며 제작 가능으로 복귀")
	_check(panel._title.text.contains("1 / 3단계") and not "_upgrade" in panel, "제작 창은 현재 단계만 표시하고 강화 UI는 제거")
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
	progression.lose_level_progress()

	# 채집 경험치는 호스트가 20% 확률로 굴린다(확률은 logic_test). 여기서는 굴린 값이 그대로 들어오는지만 본다
	var tree_cell := _find_tree(world)
	main.grant_harvest(WorldData.Obj.TREE, tree_cell, {"wood": 1}, 2)
	_check(progression.xp == 2, "채집 경험치가 나오면 그만큼 받음 (경험치 %d)" % progression.xp)
	main.grant_harvest(WorldData.Obj.TREE, tree_cell, {"wood": 1}, 0)
	_check(progression.xp == 2, "채집 경험치가 안 나오면 재료만 받음")

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
	var level_before := progression.level
	var points_before := progression.points
	progression.add_xp(1)
	await _kill_player(player)
	_check(player.is_dead and progression.xp == 0 and progression.rank("vitality") == vitality_rank
			and progression.level == level_before and progression.points == points_before,
		"죽으면 이번 레벨의 경험치만 사라지고 레벨·포인트·패시브는 남음")
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
	player.global_position = player.spawn_point
	await _frames(2)
	var near := _free_cell_near(main, world.cell_at(player.spawn_point), 2)
	var error := kingdom.build(near, "iron_wall", player.global_position, null)
	_check(error.contains("방어") and not kingdom.buildings.has(near), "방어 단계가 모자라면 철벽을 못 지음 (%s)" % error)
	if bench == World.NO_CELL:
		bench = _free_cell_near(main, world.cell_at(player.spawn_point), 3)
		kingdom.build(bench, "workbench", player.global_position, null)
	_check(kingdom.workbench_tier() >= 0 and kingdom.build(near, "iron_wall", player.global_position, null) != "",
		"제작대 단계는 건물을 열지 않음 (D-027)")
	var upgraded := 0
	for i in BuildingDB.max_defense_tier():
		if kingdom.upgrade_defense(player.global_position, null) == "":
			upgraded += 1
	_check(upgraded == BuildingDB.max_defense_tier() and kingdom.upgrade_defense(player.global_position, null) != "",
		"채집 재료로 방어 단계를 최고까지 올림 (%d단계)" % kingdom.defense_tier)
	_check(kingdom.build(near, "iron_wall", player.global_position, null) == "", "방어 단계가 오르면 철벽을 지을 수 있음")
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


## 환경 설정(D-030): Esc 메뉴 → 설정, 볼륨·UI 크기·흔들림·피해 숫자가 바로 적용되고 기본값으로 돌아감
func _check_settings(main: Main) -> void:
	var settings := Session.settings
	var hud := main.hud
	var press_escape := func() -> void:
		var escape := InputEventAction.new()
		escape.action = "ui_cancel"
		escape.pressed = true
		Input.parse_input_event(escape)
	main._close_overlays()
	await _frames(1)
	press_escape.call()
	await _frames(2)
	_check(hud.pause_menu.visible and not main.player.attack_enabled, "아무 창도 없을 때 Esc로 메뉴가 열리고 공격이 멈춤")
	# 게임 종료는 한 번 누르면 확인만 묻는다 (두 번째는 실제로 꺼지므로 여기서 누르지 않는다)
	hud.pause_menu.quit_button.pressed.emit()
	_check(hud.pause_menu.visible and hud.pause_menu.quit_button.text == PauseMenu.QUIT_CONFIRM_TEXT, "게임 종료는 한 번 더 눌러야 꺼짐")
	hud.pause_menu.open_settings()
	await _frames(1)
	var panel := hud.pause_menu.settings_panel
	(panel._controls["music_volume"] as Range).value = 0.0
	(panel._controls["ui_scale"] as Range).value = 1.2
	(panel._controls["shake"] as Range).value = 0.0
	(panel._controls["damage_numbers"] as CheckBox).button_pressed = false
	await _frames(1)
	var music_db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index(GameSettings.MUSIC_BUS))
	_check(panel.visible and music_db <= -79.0, "설정 창에서 음악 볼륨 0이면 음악 버스가 꺼짐 (%.0fdB)" % music_db)
	_check(is_equal_approx(get_tree().root.content_scale_factor, 1.2) and main.player.camera.zoom.is_equal_approx(main._base_zoom / 1.2),
		"UI 크기 120%: 화면 배율은 커지고 카메라 줌은 되돌려 월드 크기는 그대로")
	main.player._shake = 0.0
	main.player.add_shake(5.0)
	var fx := get_tree().get_first_node_in_group("fx_layer")
	var labels_before := fx.get_children().filter(func(node: Node) -> bool: return node is Label).size()
	main.show_damage(main.player.global_position, 10.0, false)
	var labels_after := fx.get_children().filter(func(node: Node) -> bool: return node is Label).size()
	_check(main.player._shake == 0.0 and labels_after == labels_before, "흔들림 0·피해 숫자 끄기가 바로 적용됨")
	press_escape.call()
	await _frames(2)
	_check(not panel.visible and hud.pause_menu.visible, "설정 창에서 Esc는 설정만 닫고 메뉴로 돌아감")
	var saved := GameSettings.new()
	saved.path = TEST_SETTINGS
	saved.load_file()
	_check(is_equal_approx(saved.get_value("ui_scale"), 1.2) and not saved.get_value("damage_numbers"), "설정 창을 닫으면 파일에 저장됨")
	press_escape.call()
	await _frames(2)
	_check(not hud.pause_menu.visible, "메뉴에서 Esc를 다시 누르면 닫힘")
	settings.reset()
	await _frames(1)
	_check(is_equal_approx(get_tree().root.content_scale_factor, 1.0) and main.player.shake_scale == 1.0, "기본값으로 되돌리면 원래 화면으로")


## 무기별 타격감(D-029): 내가 맞힌 것만 흔들리고, 대검은 쌍검보다 세게 흔들리고 멀리 밀어낸다
func _check_weapon_feel(main: Main) -> void:
	var player := main.player
	var missing := ItemDB.ITEMS.keys().filter(func(id: String) -> bool:
		return ItemDB.ITEMS[id].has("weapon") and not WeaponArtDB.FEEL.has(WeaponArtDB.art(id).get("branch", "")))
	_check(missing.is_empty(), "모든 무기 갈래에 타격감 값이 있음 %s" % [missing])
	var previous := player.equipment.item_in("weapon")
	var me := multiplayer.get_unique_id()
	var hit_feel := func(weapon: String, source: int) -> float:
		player.equipment.add_to_bag(weapon)
		player.equipment.equip(weapon)
		player._shake = 0.0
		main._last_hit_feel = 0
		main.show_damage(player.global_position + Vector2(40, 0), 10.0, false, source)
		return player._shake
	var tower: float = hit_feel.call("greatsword", Enemy.SOURCE_TOWER)
	var heavy: float = hit_feel.call("greatsword", me)
	await get_tree().create_timer(0.2, true, false, true).timeout  # 대검 멈칫이 끝나기를 기다린다
	var light: float = hit_feel.call("twin_blades", me)
	_check(tower == 0.0 and heavy > light and light > 0.0, "내가 맞힌 것만 흔들리고 대검이 쌍검보다 셈 (탑 %.1f, 대검 %.1f, 쌍검 %.1f)" % [tower, heavy, light])
	await get_tree().create_timer(0.2, true, false, true).timeout
	var pushed := func(weapon: String) -> float:
		var dummy := Enemy.new().setup("brute", false)
		dummy.position = player.global_position + Vector2(30, 0)
		main.get_node("Enemies").add_child(dummy)
		dummy.set_physics_process(false)
		var stats: Dictionary = ItemDB.ITEMS[weapon]["weapon"].duplicate()
		stats["damage"] = 0.0
		stats["hits_world"] = false
		Melee.swing(get_tree(), player.global_position, Vector2.RIGHT, stats)
		var push := dummy._knockback.length()
		dummy.queue_free()
		return push
	await _frames(1)
	_check(pushed.call("greatsword") > pushed.call("twin_blades"), "대검은 쌍검보다 맞은 적을 멀리 밀어냄")
	player.add_kick(WeaponArtDB.feel("longbow")["kick"])
	_check(player._kick.dot(player.aim_direction) < 0.0, "장궁을 쏘면 화면이 조준 반대쪽으로 밀림 (반동)")
	player._kick = Vector2.ZERO
	player.equipment.add_to_bag(previous)
	player.equipment.equip(previous)
	await get_tree().create_timer(0.2, true, false, true).timeout


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
	await _check_weapon_feel(main)
	await _check_settings(main)
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
	# 3일 밤 보스전에서 튕긴 원인: 사라진 부하가 목록에 남은 채 다시 소환하면 오류로 멈췄다
	for minion: Enemy in boss._minions:
		minion.take_damage(999999.0)
	await _frames(2)
	enemy_count = enemies.get_child_count()
	for pattern: Dictionary in patterns:
		if pattern["type"] == "summon":
			boss._start_pattern(pattern)
	await _frames(2)
	_check(enemies.get_child_count() > enemy_count and boss._minions.all(is_instance_valid), "부하가 죽은 뒤에도 다시 부하를 부름")
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
	await get_tree().create_timer(SoundDB.BOSS_MUSIC_FADE_SECONDS + 0.1).timeout
	_check(not main.boss_music._player.playing, "승리 화면 일시정지 뒤에도 보스 음악 페이드 종료")
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
	_check(menu_buttons == ["싱글플레이", "멀티플레이", "설정"] and not title._single_popup.visible and not title._multi_popup.visible,
		"시작 화면에는 싱글플레이·멀티플레이 버튼과 설정 버튼만 보임 %s" % [menu_buttons])
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
	_check(panel._selected_id == "fortify" and panel._learn_button.disabled and progression.ranks.is_empty(), "잠긴 노드 선택은 상세만 열고 포인트를 쓰지 않음")
	panel._tree.buttons["sword_mastery"].pressed.emit()
	_check(panel._learn_button.disabled and panel._tree.buttons["sword_mastery"].state == PassiveNode.State.LOCKED, "포인트 부족은 배울 수 없는 상태로 표시")
	progression.add_xp(200)
	var before := progression.points
	var cost := progression.next_cost("sword_mastery")
	panel._learn_button.pressed.emit()
	_check(progression.rank("sword_mastery") == 1 and progression.points == before - cost and panel._tree.buttons["sword_sweep"].state == PassiveNode.State.AVAILABLE and panel._tree.buttons["sword_mastery"].learn_pulse > 0.0, "배우기 버튼은 학습 명령을 호출하고 다음 노드를 열음")
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


func _check_map_bag_art(main: Main) -> void:
	var map_view := main.hud._minimap
	var bounds := map_view._map_rect()
	_check(map_view.mini and bounds.size.x == bounds.size.y and bounds.position.x > 0.0 and bounds.end.y < map_view.size.y,
		"미니맵은 프레임 안의 정사각형 영역에 지도를 그려 지도 좌표 비율 유지")
	_check(main.hud._bag_gauge.get_global_rect().end.x < map_view.get_global_rect().position.x,
		"가방 적재량은 미니맵 왼쪽에 겹치지 않게 배치")
	var bag := Inventory.new()
	var gauge := Hud.BagGauge.new()
	gauge.setup(bag)
	main.hud.add_child(gauge)
	_check(gauge.used == 0 and gauge.ratio == 0.0, "빈 재료 가방은 0칸·0% 표시")
	bag.add({"wood": 1, "stone": 1})
	gauge._refresh()
	_check(gauge.used == 2 and is_equal_approx(gauge.ratio, 2.0 / bag.capacity()), "적재율은 재료 개수가 아니라 실제 사용 칸 기준")
	bag.add({"wood": Balance.STACK_SIZE * bag.capacity()})
	gauge._refresh()
	_check(gauge.used == gauge.capacity and gauge.ratio == 1.0 and gauge.tooltip_text.contains("0칸 남음"), "가득 찬 가방은 용량·잔여 칸을 정확하게 표시")
	bag.clear()
	bag.bonus_slots = 4
	gauge._refresh()
	_check(gauge.capacity == Balance.INVENTORY_SLOTS + 4 and gauge.used == 0, "입고·사망으로 비운 재료와 큰 가방의 추가 용량을 즉시 반영")
	gauge.queue_free()
	var drawer_was_open := main.hud._resource_toggle.button_pressed
	main.hud._bag_gauge.activated.emit()
	_check(main.hud._resource_drawer.visible != drawer_was_open, "가방을 누르면 기존 가방·창고 재료 목록 열림")
	main.hud._resource_toggle.button_pressed = drawer_was_open
	await _frames(1)


func _check_cursor_lifecycle() -> void:
	var window := get_window()
	var mouse_connections := window.mouse_entered.get_connections().size()
	var focus_connections := window.focus_entered.get_connections().size()
	var owner := Node.new()
	add_child(owner)
	CursorArt.attach(owner, true)
	_check(window.mouse_entered.get_connections().size() == mouse_connections + 1
		and window.focus_entered.get_connections().size() == focus_connections + 1, "커서 소유 씬이 창 진입·포커스 복귀 갱신을 등록")
	window.mouse_entered.emit()
	window.focus_entered.emit()
	owner.queue_free()
	await _frames(2)
	_check(window.mouse_entered.get_connections().size() == mouse_connections
		and window.focus_entered.get_connections().size() == focus_connections, "씬 종료 시 커서 갱신 연결도 해제돼 다음 화면을 덮어쓰지 않음")
	window.mouse_entered.emit()
	CursorArt.clear()


func _check_building_lighting(main: Main) -> void:
	var tower := Building.new().setup("arrow_tower", Vector2i.ZERO)
	tower.position = main.player.position + Vector2(2000, 0)
	main.add_child(tower)
	tower.set_physics_process(false)
	var tower_light := tower.get_children().filter(func(node: Node) -> bool: return node is PointLight2D)[0] as PointLight2D
	var core_light := main.kingdom.core.get_children().filter(func(node: Node) -> bool: return node is PointLight2D)[0] as PointLight2D
	var player_light := main.player.get_children().filter(func(node: Node) -> bool: return node is PointLight2D)[0] as PointLight2D
	var clock := main.day_night
	var phase := clock.phase
	var time := clock.time
	clock.phase = DayNight.Phase.NIGHT
	clock.time = 0.0
	clock._process(0.0)
	_check(tower_light.energy < player_light.energy and core_light.energy < player_light.energy
		and is_equal_approx(player_light.energy, DayNight.LIGHT_ENERGY), "밤에는 건물·성 조명만 약하게 하고 플레이어 조명 유지")
	var night_energy := tower_light.energy
	clock.phase = DayNight.Phase.DAY
	clock.time = Balance.DAY_LENGTH - Balance.DUSK_LENGTH * 0.5
	clock._process(0.0)
	_check(is_equal_approx(tower_light.energy, night_energy * 0.5), "광원별 밝기 배율은 황혼 보간 중에도 유지")
	clock.time = Balance.DAY_LENGTH * 0.5
	clock._process(0.0)
	_check(tower_light.energy == 0.0 and core_light.energy == 0.0, "낮에는 건물·성 조명이 모두 꺼짐")
	clock.phase = phase
	clock.time = time
	clock._process(0.0)
	tower.queue_free()
	await _frames(1)
