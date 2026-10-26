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

`CursorArt`(src/core)는 씬 진입 시 커서 이미지·클릭 기준점을 적용하는 정적 모음이다. Title._ready의 CursorArt.attach는 황동/강철 화살표(32×32, 핫스팟 3,2), Main._ready의 attach는 중앙 조준점(32×32, 핫스팟 16,16)을 기본 화살표 형태에 매핑한다. 따라서 시작 화면 복귀·즉시 시드 시작도 현재 화면의 커서로 바뀐다. UiKit.button은 POINTING_HAND를 써 왕실 장갑 포인터(핫스팟 10,5)를 표시한다. attach는 해당 창의 mouse_entered/focus_entered에서 이미지를 재적용하고 모양을 한 번 왕복해 네이티브 커서를 갱신한다. macOS에서는 같은 모양·이미지 캐시가 갱신을 생략해 기본 화살표가 남을 수 있기 때문이다(Godot #121474). owner.tree_exiting에서 두 연결과 네이티브 텍스처 참조를 해제해 다음 씬의 커서를 덮어쓰거나 렌더러 종료 시 GPU 자원이 남지 않게 한다. 텍스트 입력용 IBEAM은 엔진 기본을 유지한다. 커서 그림은 assets/ui/cursor_menu·cursor_hand·cursor_aim의 PNG/Aseprite이며 tools/build_cursor_art.lua로 재현한다. 오토로드·추가 노드·조준/입력 좌표 변경은 없다.

## 2. 한 판의 씬 구성 (`scenes/main.tscn`)

```
Main (Node2D, Y 정렬, scenes/main.gd)   조립 지점: 모든 시스템의 setup() 호출, 전역 단축키
├─ Darkness (CanvasModulate)           DayNight가 색을 바꿈
├─ World [world] (Y 정렬)              src/world/world.gd — Terrain/Objects TileMapLayer
├─ Kingdom (Y 정렬)                   src/kingdom/kingdom.gd — 자원, 건물
│  └─ Core [core] (StaticBody2D)       src/kingdom/core.gd — 왕국 핵 체력
├─ Enemies (Node2D, Y 정렬)           WaveSpawner가 Enemy를 여기에 추가
├─ Player [player] (CharacterBody2D)   src/characters/player.gd
│  └─ Camera
├─ Projectiles [projectiles]           Projectile.spawn()이 여기에 추가
├─ Effects [fx_layer]                  Fx가 파티클·글자를 여기에 추가
├─ PingMarkers                         전략회의 핑 표시
├─ BossMusic (코드로 추가)               MusicPlayer: 보스전 반복 음악·페이드·회의 일시정지
├─ SoundEffects (코드로 추가)            효과음 재생·거리 감쇠·동시 재생 제한
├─ BuildMode                           건설 모드 입력·미리보기
├─ DayNight (Node)                     낮/밤 시간
├─ WaveSpawner (Node)                  낮 배회 적, 밤 침공 웨이브
└─ Hud (CanvasLayer)                   UI 전체 (패널은 코드로 생성)
```

`Main._ready()`가 코드로 붙이는 동기화 노드(이름이 모두에게 같아야 RPC가 닿는다, D-017): `PlayerSync`(플레이어), `CombatSync`(적·시간·핵·효과음), `WorldSync`(나무·바위·상자), `KingdomSync`(창고·건물·장비 상자·제작대·수리·입고. 입력·UI는 Kingdom 명령 메서드 대신 이 노드의 같은 이름 메서드를 부른다), `MapSync`(탐험 칸·핑, D-018. 전략회의 창은 이 노드의 `add_ping`·`clear_pings`를 부른다), `MeetingSync`(전략회의 열기·준비·전원 재개, D-019. T 키와 회의 창의 준비 완료가 이걸 거친다). 혼자 플레이에서는 아무것도 보내지 않고 Kingdom을 바로 부른다.

`[이름]`은 노드 그룹. 코드에서 추가되는 그룹: `kingdom`(Kingdom, 적이 영토 크기를 읽는다, D-026·D-027), `enemies`(Enemy, 호스트에만), `lights`(Fx.add_light), `player`(RemotePlayer도 들어간다. 그래서 `player` 그룹을 `Player` 타입으로 가정하면 안 된다, D-017).
`Enemy`, `Building`, `Projectile`, UI 패널은 `.tscn` 없이 코드로 생성한다. 플레이어 몸은 `Player`가 코드로 붙이는 `Sprite2D`(`assets/characters/player.png`, D-012)가, 무기·공격 궤적은 그 뒤에 붙인 `WeaponVisual`이 그린다. Player의 `_draw()`는 보호막 표시만 맡는다. 투사체도 픽셀 시트를 사용하며 나머지 UI는 기존 코드로 그린다.

건설물은 `assets/kingdom/buildings_expanded.aseprite`·PNG(1472×384)를 쓴다. 한 칸 64×96, 가로 23개 외형(20종 + 제작대 추가 3단계), 세로 4프레임·0.16초다. `BuildingDB.sprite_column`·`sprite_top`과 제작대 `sprite_tops`가 메뉴 크롭·단계별 체력바를 정한다. `Building.draw_art()`를 월드·설치 미리보기·도감이 공유한다. 원본 위치 (-32,-80)에 Building.art_scale을 함께 적용해 공성탑(siege)은 70%, 생활 건물(utility)은 55%로 접지 기준점을 유지하며 그린다. 벽·문은 100%다. 설치 미리보기와 도감 상세도 같은 draw_art를 사용하고 체력바는 축소 후 최상단을 따른다. 아이콘은 원본 크롭, 실제 충돌은 기존 32×32 한 칸이다. 목재·금속·흑요석·정수 벽, 각 공성 장치, 생활 설비가 고유 실루엣을 쓴다. 색만 입힌 확장 건물 임시 그림은 대체됐고 기존 8칸 원본은 최초 시안으로 보존한다. 불·서리·번개·마법 고리 등은 연출만 반복하며 전투 판정·난수는 소비하지 않는다.

적은 `assets/enemies/enemies.aseprite`(64×64, 32프레임, 종류별 태그·레이어)에서 내보낸 `enemies.png`(256×512)를 쓴다. 4열은 움직임 프레임, 8행은 슬라임·고블린·거인·늑대·전갈·늪 슬라임·화염 정령·보스다. `EnemyDB`의 `sprite_row`가 행, `sprite_top`이 전체 프레임의 최상단 y좌표다. `Enemy._draw()`는 원래 크기로 `(-32, -40)`에 그리고 x 이동 방향으로 좌우 반전한다. 8fps로 걷고 정지 시 0번 칸으로 돌아간다(슬라임·늪 슬라임·불꽃·보스는 정지 중에도 움직임 유지). 체력바는 반전하지 않으며 뿔·불꽃을 포함한 그림 위에 둔다. 피격 시 기존 0.08초 동안 그림을 밝게 하며 AI·원형 충돌·공격·보상은 기존 시스템이 맡는다.

건설(D-022)은 `BuildingDB`의 `category`(벽·공성탑·생활 탭)·`tier`(필요한 왕국 방어 단계, D-027)·`outside`(영토 밖 가능)로 나뉜다. `Kingdom.tech_error()`가 잠금 검증을 맡고, `teleports()`·`find_teleport_near()`·`can_deposit_at()`(핵·보급소)이 생활 건물을 찾는다. 순간이동 탑 창(`TeleportPanel`)은 E로 열리며 이동은 `Player.teleport_to()`로 각자 정한다. 감시탑은 `World.reveal_area()`로 지도를 밝히고 `cells_explored`로 모두에게 전한다. 모닥불 회복은 각자의 `Main`이 내 캐릭터에 적용한다. 새 건물 그림은 원본 칸에 `tint`만 입힌다(임시).

보스 7종(D-021)은 `assets/enemies/bosses.aseprite`·PNG(1024×896)의 128×128 고유 외형·8프레임을 쓴다. 원본은 56프레임·ID별 태그·접지 그림자/몸체/문양 레이어로 나뉜다. `EnemyDB.sprite_row`·`sprite_top`은 각 보스의 행·전체 프레임 최상단이다. Enemy의 `sprite_texture`·`sprite_region`·`sprite_offset`·`animation_frames`를 로컬/EnemyPuppet이 공유한다. 그림 원점(-64,-104), 충돌은 원래 반경을 유지하며 몸·장식은 기존 배치 기준점에 묶어 Y 정렬한다. 기존 분노 체력 조건에서만 호흡 속도(최대 1.5배)·밝기를 강조하고 피격/돌진 예고는 기존 번쩍임을 쓴다. 일반 적은 기존 64×64·4프레임을 유지하며 과거 공통 보스 행은 최초 원본으로 보존한다. 보스 패턴은 `Enemy`가 `patterns`·`rage` 데이터를 읽어 호스트에서만 실행한다. 탄은 `Projectile`(적 탄 → `enemy_shot`으로 참가자에게 복제), 소환은 부모 노드에 `Enemy`를 추가한다. 패턴에는 무작위가 없다.

무기 34종은 `assets/combat/weapon_tree.aseprite`·PNG(512×2176)의 64×64·8프레임 고유 외형을 쓴다. 대검·쌍검·수호검, 장궁·연사궁, 산탄·공성 석궁, 화염·서리·번개 지팡이는 실루엣·재질·강화 장식을 구분한다. `WeaponArtDB`가 행·피벗(20,32)·모션 시간·반동·검 궤적을 정의하고 `WeaponVisual`을 Player/RemotePlayer가 공유한다. 두 플레이어 모두 몸 Sprite2D·착용 장비를 먼저 추가하고 무기를 다음 형제로 그려 무기가 몸 위에 보인다. 무기에 별도 Z를 주지 않아 다른 월드 물체와의 Y 정렬은 그대로 유지한다. 손에 드는 무기·폭탄 주머니 그림만 HELD_SCALE=0.5로 줄여 64×64 원본 칸을 32×32로 표시한다. 손잡이 피벗도 같은 비율로 적용해 기준점을 고정하며 대기·공격·원격 표시가 동일하다. 노드 전체를 축소하지 않아 검 궤적·몸 반동·아이콘·투사체·실제 공격 사거리는 유지한다. 기본 검·활·석궁·지팡이도 각각 독립 행을 사용하며 폭탄 주머니는 최초 `weapons` 시트를 보존한다. `ItemArtDB.icon`은 무기 대기 외형에서 아이콘을 가져와 장비창·제작·상자가 같은 모양을 보여준다.

`weapon_tree_projectiles`는 32×32·4프레임×25종(관통/연사 화살·산탄·공성탄·원소탄·강화 스킬탄), `weapon_tree_effects`는 128×128·6프레임×25종(계열별 검 궤적·내려찍기·돌진 베기·반격·화살비·포격·서리 고리·낙뢰·번개 연결·명중)이다. 기존 `projectiles`·`attack_effects`도 기본 탄·폭탄·기존 효과에 계속 쓴다. 실제 그림은 `WeaponArtDB.weapon_texture/projectile_texture/effect_texture`와 각 region으로 고른다. 무기 스킬 8종은 `weapon_skill_icons`의 32×32 아이콘을 하단 바에 쓴다. Aseprite 원본과 재현 도구 `tools/build_weapon_tree_art.lua`를 함께 보관한다.

PlayerSync는 장착 무기·공격 모션과 `Player.weapon_effect_requested`의 스킬 그림을 공유한다. 스킬 그림 RPC는 ID·위치·크기·거리·유한값을 검사하고 피해 명령을 실행하지 않는다. CombatSync는 아군 탄을 발사자 외 화면에 `visual_only`로 보여주며 명중·폭발·연쇄 번개는 호스트 확정 결과로 전달한다. `CombatEffect`는 기존 패시브와 신규 무기 효과의 지연 생성 예약을 합쳐 표시 한도를 지킨다. 효과가 수명 후 사라져도 실제 피해·속도·쿨타임·범위·강화 효과는 ItemDB와 기존 전투 명령 경로를 유지한다.

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
| `damage_dealt` | Enemy(`take_damage`, 강조 여부) | Main(피해 숫자·혼자 플레이 멈칫), CombatSync(호스트: 묶어서 참가자에게) (D-023) |
| `screen_shake_requested` | Enemy(보스 돌진·처치), Projectile(폭발·범위 피해) | Main(거리만큼 내 화면 흔들기), CombatSync(호스트: 참가자에게) (D-023) |
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
| 개인 가방·장비 가방·경험치·레벨을 각자 소유 | `Player.inventory`·`equipment`·`progression`, `KingdomSync`의 요청 | 호스트가 정하는 것(월드·왕국·보상 추첨)과 달리 참가자 화면에 있다. 참가자는 요청에 가방 내용을 실어 보내고 호스트는 그 값을 믿는다(임시, D-017). 패시브 단계는 각자 정하고 `PlayerSync`로 알린다. 호스트는 받은 단계(`RemotePlayer.ranks`)를 믿고 약탈자·보물 사냥꾼·건설 패시브에 쓴다(D-020) |

## 6. 멀티플레이 구조 (목표, 미구현)

- Godot 고수준 멀티플레이(`ENetMultiplayerPeer`), 호스트 = 피어 1 = 권한자. 전용 서버 여부는 기획 미정.
- 모든 참가자는 같은 시드로 `WorldGenerator.generate()`를 실행해 같은 기본 월드를 만들고, 이후 **변경분**(오브젝트 제거, 건물, 탐험 칸)만 호스트가 전파한다.
- 클라이언트 → 호스트: 입력과 요청(이동 방향·조준, 공격, 스킬 사용, 건설 요청). 호스트가 소유 시스템의 명령 메서드로 검증·적용.
- 호스트 → 클라이언트: 결과 상태(위치, 체력, 자원, 건물, 낮/밤 시간, 웨이브 적).
- 네트워크 코드는 `src/multiplayer/`와 각 기능의 얇은 동기화 노드에만 두고, 1인 플레이는 "로컬 호스트 1명"으로 같은 경로를 탄다.
- 구체적인 방식(동기화 노드 사용 여부, 보간, 재접속)은 구현 시작 때 `docs/DECISIONS.md`에 기록한다.

## 7. 알아둘 점

- 패시브 트리(D-020)는 `PassiveArtDB`(`data/passive_art.gd`)의 아이콘·방사형 배치와 `PassiveDB.requires`의 실제 선행 연결선을 사용한다. `PassiveTree`는 중앙 왕관에서 전투·생존·건설 경로를 펼치고 `PassiveNode`는 잠금·학습 가능·학습 중·완료 및 선택 상태를 그린다. 노드 선택은 상세만 열고, 오른쪽 배우기 버튼이 `Progression.learn()`을 호출한다. 비용·효과·선행 규칙은 PassiveDB/Progression이 소유한다. 1232×672 화면을 창에 맞춰 축소한다. 기존 `pos`는 게임 데이터의 격자 좌표이며 시각 배치와 분리된다.
- 새 패시브 노드는 `PassiveDB`와 함께 `PassiveArtDB`의 `ICON_ORDER`·`LAYOUT`에도 넣어야 패시브 창에 보인다(로직 테스트가 확인). D-020 확장 노드 24개는 바깥 고리에 임시 배치했고 아이콘 그림은 아직 없다. 수리·건설 효과는 `PassiveDB.repair_perks()`·`build_perks()`로 모아 `Kingdom.repair()`·`build()`에 넘긴다.
- 노드가 트리에 붙기 전에 `set_physics_process(false)`를 불러도, `_physics_process`를 정의한 노드는 `_ready` 때 Godot이 다시 켠다. 켜고 끌 조건은 `_ready()`에서 정한다 (`WorldSync`, `KingdomSync`).
- 투사체는 `Area2D` 겹침 신호 대신 매 물리 프레임 `intersect_shape`로 직접 충돌을 조회한다. `Area2D` 신호로는 타일·벽·핵 같은 정적 바디가 감지되지 않았기 때문이다.
- 타일 충돌은 여러 칸이 한 바디로 묶여 있어서, 맞은 칸은 `World.object_cell_near()`로 위치를 보고 찾는다.
- 월드는 288×288칸 단일 배열(`WorldData`)이다(D-032에서 192에서 키움). 이 크기에서는 청크 로딩이 필요 없어서 없다(D-006).
- 충돌 레이어: 1 water, 2 objects, 3 buildings, 4 player, 5 enemies, 6 passable (`PhysicsLayers` = `project.godot [layer_names]`). passable은 벽을 뺀 모든 건물(`BuildingDB.player_passable()`, D-036)이 쓴다. 플레이어(`main.tscn` mask 7)는 이 레이어를 보지 않아 지나가고, 적 몸·적 탄은 막혀서 부순다 (D-025).
- 입력은 `InputBindings.register()`가 `Session._ready()`에서 런타임에 등록한다. 그래서 `--script`로 실행한 테스트에는 입력 액션이 없다.

### 시작 화면·패시브 그래픽 (2026-10-26)

`MenuArt`는 시작 화면과 패시브 창만 사용하는 픽셀 패널·버튼 테마다. `assets/ui/menu_chrome`·`passive_nodes`·`passive_icons`의 Aseprite 원본과 PNG를 사용한다. 시작 화면은 `assets/branding/title_background.png`를 화면에 채우고 왼쪽에 로고·메뉴를 둔다. 싱글/멀티 팝업과 호스트 시작 조건은 유지하며 팝업 뒤 메뉴의 키보드 포커스를 막는다. 새 오토로드·그룹·네트워크 상태는 없다.

### 메뉴 음악·한국어 글꼴 (2026-10-26)

`Title`은 `MenuMusic` AudioStreamPlayer를 직접 소유한다. `SoundDB.TITLE_MUSIC`의 OGG 스트림을 복제해 반복하며 목표 음량·페이드 시간은 같은 데이터 파일에 있다. 팝업은 재생기를 만들지 않으며 씬 종료 시 함께 해제된다. 음악은 오토로드나 RPC로 공유하지 않는다. `assets/audio/music/`에 게임용 약 74초 루프와 생성 원본·편집 기록을 보관한다.

`assets/fonts/kingdom_dot.ttf`는 Galmuri11(OFL 1.1) 기반 파생 글꼴이며 한글 11,172자를 보존하고 고정폭 숫자·왕관/검/방패 등을 새로 그렸다. 프로젝트의 `gui/theme/custom_font`가 전체 Control UI에 적용하고 `MenuArt.theme`와 직접 그리는 `ActionBar`도 `UiKit.GAME_FONT`를 쓴다. 원본·라이선스는 같은 폴더에, 개발용 재현 도구는 tools/build_kingdom_font.py에 있다.

### 건설 도감·전체 장비 그래픽 (2026-10-26)

`BuildMenu`는 MenuArt 테마의 1232×672 도감을 창에 맞춰 축소한다. 세 분류의 `BuildCard`를 선택하면 `BuildPreview`와 오른쪽 설명·체력·기본 공격 수치·재료 필요/보유·해금 조건을 갱신한다. 잠긴 카드도 상세 확인 가능, 설치 모드 진입은 불가다. 자원 부족 때는 미리보기 가능하며 실제 지불·검증은 기존 Kingdom 명령에 남는다. 가방+창고 수량과 테크를 열려 있는 동안 0.25초마다 읽는다. 신규 그룹·오토로드는 없다.

`ItemArtDB`는 무기 34종의 실제 대기 자세 아이콘과 assets/ui/equipment_items의 비무기 10종·재료 아이콘을 공유한다. 방패·모자·투구·갑옷·신발·부적·뿔피리와 폭탄 주머니는 기존 아이콘을 유지한다. 장비창·제작·상자가 같은 아이콘을 쓰며 상자는 고정 높이 스크롤과 호버 상세를 제공한다. 석탄·송진·보스 정수는 construction_materials에 추가했다.

`EquipmentVisual`은 몸 Sprite2D의 자식으로 비무기 10종의 24×24·12자세(정면/뒷면/측면 × 걷기4) 오버레이를 그린다. 몸의 반동·숨김을 상속하고 좌우 반전은 같은 상태로 적용한다. Player의 Equipment.changed가 읽기 전용 외형을 갱신한다. PlayerSync가 기존 위치/무기 상태에 직렬화 가능한 장착 ID 사전을 추가해 RemotePlayer도 같은 그림을 쓴다. ID·슬롯을 검사하며 능력치나 피해를 변경하지 않는다. RPC는 계속 src/multiplayer에만 있다.

### K 패시브 발동 연출 (2026-10-26)

`PassiveEffectDB`는 패시브55종의 연출 분류와 assets/combat/passive_effects.aseprite·PNG(128×128, 14종×8프레임)를 정의한다. `CombatEffect`가 기존 공격 효과와 같은 fx_layer에 표시하고 수명 뒤 제거한다. K에서 배우기 성공 시 PassiveNode가 습득 파동을 그린다. 상시 수치 노드는 이 습득 표시를 사용하며 별도의 액티브 스킬로 바꾸지 않는다.

실제 발동은 원래 상태 소유 코드의 성공 지점에 연결한다: Player의 회오리 횟수·마무리/광전사·다중 사격·대시 강화·회복/재생·피해 경감/최후의 저항·복귀, Melee/Projectile의 강화 명중·관통/불씨, World의 광역 채집, Main의 풍요/약초/새벽/보물, Kingdom/Building의 할인·강화 건설/해체·가시 반사·자가 보수·수리/요새화. 긴 칼날의 검 궤적도 실제 사거리 배율을 따른다. 그래픽은 피해·회복·드롭·난수를 다시 계산하지 않는다.

로컬 캐릭터 연출은 Player.show_passive가 동일 계열 0.6초 간격으로 만들고 PlayerSync의 전용 외형 RPC로 다른 화면에만 보낸다. ID/위치/범위/유한값을 검사한다. 호스트가 확정하는 월드 연출은 기존 Events.combat_effect_requested→CombatSync 경로를 사용한다. 두 경로는 각각 캐릭터 시전과 월드 결과를 맡으며 같은 결과를 재실행하지 않는다. 동시에 보이는 패시브 효과는 fx_layer 자식 수 48개를 기준으로 제한한다. 신규 그룹·오토로드 없음.

패시브 표시 한도는 fx_layer의 예약 메타데이터를 함께 센다. 지연 add_child가 실행되기 전에 예약하므로 요새화로 같은 프레임에 요청이 몰려도 상한을 넘지 않는다. 예약 값도 한 판의 fx_layer와 함께 사라진다.


## 보스전 음악

`Main`이 `MusicPlayer`와 자식 `AudioStreamPlayer`를 한 판 아래에 소유한다. `SoundDB.BOSS_MUSIC`·음량·페이드 시간을 `setup()`으로 주입하고, 기존 `boss_status()`로 호스트의 Enemy 또는 참가자의 EnemyPuppet이 있는 동안 활성화한다. 보스가 아침까지 남아 있으면 계속 재생하며 마지막 보스가 사라지거나 승리·멸망 화면이 열리면 페이드아웃한다. 승패 판정이나 별도 음악 RPC는 추가하지 않는다.

`MusicPlayer`는 게임 규칙·월드·난수를 참조하지 않는다. 일시정지 중에도 처리해서 활성 음악은 `stream_paused`로 위치를 보존하고, 비활성화된 음악의 종료 페이드는 끝낸다. 페이드는 hitstop의 게임 속도와 무관한 실제 시간을 쓴다. 페이드 도중 새 보스가 나타나면 기존 트윈을 취소해 이전 stop 콜백이 음악을 끊지 않게 한다. 씬이 해제되면 음악도 함께 해제된다. 새 오토로드·버스·그룹은 없다.


## 게임 화면 경험치·레벨 표시

`Hud`가 상단 왼쪽 상태창 안에 축소된 `ProgressionHud`를 소유하고 개인 `Progression`을 setup으로 주입한다. `changed` 신호에서 레벨·이번 레벨의 경험치/필요량·패시브 포인트를 읽는다. 진행바는 현재 레벨의 실제 비율을 쓰며 경험치 획득만 짧게 보간하고, 레벨업에는 왕관 배지·테두리를 잠시 강조한다. 경험치 감소는 즉시 표시한다. 학습·경험치·사망 규칙은 기존 `Progression`이 소유한다.

포인트 버튼은 `passive_requested` 로컬 신호로 기존 K 패시브 창을 연다. Hud의 포인터 판정에 패널을 포함해 클릭이 월드 기본 공격으로 이어지지 않게 한다. 캐릭터 외형·체력·보스 체력바와 겹치지 않도록 상단 상태창의 체력바 아래에 통합한다. 크기는 252×44로 줄이고, 작은 창에서는 펼친 재화 영역만 스크롤해 화면 밖으로 나가지 않게 한다. 그림은 `assets/ui/progression_hud.aseprite`·PNG(128×64)의 일반/성장 왕관 배지, 보라색 경험치바 테두리/채움을 사용한다. 게임용 난수나 네트워크 상태를 바꾸지 않는다.


## 월드 앞뒤 그리기 순서

`main.tscn`의 Main·World·Objects(TileMapLayer)·Kingdom·Enemies가 중첩 Y 정렬을 사용한다. 플레이어, Main에 붙는 RemotePlayer, Enemies 아래의 Enemy/EnemyPuppet, Kingdom 아래의 성·건물, Objects의 각 생성물 타일은 같은 Z=0에서 배치 기준점의 전역 Y를 비교한다. 화면 아래쪽(Y가 큰 쪽)을 나중에 그린다. 생성 순서·나무 높이·건물 그림의 상단 위치로 우선순위를 정하지 않는다. 같은 Y일 때는 기존 트리 순서로 결정된다.

개별 캐릭터·건물의 Y 정렬은 켜지 않는다. 몸·장비·무기·체력바는 각 객체의 기준점에 묶어서 기존 내부 순서를 보존한다. Terrain은 Z=-1, 투사체는 1, 전투 효과는 2, 핑은 3, 설치 미리보기는 4다. 채집물 체력바 overlay는 기존 Z=1을 유지하고 HUD는 CanvasLayer를 사용한다. 씬 노드를 이동하거나 RPC 경로·충돌·월드 상태·그림 위치를 바꾸지 않는다.

### 왕국 핵 창 (D-027)

`KingdomPanel`은 핵 옆에서 E로 열린다(건물이 더 가까우면 그 건물 창이 먼저). 제작대 강화(`Kingdom.upgrade_workbench`, 몬스터 재료)·방어 강화(`upgrade_defense`, 채집 재료)·영토 확장(`expand_territory`, 둘 다)·수리(`repair`)를 `KingdomSync`의 같은 이름 메서드로 부른다. 참가자 요청은 호스트가 같은 명령 메서드로 검증하고, `defense_tier`·`territory_level`은 `Kingdom.snapshot()`으로 전한다. 모든 명령은 `Kingdom.core_use_error()`(핵에서 `Balance.CORE_USE_RANGE`)로 거리를 검사한다. 영토 반지름은 `Kingdom.territory_radius()`가 정하며 건설 범위·경계 그림·적의 낮 경계(`Enemy.in_kingdom`)·침공 등장 위치·배회 적 등장 거리가 모두 이 값을 따른다. 월드 생성의 시작 지역 크기는 기본 반지름(`Balance.TERRITORY_RADIUS`)을 그대로 쓴다.



### 왕국 집무실 그래픽·제작 창 정리

`KingdomPanel`은 성채·영토 링 미리보기, 실제 핵 체력과 제작대/방어/확장 현황, 네 운영 카드(제작대 강화·방어 강화·영토 확장·수리)를 MenuArt 픽셀 테마로 표시한다. `assets/ui/kingdom_ui.aseprite`·PNG(256×64)의 전용 아이콘·왕관 문장과 기존 성채 원본을 사용한다. 카드는 보유/필요 재료 아이콘·가방/창고 툴팁·부족/완료 조건을 보여주고 기존 KingdomSync 명령만 호출한다. 열려 있는 동안 호스트의 상태·자원·수리 패시브 값을 주기적으로 반영한다.

`CraftingPanel`에서는 제작대 강화 버튼·비용·설비 패널을 제거했다. 장비 목록과 제작 상세의 2열로 줄였고 현재 제작대 단계와 레시피 잠금 설명만 남긴다. 강화는 기존 D-027대로 핵 E 창에서 한다. 새 신호·오토로드·RPC·성장 규칙은 추가하지 않는다.

### 무기 트리 (D-028)

무기는 `ItemDB`(능력치·`concept`·우클릭 `skill`)와 `RecipeDB`(`tier`·`from`)로 정의한다. `Kingdom.craft()`는 "from"이 있으면 `Equipment.replace_item()`으로 이전 무기를 새 무기로 바꾼다(들고 있으면 손에서, 아니면 가방에서). 새 효과는 데이터 키로 켠다: 투사체 `knockback`·`pierce_ramp`·`chain`·`second_blast`(`Projectile`), 범위 공격의 감속·기절(`Melee.blast`의 `slow_factor`·`slow_time`, `Player.blast_at`), 돌진(`Player.lunge`), 반격 자세(`Player.activate_counter`). 스킬 효과는 `Skills.cast()`에 있고, 여러 번 떨어지는 스킬은 `Skills._later()`로 일시정지를 따르는 타이머를 쓴다. 그림이 없는 무기는 `WeaponArtDB.art()`·`basic_projectile()`, `ItemArtDB.icon()`이 계열 기본 그림을 돌려준다.


### 미니맵·재료 가방 표시

Hud의 우상단 `MapView.mini`는 192×224의 황동 지도 프레임과 160×160 탐험 영역을 쓴다. `MapView._map_rect`를 그리기·클릭 좌표 변환에 공통으로 사용하고 전체 지도/전략회의의 기존 영역은 유지한다. 성·플레이어·침공·순간이동 탑·핑은 `assets/ui/minimap_ui`의 픽셀 표식을 공유한다. 탐험 정보와 핑 규칙은 MapState·MapSync가 계속 소유한다.

미니맵 왼쪽 `Hud.BagGauge`는 96×84의 가죽 가방과 사용/전체 칸·적재율을 표시한다. Inventory.used_slots/capacity를 읽어 빈 칸·부분 스택·큰 가방·입고/사망 초기화를 반영한다. 80% 이상은 금색, 만원은 붉은색과 ‘가득 참’ 문구로 구분하며 누르면 기존 재료 목록을 펼친다. 가방 영역 클릭은 기본 공격으로 전달하지 않는다. 재료 변경·입고·수용량 규칙을 소유하지 않는다. 원본은 `minimap_ui.aseprite`, 재현은 `tools/build_minimap_art.lua`다.

### 무기 타격감 (D-029)

`WeaponArtDB.FEEL`이 갈래별 멈칫·화면 흔들림·공격 반동을 정한다. 반동은 `Player._fire_weapon()`이 `add_kick()`으로 바로 낸다. 맞혔을 때의 느낌은 `Events.damage_dealt`의 `source`(때린 peer id)가 내 것일 때만 `Main.show_damage()`가 낸다. 참가자는 호스트가 묶어 보내는 피해 숫자에 실린 `source`로 같은 판단을 하므로, 피해는 호스트가 정하고 느낌은 각자 화면에서만 난다. 근접 넉백은 무기 데이터의 `knockback`을 따른다.

### 환경 설정 (D-030)

`GameSettings`(RefCounted)가 볼륨·UI 크기·전체 화면·수직 동기화·흔들림·피해 숫자·멈칫 값을 가지고 `user://settings.cfg`에 저장한다. `Session.settings`가 하나를 소유하고, 값이 바뀌면 `apply()`가 오디오 버스(실행할 때 코드로 만드는 `Music`·`SFX`, `MusicPlayer`·`SoundEffects`·시작 화면 음악이 보냄)·창 배율·창 모드에 반영한다. UI 크기는 `Window.content_scale_factor`로 바꾸고 `Main._apply_settings()`가 플레이어 카메라 줌을 그만큼 되돌려 월드 크기는 유지한다. 흔들림 배율은 `Player.shake_scale`, 피해 숫자·멈칫은 `Main`이 읽는다. 게임 중에는 아무 창도 없을 때 Esc가 `PauseMenu`를 열고(게임은 멈추지 않음) 그 안에서 `SettingsPanel`을 연다. 시작 화면에도 같은 설정 창이 있다. 테스트는 `settings.path`를 테스트 파일로 바꾸고 기본값으로 시작한다.

### 전체 지도·전략회의 창 그래픽 (2026-10-26)

전체 지도(M)는 `WorldMapPanel`이 맡는다. MenuArt 판 왼쪽에 `MapView`(지도 액자), 오른쪽에 미니맵 표식 범례와 일차·영토 반지름·탐험 비율을 1초마다 읽어 보여준다. `Hud.toggle_big_map()`·`close_big_map()`·`is_big_map_open()`으로 열고 닫으며, 열려 있으면 `Main`이 기본 공격을 막는다. 전략회의(T) `MeetingPanel`은 같은 판·액자·범례 함수(`WorldMapPanel.section()`·`icon()`·`label()`)를 쓰고, 핑·준비·재개 흐름(MapSync·MeetingSync)은 바꾸지 않았다. 새 오토로드·그룹·네트워크 상태는 없다.

### E 상호작용 대상 고르기 (D-031)

`Main.interactables()`가 내 캐릭터 주변에서 E로 열 수 있는 것(장비 상자·제작대·순간이동 탑은 `Balance.USE_REACH`, 왕국 핵은 `CORE_USE_RANGE`, 보물 상자는 둘레 한 칸)을 모으고, `interact_target(마우스 월드 좌표)`가 하나면 그것, 여럿이면 마우스에 가장 가까운 것을 고른다. `_interact()`와 월드 위 안내(`InteractPrompt`, "E 이름" 표와 금색 모서리)가 같은 함수를 써서 보이는 대상과 열리는 대상이 항상 같다. 안내는 기본 공격이 막힌 상태(창·설치 모드)에서는 숨는다. 테스트는 `Main.mouse_override`로 마우스 위치를 정한다.

### 건물 야간 조명 강도

Fx.add_light(owner, radius, energy_scale=1.0)는 광원별 표시 강도를 메타데이터로 보관하고 DayNight는 darkness×LIGHT_ENERGY×광원 강도로 매 프레임 갱신한다. 건물은 기존 반경의 65%·강도 0.3, 왕국 핵은 반경 210px·강도 0.35로 겹친 빛의 과다 노출을 줄인다. 플레이어와 원격 플레이어는 기본 강도 1.0·기존 반경을 쓴다. 낮 0과 황혼/새벽 보간은 광원별 배율에도 그대로 적용한다. 조명은 연출이며 탐험·치유·공격 사거리·호스트 판정은 바꾸지 않는다.

### 아침 재생과 서식 몬스터 (D-035)

`WorldGenerator`는 자원을 `RESOURCE_DENSITY`(25%)만큼만 만들고 바이옴·종류별 개수를 `WorldData.resource_targets`에 남긴다. 호스트의 `Main._on_day_started()`가 `World.regrow(rng, blocked)`로 모자란 만큼 다시 자라게 하고 `WorldSync.send_regrowth()`로 참가자에게 `World.apply_grown()`을 시킨다. `WaveSpawner`는 시작할 때 지형별 칸 목록과 서식 수를 정하고(`_plan_residents`), 첫 낮과 매일 아침 `refill_residents()`로 채운다. 서식 몬스터는 `Enemy.home`·`home_terrain`을 가지고 집 근처를 돌아다닌다(`Balance.RESIDENT_*`). 참가자 쪽 생성기는 꺼져 있어 아침 신호가 와도 채우지 않는다(`can_process()`).

