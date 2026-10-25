class_name Palette
extends RefCounted
## 픽셀아트가 들어오기 전까지 쓰는 임시 색. 지도 색으로도 쓴다.

## WorldData.Terrain 순서
const TERRAIN := [
	Color("1f3d5e"), Color("c8b479"), Color("4e7a39"), Color("2f5a2b"),
	Color("b8945a"), Color("d6dce0"), Color("6b5f4c"),
]
const TERRAIN_SPECK := [
	Color("28496d"), Color("b39f66"), Color("43692f"), Color("264b23"),
	Color("a5824b"), Color("c3cacf"), Color("5d5241"),
]
const OBJECTS := {
	WorldData.Obj.TREE: Color("1d3d1a"),
	WorldData.Obj.ROCK: Color("7d7f82"),
	WorldData.Obj.GOLD_ORE: Color("d9b23c"),
	WorldData.Obj.CHEST: Color("f0d070"),
}
const CORE := Color("e3b341")
const PING := Color("5bd0ff")
const ENEMY_MARK := Color("ff5040")
const TERRITORY := Color(0.89, 0.7, 0.25, 0.35)
