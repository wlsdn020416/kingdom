extends Node
## 판 단위 정보와 씬 전환 (오토로드: Session).
## 왕국이 멸망하면 게임 씬을 통째로 버리고 새로 만들어서 진행 상황을 완전히 초기화한다.

const TITLE_SCENE := "res://scenes/title.tscn"
const GAME_SCENE := "res://scenes/main.tscn"
const SEED_WORDS := ["oak", "ember", "frost", "dune", "moss", "iron", "crown", "ash", "tide", "wolf"]

var seed_text := ""
## 직전 판 결과 문장. 시작 화면에 보여준다.
var last_result := ""
## `godot --path . -- --seed=abc` 로 실행하면 시작 화면을 건너뛴다 (테스트용)
var autostart_seed := ""
## 게임을 켜 있는 동안 계속 살아 있어야 해서 오토로드인 Session 아래에 둔다 (새 오토로드를 만들지 않음, D-016)
var steam := SteamService.new()


func _ready() -> void:
	InputBindings.register()
	add_child(steam)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			autostart_seed = arg.trim_prefix("--seed=")


func start_game(text: String) -> void:
	seed_text = text if text != "" else random_seed()
	get_tree().paused = false
	get_tree().change_scene_to_file(GAME_SCENE)


func back_to_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)


func random_seed() -> String:
	return "%s-%d" % [SEED_WORDS.pick_random(), randi_range(1000, 9999)]
