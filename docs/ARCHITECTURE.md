# 아키텍처

현재 코드(1인용 프로토타입) 기준의 구조와 의존성 경계. 목표 구조와 다른 부분은 "현재 위반"과 "목표"로 구분해서 적는다.

## 1. 실행 흐름

```
project.godot ─ 오토로드 Events(신호), Session(시드·씬 전환·입력 등록, 자식 SteamService = Steam 연결)
      │
      └─ run/main_scene = scenes/title.tscn ── 시드 입력 ── Session.start_game()
                                                            │
                                   scenes/main.tscn  ◀──────┘   (한 판)
                                                            │
                         왕국 멸망 → 일시정지 → 멸망 화면 → Session.back_to_title()
                         (main.tscn을 통째로 버려서 진행 상황 완전 초기화)
```

`godot --path . -- --seed=abc`로 실행하면 시작 화면을 건너뛴다.

## 2. 한 판의 씬 구성 (`scenes/main.tscn`)

```
Main (Node2D, scenes/main.gd)          조립 지점: 모든 시스템의 setup() 호출, 전역 단축키
├─ Darkness (CanvasModulate)           DayNight가 색을 바꿈
├─ World [world]                       src/world/world.gd — Terrain/Objects TileMapLayer
├─ Kingdom                             src/kingdom/kingdom.gd — 자원, 건물
│  └─ Core [core] (StaticBody2D)       src/kingdom/core.gd — 왕국 핵 체력
├─ Enemies (Node2D)                    WaveSpawner가 Enemy를 여기에 추가
├─ Player [player] (CharacterBody2D)   src/characters/player.gd
│  └─ Camera
├─ Projectiles [projectiles]           Projectile.spawn()이 여기에 추가
├─ Effects [fx_layer]                  Fx가 파티클·글자를 여기에 추가
├─ PingMarkers                         전략회의 핑 표시
├─ BuildMode                           건설 모드 입력·미리보기
├─ DayNight (Node)                     낮/밤 시간
├─ WaveSpawner (Node)                  낮 배회 적, 밤 침공 웨이브
└─ Hud (CanvasLayer)                   UI 전체 (패널은 코드로 생성)
```

`[이름]`은 노드 그룹. 코드에서 추가되는 그룹: `enemies`(Enemy), `lights`(Fx.add_light).
`Enemy`, `Building`, `Projectile`, UI 패널은 `.tscn` 없이 코드로 생성한다. `Building`, `Projectile`, UI 패널은 `_draw()` 등으로 임시 도형을 그린다. 플레이어 몸은 `Player`가 코드로 붙이는 `Sprite2D`(`assets/characters/player.png`, D-012)가 그리고 `_draw()`는 무기·공격 궤적·보호막만 그린다.

적은 `assets/enemies/enemies.aseprite`(64×64, 32프레임, 종류별 태그·레이어)에서 내보낸 `enemies.png`(256×512)를 쓴다. 4열은 움직임 프레임, 8행은 슬라임·고블린·거인·늑대·전갈·늪 슬라임·화염 정령·보스다. `EnemyDB`의 `sprite_row`가 행, `sprite_top`이 전체 프레임의 최상단 y좌표다. `Enemy._draw()`는 원래 크기로 `(-32, -40)`에 그리고 x 이동 방향으로 좌우 반전한다. 8fps로 걷고 정지 시 0번 칸으로 돌아간다(슬라임·늪 슬라임·불꽃·보스는 정지 중에도 움직임 유지). 체력바는 반전하지 않으며 뿔·불꽃을 포함한 그림 위에 둔다. 피격 시 기존 0.08초 동안 그림을 밝게 하며 AI·원형 충돌·공격·보상은 기존 시스템이 맡는다.

기본 낡은 검은 `assets/combat/rusty_sword.png`(32×16), 궤적은 `sword_slash.png`(112×112 4칸, 가로 448×112)를 쓴다. 같은 폴더에 각각의 `.aseprite` 원본이 있다. `Player._draw_rusty_sword()`가 기존 0.12초 동안 4프레임을 재생하고 검을 회전시킨다. 판정이 즉시 끝나므로 첫 프레임부터 사거리 52·120도 전체 궤적을 보이며 공격 시 방향을 저장해 조준을 바꾸어도 유지한다. 부모의 그리기를 자식 몸 스프라이트가 덮어 손잡이를 몸 안쪽에 가린다. 다른 무기는 기존 선·호를 사용한다. 피해·채집은 기존 `Melee.swing()`이 맡는다.

왕국 핵 `Core`는 `_draw()`에서 `assets/kingdom/castle.png`를 원래 크기(96×128)로 그린다. 원본은 같은 폴더의 `castle.aseprite`이며 기단·중앙 성채·성문과 전면 성벽·양쪽 첨탑·깃발과 횃불 레이어로 나뉜다. 그리기 위치 `(-48, -84)`는 기단을 기존 96×96 충돌 영역 안에 맞추고 탑을 위로 올린다. 충돌·체력·조명·멸망 처리는 기존 `Core`가 맡는다.

바닥은 `assets/world/terrain.aseprite`에서 내보낸 `terrain.png`(288×128)를 사용한다. 한 칸 32×32이며 열은 `WorldData.Terrain` 순서(9종), 행은 질감 변형 4종이다. `TilesetBuilder`가 모든 칸과 물 충돌을 등록하고 `World.setup()`은 좌표 해시로 변형을 고른다. 게임용 난수를 소비하지 않으며 월드 데이터는 바꾸지 않는다. 지도 색은 `Palette.TERRAIN`이 맡는다. 서로 다른 지형 사이의 경계는 현재 타일 칸 단위다.

생성물은 `assets/world/objects.aseprite`에서 내보낸 `objects.png`(288×48)를 쓴다. 한 칸 32×48, `WorldData.Obj` 순서의 가로 9칸이며 NONE 칸은 투명하고 나머지 8종은 종류별 레이어로 분리한다. `TilesetBuilder`가 `texture_origin = (0, -8)`로 그림 바닥을 32×32 지형 칸에 맞춘다. 채집·상자 칸의 28×28 충돌과 `World.damage_object()`·`open_chest()` 처리는 그대로 사용한다.

## 3. 계층과 허용되는 의존 방향

체력바 공용 그리기는 `src/core/health_bar_art.gd`(`HealthBarArt`)가 맡는다. `assets/ui/health_bars.aseprite`에서 내보낸 32×20 PNG의 금속 테두리(32×8)와 빨강·금색·녹색 채움(각 26×4)을 사용한다. 월드 그리기는 양 끝 장식을 유지하며 폭을 늘리고, HUD는 같은 PNG의 `StyleBoxTexture`를 사용한다. 이 클래스는 전달받은 비율만 그리며 체력·표시 시간은 소유하지 않는다. 월드·적·건물에서 UI 계층을 참조하지 않도록 기반 계층에 둔다.

채집물은 기존 `_hp_overlay`가 타일맵 위에 바를 그린다. 마지막 피해 후 4초, 파괴 시 제거라는 표시 규칙을 유지한다. 나무·단단한 나무는 중심에서 y=-40, 다른 채집물은 y=-24에 표시해 그림을 가리지 않는다. 적·건물의 손상 시 표시 조건과 HUD의 플레이어·왕국 수치는 기존 시스템이 맡는다.

위에서 아래로만 의존한다. 같은 층끼리는 필요할 때만, 순환 없이.

| 층 | 폴더 | 의존해도 되는 것 |
| --- | --- | --- |
| 조립 | `scenes/main.gd`, `scenes/title.gd` | 모든 것 |
| UI | `src/ui/` | 아래 전부 (읽기 + 명령 메서드 호출). **아무도 UI에 의존하지 않는다** (조립 지점 제외) |
| 네트워크 | `src/multiplayer/` (지금은 `SteamService`만) | 아래 전부. **게임 시스템은 네트워크에 의존하지 않는다** |
| 흐름 | `src/gameplay/` | 왕국, 행위자, 월드, 데이터, core |
| 왕국 | `src/kingdom/` | 행위자·전투, 월드, 데이터, core |
| 행위자·전투 | `src/characters/`, `src/enemies/`, `src/combat/` | 월드, 데이터, core |
| 월드 | `src/world/` | 데이터, core |
| 데이터 | `data/` | 원칙적으로 없음 (`EnemyDB`·`Loot` 표가 `WorldData.Terrain` enum만 참조) |
| 기반 | `src/core/` | 엔진만. 게임 규칙 없음 |

시스템 사이의 연결 방식:

- **직접 참조:** `setup(world, kingdom, player, ...)`으로 받은 대상의 메서드 호출. 명령과 조회에 사용.
- **`Events` 신호:** 여러 곳이 반응해야 하는 사건. 현재 발신자 → 수신자:

| 신호 | 보내는 곳 | 받는 곳 |
| --- | --- | --- |
| `resources_gained` | World(채집), Main(상자·처치 보상) | Main(플레이어 `Inventory`에 추가, 떠오르는 글자). 창고 입고는 `Kingdom.deposit()` (D-014) |
| `object_harvested` | World(플레이어가 오브젝트를 부숨) | Main(경험치, 풍요로운 손 추가 재료) (D-015) |
| `item_crafted` | Kingdom(`craft()`) | Main(경험치) (D-015) |
| `chest_opened` | World | Main(보상 추첨) |
| `map_cells_changed` | World, Kingdom | MapState |
| `enemy_killed` | Enemy | Main(처치 수·금 보상) |
| `core_destroyed` | Core | Main(멸망 처리) |
| `day_started` / `night_started` | DayNight | WaveSpawner |
| `message` | Main, Player, WaveSpawner, BuildMode | Hud(알림) |
| `player_died` | Player | 없음 (현재 수신자 없음) |

받는 곳은 `grep -rn "Events\.<신호>" src scenes`로 확인한다.

## 4. 순수 로직과 노드의 분리

| 노드 없음 (테스트 쉬움) | 노드 (생명주기·그리기·물리) |
| --- | --- |
| `WorldData` 월드 상태 배열, `WorldGenerator` 시드 → 월드 | `World` 타일맵 반영, 채집, 탐험 |
| `Equipment` 착용·가방·스킬바·쿨타임, `Inventory` 개인 자원·용량 | `Player` 이동·조준·공격·스킬 입력 |
| `Loot` 상자 보상 추첨, `MapState` 지도 색, `Melee` 근거리 판정(static) | `Kingdom`, `Building`, `Core` |
| `Skills` 스킬 효과(static), `Balance`/`*DB` 데이터 | `Enemy`, `Projectile`, `DayNight`, `WaveSpawner` |

새 규칙은 가능한 한 왼쪽 열에 둔다. 왼쪽 열은 `tests/logic_test.gd`에서 오토로드 없이 검사할 수 있다.
단, `Kingdom`의 자원·건설 규칙은 현재 노드 안에 있다. 멀티플레이 전에 필요해지면 분리를 검토한다(미리 하지 않음).

## 5. 현재 위반 (새로 늘리지 않는다)

| 위반 | 위치 | 비고 |
| --- | --- | --- |
| UI → 조립 지점 순환 | `Hud.setup(main: Main)` | Hud가 Main의 여러 시스템을 꺼내 씀. Hud를 크게 고칠 때 필요한 시스템만 인자로 받게 바꾼다 |
| `Player` ↔ `Skills` | `Skills.cast(skill, player)` | 스킬 효과가 플레이어를 직접 조작 |
| `Enemy` ↔ `Projectile` | 서로 생성·피격 | 보스 탄막, 투사체 피격 |
| `Building` → `Enemy` | 화살탑 조준 | 그룹 조회로 대체 가능 |
| 전역 `randf()`로 결과 결정 | `Loot`, `EnemyDB.pick_invader`, `WaveSpawner`, `World.damage_object`, `Main._on_enemy_killed` | 멀티플레이 시 호스트에서만 실행되게 해야 함 (`AGENTS.md` 5절) |

## 6. 멀티플레이 구조 (목표, 미구현)

- Godot 고수준 멀티플레이(`ENetMultiplayerPeer`), 호스트 = 피어 1 = 권한자. 전용 서버 여부는 기획 미정.
- 모든 참가자는 같은 시드로 `WorldGenerator.generate()`를 실행해 같은 기본 월드를 만들고, 이후 **변경분**(오브젝트 제거, 건물, 탐험 칸)만 호스트가 전파한다.
- 클라이언트 → 호스트: 입력과 요청(이동 방향·조준, 공격, 스킬 사용, 건설 요청). 호스트가 소유 시스템의 명령 메서드로 검증·적용.
- 호스트 → 클라이언트: 결과 상태(위치, 체력, 자원, 건물, 낮/밤 시간, 웨이브 적).
- 네트워크 코드는 `src/multiplayer/`와 각 기능의 얇은 동기화 노드에만 두고, 1인 플레이는 "로컬 호스트 1명"으로 같은 경로를 탄다.
- 구체적인 방식(동기화 노드 사용 여부, 보간, 재접속)은 구현 시작 때 `docs/DECISIONS.md`에 기록한다.

## 7. 알아둘 점

- 투사체는 `Area2D` 겹침 신호 대신 매 물리 프레임 `intersect_shape`로 직접 충돌을 조회한다. `Area2D` 신호로는 타일·벽·핵 같은 정적 바디가 감지되지 않았기 때문이다.
- 타일 충돌은 여러 칸이 한 바디로 묶여 있어서, 맞은 칸은 `World.object_cell_near()`로 위치를 보고 찾는다.
- 월드는 192×192칸 단일 배열(`WorldData`)이다. 이 크기에서는 청크 로딩이 필요 없어서 없다(D-006).
- 충돌 레이어: 1 water, 2 objects, 3 buildings, 4 player, 5 enemies (`PhysicsLayers` = `project.godot [layer_names]`).
- 입력은 `InputBindings.register()`가 `Session._ready()`에서 런타임에 등록한다. 그래서 `--script`로 실행한 테스트에는 입력 액션이 없다.
