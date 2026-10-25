class_name Palette
extends RefCounted
## 미니맵과 채집 효과에 쓰는 색. 실제 바닥 그림은 assets/world/terrain.png가 맡는다.

## WorldData.Terrain 순서
const TERRAIN := [
	Color("1f3d5e"), Color("c8b479"), Color("4e7a39"), Color("2f5a2b"),
	Color("b8945a"), Color("d6dce0"), Color("6b5f4c"), Color("3e4a2e"), Color("3a2a26"),
]
const OBJECTS := {
	WorldData.Obj.TREE: Color("1d3d1a"),
	WorldData.Obj.ROCK: Color("7d7f82"),
	WorldData.Obj.CHEST: Color("f0d070"),
	WorldData.Obj.HARDWOOD_TREE: Color("4a2f1f"),
	WorldData.Obj.COPPER_ORE: Color("c87a3e"),
	WorldData.Obj.IRON_ORE: Color("8fa3b5"),
	WorldData.Obj.MOSS: Color("7fa04a"),
	WorldData.Obj.OBSIDIAN: Color("2b2240"),
}
const CORE := Color("e3b341")
const PING := Color("5bd0ff")
const ENEMY_MARK := Color("ff5040")
const TERRITORY := Color(0.89, 0.7, 0.25, 0.35)
