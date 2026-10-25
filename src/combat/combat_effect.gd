class_name CombatEffect
extends Node2D
## 공격 명중·폭발의 일회성 픽셀 애니메이션. 피해 판정이나 게임 결과용 난수를 쓰지 않는다.

const TEXTURE := preload("res://assets/combat/attack_effects.png")
const MAX_DISPLAY_SCALE := 8.0

var effect_id := "impact"
var display_scale := 1.0
var _elapsed := 0.0


static func spawn(tree: SceneTree, id: String, at: Vector2, size := 1.0, angle := 0.0) -> CombatEffect:
	if not WeaponArtDB.EFFECTS.has(id) or not at.is_finite() or not is_finite(size) or not is_finite(angle):
		return null
	var layer := tree.get_first_node_in_group("fx_layer")
	if layer == null:
		return null
	var effect := CombatEffect.new()
	effect.effect_id = id
	effect.position = at
	effect.rotation = angle
	effect.display_scale = clampf(size, 0.1, MAX_DISPLAY_SCALE)
	effect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.add_child.call_deferred(effect)
	return effect


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= float(WeaponArtDB.EFFECTS[effect_id]["duration"]):
		queue_free()
	queue_redraw()


func _draw() -> void:
	var size := Vector2.ONE * WeaponArtDB.EFFECT_SIZE * display_scale
	var duration: float = WeaponArtDB.EFFECTS[effect_id]["duration"]
	draw_texture_rect_region(TEXTURE, Rect2(-size / 2.0, size), WeaponArtDB.effect_region(effect_id, _elapsed / duration))
