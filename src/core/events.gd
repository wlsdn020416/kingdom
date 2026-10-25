extends Node
## 시스템끼리 서로 직접 참조하지 않고 주고받는 신호 모음 (오토로드: Events).

@warning_ignore_start("unused_signal")

## 화면 위쪽 알림
signal message(text: String)
## 성공한 월드 행동의 연출음. 호스트가 참가자에게 공유하며 무한 좌표는 거리와 무관한 알림이다.
signal world_sound_requested(id: String, at: Vector2)
## 이 화면에서만 들을 UI·보상 알림음. 일시정지 중에도 재생한다.
signal ui_sound_requested(id: String)
## 호스트가 확정한 명중·폭발의 픽셀 효과. 크기·방향은 연출만 바꾸며 피해 판정과 무관하다.
signal combat_effect_requested(id: String, at: Vector2, size: float, angle: float)
## 적이 피해를 받음 (피해 숫자, D-023). emphasis = 마무리 일격·처형자·선제공격처럼 패시브로 강해진 공격. 호스트가 참가자에게 공유한다
signal damage_dealt(at: Vector2, amount: float, emphasis: bool)
## 화면 흔들림 (폭발·보스). 각자 화면에서 내 캐릭터와의 거리만큼 약해진다. at이 무한 좌표면 거리와 무관. 호스트가 참가자에게 공유한다
signal screen_shake_requested(at: Vector2, strength: float)
## 채집·상자·처치 보상. 플레이어 개인 인벤토리에 들어간다(D-014). 예: {"wood": 3}
signal resources_gained(amounts: Dictionary, at: Vector2)
## 보물 상자가 열림. opener = 연 플레이어의 peer id (혼자 플레이면 1). 보상은 Main이 그 사람에게 준다
signal chest_opened(at: Vector2, opener: int)
## 플레이어가 나무·바위·광석을 부숨. drops = 굴린 재료(예: {"wood": 3}), harvester = 부순 플레이어의 peer id.
## Main이 그 사람에게 재료·경험치·풍요로운 손 보너스를 준다. object_id는 WorldData.Obj 값
signal object_harvested(object_id: int, cell: Vector2i, drops: Dictionary, harvester: int)
## 제작대에서 장비를 만듦 (경험치). crafter = 만든 플레이어의 peer id (혼자 플레이면 1)
signal item_crafted(recipe_id: String, crafter: int)
## 적이 탄을 쏨 (보스 방사탄). 멀티플레이에서 참가자 화면에도 같은 탄을 만든다 (D-017)
signal enemy_shot(at: Vector2, params: Dictionary)
## 탐험·채집·건설로 지도 색이 바뀐 칸들 (Array of Vector2i)
signal map_cells_changed(cells: Array)
signal enemy_killed(enemy: Node)
signal player_died
signal core_destroyed
signal day_started(day: int)
signal night_started(day: int)
