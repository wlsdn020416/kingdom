class_name DayNight
extends Node
## 낮/밤 순환. 낮이 끝날 무렵 서서히 어두워지고, 밤이 되면 침공이 시작된다.

enum Phase { DAY, NIGHT }

const DAY_COLOR := Color(1, 1, 1)
const NIGHT_COLOR := Color(0.22, 0.25, 0.42)
const LIGHT_ENERGY := 1.0

var phase := Phase.DAY
var day := 1
var time := 0.0

var _darkness_node: CanvasModulate


func setup(darkness_node: CanvasModulate) -> void:
	_darkness_node = darkness_node


func _process(delta: float) -> void:
	time += delta
	if phase == Phase.DAY and time >= Balance.DAY_LENGTH:
		_start_night()
	elif phase == Phase.NIGHT and time >= Balance.NIGHT_LENGTH:
		_start_day()
	var dark := darkness()
	_darkness_node.color = DAY_COLOR.lerp(NIGHT_COLOR, dark)
	for light: PointLight2D in get_tree().get_nodes_in_group("lights"):
		light.energy = dark * LIGHT_ENERGY


func is_night() -> bool:
	return phase == Phase.NIGHT


func time_left() -> float:
	return (Balance.NIGHT_LENGTH if is_night() else Balance.DAY_LENGTH) - time


## 0 = 한낮, 1 = 한밤
func darkness() -> float:
	if is_night():
		return 1.0
	if time > Balance.DAY_LENGTH - Balance.DUSK_LENGTH:
		return (time - (Balance.DAY_LENGTH - Balance.DUSK_LENGTH)) / Balance.DUSK_LENGTH
	if day > 1 and time < Balance.DAWN_LENGTH:
		return 1.0 - time / Balance.DAWN_LENGTH
	return 0.0


## 테스트용 (N 키)
func skip_to_night() -> void:
	if phase == Phase.DAY:
		time = Balance.DAY_LENGTH


func _start_night() -> void:
	phase = Phase.NIGHT
	time = 0.0
	Events.night_started.emit(day)


func _start_day() -> void:
	phase = Phase.DAY
	time = 0.0
	day += 1
	Events.day_started.emit(day)
