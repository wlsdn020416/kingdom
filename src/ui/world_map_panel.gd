class_name WorldMapPanel
extends Control
## 전체 지도 창 (M). 다른 메뉴와 같은 MenuArt 판 위에 큰 지도와 표식 범례·현황을 보여준다.
## 지도 그림은 MapView, 표식 그림은 미니맵(minimap_ui)과 같은 것을 쓴다. 게임 상태는 읽기만 한다.

const DESIGN_SIZE := Vector2(1200, 672)
const ICONS := preload("res://assets/ui/map_ui.png")
const MAP_ICON := Rect2(0, 0, 32, 32)
const REFRESH_INTERVAL := 1.0
## 범례: [미니맵 표식 번호, 이름, 설명]
const LEGEND := [
	[0, "왕국 핵", "지켜야 할 성채"],
	[1, "나", "내 캐릭터 위치"],
	[2, "침공 적", "밤에 왕국으로 오는 적"],
	[3, "순간이동 탑", "탑끼리 오갈 수 있음"],
	[4, "핑", "전략회의(T)에서 찍은 곳"],
	[5, "낮 의뢰", "해 지기 전에 끝내면 모두 보상"],
]

var view: MapView
var _map: MapState
var _clock: DayNight
var _shell := PanelContainer.new()
var _canvas := Control.new()
var _status: Label
var _refresh_timer := 0.0


func setup(map: MapState, clock: DayNight) -> void:
	_map = map
	_clock = clock
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = MenuArt.theme()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.025, 0.04, 0.055, 0.94)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	_shell.size = DESIGN_SIZE
	_shell.add_theme_stylebox_override("panel", MenuArt.panel(0))
	add_child(_shell)
	_shell.add_child(_canvas)
	_place(_canvas, icon(ICONS, MAP_ICON, 40), Vector2(24, 16), Vector2(40, 40))
	_place(_canvas, label("전체 지도", 28, MenuArt.TEXT), Vector2(76, 17), Vector2(200, 40))
	_place(_canvas, label("탐험한 곳만 보입니다 · 동료가 밝힌 곳도 함께 보입니다", 13, MenuArt.MUTED), Vector2(236, 30), Vector2(600, 24))
	var close := UiKit.button("닫기  M", hide)
	close.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_canvas, close, Vector2(1072, 18), Vector2(104, 40))
	var frame := section(_canvas, Vector2(24, 72), Vector2(584, 584))
	view = MapView.new().setup(map)
	_place(frame, view, Vector2(12, 12), Vector2(560, 560))
	var info := section(_canvas, Vector2(624, 72), Vector2(552, 584))
	_place(info, label("지도 표식", 20, MenuArt.GOLD), Vector2(20, 18), Vector2(300, 30))
	add_legend(info, Vector2(20, 64))
	_place(info, rule(512), Vector2(20, 380), Vector2(512, 2))
	_place(info, label("현황", 20, MenuArt.GOLD), Vector2(20, 398), Vector2(300, 30))
	_status = label("", 16, MenuArt.TEXT)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(info, _status, Vector2(20, 438), Vector2(512, 130))
	resized.connect(_layout)
	visibility_changed.connect(func() -> void:
		if visible:
			_refresh_timer = 0.0)
	_layout()
	hide()


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = REFRESH_INTERVAL
		_refresh()


func _refresh() -> void:
	var explored := _map.world.data.explored
	var seen := explored.count(1)
	var ratio := float(seen) / maxi(1, explored.size())
	_status.text = "%d일차 · %s\n왕국 영토 반지름 %d칸\n탐험한 땅 %d%%" % [
		_clock.day, "밤 (침공 중)" if _clock.is_night() else "낮", _map.kingdom.territory_radius(), roundi(ratio * 100.0)]


func _layout() -> void:
	var fit := maxf(0.1, minf((size.x - 32) / DESIGN_SIZE.x, (size.y - 32) / DESIGN_SIZE.y))
	_shell.scale = Vector2.ONE * fit
	_shell.position = (size - DESIGN_SIZE * fit) / 2.0


## 범례 한 줄씩: 미니맵 표식 + 이름 + 설명
func add_legend(parent: Control, at: Vector2) -> void:
	for i in LEGEND.size():
		var entry: Array = LEGEND[i]
		var top := at.y + i * 50.0
		var marker := icon(MapView.ART, Rect2(96 + int(entry[0]) * MapView.MARKER_SIZE, 72, MapView.MARKER_SIZE, MapView.MARKER_SIZE), 32)
		_place(parent, marker, Vector2(at.x, top), Vector2(32, 32))
		_place(parent, label(entry[1], 16, MenuArt.TEXT), Vector2(at.x + 46, top + 4), Vector2(140, 24))
		_place(parent, label(entry[2], 13, MenuArt.MUTED), Vector2(at.x + 190, top + 7), Vector2(300, 24))


## 다른 메뉴의 안쪽 판과 같은 어두운 판
static func section(parent: Control, at: Vector2, dimensions: Vector2) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", MenuArt.style(Rect2(0, 96, 128, 48), 0))
	panel.position = at
	panel.size = dimensions
	parent.add_child(panel)
	var body := Control.new()
	panel.add_child(body)
	return body


static func icon(atlas: Texture2D, region: Rect2, pixels: int) -> TextureRect:
	var texture := AtlasTexture.new()
	texture.atlas = atlas
	texture.region = region
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2.ONE * pixels
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


static func label(text: String, font_size: int, color: Color) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	return result


static func rule(width: float) -> ColorRect:
	var line := ColorRect.new()
	line.color = Color(0.48, 0.57, 0.62, 0.35)
	line.custom_minimum_size = Vector2(width, 2)
	return line


func _place(parent: Control, control: Control, at: Vector2, dimensions: Vector2) -> void:
	control.position = at
	control.size = dimensions
	parent.add_child(control)
