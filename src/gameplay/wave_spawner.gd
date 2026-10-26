class_name WaveSpawner
extends Node
## 밤 침공 웨이브와 바이옴 서식 몬스터를 만든다. 규모는 Balance에서 조정.
## 서식 몬스터(D-035)는 바이옴 넓이에 비례한 수가 월드에 늘 살고, 게임 시작과 매일 아침 모자란 만큼 채운다.
## 적 구성·등장 위치는 결과에 영향을 주므로 호스트의 rng(Main.rng)로 굴린다. 참가자 쪽에서는 꺼져 있다 (D-017).
## 보스 밤마다 EnemyDB.boss_for(day)의 다른 보스가 나오고, 보스는 아침이 와도 사라지지 않는다 (D-021).
## 낮의 배회 적은 왕국 영토를 피한다(Enemy.avoids_kingdom, D-026). 밤이 되면 풀리고 아침에 다시 걸린다.

const BOSS_SPAWN_TIME := 8.0
const SPAWN_ATTEMPTS := 40
const WANDERER_KINGDOM_GAP := 4.0  # 서식 몬스터는 영토 경계에서 이 칸 수 밖에서만 산다

var _world: World
var _kingdom: Kingdom
var _player: Player
var _enemy_parent: Node2D
var _rng: RandomNumberGenerator
var _queue: Array[Dictionary] = []  # {"type", "at", "hp_scale", "damage_scale"}
var _day := 1
var _is_night := false
var _night_time := 0.0
var _resident_targets := {}  # 지형 -> 그 바이옴의 서식 몬스터 수
var _terrain_cells := {}  # 지형 -> 그 지형 칸 목록 (서식 몬스터를 놓을 자리를 고른다)
var _populated := false


func setup(world: World, kingdom: Kingdom, player: Player, enemy_parent: Node2D, rng: RandomNumberGenerator) -> void:
	_world = world
	_kingdom = kingdom
	_player = player
	_enemy_parent = enemy_parent
	_rng = rng
	Events.night_started.connect(_on_night_started)
	Events.day_started.connect(_on_day_started)
	_plan_residents()


## 바이옴(지형)마다 칸을 모으고 서식 수를 정한다. 초원은 왕국 영토 근처를 빼고 센다
func _plan_residents() -> void:
	var data := _world.data
	for y in data.size.y:
		for x in data.size.x:
			var cell := Vector2i(x, y)
			var terrain := data.get_terrain(cell)
			if not EnemyDB.RESIDENT_TERRAINS.has(terrain) or _near_kingdom(cell):
				continue
			if not _terrain_cells.has(terrain):
				_terrain_cells[terrain] = []
			_terrain_cells[terrain].append(cell)
	for terrain: int in _terrain_cells:
		var count: int = _terrain_cells[terrain].size() / Balance.RESIDENT_CELLS_PER_MONSTER
		_resident_targets[terrain] = mini(Balance.RESIDENT_MAX_PER_BIOME, maxi(1, count))


func resident_targets() -> Dictionary:
	return _resident_targets


## 바이옴마다 살아 있는 서식 몬스터 수
func resident_counts() -> Dictionary:
	var counts := {}
	for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.home_terrain >= 0 and not enemy.is_queued_for_deletion():
			counts[enemy.home_terrain] = counts.get(enemy.home_terrain, 0) + 1
	return counts


## 모자란 만큼 그 바이옴의 빈칸(플레이어와 떨어진 곳)에 채운다. 채운 수를 돌려준다
func refill_residents() -> int:
	var counts := resident_counts()
	var spawned := 0
	for terrain: int in _resident_targets:
		var cells: Array = _terrain_cells[terrain]
		for i in _resident_targets[terrain] - counts.get(terrain, 0):
			for attempt in SPAWN_ATTEMPTS:
				var cell: Vector2i = cells[_rng.randi_range(0, cells.size() - 1)]
				var at := _world.cell_center(cell)
				# 영토가 넓어졌으면 그 안의 초원 칸은 건너뛴다
				if _world.data.is_walkable(cell) and not _kingdom.is_occupied(cell) and not _near_kingdom(cell) and not _near_player(at):
					_spawn_resident(terrain, at)
					spawned += 1
					break
	return spawned


func _spawn_resident(terrain: int, at: Vector2) -> void:
	var enemy := Enemy.new().setup(EnemyDB.wanderer_for(terrain), false, Balance.wanderer_hp_scale(_day), Balance.wanderer_damage_scale(_day))
	enemy.home = at
	enemy.home_terrain = terrain
	enemy.avoids_kingdom = not _is_night
	enemy.position = at
	_enemy_parent.add_child(enemy)


func _near_kingdom(cell: Vector2i) -> bool:
	return Vector2(cell - _kingdom.core_cell()).length() < _kingdom.territory_radius() + WANDERER_KINGDOM_GAP


func _near_player(at: Vector2) -> bool:
	for someone: Node2D in get_tree().get_nodes_in_group("player"):
		if someone.global_position.distance_to(at) < Balance.RESIDENT_PLAYER_GAP:
			return true
	return false


func _physics_process(delta: float) -> void:
	if _is_night:
		_night_time += delta
		while not _queue.is_empty() and _queue[0]["at"] <= _night_time:
			var entry: Dictionary = _queue.pop_front()
			var ring := Vector2.ONE * _kingdom.territory_radius() + Balance.WAVE_SPAWN_BEYOND_TERRITORY
			var at: Variant = _find_spawn(_kingdom.core.global_position, ring)
			if at != null:
				_spawn(entry["type"], at, true, entry["hp_scale"], entry["damage_scale"])
	elif not _populated:
		# 참가자 쪽 생성기는 꺼져 있어서 여기 오지 않는다. 호스트·혼자 플레이에서 첫 낮에 한 번 채운다
		_populated = true
		refill_residents()


func invader_count() -> int:
	var count := 0
	for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.is_invader:
			count += 1
	return count


func _on_night_started(day: int) -> void:
	_day = day
	_is_night = true
	_night_time = 0.0
	_queue.clear()
	_set_wanderers_avoid_kingdom(false)
	var size := Balance.wave_size(day)
	for i in size:
		_queue.append({"type": EnemyDB.pick_invader(day, _rng), "at": _rng.randf() * Balance.WAVE_SPAWN_WINDOW,
			"hp_scale": Balance.wave_hp_scale(day), "damage_scale": Balance.wave_damage_scale(day)})
	if Balance.is_boss_night(day):
		var boss_id := EnemyDB.boss_for(day)
		var players := get_tree().get_nodes_in_group("player").size()
		_queue.append({"type": boss_id, "at": BOSS_SPAWN_TIME, "hp_scale": Balance.boss_hp_scale(players), "damage_scale": 1.0})
		var boss_name: String = EnemyDB.TYPES[boss_id]["name"]
		if EnemyDB.TYPES[boss_id].get("final", false):
			Events.message.emit("%d일차 밤 · 최종 보스 %s이(가) 왕국을 노립니다! 쓰러뜨리면 승리합니다" % [day, boss_name])
		else:
			Events.message.emit("%d일차 밤 · 보스 %s이(가) 접근합니다! (침공 %d마리)" % [day, boss_name, size])
	else:
		Events.message.emit("%d일차 밤 · 침공이 시작됩니다 (%d마리)" % [day, size])
	_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["at"] < b["at"])


func _on_day_started(day: int) -> void:
	_day = day
	# 참가자 쪽 생성기는 꺼져 있다(D-017). 신호는 그래도 오므로 몬스터는 호스트에서만 채운다
	if can_process():
		var refilled := refill_residents()
		if refilled > 0:
			Events.message.emit("바이옴의 몬스터 %d마리가 다시 나타났습니다" % refilled)
	_is_night = false
	_queue.clear()
	_set_wanderers_avoid_kingdom(true)
	var burned := 0
	for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.is_invader and not enemy.is_boss():
			enemy.burn_away()
			burned += 1
	var text := "%d일차 아침" % day
	if burned > 0:
		text += " · 남은 적 %d마리가 햇빛에 사라졌습니다" % burned
	Events.message.emit(text)


func _set_wanderers_avoid_kingdom(avoid: bool) -> void:
	for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy.is_invader:
			enemy.avoids_kingdom = avoid


func _spawn(type_id: String, at: Vector2, invader: bool, hp_scale: float, damage_scale := 1.0) -> void:
	var enemy := Enemy.new().setup(type_id, invader, hp_scale, damage_scale)
	enemy.avoids_kingdom = not invader and not _is_night
	enemy.minion_hp_scale = Balance.wave_hp_scale(_day)
	enemy.minion_damage_scale = Balance.wave_damage_scale(_day)
	enemy.position = at
	_enemy_parent.add_child(enemy)
	if enemy.is_boss():
		Events.world_sound_requested.emit("boss_spawn", Vector2.INF)


## ring = 칸 단위 최소/최대 거리. 찾지 못하면 null
func _find_spawn(center: Vector2, ring: Vector2) -> Variant:
	for attempt in SPAWN_ATTEMPTS:
		var offset := Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(ring.x, ring.y) * Balance.TILE
		var cell := _world.cell_at(center + offset)
		if not _world.data.is_walkable(cell) or _kingdom.is_occupied(cell):
			continue
		return _world.cell_center(cell)
	return null
