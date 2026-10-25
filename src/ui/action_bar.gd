class_name ActionBar
extends Control
## 하단 스킬바의 픽셀 아이콘·단축키·쿨타임을 표시한다. 스킬 배치는 Equipment가 결정한다.
## 설치 모드에서는 기존 건물 비용과 조작 안내로 전환한다.

enum SlotState { READY, COOLDOWN, EMPTY, PRESSED }

const TEXTURE := preload("res://assets/ui/skill_ui.png")
const ICON_ORDER := ["dash", "shotgun", "fireball", "bomb", "shield", "heal", "rally"]
const ICON_SIZE := 32
const FRAME_SIZE := 40
const SLOT_SIZE := Vector2(64, 64)
const BUILD_SLOT_SIZE := Vector2(110, 54)
const GAP := 6.0
const DASH_GAP := 10.0
const ROW_WIDTH := SLOT_SIZE.x * (Equipment.MAX_SKILLS + 1) + GAP * Equipment.MAX_SKILLS + DASH_GAP
const DOCK_HEIGHT := 92.0
const DOCK_PADDING := 8.0
const DOCK_COLOR := Color(0.04, 0.065, 0.095, 0.94)
const TEXT := Color("e7e8dd")
const MUTED := Color("8493a3")

var _player: Player
var _build_mode: BuildMode
var _kingdom: Kingdom


func setup(player: Player, build_mode: BuildMode, kingdom: Kingdom) -> void:
	_player = player
	_build_mode = build_mode
	_kingdom = kingdom
	mouse_filter = Control.MOUSE_FILTER_PASS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


static func icon_region(skill_id: String) -> Rect2:
	var index := ICON_ORDER.find(skill_id)
	return Rect2(index * ICON_SIZE, 0, ICON_SIZE, ICON_SIZE) if index >= 0 else Rect2()


func skill_slot_rect(index: int) -> Rect2:
	var extra := DASH_GAP if index > 0 else 0.0
	return Rect2(Vector2((size.x - ROW_WIDTH) * 0.5 + index * (SLOT_SIZE.x + GAP) + extra, 6), SLOT_SIZE)


func is_pointer_over_bar() -> bool:
	if _build_mode.active:
		return false
	return Rect2(Vector2((size.x - ROW_WIDTH) * 0.5 - DOCK_PADDING, 0), Vector2(ROW_WIDTH + DOCK_PADDING * 2, DOCK_HEIGHT)).has_point(get_local_mouse_position())


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _player == null:
		return
	if _build_mode.active:
		_draw_build_bar()
	else:
		_draw_skill_bar()


func _get_tooltip(at_position: Vector2) -> String:
	if _player == null or _build_mode.active:
		return ""
	if skill_slot_rect(0).has_point(at_position):
		return "대시 · Space\n조준 방향으로 빠르게 이동 · 재사용 %.1f초" % Balance.DASH_COOLDOWN
	var bar := _player.equipment.skill_bar()
	for i in Equipment.MAX_SKILLS:
		if not skill_slot_rect(i + 1).has_point(at_position):
			continue
		if i >= bar.size():
			return "%d번 · 미장착\n스킬이 있는 장비를 착용하면 자동 등록됩니다.\nI 장비 · 소지품" % (i + 1)
		var item: Dictionary = ItemDB.ITEMS[bar[i]]
		return "%s · %d번\n%s\n%s" % [item["skill"]["name"], i + 1, item["name"], ItemDB.describe(bar[i])]
	return ""


func _draw_skill_bar() -> void:
	var font := UiKit.GAME_FONT
	var equipment := _player.equipment
	var bar := equipment.skill_bar()
	var dock := Rect2(Vector2((size.x - ROW_WIDTH) * 0.5 - DOCK_PADDING, 0), Vector2(ROW_WIDTH + DOCK_PADDING * 2, DOCK_HEIGHT))
	draw_rect(dock, DOCK_COLOR)
	draw_rect(Rect2(dock.position, Vector2(dock.size.x, 2)), Color("465568"))
	draw_rect(Rect2(dock.position + Vector2(0, DOCK_HEIGHT - 2), Vector2(dock.size.x, 2)), Color("101925"))
	var divider_x := skill_slot_rect(0).end.x + GAP + DASH_GAP * 0.5
	draw_line(Vector2(divider_x, 18), Vector2(divider_x, 60), Color("415363"), 2)
	_draw_skill_slot(skill_slot_rect(0), "Space", "dash", "대시", _player.dash_cooldown_left(), Balance.DASH_COOLDOWN, "dash")
	for i in Equipment.MAX_SKILLS:
		var rect := skill_slot_rect(i + 1)
		if i >= bar.size():
			_draw_skill_slot(rect, str(i + 1), "", "미장착", 0.0, 1.0, "")
			continue
		var skill: Dictionary = ItemDB.ITEMS[bar[i]]["skill"]
		_draw_skill_slot(rect, str(i + 1), skill["id"], skill["name"], equipment.cooldown_left(bar[i]), skill["cooldown"], "skill_%d" % (i + 1))
	var hidden := equipment.hidden_skill_count()
	if hidden > 0:
		draw_string(font, Vector2(0, -8), "스킬바가 가득 차서 스킬 %d개가 숨겨졌습니다" % hidden, HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, UiKit.MUTED)


func _draw_skill_slot(rect: Rect2, key: String, skill_id: String, skill_name: String, cooldown_left: float, cooldown: float, action: String) -> void:
	var font := UiKit.GAME_FONT
	var state := SlotState.READY
	if skill_id.is_empty():
		state = SlotState.EMPTY
	elif cooldown_left > 0.0 or _player.is_dead:
		state = SlotState.COOLDOWN
	elif not action.is_empty() and Input.is_action_pressed(action):
		state = SlotState.PRESSED
	draw_texture_rect_region(TEXTURE, rect, Rect2(int(state) * FRAME_SIZE, ICON_SIZE, FRAME_SIZE, FRAME_SIZE))
	var inside := Rect2(rect.position + Vector2(6, 6), Vector2(52, 52))
	if not skill_id.is_empty():
		var tint := Color.WHITE if state == SlotState.READY or state == SlotState.PRESSED else Color(0.65, 0.65, 0.7)
		draw_texture_rect_region(TEXTURE, inside, icon_region(skill_id), tint)
		if cooldown_left > 0.0:
			var ratio := clampf(cooldown_left / maxf(cooldown, 0.01), 0.0, 1.0)
			draw_rect(Rect2(inside.position, Vector2(inside.size.x, inside.size.y * ratio)), Color(0.025, 0.04, 0.07, 0.82))
			draw_rect(Rect2(rect.position + Vector2(8, 56), Vector2(48, 3)), Color("0b111b"))
			draw_rect(Rect2(rect.position + Vector2(8, 56), Vector2(48 * (1.0 - ratio), 3)), Skills.color(skill_id))
			draw_string(font, rect.position + Vector2(0, 43), "%.1f" % cooldown_left, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 22, TEXT)
		elif not _player.is_dead:
			draw_rect(Rect2(rect.position + Vector2(50, 10), Vector2(4, 4)), Skills.color(skill_id))
	var badge_width := 42.0 if key == "Space" else 22.0
	draw_rect(Rect2(rect.position + Vector2(4, 2), Vector2(badge_width, 18)), Color("101925"))
	draw_string(font, rect.position + Vector2(4, 15), key, HORIZONTAL_ALIGNMENT_CENTER, badge_width, 11, MUTED if state == SlotState.EMPTY else Color("e5c888"))
	draw_string(font, rect.position + Vector2(0, 82), skill_name, HORIZONTAL_ALIGNMENT_CENTER, SLOT_SIZE.x, 12, MUTED if state == SlotState.EMPTY else TEXT)


func _draw_build_bar() -> void:
	var font := UiKit.GAME_FONT
	var info: Dictionary = BuildingDB.TYPES[_build_mode.selected_type()]
	var rect := Rect2(Vector2((size.x - BUILD_SLOT_SIZE.x) * 0.5, size.y - BUILD_SLOT_SIZE.y), BUILD_SLOT_SIZE)
	draw_rect(rect, Color("273544"))
	draw_rect(rect, UiKit.ACCENT, false, 2.0)
	draw_string(font, rect.position + Vector2(0, 22), info["name"], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 13, UiKit.TEXT)
	var cost := BuildingDB.discounted(info["cost"], _player.progression.build_perks()["discount"])
	var cost_color := UiKit.MUTED if _kingdom.can_afford(cost, _player.inventory) else UiKit.DANGER
	draw_string(font, rect.position + Vector2(0, 42), Balance.format_cost(cost), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 11, cost_color)
	draw_string(font, Vector2(0, 12), "설치 모드 · 좌클릭 설치 · 우클릭 철거(반값 환불) · B 건물 목록 · Esc 종료", HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, UiKit.ACCENT)
