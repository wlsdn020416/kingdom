# KINGDOM SYSTEM

2~4인 협동 하드코어 왕국 생존 게임 (Godot 4.7, GDScript). 기획은 `기획서.md`.

지금은 1인용 플레이 가능 프로토타입입니다(전투, 낮/밤 침공, 건설, 장비, 시드 기반 월드). 멀티플레이와 픽셀아트는 아직 없고, 그림은 전부 코드로 그린 임시 도형입니다. 단계별 상태는 `docs/ROADMAP.md`.

## 실행

- 에디터: Godot에서 이 폴더를 열고 F5
- 터미널: `godot --path .`
- 시작 화면 건너뛰기: `godot --path . -- --seed=oak-1234`

## 검사

```sh
sh tests/run_all.sh   # 스크립트·씬 로딩 + 로직 테스트 + 실제 게임 스모크 테스트 (약 25초)

# 시드별 지형 비율과 왕국에서 갈 수 있는 땅 비율 (월드 생성 조정용)
godot --headless --path . --script res://tools/world_stats.gd
```

자세한 내용은 `docs/TESTING.md`.

## 구조

```
scenes/          시작 화면(title), 한 판의 게임(main — 시스템 조립)
src/
  core/          Events·Session 오토로드, 키 배치, 충돌 레이어, 임시 이펙트
  world/         월드 데이터·생성·타일맵, 임시 색과 타일셋
  characters/    플레이어, 장비
  combat/        투사체, 장비 스킬 효과
  enemies/       적
  kingdom/       왕국 핵, 건물, 건설 모드
  gameplay/      낮/밤, 웨이브, 공유 지도, 상자 보상, 핑 표시
  ui/            HUD, 스킬바, 지도, 장비창, 전략회의, 멸망 화면
data/            밸런스 수치, 장비, 적, 건물 목록  ← 숫자 조정은 여기서만
tests/           자동 검사 (run_all.sh)
tools/           월드 통계
docs/            아키텍처, 설계 결정, 로드맵, 테스트
```

개발 규칙(AI 에이전트 포함)은 `AGENTS.md`, 구조와 의존성은 `docs/ARCHITECTURE.md`, 임시로 정한 기획 규칙은 `docs/DECISIONS.md`에 있습니다.

## 자주 하는 수정

| 하고 싶은 것 | 고칠 곳 |
| --- | --- |
| 낮/밤 길이, 웨이브 규모, 체력, 비용 | `data/balance.gd` |
| 장비 추가 | `data/items.gd`의 `ITEMS`에 한 줄 (상자에서 자동으로 나옴) |
| 새 스킬 효과 | `data/items.gd`에 `skill.id`를 정하고 `src/combat/skills.gd`의 `match`에 추가 |
| 적 추가 | `data/enemies.gd` |
| 건물 추가 | `data/buildings.gd` (`ORDER` 순서 = 건설 모드 1, 2, 3 키) |
| 키 배치 | `src/core/input_bindings.gd` (+ `scenes/title.gd`의 조작 안내) |
| 지형 분포 | `src/world/world_generator.gd` 상수 → `tools/world_stats.gd`로 확인 |
| 픽셀아트 타일셋 적용 (Phase 2) | `src/world/tileset_builder.gd`의 이미지 함수만 교체 |
| 캐릭터·적 스프라이트 (Phase 2) | 각 스크립트의 `_draw()`를 스프라이트 노드로 교체 |
