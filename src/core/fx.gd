class_name Fx
extends RefCounted
## 임시 이펙트: 파티클, 떠오르는 글자, 밤 조명. Phase 2에서 픽셀아트 이펙트로 교체한다.

const LIGHT_TEXTURE_SIZE := 256
const LIGHT_ENERGY_META := &"light_energy_scale"

static var _light_texture: GradientTexture2D


static func burst(tree: SceneTree, at: Vector2, color: Color, amount := 10, speed := 120.0) -> void:
	var parent := tree.get_first_node_in_group("fx_layer")
	if parent == null:
		return
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = amount
	particles.lifetime = 0.5
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = speed * 0.3
	particles.initial_velocity_max = speed
	particles.damping_min = speed
	particles.damping_max = speed * 1.5
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 4.0
	particles.color = color
	particles.position = at
	particles.emitting = true
	parent.add_child(particles)
	tree.create_timer(1.0).timeout.connect(particles.queue_free)


static func float_text(tree: SceneTree, at: Vector2, text: String, color: Color) -> void:
	var parent := tree.get_first_node_in_group("fx_layer")
	if parent == null:
		return
	var label := Label.new()
	label.text = text
	label.z_index = 100
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(160, 20)
	label.position = at - Vector2(80, 30)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	parent.add_child(label)
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", label.position.y - 30.0, 1.0)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(label.queue_free)


## 적이 받은 피해 숫자 (D-023). 강조(패시브로 강해진 공격)는 크고 주황색에 느낌표를 붙인다
static func damage_number(tree: SceneTree, at: Vector2, amount: float, emphasis: bool) -> void:
	var parent := tree.get_first_node_in_group("fx_layer")
	if parent == null:
		return
	var label := Label.new()
	label.text = ("%d!" if emphasis else "%d") % maxi(1, roundi(amount))
	label.z_index = 101
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(120, 28)
	# 같은 자리에 여러 번 맞아도 숫자가 겹치지 않게 살짝 흩뿌린다 (연출용 무작위)
	label.position = at - Vector2(60, 34) + Vector2(randf_range(-10, 10), randf_range(-4, 4))
	label.add_theme_font_size_override("font_size", 22 if emphasis else 12)
	label.add_theme_color_override("font_color", Color("ffb030") if emphasis else Color("f4efe0"))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6 if emphasis else 4)
	parent.add_child(label)
	var tween := label.create_tween()
	if emphasis:
		label.pivot_offset = label.size / 2.0
		label.scale = Vector2.ONE * 1.6
		tween.tween_property(label, "scale", Vector2.ONE, 0.12)
	tween.tween_property(label, "position:y", label.position.y - 26.0, 0.7)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.7)
	tween.tween_callback(label.queue_free)


## 밤에 주변을 밝히는 빛. DayNight가 "lights" 그룹의 밝기를 조절한다.
static func add_light(owner: Node2D, radius: float, energy_scale := 1.0) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = _get_light_texture()
	light.texture_scale = radius * 2.0 / LIGHT_TEXTURE_SIZE
	light.energy = 0.0
	light.set_meta(LIGHT_ENERGY_META, energy_scale)
	light.add_to_group("lights")
	owner.add_child(light)
	return light


static func _get_light_texture() -> GradientTexture2D:
	if _light_texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color.WHITE)
		gradient.set_color(1, Color(1, 1, 1, 0))
		_light_texture = GradientTexture2D.new()
		_light_texture.gradient = gradient
		_light_texture.fill = GradientTexture2D.FILL_RADIAL
		_light_texture.fill_from = Vector2(0.5, 0.5)
		_light_texture.fill_to = Vector2(1.0, 0.5)
		_light_texture.width = LIGHT_TEXTURE_SIZE
		_light_texture.height = LIGHT_TEXTURE_SIZE
	return _light_texture
