class_name BuildCard
extends Button
## 건설 도감의 한 카드. 잠긴 건물도 선택해 외형·해금 조건을 볼 수 있다.

const CARD_SIZE := Vector2(254, 146)
var type_id := ""
var selected := false
var status := ""
var locked := false
var affordable := false
var health := 0


func setup(id: String) -> void:
	type_id = id
	icon = Building.icon_texture(id)
	custom_minimum_size = CARD_SIZE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_color_override("icon_" + state + "_color", Color.TRANSPARENT)
	add_theme_stylebox_override("normal", MenuArt.panel(10))
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func _draw() -> void:
	if selected or is_hovered() or has_focus():
		draw_rect(Rect2(3, 3, size.x - 6, size.y - 6), MenuArt.GOLD if selected else Color("819eae"), false, 1.0)
	var art := icon as AtlasTexture
	var fit := minf(78.0 / art.region.size.x, 72.0 / art.region.size.y)
	var dimensions := art.region.size * fit
	var tint := Color(0.58, 0.65, 0.7) if locked else Color.WHITE
	draw_texture_rect_region(art.atlas, Rect2(Vector2(size.x / 2.0, 45) - dimensions / 2.0, dimensions), art.region, tint)
	var font := get_theme_default_font()
	draw_string(font, Vector2(8, 101), BuildingDB.TYPES[type_id]["name"], HORIZONTAL_ALIGNMENT_CENTER, size.x - 16, 17, MenuArt.TEXT if not locked else MenuArt.MUTED)
	var tier: int = BuildingDB.TYPES[type_id]["tier"]
	draw_string(font, Vector2(8, 119), "방어 %d단계  ·  체력 %d" % [tier, health], HORIZONTAL_ALIGNMENT_CENTER, size.x - 16, 11, MenuArt.MUTED)
	var color := MenuArt.MUTED if locked else MenuArt.GOLD if affordable else Color("d9937d")
	draw_string(font, Vector2(8, 137), status, HORIZONTAL_ALIGNMENT_CENTER, size.x - 16, 11, color)
