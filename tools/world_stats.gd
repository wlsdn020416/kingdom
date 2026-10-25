extends SceneTree
## 시드 몇 개로 월드를 만들어 지형 비율과 왕국에서 걸어갈 수 있는 땅 비율을 출력한다.
## WorldGenerator 상수를 조정할 때 쓴다.
## 실행: godot --headless --path . --script res://tools/world_stats.gd

const SEEDS := ["oak-1234", "ember-5555", "frost-9876", "dune-4242", "moss-1111", "wolf-2024"]


func _initialize() -> void:
	for seed_text in SEEDS:
		var data := WorldGenerator.generate(seed_text)
		var counts := {}
		var land := 0
		for i in data.terrain.size():
			counts[data.terrain[i]] = counts.get(data.terrain[i], 0) + 1
			if data.terrain[i] != WorldData.Terrain.WATER:
				land += 1
		var parts := PackedStringArray()
		for terrain in WorldData.Terrain.values():
			parts.append("%s %d%%" % [WorldData.TERRAIN_NAMES[terrain], roundi(100.0 * counts.get(terrain, 0) / data.terrain.size())])
		var reachable := _reachable_land(data)
		print("%-12s %s | 왕국에서 갈 수 있는 땅 %d%%" % [seed_text, " ".join(parts), roundi(100.0 * reachable / land)])
	quit()


## 물만 막힌다고 보고(나무·바위는 부술 수 있으니) 왕국에서 닿는 땅 칸 수
func _reachable_land(data: WorldData) -> int:
	var seen := PackedByteArray()
	seen.resize(data.terrain.size())
	var queue: Array[Vector2i] = [data.core_cell]
	seen[data.index(data.core_cell)] = 1
	var count := 0
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		count += 1
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + step
			if data.in_bounds(next) and seen[data.index(next)] == 0 and data.get_terrain(next) != WorldData.Terrain.WATER:
				seen[data.index(next)] = 1
				queue.append(next)
	return count
