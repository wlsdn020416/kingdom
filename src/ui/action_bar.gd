class_name ActionBar
extends Control
## 화면 아래 바. 평소엔 장비 스킬바(1~4), 건설 모드에선 건물 목록을 보여준다.

const SLOT_SIZE := Vector2(72, 54)
const BUILD_SLOT_SIZE := Vector2(110, 54)
const GAP := 6.0

var _player: Player
var _build_mode: BuildMode
var _kingdom: Kingdom


func setup(player: Player, build_mode: BuildMode, kingdom: Kingdom) -> void:
	_player = player
	_build_mode = build_mode
	_kingdom = kingdom
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _player == null:
		return
	if _build_mode.active:
		_draw_build_bar()
	else:
		_draw_skill_bar()


func _draw_skill_bar() -> void:
	var font := ThemeDB.fallback_font
	var equipment := _player.equipment
	var bar := equipment.skill_bar()
	var start := _row_start(Equipment.MAX_SKILLS, SLOT_SIZE.x)
	for i in Equipment.MAX_SKILLS:
		var rect := Rect2(start + Vector2(i * (SLOT_SIZE.x + GAP), 0), SLOT_SIZE)
		_draw_slot(rect, false)
		draw_string(font, rect.position + Vector2(5, 14), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiKit.MUTED)
		if i >= bar.size():
			continue
		var skill: Dictionary = ItemDB.ITEMS[bar[i]]["skill"]
		draw_rect(Rect2(rect.position + Vector2(SLOT_SIZE.x / 2.0 - 8.0, 10), Vector2(16, 16)), Skills.color(skill["id"]))
		draw_string(font, rect.position + Vector2(0, 46), skill["name"], HORIZONTAL_ALIGNMENT_CENTER, SLOT_SIZE.x, 12, UiKit.TEXT)
		var left := equipment.cooldown_left(bar[i])
		if left > 0.0:
			var ratio := left / float(skill["cooldown"])
			draw_rect(Rect2(rect.position.x, rect.end.y - rect.size.y * ratio, rect.size.x, rect.size.y * ratio), Color(0, 0, 0, 0.7))
			draw_string(font, rect.position + Vector2(0, 32), "%.1f" % left, HORIZONTAL_ALIGNMENT_CENTER, SLOT_SIZE.x, 13, Color.WHITE)
	var hidden := equipment.hidden_skill_count()
	if hidden > 0:
		draw_string(font, Vector2(0, -8), "스킬바가 가득 차서 스킬 %d개가 숨겨졌습니다" % hidden, HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, UiKit.MUTED)


func _draw_build_bar() -> void:
	var font := ThemeDB.fallback_font
	var start := _row_start(BuildingDB.ORDER.size(), BUILD_SLOT_SIZE.x)
	for i in BuildingDB.ORDER.size():
		var info: Dictionary = BuildingDB.TYPES[BuildingDB.ORDER[i]]
		var rect := Rect2(start + Vector2(i * (BUILD_SLOT_SIZE.x + GAP), 0), BUILD_SLOT_SIZE)
		_draw_slot(rect, i == _build_mode.selected)
		draw_string(font, rect.position + Vector2(0, 22), "%d %s" % [i + 1, info["name"]], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 13, UiKit.TEXT)
		var cost_color := UiKit.MUTED if _kingdom.can_afford(info["cost"]) else UiKit.DANGER
		draw_string(font, rect.position + Vector2(0, 42), Balance.format_cost(info["cost"]), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 11, cost_color)
	draw_string(font, Vector2(0, -8), "건설 모드 · 좌클릭 설치 · 우클릭 철거(반값 환불) · B로 종료", HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, UiKit.ACCENT)


func _draw_slot(rect: Rect2, selected: bool) -> void:
	draw_rect(rect, Color(0.06, 0.07, 0.07, 0.85) if not selected else Color("3b4636"))
	draw_rect(rect, UiKit.ACCENT if selected else UiKit.BORDER, false, 2.0)


func _row_start(count: int, slot_width: float) -> Vector2:
	var total := count * slot_width + (count - 1) * GAP
	return Vector2((size.x - total) / 2.0, size.y - SLOT_SIZE.y)
