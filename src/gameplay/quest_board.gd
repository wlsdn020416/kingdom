class_name QuestBoard
extends Node
## 낮 의뢰 (D-037). 아침마다 QuestDB.PER_DAY개가 무작위 바이옴에 나타나고, 해가 지면 끝내지 못한 의뢰는 실패한다.
## 굴림·판정·보상은 호스트만 한다(Main.rng). 참가자는 QuestSync로 받은 목록을 apply_remote()로 그대로 보여준다.
## quests의 각 항목은 직렬화할 수 있는 값만 담는다: {"id", "kind", "terrain", "at", "title", "goal", "state", "progress", "total", "xp", "reward"}

signal changed

const FOLLOW_INTERVAL := 1.0  # 움직이는 의뢰 대상(정예·도망자)의 지도 위치를 갱신하는 간격
const FOLLOW_MIN_MOVE := 2.0 * Balance.TILE  # 이보다 적게 움직였으면 다시 알리지 않는다

var quests: Array[Dictionary] = []
var _world: World
var _spawner: WaveSpawner
var _map_state: MapState
var _rng: RandomNumberGenerator
var _reward_everyone: Callable
var _grow: Callable
var _host := true
var _targets := {}  # 의뢰 id -> Enemy (호스트만)
var _vein_cells := {}  # 의뢰 id -> Array[Vector2i] (호스트만)
var _next_id := 1
var _rolled := false
var _follow := 0.0


## reward_everyone(xp, 재료, 위치): 모두에게 보상. grow(목록): 광맥 오브젝트를 놓고 참가자에게도 알린다
func setup(world: World, spawner: WaveSpawner, map_state: MapState, rng: RandomNumberGenerator,
		reward_everyone: Callable, grow: Callable, is_host: bool) -> void:
	_world = world
	_spawner = spawner
	_map_state = map_state
	_rng = rng
	_reward_everyone = reward_everyone
	_grow = grow
	_host = is_host
	if _host:
		Events.day_started.connect(roll)
		Events.night_started.connect(_on_night_started)
		Events.enemy_killed.connect(_on_enemy_killed)
		_world.object_changed.connect(_on_object_changed)


func active() -> Array[Dictionary]:
	return quests.filter(func(quest: Dictionary) -> bool: return quest["state"] == "active")


func _physics_process(delta: float) -> void:
	if not _host:
		return
	if not _rolled:
		# 첫날 아침에는 아침 신호가 없으므로 게임이 시작되면 한 번 굴린다
		roll(1)
	_follow -= delta
	if _follow > 0.0:
		return
	_follow = FOLLOW_INTERVAL
	var moved := false
	for quest in active():
		var target := _target(quest["id"])
		if target != null and target.global_position.distance_to(quest["at"]) > FOLLOW_MIN_MOVE:
			quest["at"] = target.global_position
			moved = true
	if moved:
		_publish()


## 그날의 의뢰를 새로 굴린다 (호스트). 지난 의뢰는 지운다
func roll(day: int) -> void:
	_rolled = true
	quests.clear()
	_targets.clear()
	_vein_cells.clear()
	var kinds: Array = QuestDB.KINDS.keys()
	for i in range(kinds.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var swap: Variant = kinds[i]
		kinds[i] = kinds[j]
		kinds[j] = swap
	var terrains := _spawner.resident_terrains().filter(func(terrain: int) -> bool: return QuestDB.tier_of(terrain) <= QuestDB.max_tier(day))
	if terrains.is_empty():
		return
	for i in QuestDB.PER_DAY:
		_start(kinds[i % kinds.size()], terrains[_rng.randi_range(0, terrains.size() - 1)])
	if not quests.is_empty():
		Events.message.emit("오늘의 의뢰 %d개가 나타났습니다 · 해가 지기 전에 끝내세요 (지도에 표시)" % quests.size())
	_publish()


func _start(kind: String, terrain: int) -> void:
	var cell := _spawner.random_cell(terrain, QuestDB.MIN_DISTANCE * Balance.TILE)
	if cell == World.NO_CELL:
		return
	var at := _world.cell_center(cell)
	var info: Dictionary = QuestDB.KINDS[kind]
	var quest := {"id": _next_id, "kind": kind, "terrain": terrain, "at": at, "title": QuestDB.title(kind, terrain),
		"goal": QuestDB.goal(kind, terrain), "state": "active", "progress": 0, "total": 1,
		"xp": QuestDB.xp(kind, terrain), "reward": QuestDB.reward(kind, terrain)}
	match kind:
		"elite":
			var elite := _spawner.spawn_quest_monster(EnemyDB.wanderer_for(terrain), at, info["hp_scale"], info["damage_scale"])
			elite.elite = true
			_targets[_next_id] = elite
		"runner":
			var runner := _spawner.spawn_quest_monster(info["monster"], at, info["hp_scale"], 1.0)
			runner.flees = true
			runner.speed_scale = info["speed_scale"]
			_targets[_next_id] = runner
		"vein":
			var cells := _vein_spot(cell, info["count"][QuestDB.tier_of(terrain)], info["radius"])
			if cells.is_empty():
				return
			var grown := []
			for vein_cell in cells:
				grown.append([vein_cell, QuestDB.VEIN_OBJECTS[terrain]])
			_grow.call(grown)
			_vein_cells[_next_id] = cells
			quest["total"] = cells.size()
	quests.append(quest)
	_next_id += 1


## 광맥 자리: center에서 가까운 순으로 radius칸 안의 빈칸을 count개까지
func _vein_spot(center: Vector2i, count: int, radius: int) -> Array[Vector2i]:
	var options: Array[Vector2i] = []
	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			var cell := center + Vector2i(x, y)
			if Vector2(x, y).length() <= radius and _world.data.is_walkable(cell) and _world.data.get_terrain(cell) != WorldData.Terrain.SAND:
				options.append(cell)
	options.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return Vector2(a - center).length() < Vector2(b - center).length())
	return options.slice(0, count)


## 의뢰 대상 몬스터. 이미 사라졌으면 null (해제된 객체를 타입 있는 변수에 넣지 않게 먼저 확인한다)
func _target(quest_id: int) -> Enemy:
	var target: Variant = _targets.get(quest_id)
	return target if target != null and is_instance_valid(target) and not (target as Enemy).is_queued_for_deletion() else null


func _on_enemy_killed(enemy: Node) -> void:
	for quest in active():
		if _targets.get(quest["id"]) == enemy:
			_complete(quest)


func _on_object_changed(cell: Vector2i, hp: float) -> void:
	if hp > 0.0:
		return
	for quest in active():
		var cells: Array = _vein_cells.get(quest["id"], [])
		if not cells.has(cell):
			continue
		quest["progress"] = cells.filter(func(vein: Vector2i) -> bool: return _world.data.get_object(vein) == WorldData.Obj.NONE).size()
		if quest["progress"] >= quest["total"]:
			_complete(quest)
		else:
			_publish()


func _complete(quest: Dictionary) -> void:
	quest["state"] = "done"
	quest["progress"] = quest["total"]
	_targets.erase(quest["id"])
	_reward_everyone.call(quest["xp"], quest["reward"], quest["at"])
	Events.message.emit("의뢰 완료: %s! 모두 보상을 받았습니다 (%s)" % [quest["title"], Balance.format_gain(quest["reward"])])
	Events.ui_sound_requested.emit("level_up")
	_publish()


## 해가 지면 끝내지 못한 의뢰는 실패하고 정예·도망자는 사라진다. 광맥은 그대로 남아 평범한 자원이 된다
func _on_night_started(_day: int) -> void:
	var failed := 0
	for quest in active():
		quest["state"] = "failed"
		failed += 1
		var target := _target(quest["id"])
		if target != null:
			target.queue_free()
	_targets.clear()
	if failed > 0:
		Events.message.emit("해가 져서 끝내지 못한 의뢰 %d개가 사라졌습니다" % failed)
		_publish()


## 참가자: 호스트의 목록을 그대로 따르고, 바뀐 상태를 알림으로 보여준다
func apply_remote(list: Array) -> void:
	var before := {}
	for quest in quests:
		before[quest["id"]] = quest["state"]
	var fresh := 0
	quests.clear()
	for entry: Dictionary in list:
		quests.append(entry)
		var was: String = before.get(entry["id"], "")
		if was == "" and entry["state"] == "active":
			fresh += 1
		elif was == "active" and entry["state"] == "done":
			Events.message.emit("의뢰 완료: %s! 모두 보상을 받았습니다" % entry["title"])
	if fresh > 0:
		Events.message.emit("오늘의 의뢰 %d개가 나타났습니다 · 해가 지기 전에 끝내세요 (지도에 표시)" % fresh)
	_publish()


func _publish() -> void:
	var markers: Array[Vector2] = []
	for quest in active():
		markers.append(quest["at"])
	_map_state.quest_markers = markers
	changed.emit()
