class_name QuestTracker
extends PanelContainer
## 미니맵 아래 "오늘의 의뢰" (D-037). QuestBoard 목록을 읽어 제목·목표·진행도와 내 위치에서의 방향·거리를 보여준다.
## 게임 상태는 읽기만 한다. 의뢰가 없으면 숨는다.

const REFRESH_INTERVAL := 0.25
const DONE := Color("97c8ad")
const FAILED := Color("8a8f96")
const DIRECTIONS := ["동", "남동", "남", "남서", "서", "북서", "북", "북동"]

var _board: QuestBoard
var _player: Player
var _rows := VBoxContainer.new()
var _refresh_timer := 0.0


func setup(board: QuestBoard, player: Player) -> void:
	_board = board
	_player = player
	theme = MenuArt.theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", MenuArt.panel(10))
	_rows.add_theme_constant_override("separation", 4)
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rows)
	_board.changed.connect(_refresh)
	_refresh()


func _process(delta: float) -> void:
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = REFRESH_INTERVAL
		_refresh()


func _refresh() -> void:
	visible = not _board.quests.is_empty()
	if not visible:
		return
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_rows.add_child(_label("오늘의 의뢰", 13, MenuArt.GOLD))
	for quest: Dictionary in _board.quests:
		var state: String = quest["state"]
		var color := MenuArt.TEXT if state == "active" else DONE if state == "done" else FAILED
		_rows.add_child(_label("◆ " + str(quest["title"]), 12, color))
		_rows.add_child(_label("   " + _detail(quest), 11, MenuArt.MUTED if state == "active" else color))


func _detail(quest: Dictionary) -> String:
	match quest["state"]:
		"done":
			return "완료!"
		"failed":
			return "실패 (해가 졌습니다)"
	var text: String = quest["goal"]
	if int(quest["total"]) > 1:
		text += " %d/%d" % [quest["progress"], quest["total"]]
	var offset: Vector2 = Vector2(quest["at"]) - _player.global_position
	var tiles := roundi(offset.length() / Balance.TILE)
	if tiles <= 3:
		return text + " · 여기"
	var index := posmod(roundi(offset.angle() / (PI / 4.0)), 8)
	return text + " · %s %d칸" % [DIRECTIONS[index], tiles]


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
