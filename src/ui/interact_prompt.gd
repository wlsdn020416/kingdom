class_name InteractPrompt
extends Node2D
## E 상호작용 안내 (D-031). 지금 E를 누르면 열릴 대상 위에 "E 이름" 표와 금색 모서리 테두리를 그린다.
## 대상은 Main.interact_target()이 고르고, 이 노드는 그리기만 한다. 각자 화면에만 있다.

const LIFT := 54.0  # 대상 칸 위로 표를 띄우는 높이 (건물 그림이 칸보다 위로 솟아 있다)
const BRACKET := 6.0  # 모서리 테두리 한 변 길이
const PAD := Vector2(8, 4)
const FONT_SIZE := 12
const PANEL := Color(0.06, 0.09, 0.13, 0.88)

var _target := {}


func _ready() -> void:
	z_index = 100
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## target: Main.interact_target() 결과. 비었으면 숨긴다
func show_target(target: Dictionary) -> void:
	if target == _target:
		return
	_target = target
	visible = not target.is_empty()
	queue_redraw()


func _draw() -> void:
	if _target.is_empty():
		return
	var at: Vector2 = _target["at"]
	var half := Vector2.ONE * float(_target.get("size", Balance.TILE)) / 2.0
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var point := at + half * corner
		draw_line(point, point - Vector2(corner.x * BRACKET, 0), MenuArt.GOLD, 2.0)
		draw_line(point, point - Vector2(0, corner.y * BRACKET), MenuArt.GOLD, 2.0)
	var font := UiKit.GAME_FONT
	var text: String = _target["name"]
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	var key_width := 16.0
	var box_size := Vector2(key_width + 6.0 + text_size.x, text_size.y) + PAD * 2.0
	var box := Rect2(at - Vector2(box_size.x / 2.0, half.y + LIFT - 20.0), box_size)
	draw_rect(box, PANEL)
	draw_rect(box, MenuArt.GOLD, false, 1.0)
	var key := Rect2(box.position + Vector2(PAD.x - 2.0, 3.0), Vector2(key_width, box_size.y - 6.0))
	draw_rect(key, MenuArt.GOLD)
	var baseline := box.position.y + PAD.y + font.get_ascent(FONT_SIZE)
	draw_string(font, Vector2(key.position.x, baseline), "E", HORIZONTAL_ALIGNMENT_CENTER, key_width, FONT_SIZE, PANEL.lightened(0.0))
	draw_string(font, Vector2(key.end.x + 6.0, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, MenuArt.TEXT)
