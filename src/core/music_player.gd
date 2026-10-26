class_name MusicPlayer
extends Node
## 한 판이 소유하는 반복 음악 재생기. 활성 전환을 페이드하고 회의 중에는 위치를 보존해 멈춘다.
## 보스 유무·승패 판정은 호출자가 맡으며 게임 상태나 난수를 바꾸지 않는다.

const SILENT_DB := -60.0
var _player := AudioStreamPlayer.new()
var _fade: Tween
var _active := false
var _volume_db := 0.0
var _fade_seconds := 1.0


func setup(stream: AudioStreamOggVorbis, volume_db: float, fade_seconds: float) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_volume_db = volume_db
	_fade_seconds = fade_seconds
	var loop := stream.duplicate() as AudioStreamOggVorbis
	loop.loop = true
	_player.stream = loop
	_player.volume_db = SILENT_DB
	_player.bus = GameSettings.MUSIC_BUS
	add_child(_player)


func _process(_delta: float) -> void:
	# 승패 화면의 일시정지 뒤에도 종료 페이드는 진행하고, 회의 중인 곡은 위치를 보존한다.
	_player.stream_paused = get_tree().paused and _active


func set_active(active: bool) -> void:
	if _active == active:
		return
	_active = active
	if _fade != null and _fade.is_valid():
		_fade.kill()
	if active and not _player.playing:
		_player.volume_db = SILENT_DB
		_player.play()
	_player.stream_paused = get_tree().paused and active
	_fade = create_tween().set_ignore_time_scale(true)
	_fade.tween_property(_player, "volume_db", _volume_db if active else SILENT_DB, _fade_seconds)
	if not active:
		_fade.tween_callback(_player.stop)
