class_name MapView
extends Control
## MapState를 그리는 지도. 미니맵, 전체 지도(M), 전략회의 지도에서 같이 쓴다.

signal cell_clicked(cell: Vector2i)

const BACKGROUND := Color("080a09")

var map: MapState
var clickable := false


func setup(state: MapState, is_clickable := false) -> MapView:
	map = state
	clickable = is_clickable
	mouse_filter = Control.MOUSE_FILTER_STOP if clickable else Control.MOUSE_FILTER_IGNORE
	return self


func _process(_delta: float) -> void:
	if map != null and is_visible_in_tree():
		map.flush()
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	if map == null:
		return
	var area := _map_rect()
	draw_texture_rect(map.texture, area, false)
	var core_at := _to_map(map.kingdom.core.global_position, area)
	draw_rect(Rect2(core_at - Vector2(3, 3), Vector2(6, 6)), Palette.CORE)
	for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.is_invader:
			draw_rect(Rect2(_to_map(enemy.global_position, area) - Vector2.ONE, Vector2(3, 3)), Palette.ENEMY_MARK)
	for cell in map.pings:
		draw_arc(_to_map(map.world.cell_center(cell), area), 5.0, 0.0, TAU, 16, Palette.PING, 2.0)
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		draw_rect(Rect2(_to_map(player.global_position, area) - Vector2(2, 2), Vector2(4, 4)), Color.WHITE)


func _gui_input(event: InputEvent) -> void:
	if not clickable or map == null:
		return
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var area := _map_rect()
	if area.has_point(click.position):
		var ratio := (click.position - area.position) / area.size
		cell_clicked.emit(Vector2i(ratio * Vector2(map.world.data.size)))
		accept_event()


## 정사각형으로 가운데 맞춤
func _map_rect() -> Rect2:
	var side := minf(size.x, size.y)
	return Rect2((size - Vector2(side, side)) / 2.0, Vector2(side, side))


func _to_map(world_position: Vector2, area: Rect2) -> Vector2:
	return area.position + world_position / map.world_size_pixels() * area.size
