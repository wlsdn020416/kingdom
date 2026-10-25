class_name InputBindings
extends RefCounted
## 키 배치. project.godot 입력 맵 대신 여기 한 곳에서 관리한다.
## 물리 키 기준이라 한글 자판 상태에서도 그대로 동작한다.

const KEYS := {
	"move_up": [KEY_W],
	"move_down": [KEY_S],
	"move_left": [KEY_A],
	"move_right": [KEY_D],
	"dash": [KEY_SPACE],
	"skill_1": [KEY_1],
	"skill_2": [KEY_2],
	"skill_3": [KEY_3],
	"skill_4": [KEY_4],
	"interact": [KEY_E],
	"repair": [KEY_R],
	"build_toggle": [KEY_B],
	"equipment": [KEY_I],
	"meeting": [KEY_T],
	"world_map": [KEY_M],
	"skip_night": [KEY_N],
	"confirm": [KEY_ENTER, KEY_KP_ENTER],
}

const MOUSE_BUTTONS := {
	"attack": MOUSE_BUTTON_LEFT,
	"build_remove": MOUSE_BUTTON_RIGHT,
}


static func register() -> void:
	for action in KEYS:
		_ensure_action(action)
		for key in KEYS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
	for action in MOUSE_BUTTONS:
		_ensure_action(action)
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTONS[action]
		InputMap.action_add_event(action, event)


static func _ensure_action(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
