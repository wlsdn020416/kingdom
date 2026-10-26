class_name CursorArt
extends RefCounted
## 화면별 기본 커서와 버튼 포인터의 픽셀 원본·클릭 기준점을 적용한다. 조준·입력 좌표는 바꾸지 않는다.

const MENU := preload("res://assets/ui/cursor_menu.png")
const HAND := preload("res://assets/ui/cursor_hand.png")
const AIM := preload("res://assets/ui/cursor_aim.png")
const MENU_HOTSPOT := Vector2(3, 2)
const HAND_HOTSPOT := Vector2(10, 5)
const AIM_HOTSPOT := Vector2(16, 16)


## 창 진입 때 macOS가 기본 커서를 복원할 수 있어 씬 생명주기에 갱신 연결을 묶는다.
static func attach(owner: Node, in_game: bool) -> void:
	var window := owner.get_window()
	var refresh := func() -> void: apply(in_game)
	window.mouse_entered.connect(refresh)
	window.focus_entered.connect(refresh)
	owner.tree_exiting.connect(func() -> void:
		window.mouse_entered.disconnect(refresh)
		window.focus_entered.disconnect(refresh)
		clear())
	apply(in_game)


static func apply(in_game: bool) -> void:
	Input.set_custom_mouse_cursor(AIM if in_game else MENU, Input.CURSOR_ARROW, AIM_HOTSPOT if in_game else MENU_HOTSPOT)
	Input.set_custom_mouse_cursor(HAND, Input.CURSOR_POINTING_HAND, HAND_HOTSPOT)
	Input.set_custom_mouse_cursor(AIM, Input.CURSOR_CROSS, AIM_HOTSPOT)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	# 같은 이미지는 엔진 캐시가 갱신을 생략한다. 모양을 왕복해 OS 커서를 다시 설정한다 (#121474).
	var shape: int = Input.get_current_cursor_shape()
	DisplayServer.cursor_set_shape(DisplayServer.CURSOR_CROSS if shape != Input.CURSOR_CROSS else DisplayServer.CURSOR_ARROW)
	DisplayServer.cursor_set_shape(shape)


## 네이티브 커서가 참조하는 GPU 이미지를 렌더러 종료 전에 놓는다.
static func clear() -> void:
	for shape: int in [Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND, Input.CURSOR_CROSS]:
		Input.set_custom_mouse_cursor(null, shape)
