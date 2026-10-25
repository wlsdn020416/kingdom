extends Node2D
## 전략회의에서 찍은 핑을 월드에도 깃발로 보여준다.

var map_state: MapState
var _world: World


func setup(state: MapState, world: World) -> void:
	map_state = state
	_world = world


func _process(_delta: float) -> void:
	if map_state != null and not map_state.pings.is_empty():
		queue_redraw()


func _draw() -> void:
	if map_state == null:
		return
	var bob := sin(Time.get_ticks_msec() / 200.0) * 4.0
	for cell in map_state.pings:
		var base := _world.cell_center(cell)
		draw_rect(Rect2(base + Vector2(-2, -40 + bob), Vector2(4, 30)), Palette.PING)
		draw_rect(Rect2(base + Vector2(-6, -46 + bob), Vector2(12, 8)), Palette.PING)
