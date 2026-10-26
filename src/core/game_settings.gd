class_name GameSettings
extends RefCounted
## 환경 설정 (D-030): 볼륨·UI 크기·화면·연출. 판과 상관없이 이 기기에만 저장된다(user://settings.cfg).
## Session이 하나를 소유한다. 값을 바꾸면 changed가 나가고, apply()가 엔진(오디오 버스·창)에 반영한다.
## 멀티플레이 상대에게는 아무 영향이 없다.

signal changed

const PATH := "user://settings.cfg"
const SECTION := "settings"
## 실행할 때 만드는 오디오 버스. 음악·효과음 재생기가 이 이름으로 보낸다
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
const UI_SCALE_MIN := 0.8
const UI_SCALE_MAX := 1.3
const DEFAULTS := {
	"master_volume": 1.0, "music_volume": 0.8, "sfx_volume": 1.0,
	"ui_scale": 1.0, "shake": 1.0, "damage_numbers": true, "hitstop": true,
	"fullscreen": false, "vsync": true,
}

var values := DEFAULTS.duplicate()
## 테스트는 다른 파일에 쓰게 바꿔서 실제 설정을 건드리지 않는다
var path := PATH


func get_value(key: String) -> Variant:
	return values.get(key, DEFAULTS[key])


## 범위를 벗어난 값은 잘라서 넣는다. 바뀌었으면 changed
func set_value(key: String, value: Variant) -> void:
	if not DEFAULTS.has(key):
		return
	if key == "ui_scale":
		value = clampf(value, UI_SCALE_MIN, UI_SCALE_MAX)
	elif DEFAULTS[key] is float:
		value = clampf(value, 0.0, 1.0)
	if values.get(key) == value:
		return
	values[key] = value
	changed.emit()


func reset() -> void:
	values = DEFAULTS.duplicate()
	changed.emit()


func load_file() -> void:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	for key: String in DEFAULTS:
		if file.has_section_key(SECTION, key):
			var value: Variant = file.get_value(SECTION, key)
			# 손으로 고친 파일의 잘못된 타입은 무시하고 기본값을 쓴다
			if typeof(value) == typeof(DEFAULTS[key]) or (DEFAULTS[key] is float and value is int):
				set_value(key, float(value) if DEFAULTS[key] is float else value)


func save_file() -> void:
	var file := ConfigFile.new()
	for key: String in values:
		file.set_value(SECTION, key, values[key])
	file.save(path)


## 0~1 볼륨을 데시벨로. 0이면 끈다
static func volume_db(linear: float) -> float:
	return linear_to_db(linear) if linear > 0.001 else -80.0


## 볼륨·창 모드를 엔진에 반영한다. UI 크기와 연출 값은 화면 쪽(Main·Player)이 changed를 듣고 읽는다
func apply(root: Window) -> void:
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)
	AudioServer.set_bus_volume_db(0, volume_db(get_value("master_volume")))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(MUSIC_BUS), volume_db(get_value("music_volume")))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(SFX_BUS), volume_db(get_value("sfx_volume")))
	root.content_scale_factor = get_value("ui_scale")
	# headless(테스트)에는 창이 없다
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if get_value("fullscreen") else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if get_value("vsync") else DisplayServer.VSYNC_DISABLED)


static func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")
