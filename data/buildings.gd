class_name BuildingDB
extends RefCounted
## 건설 가능한 건물. ORDER 순서대로 건설 모드의 1, 2, 3번 키에 배치된다.

const ORDER := ["wood_wall", "stone_wall", "arrow_tower"]
const REFUND_RATE := 0.5

const TYPES := {
	"wood_wall": {"name": "나무벽", "hp": 120.0, "cost": {"wood": 5}, "color": Color("8a5a2b")},
	"stone_wall": {"name": "돌벽", "hp": 300.0, "cost": {"stone": 8}, "color": Color("9a9ca0")},
	"arrow_tower": {
		"name": "화살탑", "hp": 150.0, "cost": {"wood": 10, "stone": 10}, "color": Color("c9c2b0"),
		"tower": {"range": 224.0, "interval": 0.8, "damage": 9.0, "speed": 520.0},
	},
}
