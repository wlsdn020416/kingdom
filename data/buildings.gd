class_name BuildingDB
extends RefCounted
## 건설 가능한 건물. ORDER 순서대로 건설 메뉴(B)에 나온다.
## sprite_column은 그림 칸, sprite_top은 체력바·메뉴 아이콘용 최상단 y좌표다.
## "storage": 장비 상자 칸 수. 죽으면 장비 가방이 사라지므로 예비 장비는 여기에 맡긴다 (D-014).
## "workbench": 제작대(RecipeDB). "unique": 왕국에 하나만 지을 수 있다.

const ORDER := ["wood_wall", "stone_wall", "arrow_tower", "gear_chest", "workbench"]
const REFUND_RATE := 0.5

const TYPES := {
	"wood_wall": {"name": "나무벽", "sprite_column": 0, "sprite_top": 27, "hp": 120.0, "cost": {"wood": 5}, "color": Color("8a5a2b")},
	"stone_wall": {"name": "돌벽", "sprite_column": 1, "sprite_top": 28, "hp": 300.0, "cost": {"stone": 8}, "color": Color("9a9ca0")},
	"arrow_tower": {
		"name": "화살탑", "sprite_column": 2, "sprite_top": 4, "hp": 150.0, "cost": {"wood": 10, "stone": 10}, "color": Color("c9c2b0"),
		"tower": {"range": 224.0, "interval": 0.8, "damage": 9.0, "speed": 520.0},
	},
	"gear_chest": {"name": "장비 상자", "sprite_column": 3, "sprite_top": 36, "hp": 100.0, "cost": {"wood": 15}, "color": Color("a0703a"), "storage": 12},
	"workbench": {
		"name": "제작대", "sprite_column": 4, "sprite_top": 22, "hp": 150.0, "cost": {"wood": 20, "stone": 5}, "color": Color("7a5a3a"),
		"workbench": true, "unique": true,
	},
}


## 알뜰한 건축 패시브(D-020)로 깎인 비용. 자원마다 반올림하고 최소 1개는 낸다
static func discounted(cost: Dictionary, discount: float) -> Dictionary:
	if discount <= 0.0:
		return cost
	var result := {}
	for kind: String in cost:
		result[kind] = maxi(1, roundi(cost[kind] * (1.0 - discount)))
	return result
