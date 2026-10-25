# 아키텍처

현재 코드(1인용 프로토타입) 기준의 구조와 의존성 경계. 목표 구조와 다른 부분은 "현재 위반"과 "목표"로 구분해서 적는다.

## 1. 실행 흐름

```
project.godot ─ 오토로드 Events(신호), Session(시드·씬 전환·입력 등록, 자식 SteamService = Steam 연결, NetSession = 멀티플레이 접속·명단)
      │
      └─ run/main_scene = scenes/title.tscn ── 싱글·멀티 팝업에서 시드 입력 ── Session.start_game()
                                                            │
                                   scenes/main.tscn  ◀──────┘   (한 판)
                                                            │
                         왕국 멸망 → 일시정지 → 멸망 화면 → Session.back_to_title()
                         (main.tscn을 통째로 버려서 진행 상황 완전 초기화)
```

시작 화면은 로고와 싱글플레이·멀티플레이 버튼만 보인다. 싱글플레이 팝업은 시드·지난 판 결과·조작법(`title.gd`의 `CONTROLS`), 멀티플레이 팝업은 방 만들기·참가(`LobbyPanel`)·Steam 상태·시드를 받고 호스트만 시작할 수 있다. 방에 들어오면(초대 수락 포함) 멀티플레이 팝업이 자동으로 열린다.

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
├─ SoundEffects (코드로 추가)            효과음 재생·거리 감쇠·동시 재생 제한
├─ BuildMode                           건설 모드 입력·미리보기
├─ DayNight (Node)                     낮/밤 시간
├─ WaveSpawner (Node)                  낮 배회 적, 밤 침공 웨이브
└─ Hud (CanvasLayer)                   UI 전체 (패널은 코드로 생성)
```

`Main._ready()`가 코드로 붙이는 동기화 노드(이름이 모두에게 같아야 RPC가 닿는다, D-017): `PlayerSync`(플레이어), `CombatSync`(적·시간·핵·효과음), `WorldSync`(나무·바위·상자), `KingdomSync`(창고·건물·장비 상자·제작대·수리·입고. 입력·UI는 Kingdom 명령 메서드 대신 이 노드의 같은 이름 메서드를 부른다), `MapSync`(탐험 칸·핑, D-018. 전략회의 창은 이 노드의 `add_ping`·`clear_pings`를 부른다), `MeetingSync`(전략회의 열기·준비·전원 재개, D-019. T 키와 회의 창의 준비 완료가 이걸 거친다). 혼자 플레이에서는 아무것도 보내지 않고 Kingdom을 바로 부른다.

`[이름]`은 노드 그룹. 코드에서 추가되는 그룹: `enemies`(Enemy, 호스트에만), `lights`(Fx.add_light), `player`(RemotePlayer도 들어간다. 그래서 `player` 그룹을 `Player` 타입으로 가정하면 안 된다, D-017).
`Enemy`, `Building`, `Projectile`, UI 패널은 `.tscn` 없이 코드로 생성한다. 플레이어 몸은 `Player`가 코드로 붙이는 `Sprite2D`(`assets/characters/player.png`, D-012)가, 무기·공격 궤적은 그 뒤에 붙인 `WeaponVisual`이 그린다. Player의 `_draw()`는 보호막 표시만 맡는다. 투사체도 픽셀 시트를 사용하며 나머지 UI는 기존 코드로 그린다.

건설물은 `assets/kingdom/buildings.aseprite`에서 내보낸 `buildings.png`(256×64)를 쓴다. 한 칸 32×64이며 나무벽·돌벽·화살탑·장비 상자·제작대 0~3단계 순서의 8칸이다. `BuildingDB.sprite_column`은 기본 칸, `sprite_top`은 체력바·메뉴 아이콘용 최상단이다. `Building.sprite_region()`이 제작대 단계에 맞는 칸을 선택하며 `draw_art()`를 실제 건물과 `BuildMode`가 공유한다. 그림 위치 `(-16, -48)`로 바닥을 기존 32×32 충돌 칸에 맞춘다. B 메뉴는 같은 원본에서 위쪽 투명 여백만 자른 아이콘을, 설치 미리보기는 반투명 그림과 기존 가능·불가 테두리를 쓴다. 건설·철거·보관·제작·화살탑 판정은 기존 소유 시스템이 유지한다.

적은 `assets/enemies/enemies.aseprite`(64×64, 32프레임, 종류별 태그·레이어)에서 내보낸 `enemies.png`(256×512)를 쓴다. 4열은 움직임 프레임, 8행은 슬라임·고블린·거인·늑대·전갈·늪 슬라임·화염 정령·보스다. `EnemyDB`의 `sprite_row`가 행, `sprite_top`이 전체 프레임의 최상단 y좌표다. `Enemy._draw()`는 원래 크기로 `(-32, -40)`에 그리고 x 이동 방향으로 좌우 반전한다. 8fps로 걷고 정지 시 0번 칸으로 돌아간다(슬라임·늪 슬라임·불꽃·보스는 정지 중에도 움직임 유지). 체력바는 반전하지 않으며 뿔·불꽃을 포함한 그림 위에 둔다. 피격 시 기존 0.08초 동안 그림을 밝게 하며 AI·원형 충돌·공격·보상은 기존 시스템이 맡는다.

무기 5종과 폭탄은 `assets/combat/weapons.aseprite`·PNG(512×384)를 쓴다. 64×64의 가로 8칸(대기 1 + 공격·회복 7), 세로 6행(낡은 검·흑요석 검·낡은 활·산탄 석궁·화염 지팡이·폭탄 주머니)이다. `WeaponArtDB`가 행·피벗·연출 시간·반동을 정의한다. `WeaponVisual`은 Player와 RemotePlayer가 공유하며 무기와 장갑을 몸 뒤에 그리고 몸에 짧은 이동·기울기 반동을 준다. 공격 시 장비·방향을 저장하며 무기 교체 시 이전 모션을 끝낸다. 두 검의 0.12초 궤적은 첫 프레임부터 기존 사거리·부채꼴을 표시한다. 휩쓸기 패시브로 넓어진 각도는 칼끝 사거리를 유지하며 궤적 양 끝을 확장해 표현하고, 원격 플레이어는 전달받은 패시브 단계로 같은 그림을 그린다. 활은 시위 복귀·재장전, 석궁은 반동·발사 섬광, 지팡이는 시전, 폭탄은 투척·작은 주머니 회복 자세를 쓴다. 기존 낡은 검 단독 PNG·Aseprite와 4프레임 궤적은 최초 원본으로 보존한다.

`projectiles.aseprite`·PNG(128×192)는 32×32의 4프레임×6행(화살·볼트·작은 화염탄·화염구·폭탄·적 마법탄)이다. Projectile의 `art_id`는 그림만 고른다. 폭탄의 높이·회전은 그리기 변환뿐이며 기존 지면 경로·수명·범위를 유지한다. `attack_effects.aseprite`·PNG(768×640)는 128×128의 6프레임×5행(강철 검 궤적·흑요석 검 궤적·명중·폭발·화염 명중)이다. `CombatEffect`는 명중·폭발을 재생 후 제거하며 피해를 계산하지 않는다. Main이 `Events.combat_effect_requested`를 받아 생성하고 CombatSync가 호스트 확정 결과를 참가자에게 전달한다. 폭발 그림 크기는 실제 폭발 반경을 따른다.

PlayerSync는 장착 무기를 기존 위치 상태에 싣고 `Player.attack_visual_requested`로 시작한 모션을 다른 화면에도 보낸다. CombatSync는 플레이어의 실제 아군 탄을 쏜 사람 외의 참가자에게 `visual_only` 복제본으로 보여준다. 복제본은 월드·적 체력·보상을 바꾸지 않고, 명중·폭발 그림은 호스트 결과로 한 번 전달한다. 로컬 공격·피해·공격 속도·채집은 기존 Player·Melee·Projectile 명령 경로를 유지한다.

왕국 핵 `Core`는 `_draw()`에서 `assets/kingdom/castle.png`를 원래 크기(96×128)로 그린다. 원본은 같은 폴더의 `castle.aseprite`이며 기단·중앙 성채·성문과 전면 성벽·양쪽 첨탑·깃발과 횃불 레이어로 나뉜다. 그리기 위치 `(-48, -84)`는 기단을 기존 96×96 충돌 영역 안에 맞추고 탑을 위로 올린다. 충돌·체력·조명·멸망 처리는 기존 `Core`가 맡는다.

바닥은 `assets/world/terrain.aseprite`에서 내보낸 `terrain.png`(288×128)를 사용한다. 한 칸 32×32이며 열은 `WorldData.Terrain` 순서(9종), 행은 질감 변형 4종이다. `TilesetBuilder`가 모든 칸과 물 충돌을 등록하고 `World.setup()`은 좌표 해시로 변형을 고른다. 게임용 난수를 소비하지 않으며 월드 데이터는 바꾸지 않는다. 지도 색은 `Palette.TERRAIN`이 맡는다. 서로 다른 지형 사이의 경계는 현재 타일 칸 단위다.

생성물은 `assets/world/objects.aseprite`에서 내보낸 `objects.png`(288×48)를 쓴다. 한 칸 32×48, `WorldData.Obj` 순서의 가로 9칸이며 NONE 칸은 투명하고 나머지 8종은 종류별 레이어로 분리한다. `TilesetBuilder`가 `texture_origin = (0, -8)`로 그림 바닥을 32×32 지형 칸에 맞춘다. 채집·상자 칸의 28×28 충돌과 `World.damage_object()`·`open_chest()` 처리는 그대로 사용한다.

기본 효과음은 `assets/audio/sfx/`에 보관한다(43종·168개 변형). `movement/`, `combat/`, `skills/`, `world/`, `kingdom/`, `ui/`, `alerts/`는 게임용 44.1kHz·16bit·모노 WAV이고, `sources/`는 ElevenLabs MP3 원본이다. 원본 폴더의 `.gdignore`로 중복 임포트를 막는다. `manifest.json`에 생성 정보·편집 내역·해시를, `index.html`에 로컬 미리듣기를 둔다. 긴 생성물은 첫 소리를 발췌했다. 게임에 연결했으며 실제 청음·체감 음량 확인은 남아 있다.

`data/sounds.gd`(`SoundDB`)가 파일·종류별 음량·재생 간격·이동 거리 기준을 정의한다. `Main`은 `src/core/sound_effects.gd`(`SoundEffects`)에 플레이어 청취 위치와 카탈로그를 주입한다. 재생기는 게임 규칙·월드·네트워크를 참조하지 않고, 800px 밖의 위치음을 제외하고 거리 감쇠·좌우 배치를 적용한다. 월드 20개·UI 8개 음원 노드를 재사용하고 같은 종류의 연속 재생을 제한한다. 변형은 순환 선택해 `Main.rng`를 소비하지 않는다. 시작 화면도 별도 재생기를 소유하며 씬 교체 시 버린다. 새 오토로드·그룹·오디오 버스는 없다.

내 캐릭터의 성공한 공격·대시·스킬·피격은 `Player.sound_requested`로 즉시 재생한다. 발소리는 Main이 로컬·원격 플레이어의 실제 이동 거리와 지형을 읽어 만들며 정지·대시·순간이동은 제외한다(늪은 물, 왕국·화산은 돌, 나머지는 풀밭 소리). 채집·상자·적 피해/사망·건설·수리·제작·건물 피해/파괴·폭발은 상태 소유자가 성공한 지점에서 `Events.world_sound_requested`를 낸다. 동기화 상태 적용에서는 다시 내지 않는다. `CombatSync`는 호스트 결과음을 공유하고, 참가자 캐릭터 소리는 허용 목록·요청 간격·호스트가 아는 그 사람 위치를 거쳐 다른 사람에게 전달한다. 요청한 사람에게는 되돌려 보내지 않는다. 음원 RPC는 연출만 다루며 게임 상태를 바꾸지 않는다.

UI·보상 알림은 `Events.ui_sound_requested`로 이 화면에서만 재생한다. UiKit 버튼·장비창 탭/장착·패시브 학습·지도 핑과 명령 오류를 연결했다. Main은 패널 표시 변화와 낮/밤 신호를 구독한다. UI·알림 재생기는 일시정지 중에도 돌고 위치음은 멈춘다. 멸망음은 `show_game_over()`에서 거리와 무관하게 재생해 호스트·참가자 모두 일시정지 이후까지 듣는다.

## 3. 계층과 허용되는 의존 방향

I 창 `EquipmentPanel`은 `Hud.setup()`에서 `Equipment`와 `Inventory`를 주입받는다. 처음 열 때만 UI를 구성하고, 왼쪽 마네킹의 6부위 슬롯과 오른쪽 장비·재료 탭을 보여준다. 장착·해제는 기존 Equipment 명령을 호출한다. 장비는 6열의 스크롤 격자이며 최소 24칸을 보여주되 실제 용량 제한을 추가하지 않는다. 재료는 기존 Inventory의 50개 스택·실제 칸 수를 그대로 표시한다. Inventory에는 변경 신호가 없으므로 열린 동안 0.2초마다 수량·용량을 비교해 갱신하고, 닫히면 처리와 툴팁을 중지한다.

그래픽은 `assets/ui/equipment_ui.aseprite`·PNG(384×160)의 마네킹·슬롯 4상태와 `material_icons.aseprite`·PNG(24×24 12칸)를 쓴다. 무기 5종·폭탄 주머니는 같은 무기 시트의 대기 자세를 아이콘으로 재사용하고, 나머지 장비는 이름을 표시한다. 장비 호버는 설명과 장착될 부위를 강조하고, 재료 호버는 스택 수량·총량을 보여준다. 툴팁은 마우스를 따라가며 화면 안에 제한하고 I·Esc·닫기로 함께 숨긴다. 패널은 UiKit의 다른 창을 바꾸지 않고 이 창 안에서만 스타일을 지정한다.

HUD 왼쪽 위는 낮·밤 시계와 성·내 체력 두 줄을 상시 표시한다. `Hud.ClockFace`는 DayNight의 진행을 읽어 낮(위쪽 금색)·밤(아래쪽 파랑) 반원 위로 바늘을 회전시키고 남은 초는 툴팁으로 표시한다. 재화 버튼은 기본 접힘이며 아래로 펼치면 내 가방·공용 창고의 12종 재료 아이콘과 수량을 보여준다. 펼친 동안만 수량을 갱신하며 0개는 흐리게 표시한다. 기존 재료 아틀라스를 재사용하고 게임 상태는 바꾸지 않는다. `Main`은 HUD 상태 패널 위 포인터를 확인해 클릭이 기본 공격으로 이어지지 않게 한다.

하단 `ActionBar`는 `assets/ui/skill_ui.aseprite`에서 내보낸 224×72 PNG를 사용한다. 위쪽은 32×32 아이콘 7칸(대시·산탄·화염구·폭탄·보호막·치유·함성), 아래쪽은 40×40 슬롯 4칸(준비·쿨타임·미장착·키 누름)이다. 64×64 슬롯(하단 바 370×92)에 최근접 보간으로 그리며 대시와 장비 스킬 1~4 사이를 구분한다. 쿨타임은 아이콘의 어두운 덮개·남은 초·하단 회복 막대로, 빈칸은 미장착 문구로 표시한다. 호버 설명은 실제 장착 장비를 읽고 등록은 기존 Equipment.skill_bar()의 자동 정렬을 따른다. HUD는 하단 바 위에서도 기본 공격을 차단한다. 건설 모드에서는 기존 설치 비용·조작 안내로 바뀐다.

체력바 공용 그리기는 `src/core/health_bar_art.gd`(`HealthBarArt`)가 맡는다. `assets/ui/health_bars.aseprite`에서 내보낸 32×20 PNG의 금속 테두리(32×8)와 빨강·금색·녹색 채움(각 26×4)을 사용한다. 월드 그리기는 양 끝 장식을 유지하며 폭을 늘리고, HUD는 같은 PNG의 `StyleBoxTexture`를 사용한다. 이 클래스는 전달받은 비율만 그리며 체력·표시 시간은 소유하지 않는다. 월드·적·건물에서 UI 계층을 참조하지 않도록 기반 계층에 둔다.

채집물은 기존 `_hp_overlay`가 타일맵 위에 바를 그린다. 마지막 피해 후 4초, 파괴 시 제거라는 표시 규칙을 유지한다. 나무·단단한 나무는 중심에서 y=-40, 다른 채집물은 y=-24에 표시해 그림을 가리지 않는다. 적·건물의 손상 시 표시 조건과 HUD의 플레이어·왕국 수치는 기존 시스템이 맡는다.

위에서 아래로만 의존한다. 같은 층끼리는 필요할 때만, 순환 없이.

| 층 | 폴더 | 의존해도 되는 것 |
| --- | --- | --- |
| 조립 | `scenes/main.gd`, `scenes/title.gd` | 모든 것 |
| UI | `src/ui/` | 아래 전부 (읽기 + 명령 메서드 호출). **아무도 UI에 의존하지 않는다** (조립 지점 제외) |
| 네트워크 | `src/multiplayer/` (`SteamService`, `NetSession`, 게임 씬의 `PlayerSync`·`RemotePlayer`·`CombatSync`·`EnemyPuppet`·`WorldSync`·`KingdomSync`·`MapSync`·`MeetingSync`, D-017~D-019) | 아래 전부. **게임 시스템은 네트워크에 의존하지 않는다** |
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
| `resources_gained` | Main(채집·상자·처치 보상을 내 캐릭터에 줄 때) | Main(플레이어 `Inventory`에 추가, 떠오르는 글자). 창고 입고는 `Kingdom.deposit()` (D-014) |
| `object_harvested` | World(플레이어가 오브젝트를 부숨, 굴린 재료·부순 사람 peer id) | Main(부순 사람에게 재료·경험치·풍요로운 손. 참가자면 WorldSync로 보냄) (D-015, D-017) |
| `item_crafted` | Kingdom(`craft()`, 만든 사람 peer id) | Main(만든 사람에게 경험치) (D-015) |
| `enemy_shot` | Projectile(적 탄 생성) | CombatSync(호스트: 참가자 화면에 같은 탄) (D-017) |
| `chest_opened` | World(연 사람 peer id) | Main(호스트가 보상 추첨, 연 사람에게) |
| `map_cells_changed` | World, Kingdom | MapState |
| `enemy_killed` | Enemy | Main(처치 수·금 보상) |
| `core_destroyed` | Core | Main(멸망 처리) |
| `day_started` / `night_started` | DayNight | WaveSpawner |
| `message` | Main, Player, WaveSpawner, BuildMode | Hud(알림) |
| `world_sound_requested(id, at)` | World, Enemy, Kingdom, Building, Core, Projectile, WaveSpawner | SoundEffects(현재 화면), CombatSync(호스트: 다른 화면에 전달) |
| `ui_sound_requested(id)` | UI, Player(사용 불가), Main(획득·입고), KingdomSync(명령 오류) | 현재 씬의 SoundEffects |
| `combat_effect_requested(id, at, size, angle)` | Melee, Projectile(확정한 명중·폭발) | Main(CombatEffect 생성), CombatSync(호스트: 참가자에게 연출 전달) |
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
| 개인 가방·장비 가방·경험치를 각자 소유 | `Player.inventory`·`equipment`·`progression`, `KingdomSync`의 요청 | 호스트가 정하는 것(월드·왕국·보상 추첨)과 달리 참가자 화면에 있다. 참가자는 요청에 가방 내용을 실어 보내고 호스트는 그 값을 믿는다(임시, D-017). 패시브 단계는 각자 정하고 `PlayerSync`로 알린다. 호스트는 받은 단계(`RemotePlayer.ranks`)를 믿고 약탈자·보물 사냥꾼·건설 패시브에 쓴다(D-020) |

## 6. 멀티플레이 구조 (목표, 미구현)

- Godot 고수준 멀티플레이(`ENetMultiplayerPeer`), 호스트 = 피어 1 = 권한자. 전용 서버 여부는 기획 미정.
- 모든 참가자는 같은 시드로 `WorldGenerator.generate()`를 실행해 같은 기본 월드를 만들고, 이후 **변경분**(오브젝트 제거, 건물, 탐험 칸)만 호스트가 전파한다.
- 클라이언트 → 호스트: 입력과 요청(이동 방향·조준, 공격, 스킬 사용, 건설 요청). 호스트가 소유 시스템의 명령 메서드로 검증·적용.
- 호스트 → 클라이언트: 결과 상태(위치, 체력, 자원, 건물, 낮/밤 시간, 웨이브 적).
- 네트워크 코드는 `src/multiplayer/`와 각 기능의 얇은 동기화 노드에만 두고, 1인 플레이는 "로컬 호스트 1명"으로 같은 경로를 탄다.
- 구체적인 방식(동기화 노드 사용 여부, 보간, 재접속)은 구현 시작 때 `docs/DECISIONS.md`에 기록한다.

## 7. 알아둘 점

- 패시브 트리(D-020)의 노드 그래픽은 `PassiveDB`의 `branch`·`lane`·`pos`(갈래 격자의 열, 행)·`requires`(연결선)만 보고 그린다. 배우기는 `Progression.learn()`(선행 검사 포함)만 부른다. 지금 `PassivePanel`은 이 값으로 버튼을 격자에 놓기만 한 기능용 화면이다. 효과 값은 `Progression.value(id)`(내 것), `PassiveDB.value_in(ranks, id)`(다른 사람 것), 건설 효과는 `PassiveDB.build_perks()` 한 곳에서 읽는다.
- 노드가 트리에 붙기 전에 `set_physics_process(false)`를 불러도, `_physics_process`를 정의한 노드는 `_ready` 때 Godot이 다시 켠다. 켜고 끌 조건은 `_ready()`에서 정한다 (`WorldSync`, `KingdomSync`).
- 투사체는 `Area2D` 겹침 신호 대신 매 물리 프레임 `intersect_shape`로 직접 충돌을 조회한다. `Area2D` 신호로는 타일·벽·핵 같은 정적 바디가 감지되지 않았기 때문이다.
- 타일 충돌은 여러 칸이 한 바디로 묶여 있어서, 맞은 칸은 `World.object_cell_near()`로 위치를 보고 찾는다.
- 월드는 192×192칸 단일 배열(`WorldData`)이다. 이 크기에서는 청크 로딩이 필요 없어서 없다(D-006).
- 충돌 레이어: 1 water, 2 objects, 3 buildings, 4 player, 5 enemies (`PhysicsLayers` = `project.godot [layer_names]`).
- 입력은 `InputBindings.register()`가 `Session._ready()`에서 런타임에 등록한다. 그래서 `--script`로 실행한 테스트에는 입력 액션이 없다.
