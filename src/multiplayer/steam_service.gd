class_name SteamService
extends Node
## Steam 연결 (GodotSteam GDExtension, D-016). 게임을 켤 때 한 번 초기화하고 매 프레임 콜백을 돌린다.
## Session이 자식으로 들고 있어 씬이 바뀌어도 살아 있다. 게임 규칙은 이 노드를 모른다.
## GodotSteam을 못 불러오거나 Steam이 꺼져 있어도 게임은 그대로 돌아가야 하므로
## 전역 Steam 클래스를 직접 쓰지 않고 엔진 싱글턴으로 찾는다.

## 개발용 Valve 테스트 앱(Spacewar). 우리 게임의 Steam App ID를 받으면 바꾼다
const APP_ID := 480
const NO_STEAM_ARG := "--no-steam"

var available := false
var persona_name := ""
var steam_id := 0
## 시작 화면에 보여줄 한 줄 상태
var status_text := ""

var _steam: Object


func _ready() -> void:
	# 일시정지 중(전략회의·멸망 화면)에도 Steam 콜백이 멈추지 않게 한다
	process_mode = Node.PROCESS_MODE_ALWAYS
	status_text = _initialize()
	print("Steam: " + status_text)


func _process(_delta: float) -> void:
	if available:
		_steam.run_callbacks()


func _initialize() -> String:
	# 자동 테스트마다 Steam에 "플레이 중"이 뜨지 않게 headless에서는 켜지 않는다
	if DisplayServer.get_name() == "headless":
		return "꺼짐 (headless 실행)"
	if NO_STEAM_ARG in OS.get_cmdline_user_args():
		return "꺼짐 (%s)" % NO_STEAM_ARG
	if not Engine.has_singleton("Steam"):
		return "GodotSteam을 불러오지 못함 (addons/godotsteam 확인)"
	_steam = Engine.get_singleton("Steam")
	var result: Dictionary = _steam.steamInitEx(APP_ID)
	if result.get("status", -1) != 0:
		return "연결 실패: %s (Steam 클라이언트가 켜져 있고 로그인했는지 확인)" % result.get("verbal", "알 수 없음")
	available = true
	persona_name = _steam.getPersonaName()
	steam_id = _steam.getSteamID()
	return "%s (App %d)" % [persona_name, APP_ID]
