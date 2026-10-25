class_name EnemyPuppet
extends Node2D
## 참가자 화면의 적 (D-017). 진짜 적은 호스트에만 있고, 이 노드는 CombatSync가 받은 모습을 그리기만 한다.
## "enemies" 그룹이 아니다. 참가자의 공격은 호스트의 진짜 적에게 다시 실행된다.

const FOLLOW_RATE := 14.0

var type_id := ""
var _target := Vector2.ZERO
var _hp_ratio := 1.0
var _frame := 0
var _facing_left := false
var _flashing := false


func setup(id: String, at: Vector2) -> EnemyPuppet:
	type_id = id
	position = at
	_target = at
	return self


func apply(at: Vector2, hp_ratio: float, frame: int, facing_left: bool, flashing: bool) -> void:
	_target = at
	_hp_ratio = hp_ratio
	_frame = frame
	_facing_left = facing_left
	_flashing = flashing
	queue_redraw()


func hp_ratio() -> float:
	return _hp_ratio


func die() -> void:
	Fx.burst(get_tree(), global_position, EnemyDB.TYPES[type_id]["color"], 12)
	queue_free()


func _process(delta: float) -> void:
	position = position.lerp(_target, minf(1.0, FOLLOW_RATE * delta))


func _draw() -> void:
	Enemy.draw_body(self, type_id, _frame, _facing_left, _flashing, _hp_ratio, EnemyDB.TYPES[type_id]["radius"])
