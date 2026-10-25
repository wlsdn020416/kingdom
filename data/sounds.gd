class_name SoundDB
extends RefCounted
## 효과음의 파일·음량·연속 재생 간격과 시작 화면 음악. 원본은 assets/audio/에 있다.

const TITLE_MUSIC := preload("res://assets/audio/music/title_theme.ogg")
const TITLE_MUSIC_VOLUME_DB := -8.0
const TITLE_MUSIC_FADE_SECONDS := 1.6

const ROOT := "res://assets/audio/sfx/"
const GROUPS := {
	"movement": ["footstep_grass", "footstep_stone", "footstep_water", "dash"],
	"combat": ["sword_swing", "bow_shoot", "crossbow_shoot", "magic_shoot", "hit_flesh", "hit_armor", "player_hurt", "player_death", "enemy_death"],
	"skills": ["shotgun", "fireball", "explosion", "shield", "heal", "rally"],
	"world": ["wood_hit", "stone_hit", "tree_break", "rock_break", "pickup", "chest_open"],
	"kingdom": ["build", "repair", "demolish", "craft", "upgrade", "deposit", "core_hit", "core_destroyed"],
	"ui": ["click", "open", "close", "error", "equip", "level_up", "map_ping"],
	"alerts": ["day_start", "night_start", "boss_spawn"],
}
## 참가자가 자기 캐릭터의 연출로 알릴 수 있는 것만 허용한다. 월드 결과음은 호스트가 따로 보낸다.
const PLAYER_SOUNDS := ["sword_swing", "bow_shoot", "crossbow_shoot", "magic_shoot", "dash", "shotgun", "fireball", "shield", "heal", "rally", "player_hurt", "player_death"]
const VARIANT_COUNTS := {"explosion": 3, "tree_break": 1}
const GROUP_VOLUME_DB := {"movement": -6.0, "combat": -7.0, "skills": -7.0, "world": -8.0, "kingdom": -7.0, "ui": -3.0, "alerts": -5.0}
const STEP_DISTANCE := 56.0
const MAX_STEP_DISTANCE := 96.0
const MAX_STEP_SPEED := 450.0
const MIN_INTERVAL := 0.055
const INTERVALS := {"pickup": 0.15, "error": 0.2, "core_hit": 0.15, "footstep_grass": 0.16, "footstep_stone": 0.16, "footstep_water": 0.16}


static func catalog() -> Dictionary:
	var result := {}
	for folder: String in GROUPS:
		for id: String in GROUPS[folder]:
			var paths: Array[String] = []
			for i in int(VARIANT_COUNTS.get(id, 4)):
				paths.append(ROOT + folder + "/%s_%02d.wav" % [id, i + 1])
			result[id] = {"paths": paths, "volume_db": GROUP_VOLUME_DB[folder], "interval": INTERVALS.get(id, MIN_INTERVAL)}
	return result


static func weapon(id: String) -> String:
	match id:
		"old_bow": return "bow_shoot"
		"scatter_crossbow": return "crossbow_shoot"
		"fire_staff": return "magic_shoot"
		_: return "sword_swing"


static func footstep(terrain: int) -> String:
	match terrain:
		WorldData.Terrain.FLOOR, WorldData.Terrain.VOLCANO: return "footstep_stone"
		WorldData.Terrain.SWAMP: return "footstep_water"
		_: return "footstep_grass"
