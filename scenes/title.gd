extends Control
## 시작 화면. 시드를 정하고 새 월드를 만든다.

const CONTROLS := [
	["WASD", "이동"],
	["마우스", "조준 / 좌클릭 기본 공격 (나무·바위·광석도 공격해서 채집)"],
	["1-4", "장비 액티브 스킬 (스킬 있는 장비만 빈칸 없이 배치)"],
	["E", "상자 열기"],
	["B", "건설 모드 (1 나무벽 · 2 돌벽 · 3 화살탑, 우클릭 철거)"],
	["R", "왕국 핵 근처에서 수리"],
	["I", "장비창"],
	["T", "전략회의 (게임 일시정지, 지도에 핑)"],
	["M", "전체 지도"],
	["N", "바로 밤으로 넘기기 (테스트용)"],
]

var _seed_input: LineEdit


func _ready() -> void:
	if Session.autostart_seed != "":
		var seed_text := Session.autostart_seed
		Session.autostart_seed = ""
		Session.start_game.call_deferred(seed_text)
		return
	var background := ColorRect.new()
	background.color = Color("0f1311")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var box := UiKit.dialog(self, "KINGDOM SYSTEM", 600.0)
	(box.get_child(0) as Label).add_theme_font_size_override("font_size", 32)
	(box.get_child(0) as Label).add_theme_color_override("font_color", UiKit.ACCENT)
	box.add_child(UiKit.note("낮에는 탐험하고 자원을 모아 왕국을 강화하고, 밤에는 몰려오는 적과 보스로부터 왕국을 지키세요. 왕국이 무너지면 새 월드에서 처음부터 다시 시작합니다."))
	if Session.last_result != "":
		box.add_child(UiKit.heading("지난 판: " + Session.last_result, 14, UiKit.DANGER))
	box.add_child(_controls_grid())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(UiKit.heading("월드 시드", 14, UiKit.MUTED))
	_seed_input = LineEdit.new()
	_seed_input.text = Session.random_seed()
	_seed_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seed_input.text_submitted.connect(func(_text: String) -> void: _start())
	row.add_child(_seed_input)
	var start := UiKit.button("시작", _start)
	start.alignment = HORIZONTAL_ALIGNMENT_CENTER
	start.custom_minimum_size.x = 90
	row.add_child(start)
	box.add_child(row)
	box.add_child(UiKit.note("프로토타입: 1인 플레이. 멀티플레이와 픽셀아트는 아직 없습니다."))
	_seed_input.grab_focus()


func _controls_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	for entry in CONTROLS:
		grid.add_child(UiKit.heading(entry[0], 13, UiKit.ACCENT))
		grid.add_child(UiKit.heading(entry[1], 13))
	return grid


func _start() -> void:
	Session.start_game(_seed_input.text.strip_edges())
