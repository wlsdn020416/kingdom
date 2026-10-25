class_name MenuArt
extends RefCounted
## 시작 화면·패시브·건설 도감의 픽셀 테두리와 색을 공유한다.

const TEXTURE := preload("res://assets/ui/menu_chrome.png")
const TEXT := Color("e1e5db")
const MUTED := Color("95a9b3")
const GOLD := Color("dfbe7d")
const BRANCH_COLORS := {"combat": Color("dc997b"), "survival": Color("89c4ac"), "building": Color("ddbf7b")}
const CREST := Rect2(256, 96, 64, 64)
const SINGLE_ICON := Rect2(320, 96, 32, 32)
const MULTI_ICON := Rect2(352, 96, 32, 32)
const CHEVRON := Rect2(320, 136, 16, 16)


static func texture(region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = TEXTURE
	atlas.region = region
	return atlas


static func style(region: Rect2, margin := 12.0) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = texture(region)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_texture_margin(side, 8.0)
		box.set_content_margin(side, margin)
	return box


static func panel(margin := 20.0) -> StyleBoxTexture:
	return style(Rect2(0, 0, 128, 96), margin)


static func theme() -> Theme:
	var result := Theme.new()
	result.default_font = UiKit.GAME_FONT
	result.default_font_size = 16
	result.set_color("font_color", "Label", TEXT)
	result.set_color("font_color", "Button", TEXT)
	result.set_color("font_hover_color", "Button", Color("fff0cf"))
	result.set_color("font_pressed_color", "Button", GOLD)
	result.set_color("font_disabled_color", "Button", Color("627783"))
	result.set_stylebox("normal", "Button", style(Rect2(128, 0, 128, 48)))
	result.set_stylebox("hover", "Button", style(Rect2(256, 0, 128, 48)))
	result.set_stylebox("pressed", "Button", style(Rect2(0, 96, 128, 48)))
	var disabled := style(Rect2(128, 0, 128, 48))
	disabled.modulate_color = Color(0.6, 0.65, 0.7, 0.8)
	result.set_stylebox("disabled", "Button", disabled)
	result.set_stylebox("focus", "Button", style(Rect2(128, 96, 128, 48)))
	result.set_stylebox("normal", "LineEdit", style(Rect2(0, 96, 128, 48)))
	result.set_stylebox("focus", "LineEdit", style(Rect2(128, 96, 128, 48)))
	result.set_color("font_color", "LineEdit", TEXT)
	result.set_color("caret_color", "LineEdit", GOLD)
	result.set_color("selection_color", "LineEdit", Color("3c596c"))
	return result
