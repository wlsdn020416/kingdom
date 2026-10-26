class_name BuildingDB
extends RefCounted
## 건설 가능한 건물 (D-022). 건설 메뉴(B)는 "category"별 탭(CATEGORIES)으로, 탭 안은 ORDER 순서로 나온다.
## sprite_column은 그림 칸, sprite_top은 체력바·메뉴 아이콘용 최상단 y좌표다. 각 건물은 고유 그림을 사용하며 제작대만 단계별 연속 칸이다.
## "tier": 지으려면 필요한 왕국 방어 단계 (0이면 언제나, D-027). 방어 단계는 왕국 핵 창에서 채집 재료로 올린다. "outside": 왕국 영토 밖에도 지을 수 있다.
## "storage": 장비 상자 칸 수. 죽으면 장비 가방이 사라지므로 예비 장비는 여기에 맡긴다 (D-014).
## "workbench": 제작대(RecipeDB). "unique": 왕국에 하나만 지을 수 있다. "door": 플레이어만 드나드는 문.
## 벽을 뺀 모든 건물(문·공성탑·생활 건물)은 플레이어가 뚫고 지나가고 적은 막힌다 (player_passable(), D-025·D-036).
## "thorns"·"regen": 건물 자체의 반사 피해 비율·초당 회복 (가시 벽·자가 보수 패시브와 더해진다).
## "tower": 화살탑류. range·interval·damage·speed 외에 pierce, splash(맞힌 적 주변 반경), slow([속도 배수, 초]), shots(한 번에 쏘는 수), lifetime.
## 생활: "teleport"(모든 순간이동 탑이 연결), "heal_aura"([반경 칸, 초당 회복]), "depot"(근처에서 가방 자원이 창고로), "reveal"(지을 때 주변 칸 수만큼 지도 탐험), "light"(밤 조명 반경 px).

const CATEGORIES := ["wall", "siege", "utility"]
const CATEGORY_NAMES := {"wall": "벽", "siege": "공성탑", "utility": "생활"}
const ORDER := [
	"wood_wall", "wood_door", "stone_wall", "palisade", "hardwood_wall", "iron_wall", "obsidian_wall", "essence_wall",
	"arrow_tower", "ballista", "cannon_tower", "frost_tower", "flame_tower", "thunder_tower",
	"gear_chest", "workbench", "teleport_tower", "campfire", "supply_depot", "watchtower",
]
const REFUND_RATE := 0.5
## DEFENSE_UPGRADES[n] = 방어 n단계 → n+1단계 비용. 나무·바위·광석에서 캐는 채집 재료만 든다 (D-027, 수치 임시)
const DEFENSE_UPGRADES := [
	{"wood": 40, "stone": 30},
	{"hardwood": 20, "copper": 15, "stone": 30},
	{"iron_ore": 20, "coal": 12, "hardwood": 20},
]

const TYPES := {
	# --- 벽: 제작대 단계가 오를수록 단단한 벽이 열린다 ---
	"wood_wall": {"description": "나무 말뚝과 가로 버팀목으로 세운 기본 방어선.","name": "나무벽", "category": "wall", "tier": 0, "sprite_column": 0, "sprite_top": 47, "hp": 120.0, "cost": {"wood": 5}, "color": Color("8a5a2b")},
	"wood_door": {"description": "튼튼한 문틀에 널빤지 문을 달았습니다. 우리 편은 드나들고 적은 막습니다.",
		"name": "나무 문", "category": "wall", "tier": 0, "sprite_column": 22, "sprite_top": 44,
		"hp": 120.0, "cost": {"wood": 8}, "color": Color("8a5a2b"), "door": true,
	},
	"stone_wall": {"description": "단단한 석재를 층층이 쌓은 왕국의 기본 성벽.","name": "돌벽", "category": "wall", "tier": 0, "sprite_column": 1, "sprite_top": 47, "hp": 300.0, "cost": {"stone": 8}, "color": Color("9a9ca0")},
	"palisade": {"description": "구리 못과 날카로운 목재 가시로 접촉한 적을 되받아칩니다.",
		"name": "가시 목책", "category": "wall", "tier": 1, "sprite_column": 2, "sprite_top": 38,
		"hp": 260.0, "cost": {"wood": 10, "copper": 3}, "color": Color("a0503a"), "thorns": 0.5,
	},
	"hardwood_wall": {"description": "단단한 목재에 대각 버팀목과 금속 띠를 둘렀습니다.",
		"name": "단단한 목벽", "category": "wall", "tier": 1, "sprite_column": 3, "sprite_top": 44,
		"hp": 520.0, "cost": {"hardwood": 8, "stone": 4}, "color": Color("5a3a1b"),
	},
	"iron_wall": {"description": "철판과 리벳으로 보강한 중장갑 성벽입니다.",
		"name": "철벽", "category": "wall", "tier": 2, "sprite_column": 4, "sprite_top": 47,
		"hp": 950.0, "cost": {"iron_ore": 8, "stone": 6, "coal": 2}, "color": Color("8a9ab0"),
	},
	"obsidian_wall": {"description": "검은 화산석과 날카로운 흑요석 결정으로 세운 성벽.",
		"name": "흑요석 성벽", "category": "wall", "tier": 3, "sprite_column": 5, "sprite_top": 40,
		"hp": 1700.0, "cost": {"obsidian": 8, "iron_ore": 4, "coal": 4}, "color": Color("3a2a50"),
	},
	"essence_wall": {"description": "보스의 정수를 담은 황금 룬이 방벽을 스스로 복구합니다.",
		"name": "정수 방벽", "category": "wall", "tier": 3, "sprite_column": 6, "sprite_top": 35,
		"hp": 2600.0, "cost": {"obsidian": 6, "boss_essence": 1}, "color": Color("e0c050"), "regen": 4.0,
	},
	# --- 공성탑: 왕국을 지키는 탑 ---
	"arrow_tower": {"description": "성벽 위 사수대가 접근하는 적에게 화살을 쏩니다.",
		"name": "화살탑", "category": "siege", "tier": 0, "sprite_column": 7, "sprite_top": 8, "hp": 150.0, "cost": {"wood": 10, "stone": 10}, "color": Color("c9c2b0"),
		"tower": {"range": 224.0, "interval": 0.8, "damage": 9.0, "speed": 520.0},
	},
	"ballista": {"description": "긴 나무 활대가 강력한 관통 볼트를 발사합니다.",
		"name": "발리스타", "category": "siege", "tier": 1, "sprite_column": 8, "sprite_top": 33,
		"hp": 260.0, "cost": {"hardwood": 10, "resin": 4, "copper": 4}, "color": Color("8a6a4a"),
		"tower": {"range": 330.0, "interval": 1.8, "damage": 48.0, "speed": 780.0, "pierce": true, "lifetime": 0.7},
	},
	"cannon_tower": {"description": "중량 포신으로 포탄을 발사해 주변 적에게 폭발 피해를 줍니다.",
		"name": "대포탑", "category": "siege", "tier": 2, "sprite_column": 9, "sprite_top": 28,
		"hp": 420.0, "cost": {"iron_ore": 10, "stone": 12, "coal": 4}, "color": Color("505058"),
		"tower": {"range": 270.0, "interval": 2.2, "damage": 42.0, "speed": 430.0, "splash": 72.0},
	},
	"frost_tower": {"description": "서리 결정의 차가운 탄환으로 적의 이동을 늦춥니다.",
		"name": "서리탑", "category": "siege", "tier": 2, "sprite_column": 10, "sprite_top": 13,
		"hp": 300.0, "cost": {"iron_ore": 6, "ice_crystal": 3, "moss": 4}, "color": Color("9ad0ff"),
		"tower": {"range": 240.0, "interval": 1.0, "damage": 8.0, "speed": 480.0, "slow": [0.45, 2.0]},
	},
	"flame_tower": {"description": "흑요석 화로에서 짧은 사거리의 관통 화염을 연속 발사합니다.",
		"name": "화염탑", "category": "siege", "tier": 3, "sprite_column": 11, "sprite_top": 17,
		"hp": 500.0, "cost": {"obsidian": 8, "fire_core": 3, "coal": 4}, "color": Color("e0603a"),
		"tower": {"range": 150.0, "interval": 0.22, "damage": 12.0, "speed": 420.0, "pierce": true, "lifetime": 0.4},
	},
	"thunder_tower": {"description": "구리 코일과 정수가 세 갈래 번개탄을 만들어 냅니다.",
		"name": "번개탑", "category": "siege", "tier": 3, "sprite_column": 12, "sprite_top": 8,
		"hp": 480.0, "cost": {"obsidian": 6, "copper": 8, "boss_essence": 1}, "color": Color("f0e060"),
		"tower": {"range": 290.0, "interval": 1.1, "damage": 30.0, "speed": 900.0, "shots": 3, "spread": 22.0},
	},
	# --- 생활 ---
	"gear_chest": {"description": "철제 띠를 두른 장비 상자. 죽음에 대비해 예비 장비를 맡기세요.","name": "장비 상자", "category": "utility", "tier": 0, "sprite_column": 13, "sprite_top": 55, "hp": 100.0, "cost": {"wood": 15}, "color": Color("a0703a"), "storage": 12},
	"workbench": {"description": "목공 작업대에서 시작해 금속 작업장과 마법 공방으로 성장합니다.",
		"name": "제작대", "category": "utility", "tier": 0, "sprite_column": 14, "sprite_top": 43, "sprite_tops": [43, 32, 32, 19], "hp": 150.0, "cost": {"wood": 20, "stone": 5}, "color": Color("7a5a3a"),
		"workbench": true, "unique": true,
	},
	"teleport_tower": {"description": "빛나는 마법 고리로 연결된 다른 순간이동 탑을 오갑니다.",
		"name": "순간이동 탑", "category": "utility", "tier": 1, "sprite_column": 18, "sprite_top": 16,
		"hp": 200.0, "cost": {"stone": 12, "copper": 4}, "color": Color("a070ff"), "teleport": true, "outside": true, "light": 90.0,
	},
	"campfire": {"description": "돌로 둘러싼 따뜻한 불가에서 몸을 회복하고 밤을 밝힙니다.",
		"name": "모닥불", "category": "utility", "tier": 0, "sprite_column": 19, "sprite_top": 45,
		"hp": 80.0, "cost": {"wood": 8, "stone": 2}, "color": Color("ff9040"), "heal_aura": [3.0, 3.0], "outside": true, "light": 150.0,
	},
	"supply_depot": {"description": "녹색 차양 아래 보급품을 모아 왕국 창고로 전달합니다.",
		"name": "보급소", "category": "utility", "tier": 1, "sprite_column": 20, "sprite_top": 40,
		"hp": 220.0, "cost": {"wood": 20, "hardwood": 6, "resin": 2}, "color": Color("7aa060"), "depot": true, "outside": true,
	},
	"watchtower": {"description": "높은 관측대에서 주변 지도를 밝히고 밤길을 비춥니다.",
		"name": "감시탑", "category": "utility", "tier": 0, "sprite_column": 21, "sprite_top": 4,
		"hp": 180.0, "cost": {"wood": 12, "stone": 6}, "color": Color("b0a080"), "reveal": 18, "outside": true, "light": 110.0,
	},
}


static func max_defense_tier() -> int:
	return DEFENSE_UPGRADES.size()


## 그 분류(탭)의 건물 id (ORDER 순서)
static func in_category(category: String) -> Array[String]:
	var ids: Array[String] = []
	for id: String in ORDER:
		if TYPES[id]["category"] == category:
			ids.append(id)
	return ids


## 플레이어가 뚫고 지나가는 건물: 벽 탭의 벽을 뺀 전부(문·공성탑·생활 건물, D-036). 적은 그대로 막혀서 부수려 한다
static func player_passable(id: String) -> bool:
	var info: Dictionary = TYPES[id]
	return info["category"] != "wall" or info.get("door", false)


## 알뜰한 건축 패시브(D-020)로 깎인 비용. 자원마다 반올림하고 최소 1개는 낸다
static func discounted(cost: Dictionary, discount: float) -> Dictionary:
	if discount <= 0.0:
		return cost
	var result := {}
	for kind: String in cost:
		result[kind] = maxi(1, roundi(cost[kind] * (1.0 - discount)))
	return result
