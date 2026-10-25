class_name HealthBarArt
extends RefCounted
## 월드·HUD 체력바의 픽셀아트 그리기. 체력 상태나 표시 시간은 소유하지 않는다.

enum Tone { RED, GOLD, GREEN }

const TEXTURE := preload("res://assets/ui/health_bars.png")
const WIDTH := 32
const HEIGHT := 8
const CAP_WIDTH := 4
const INSET := Vector2(3, 2)
const FILL_SIZE := Vector2(26, 4)


## 살아 있는 대상의 아주 적은 체력도 최소 한 픽셀은 보이게 한다.
static func fill_width(ratio: float, width: int = WIDTH) -> int:
	return ceili(maxi(0, width - int(INSET.x) * 2) * clampf(ratio, 0.0, 1.0))


static func draw_bar(canvas: CanvasItem, at: Vector2, ratio: float, tone: Tone, width: int = WIDTH) -> void:
	width = maxi(width, CAP_WIDTH * 2)
	at = at.round()
	canvas.draw_texture_rect_region(TEXTURE, Rect2(at, Vector2(CAP_WIDTH, HEIGHT)), Rect2(0, 0, CAP_WIDTH, HEIGHT))
	canvas.draw_texture_rect_region(TEXTURE, Rect2(at + Vector2(CAP_WIDTH, 0), Vector2(width - CAP_WIDTH * 2, HEIGHT)), Rect2(CAP_WIDTH, 0, WIDTH - CAP_WIDTH * 2, HEIGHT))
	canvas.draw_texture_rect_region(TEXTURE, Rect2(at + Vector2(width - CAP_WIDTH, 0), Vector2(CAP_WIDTH, HEIGHT)), Rect2(WIDTH - CAP_WIDTH, 0, CAP_WIDTH, HEIGHT))
	var filled := fill_width(ratio, width)
	if filled > 0:
		canvas.draw_texture_rect_region(TEXTURE, Rect2(at + INSET, Vector2(filled, FILL_SIZE.y)), _fill_region(tone))


static func background_style() -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = TEXTURE
	style.region_rect = Rect2(0, 0, WIDTH, HEIGHT)
	style.texture_margin_left = CAP_WIDTH
	style.texture_margin_right = CAP_WIDTH
	style.texture_margin_top = 3
	style.texture_margin_bottom = 3
	style.set_content_margin(SIDE_LEFT, INSET.x)
	style.set_content_margin(SIDE_RIGHT, INSET.x)
	style.set_content_margin(SIDE_TOP, INSET.y)
	style.set_content_margin(SIDE_BOTTOM, INSET.y)
	return style


static func fill_style(tone: Tone) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = TEXTURE
	style.region_rect = _fill_region(tone)
	style.texture_margin_top = 1
	style.texture_margin_bottom = 1
	return style


static func _fill_region(tone: Tone) -> Rect2:
	return Rect2(Vector2(0, HEIGHT + int(tone) * int(FILL_SIZE.y)), FILL_SIZE)
