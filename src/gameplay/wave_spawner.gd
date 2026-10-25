class_name WaveSpawner
extends Node
## 밤 침공 웨이브와 낮에 돌아다니는 적을 만든다. 규모는 Balance에서 조정.
## 적 구성·등장 위치는 결과에 영향을 주므로 호스트의 rng(Main.rng)로 굴린다. 참가자 쪽에서는 꺼져 있다 (D-017).
## 보스 밤마다 EnemyDB.boss_for(day)의 다른 보스가 나오고, 보스는 아침이 와도 사라지지 않는다 (D-021).

const BOSS_SPAWN_TIME := 8.0
const SPAWN_ATTEMPTS := 40
const WANDERER_KINGDOM_GAP := 17.0  # 낮 몬스터는 핵에서 이 칸 수 밖에서만 나온다

var _world: World
var _kingdom: Kingdom
var _player: Player
var _enemy_parent: Node2D
var _rng: RandomNumberGenerator
var _queue: Array[Dictionary] = []  # {"type", "at", "hp_scale", "damage_scale"}
var _day := 1
var _is_night := false
var _night_time := 0.0
var _wander_timer := 0.0


func setup(world: World, kingdom: Kingdom, player: Player, enemy_parent: Node2D, rng: RandomNumberGenerator) -> void:
	_world = world
	_kingdom = kingdom
	_player = player
	_enemy_parent = enemy_parent
	_rng = rng
	Events.night_started.connect(_on_night_started)
	Events.day_started.connect(_on_day_started)


func _physics_process(delta: float) -> void:
	if _is_night:
		_night_time += delta
		while not _queue.is_empty() and _queue[0]["at"] <= _night_time:
			var entry: Dictionary = _queue.pop_front()
			var at: Variant = _find_spawn(_kingdom.core.global_position, Balance.WAVE_SPAWN_RING, false)
			if at != null:
				_spawn(entry["type"], at, true, entry["hp_scale"], entry["damage_scale"])
	else:
		_wander_timer -= delta
		if _wander_timer <= 0.0:
			_wander_timer = Balance.WANDERER_SPAWN_INTERVAL
			_spawn_wanderer()


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
	_is_night = false
	_queue.clear()
	var burned := 0
	for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.is_invader and not enemy.is_boss():
			enemy.burn_away()
			burned += 1
	var text := "%d일차 아침" % day
	if burned > 0:
		text += " · 남은 적 %d마리가 햇빛에 사라졌습니다" % burned
	Events.message.emit(text)


func _spawn_wanderer() -> void:
	var wanderers := get_tree().get_nodes_in_group("enemies").filter(func(e: Enemy) -> bool: return not e.is_invader)
	if wanderers.size() >= Balance.WANDERER_MAX:
		return
	# 멀티플레이에서는 아무 플레이어 주변에나 나온다 (호스트 화면에 있는 RemotePlayer 포함, D-017)
	var players := get_tree().get_nodes_in_group("player")
	var around: Node2D = players[_rng.randi_range(0, players.size() - 1)]
	var at: Variant = _find_spawn(around.global_position, Balance.WANDERER_SPAWN_RING, true)
	if at != null:
		_spawn(EnemyDB.wanderer_for(_world.data.get_terrain(_world.cell_at(at))), at, false,
			Balance.wanderer_hp_scale(_day), Balance.wanderer_damage_scale(_day))


func _spawn(type_id: String, at: Vector2, invader: bool, hp_scale: float, damage_scale := 1.0) -> void:
	var enemy := Enemy.new().setup(type_id, invader, hp_scale, damage_scale)
	enemy.minion_hp_scale = Balance.wave_hp_scale(_day)
	enemy.minion_damage_scale = Balance.wave_damage_scale(_day)
	enemy.position = at
	_enemy_parent.add_child(enemy)
	if enemy.is_boss():
		Events.world_sound_requested.emit("boss_spawn", Vector2.INF)


## ring = 칸 단위 최소/최대 거리. 찾지 못하면 null
func _find_spawn(center: Vector2, ring: Vector2, avoid_kingdom: bool) -> Variant:
	for attempt in SPAWN_ATTEMPTS:
		var offset := Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(ring.x, ring.y) * Balance.TILE
		var cell := _world.cell_at(center + offset)
		if not _world.data.is_walkable(cell) or _kingdom.is_occupied(cell):
			continue
		if avoid_kingdom and Vector2(cell - _kingdom.core_cell()).length() < WANDERER_KINGDOM_GAP:
			continue
		return _world.cell_center(cell)
	return null
