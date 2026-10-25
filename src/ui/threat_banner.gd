class_name ThreatBanner
extends Control
## 화면 위쪽의 위협 표시 (D-023): 보스 체력바, 보스 등장 배너, 해 질 녘 침공 예고.
## 보스는 호스트의 Enemy나 참가자 화면의 EnemyPuppet 어느 쪽이든 Main.boss_status()로 읽는다. 게임 상태는 바꾸지 않는다.

const BAR_WIDTH := 480
const BAR_SCALE := 2.0  # 체력바 그림을 두 배로 키워 그린다
const BAR_TOP := 22.0
const NIGHT_WARNING_TIME := 15.0  # 밤까지 이 초 이하로 남으면 예고한다
const BANNER_TIME := 3.0

var _main: Main
var _boss := {}
var _last_boss_key := -1
var _name_label := UiKit.heading("", 15, Color("ff8a7a"))
var _warning_label := UiKit.heading("", 15, UiKit.ACCENT)
var _banner := Label.new()
var _banner_tween: Tween


func setup(main: Main) -> void:
	_main = main
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for label: Label in [_name_label, _warning_label]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.anchor_left = 0.5
		label.anchor_right = 0.5
		label.offset_left = -300
		label.offset_right = 300
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 4)
		add_child(label)
	_name_label.offset_top = 0
	_warning_label.offset_top = 42
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.offset_left = -400
	_banner.offset_right = 400
	_banner.offset_top = -160
	_banner.offset_bottom = -60
	_banner.add_theme_font_size_override("font_size", 40)
	_banner.add_theme_color_override("font_color", Color("ff5a4a"))
	_banner.add_theme_color_override("font_outline_color", Color.BLACK)
	_banner.add_theme_constant_override("outline_size", 10)
	_banner.modulate.a = 0.0
	add_child(_banner)


func _process(_delta: float) -> void:
	if _main == null:
		return
	_boss = _main.boss_status()
	_name_label.visible = not _boss.is_empty()
	if not _boss.is_empty():
		var info: Dictionary = EnemyDB.TYPES[_boss["id"]]
		_name_label.text = ("최종 보스 · " if info.get("final", false) else "보스 · ") + String(info["name"])
		if _boss["key"] != _last_boss_key:
			_last_boss_key = _boss["key"]
			show_banner(("최종 보스\n" if info.get("final", false) else "보스 등장\n") + String(info["name"]))
	_warning_label.text = night_warning()
	queue_redraw()


## 해 질 녘에 오늘 밤 침공 규모와 보스를 알린다. 예고할 때가 아니면 ""
func night_warning() -> String:
	var clock := _main.day_night
	if clock.is_night() or clock.time_left() > NIGHT_WARNING_TIME:
		return ""
	var text := "침공까지 %d초 · 적 약 %d마리" % [ceili(clock.time_left()), Balance.wave_size(clock.day)]
	if Balance.is_boss_night(clock.day):
		text += " · 오늘 밤 보스: %s" % EnemyDB.TYPES[EnemyDB.boss_for(clock.day)]["name"]
	return text


func show_banner(text: String) -> void:
	_banner.text = text
	if _banner_tween != null:
		_banner_tween.kill()
	_banner.modulate.a = 1.0
	_banner.scale = Vector2.ONE * 1.3
	_banner.pivot_offset = _banner.size / 2.0
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "scale", Vector2.ONE, 0.25)
	_banner_tween.tween_interval(BANNER_TIME)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.6)


func banner_text() -> String:
	return _banner.text if _banner.modulate.a > 0.0 else ""


func _draw() -> void:
	if _boss.is_empty():
		return
	var left := (size.x - BAR_WIDTH * BAR_SCALE) / 2.0
	draw_set_transform(Vector2(left, BAR_TOP), 0.0, Vector2.ONE * BAR_SCALE)
	HealthBarArt.draw_bar(self, Vector2.ZERO, _boss["ratio"], HealthBarArt.Tone.RED, BAR_WIDTH)
	draw_set_transform(Vector2.ZERO)
