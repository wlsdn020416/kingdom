class_name MapView
extends Control
## MapState를 그리는 지도. 미니맵, 전체 지도(M), 전략회의 지도에서 같이 쓴다.

signal cell_clicked(cell: Vector2i)

const BACKGROUND := Color("080a09")
const ART := preload("res://assets/ui/minimap_ui.png")
const FRAME := Rect2(0, 0, 96, 112)
const MARKER_SIZE := 16
const MAP_INSET := Vector2(8, 20)
const MAP_SIDE := 80.0

var map: MapState
var clickable := false
var mini := false


func setup(state: MapState, is_clickable := false) -> MapView:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	theme = MenuArt.theme()
	map = state
	clickable = is_clickable
	mouse_filter = Control.MOUSE_FILTER_STOP if clickable else Control.MOUSE_FILTER_IGNORE
	return self


func _process(_delta: float) -> void:
	if map != null and is_visible_in_tree():
		map.flush()
		queue_redraw()


func _draw() -> void:
	if mini:
		draw_texture_rect_region(ART, Rect2(Vector2.ZERO, size), FRAME)
		draw_string(get_theme_default_font(), Vector2(56, 27), "탐험 지도", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MenuArt.GOLD)
		draw_string(get_theme_default_font(), Vector2(45, size.y - 12), "M  전체 지도", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MenuArt.MUTED)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	if map == null:
		return
	var area := _map_rect()
	draw_texture_rect(map.texture, area, false)
	var core_at := _to_map(map.kingdom.core.global_position, area)
	_draw_marker(0, core_at, 14.0)
	for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.is_invader:
			_draw_marker(2, _to_map(enemy.global_position, area), 9.0)
	# 순간이동 탑(D-022)은 지도 한 칸이 작아도 찾을 수 있게 표시한다
	for building: Building in map.kingdom.buildings.values():
		if building.info.get("teleport", false):
			var at := _to_map(building.global_position, area)
			_draw_marker(3, at, 12.0)
	for cell in map.pings:
		_draw_marker(4, _to_map(map.world.cell_center(cell), area), 14.0)
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		_draw_marker(1, _to_map(player.global_position, area), 12.0)


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
	if mini:
		var scale := size / FRAME.size
		return Rect2(MAP_INSET * scale, Vector2.ONE * MAP_SIDE * scale)
	var side := minf(size.x, size.y)
	return Rect2((size - Vector2(side, side)) / 2.0, Vector2(side, side))


func _to_map(world_position: Vector2, area: Rect2) -> Vector2:
	return area.position + world_position / map.world_size_pixels() * area.size


func _draw_marker(index: int, at: Vector2, width: float) -> void:
	var bounds := Rect2(at - Vector2.ONE * width * 0.5, Vector2.ONE * width)
	draw_texture_rect_region(ART, bounds, Rect2(96 + index * MARKER_SIZE, 72, MARKER_SIZE, MARKER_SIZE))
