class_name BuildPreview
extends Control
## 격자·접지 칸 위에 실제 건물의 원본과 장치 애니메이션을 보여준다.

const GRID := 16
var type_id := "wood_wall"
var tier := 0
var _time := 0.0


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("10202c"))
	for x in range(0, int(size.x), GRID):
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.3, 0.5, 0.6, 0.1))
	for y in range(0, int(size.y), GRID):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.3, 0.5, 0.6, 0.1))
	var origin := Vector2(size.x / 2.0, size.y - 24)
	draw_rect(Rect2(origin - Vector2(16, 16), Vector2(32, 32)), Color("49616b"), false, 1.0)
	draw_set_transform(origin)
	Building.draw_art(self, Vector2.ZERO, type_id, tier, Color.WHITE, int(_time / Building.ART_FRAME_SECONDS))
	draw_set_transform(Vector2.ZERO)
