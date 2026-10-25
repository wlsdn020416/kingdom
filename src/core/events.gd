extends Node
## 시스템끼리 서로 직접 참조하지 않고 주고받는 신호 모음 (오토로드: Events).

@warning_ignore_start("unused_signal")

## 화면 위쪽 알림
signal message(text: String)
## 채집·상자·처치 보상. 플레이어 개인 인벤토리에 들어간다(D-014). 예: {"wood": 3}
signal resources_gained(amounts: Dictionary, at: Vector2)
signal chest_opened(at: Vector2)
## 플레이어가 나무·바위·광석을 부숨 (경험치·풍요로운 손 패시브). object_id는 WorldData.Obj 값
signal object_harvested(object_id: int, cell: Vector2i)
## 제작대에서 장비를 만듦 (경험치)
signal item_crafted(recipe_id: String)
## 탐험·채집·건설로 지도 색이 바뀐 칸들 (Array of Vector2i)
signal map_cells_changed(cells: Array)
signal enemy_killed(enemy: Node)
signal player_died
signal core_destroyed
signal day_started(day: int)
signal night_started(day: int)
