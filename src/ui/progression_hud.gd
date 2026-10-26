class_name ProgressionHud
extends Control
## 화면 상단의 레벨 배지·경험치 진행·패시브 포인트. Progression을 읽고 학습 창 열기만 요청한다.
## 경험치 감소는 즉시 반영하고 획득·레벨업만 짧게 강조해 사망 시 이전 경험치가 남아 보이지 않게 한다.

signal passive_requested

const TEXTURE := preload("res://assets/ui/progression_hud.png")
const WIDTH := 252.0
const HEIGHT := 44.0
const BADGE := Rect2(0, 0, 48, 56)
const BADGE_LIT := Rect2(48, 0, 48, 56)
const BAR := Rect2(96, 0, 32, 12)
const FILL := Rect2(96, 16, 26, 6)
const GAIN_SECONDS := 0.3
const LEVEL_FLASH_SECONDS := 1.4

var _progression: Progression
var _points_button := Button.new()
var _level := 1
var _xp := 0
var _points := 0
var _ratio := 0.0
var _target_ratio := 0.0
var _flash := 0.0
var _gain: Tween


func setup(progression: Progression) -> void:
	_progression = progression
	custom_minimum_size = Vector2(WIDTH, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	theme = MenuArt.theme()
	_points_button.position = Vector2(174, 3)
	_points_button.size = Vector2(72, 22)
	_points_button.focus_mode = Control.FOCUS_NONE
	_points_button.add_theme_font_size_override("font_size", 11)
	_points_button.add_theme_stylebox_override("normal", MenuArt.style(Rect2(128, 0, 128, 48), 4))
	_points_button.add_theme_stylebox_override("hover", MenuArt.style(Rect2(256, 0, 128, 48), 4))
	_points_button.pressed.connect(func() -> void:
		Events.ui_sound_requested.emit("click")
		passive_requested.emit())
	add_child(_points_button)
	_level = progression.level
	_xp = progression.xp
	_ratio = float(_xp) / progression.xp_to_next()
	_progression.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var level_up := _progression.level > _level
	var gained := level_up or _progression.xp > _xp
	_level = _progression.level
	_xp = _progression.xp
	_points = _progression.points
	_target_ratio = clampf(float(_xp) / _progression.xp_to_next(), 0.0, 1.0)
	if _gain != null and _gain.is_valid():
		_gain.kill()
	if level_up:
		_ratio = 0.0
		_flash = LEVEL_FLASH_SECONDS
	if gained:
		_gain = create_tween()
		_gain.tween_property(self, "_ratio", _target_ratio, GAIN_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_ratio = _target_ratio
	_points_button.text = "K · %d점" % _points
	_points_button.add_theme_color_override("font_color", MenuArt.GOLD if _points > 0 else MenuArt.MUTED)
	_points_button.tooltip_text = "패시브 포인트 %d개 · 눌러서 성장 경로 열기\n레벨이 오를 때 포인트를 얻습니다." % _points
	tooltip_text = "레벨 %d · 경험치 %d / %d\n다음 레벨까지 %d · 죽으면 이번 레벨의 경험치만 잃습니다.\n레벨·패시브 포인트·배운 능력은 유지됩니다." % [_level, _xp, _progression.xp_to_next(), _progression.xp_to_next() - _xp]
	queue_redraw()


func _process(delta: float) -> void:
	var animating := _flash > 0.0 or (_gain != null and _gain.is_running())
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
	if animating:
		queue_redraw()


func bar_rect() -> Rect2:
	return Rect2(46, 27, size.x - 54, 10)


func _draw() -> void:
	if _progression == null:
		return
	draw_style_box(MenuArt.panel(0), Rect2(Vector2.ZERO, size))
	var badge := BADGE_LIT if _flash > 0.0 else BADGE
	draw_texture_rect_region(TEXTURE, Rect2(2, 3, 32, 38), badge)
	var font := UiKit.GAME_FONT
	draw_string(font, Vector2(2, 22), "LV", HORIZONTAL_ALIGNMENT_CENTER, 32, 8, MenuArt.GOLD)
	var number_size := 14 if str(_level).length() <= 2 else 11 if str(_level).length() <= 3 else 9
	draw_string(font, Vector2(2, 34), str(_level), HORIZONTAL_ALIGNMENT_CENTER, 32, number_size, MenuArt.TEXT)
	draw_string(font, Vector2(46, 18), "경험치 %d / %d" % [_xp, _progression.xp_to_next()], HORIZONTAL_ALIGNMENT_LEFT, 125, 12, MenuArt.TEXT)
	var rect := bar_rect()
	# 금속 양 끝을 늘리지 않고 가운데만 늘려 작은 HUD에서도 픽셀 테두리를 유지한다.
	draw_texture_rect_region(TEXTURE, Rect2(rect.position, Vector2(4, rect.size.y)), Rect2(BAR.position, Vector2(4, BAR.size.y)))
	draw_texture_rect_region(TEXTURE, Rect2(rect.position + Vector2(4, 0), Vector2(rect.size.x - 8, rect.size.y)), Rect2(BAR.position + Vector2(4, 0), Vector2(24, BAR.size.y)))
	draw_texture_rect_region(TEXTURE, Rect2(Vector2(rect.end.x - 4, rect.position.y), Vector2(4, rect.size.y)), Rect2(BAR.position + Vector2(28, 0), Vector2(4, BAR.size.y)))
	var filled := ceili((rect.size.x - 6) * clampf(_ratio, 0.0, 1.0))
	if filled > 0:
		draw_texture_rect_region(TEXTURE, Rect2(rect.position + Vector2(3, 2), Vector2(filled, 6)), FILL)
	for i in range(1, 4):
		var x := roundf(rect.position.x + 3 + (rect.size.x - 6) * i / 4.0)
		draw_line(Vector2(x, rect.position.y + 4), Vector2(x, rect.end.y - 4), Color(0.06, 0.08, 0.15, 0.45), 1)
	if _flash > 0.0:
		var flash_alpha := sin(_flash / LEVEL_FLASH_SECONDS * PI) * 0.55
		draw_rect(Rect2(Vector2.ONE * 2, size - Vector2.ONE * 4), Color(1.0, 0.85, 0.55, flash_alpha), false, 2)
