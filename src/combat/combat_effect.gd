class_name CombatEffect
extends Node2D
## 공격 명중·폭발의 일회성 픽셀 애니메이션. 피해 판정이나 게임 결과용 난수를 쓰지 않는다.

const TEXTURE := preload("res://assets/combat/attack_effects.png")
const MAX_DISPLAY_SCALE := 8.0
const PENDING_META := &"pending_passive_effects"

var effect_id := "impact"
var display_scale := 1.0
var _elapsed := 0.0
var _reserved_slot := false


static func spawn(tree: SceneTree, id: String, at: Vector2, size := 1.0, angle := 0.0) -> CombatEffect:
	if (not WeaponArtDB.EFFECTS.has(id) and not PassiveEffectDB.EFFECTS.has(id)) or not at.is_finite() or not is_finite(size) or not is_finite(angle):
		return null
	var layer := tree.get_first_node_in_group("fx_layer")
	if layer == null:
		return null
	var passive := PassiveEffectDB.EFFECTS.has(id)
	var pending := int(layer.get_meta(PENDING_META, 0))
	if passive and layer.get_child_count() + pending >= PassiveEffectDB.MAX_VISIBLE:
		return null
	var effect := CombatEffect.new()
	effect.effect_id = id
	effect.position = at
	effect.rotation = angle
	effect.display_scale = clampf(size, 0.1, MAX_DISPLAY_SCALE)
	effect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if passive:
		# 같은 프레임의 요새화도 한도를 지키도록 지연 추가 전에 자리를 예약한다.
		layer.set_meta(PENDING_META, pending + 1)
		effect._reserved_slot = true
	layer.add_child.call_deferred(effect)
	return effect


func _ready() -> void:
	if _reserved_slot:
		var layer := get_parent()
		layer.set_meta(PENDING_META, maxi(0, int(layer.get_meta(PENDING_META, 0)) - 1))
		_reserved_slot = false


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= effect_duration():
		queue_free()
	queue_redraw()


func _draw() -> void:
	if PassiveEffectDB.EFFECTS.has(effect_id):
		var dimensions := Vector2.ONE * PassiveEffectDB.SIZE * display_scale
		draw_texture_rect_region(PassiveEffectDB.TEXTURE, Rect2(-dimensions / 2.0, dimensions), PassiveEffectDB.region(effect_id, _elapsed / effect_duration()))
		return
	var size := Vector2.ONE * WeaponArtDB.EFFECT_SIZE * display_scale
	var duration: float = WeaponArtDB.EFFECTS[effect_id]["duration"]
	draw_texture_rect_region(TEXTURE, Rect2(-size / 2.0, size), WeaponArtDB.effect_region(effect_id, _elapsed / duration))


func effect_duration() -> float:
	return PassiveEffectDB.EFFECTS[effect_id]["duration"] if PassiveEffectDB.EFFECTS.has(effect_id) else WeaponArtDB.EFFECTS[effect_id]["duration"]
