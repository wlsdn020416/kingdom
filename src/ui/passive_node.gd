class_name PassiveNode
extends Button
## 패시브 노드 한 개의 아이콘·학습 단계·상태를 그린다. 잠긴 노드도 설명을 선택할 수 있다.

const ICONS := preload("res://assets/ui/passive_icons.png")
const FRAMES := preload("res://assets/ui/passive_nodes.png")
enum State { LOCKED, AVAILABLE, LEARNED, SELECTED, COMPLETE }

var passive_id := ""
var state := State.LOCKED
var rank_text := "0/1"
var selected := false
var learn_pulse := 0.0


func setup(id: String) -> void:
	passive_id = id
	custom_minimum_size = Vector2.ONE * PassiveArtDB.NODE_SIZE
	size = custom_minimum_size
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for type in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(type, StyleBoxEmpty.new())
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func _draw() -> void:
	var index := State.SELECTED if selected or is_hovered() or has_focus() else state
	draw_texture_rect_region(FRAMES, Rect2(Vector2.ZERO, size), Rect2(Vector2(index * PassiveArtDB.NODE_SIZE, 0), size))
	var tint := Color(0.4, 0.46, 0.5) if state == State.LOCKED else Color.WHITE
	draw_texture_rect_region(ICONS, Rect2(12, 8, 32, 32), PassiveArtDB.icon_region(passive_id), tint)
	draw_rect(Rect2(12, 41, 32, 13), Color("101b26"))
	var color := MenuArt.GOLD if state in [State.LEARNED, State.COMPLETE] else MenuArt.MUTED
	draw_string(get_theme_default_font(), Vector2(12, 51), rank_text, HORIZONTAL_ALIGNMENT_CENTER, 32, 10, color)
	if learn_pulse > 0.0:
		var progress := 1.0 - learn_pulse / float(PassiveEffectDB.EFFECTS["passive_learn"]["duration"])
		draw_texture_rect_region(PassiveEffectDB.TEXTURE, Rect2(-32, -32, 120, 120), PassiveEffectDB.region("passive_learn", progress))


func pulse() -> void:
	learn_pulse = PassiveEffectDB.EFFECTS["passive_learn"]["duration"]
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	learn_pulse = maxf(0.0, learn_pulse - delta)
	set_process(learn_pulse > 0.0)
	queue_redraw()
