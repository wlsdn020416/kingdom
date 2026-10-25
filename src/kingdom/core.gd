class_name Core
extends StaticBody2D
## 왕국 핵 (3x3칸). 체력이 0이 되면 왕국 멸망.

const LIGHT_RADIUS := 280.0
const SPRITE_TEXTURE := preload("res://assets/kingdom/castle.png")
## 기단을 기존 3×3칸 충돌 영역의 아래쪽에 맞추고 탑은 위로 솟게 한다.
const SPRITE_OFFSET := Vector2(-48, -84)

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


## 멀티플레이 참가자: 호스트가 계산한 체력을 보여준다. 멸망 판정은 호스트가 한다 (D-017)
func set_synced_hp(value: float) -> void:
	hp = clampf(value, 0.0, max_hp)


func repair(amount: float) -> void:
	hp = minf(max_hp, hp + amount)


func _draw() -> void:
	draw_texture(SPRITE_TEXTURE, SPRITE_OFFSET)
