class_name SoundEffects
extends Node
## 주입받은 효과음을 재생한다. 위치음은 거리에 따라 줄고 UI·알림은 일시정지 중에도 들린다.

## 거리·중복 제한을 통과해 실제 재생을 시작한 효과음.
signal played(id: String, at: Vector2)

const MAX_WORLD_VOICES := 20
const MAX_UI_VOICES := 8
const AUDIBLE_DISTANCE := 800.0
const DISTANCE_ATTENUATION := 1.5
const PANNING_STRENGTH := 0.6

var _listener: Node2D
var _catalog := {}
var _streams := {}
var _next_variant := {}
var _last_played := {}
var _world_voices: Array[AudioStreamPlayer2D] = []
var _ui_voices: Array[AudioStreamPlayer] = []


func setup(listener: Node2D, catalog: Dictionary) -> void:
	_listener = listener
	_catalog = catalog
	process_mode = Node.PROCESS_MODE_ALWAYS
	if listener != null:
		var ears := AudioListener2D.new()
		listener.add_child(ears)
		ears.make_current()


## 무한 좌표는 화면 알림·UI다. 게임 규칙이나 네트워크 권한은 이 노드가 결정하지 않는다.
func play(id: String, at := Vector2.INF) -> bool:
	if not _catalog.has(id):
		return false
	var spatial := at.is_finite()
	if spatial and (not is_instance_valid(_listener) or _listener.global_position.distance_to(at) >= AUDIBLE_DISTANCE or get_tree().paused):
		return false
	var now := Time.get_ticks_msec()
	var info: Dictionary = _catalog[id]
	if now - int(_last_played.get(id, -100000)) < float(info["interval"]) * 1000.0:
		return false
	if not _streams.has(id):
		var variants: Array[AudioStream] = []
		for path: String in info["paths"]:
			var stream := load(path) as AudioStream
			if stream != null:
				variants.append(stream)
		_streams[id] = variants
	var variants: Array = _streams[id]
	if variants.is_empty():
		return false
	var index: int = _next_variant.get(id, 0)
	var stream: AudioStream = variants[index % variants.size()]
	if spatial:
		var voice := _world_voice()
		voice.stream = stream
		voice.global_position = at
		voice.volume_db = info["volume_db"]
		voice.play()
	else:
		var voice := _ui_voice()
		voice.stream = stream
		voice.volume_db = info["volume_db"]
		voice.play()
	_last_played[id] = now
	_next_variant[id] = index + 1
	played.emit(id, at)
	return true


func watch_panel(panel: Control) -> void:
	panel.visibility_changed.connect(func() -> void: play("open" if panel.visible else "close"))


func _world_voice() -> AudioStreamPlayer2D:
	for voice in _world_voices:
		if not voice.playing:
			return voice
	if _world_voices.size() >= MAX_WORLD_VOICES:
		var oldest := _world_voices.pop_front() as AudioStreamPlayer2D
		oldest.stop()
		_world_voices.append(oldest)
		return oldest
	var voice := AudioStreamPlayer2D.new()
	voice.process_mode = Node.PROCESS_MODE_PAUSABLE
	voice.max_distance = AUDIBLE_DISTANCE
	voice.attenuation = DISTANCE_ATTENUATION
	voice.panning_strength = PANNING_STRENGTH
	voice.bus = GameSettings.SFX_BUS
	add_child(voice)
	_world_voices.append(voice)
	return voice


func _ui_voice() -> AudioStreamPlayer:
	for voice in _ui_voices:
		if not voice.playing:
			return voice
	if _ui_voices.size() >= MAX_UI_VOICES:
		var oldest := _ui_voices.pop_front() as AudioStreamPlayer
		oldest.stop()
		_ui_voices.append(oldest)
		return oldest
	var voice := AudioStreamPlayer.new()
	voice.bus = GameSettings.SFX_BUS
	add_child(voice)
	_ui_voices.append(voice)
	return voice
