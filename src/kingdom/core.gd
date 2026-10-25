class_name Core
extends StaticBody2D
## 왕국 핵 (3x3칸). 체력이 0이 되면 왕국 멸망.

const LIGHT_RADIUS := 280.0

var max_hp := Balance.CORE_MAX_HP
var hp := Balance.CORE_MAX_HP


func _ready() -> void:
	Fx.add_light(self, LIGHT_RADIUS)


func take_damage(amount: float) -> void:
	if hp <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	if hp <= 0.0:
		Events.core_destroyed.emit()


func repair(amount: float) -> void:
	hp = minf(max_hp, hp + amount)


## 임시 그림. Phase 2에서 스프라이트로 교체.
func _draw() -> void:
	draw_rect(Rect2(-44, -28, 88, 72), Color("7a6a50"))
	for i in 4:
		draw_rect(Rect2(-44 + i * 24, -40, 16, 14), Color("9a8868"))
	draw_rect(Rect2(-10, 10, 20, 34), Color("3a2c1c"))
	draw_rect(Rect2(-2, -62, 3, 22), Color("d4553a"))
	draw_rect(Rect2(1, -62, 14, 9), Color("d4553a"))
