# 테스트와 검증

모든 명령은 저장소 루트에서 실행한다. 아래 명령은 2026-10-25에 Godot 4.7.2 (macOS, `/opt/homebrew/bin/godot`)에서 실제로 실행해 확인했다.

## 현재 가능한 검증

### 전체 실행 (작업 완료 전 필수)

```sh
sh tests/run_all.sh
# 다른 Godot을 쓰려면: GODOT=/path/to/godot sh tests/run_all.sh
```

세 검사를 순서대로 실행하고 `PASS  <이름>` / `FAIL  <이름>`을 출력한다. 하나라도 실패하면 종료 코드 1. 약 25초.
로그는 `$TMPDIR/kingdom-tests/*.log`에 남는다.

통과 조건은 **종료 코드 0 + 결과 줄 `<이름> PASS` + 로그에 `SCRIPT ERROR` 없음** 세 가지 모두다.
Godot은 `--script`로 실행한 파일의 파싱 오류나 실행 중 스크립트 오류가 있어도 종료 코드 0으로 끝날 수 있기 때문이다.
또 엔진이 죽으면 프로세스가 멈출 수 있어서 검사마다 제한 시간을 둔다(macOS에 `timeout`이 없어 `perl alarm` 사용).

### 개별 검사

| 검사 | 명령 | 확인하는 것 |
| --- | --- | --- |
| 스크립트·씬 로딩 | `godot --headless --path . res://tests/check_scripts.tscn` | 모든 `.gd`의 파싱·컴파일(오토로드 포함), 모든 `.tscn`의 로딩과 `ext_resource` 경로 존재 |
| 로직 테스트 | `godot --headless --path . --script res://tests/logic_test.gd` | 같은 시드 → 같은 월드, 스킬바 규칙(스킬 장비만·슬롯 순서·최대 4), 무기 해제 불가, 쿨타임, 대시가 장비 스킬이 아님 |
| 스모크 테스트 | `godot --headless --path . res://tests/smoke_test.tscn` | 실제 `main.tscn`을 돌려 탐험 표시, 건설·영토 밖 거부, Space 대시·스킬 쿨타임, 상자 보상, 투사체 채집, 밤 전환·침공, 멸망 화면 |
| 월드 통계 (도구) | `godot --headless --path . --script res://tools/world_stats.gd` | 시드 6개의 지형 비율과 왕국에서 갈 수 있는 땅 비율. 통과/실패 판정 없음, 월드 생성 상수 조정 시 눈으로 확인 |
| 직접 플레이 | `godot --path .` (시작 화면 건너뛰기: `godot --path . -- --seed=oak-1234`) | 그림, 조작감, UI 배치 — headless로 확인할 수 없는 것 |

### 어디에 테스트를 추가하나

- 노드 없이 돌아가는 규칙(`WorldGenerator`, `Equipment`, `Loot`, `Balance` 함수 등) → `tests/logic_test.gd`에 `_test_xxx()` 함수 추가.
  `--script`로 실행되어 **오토로드(`Events`, `Session`)와 입력 액션이 없다.** 이것들을 쓰는 코드는 여기서 테스트할 수 없다.
- 노드·신호·물리가 얽힌 흐름 → `tests/smoke_test.gd`에 `_check(조건, "설명")` 추가. 실제 게임 씬이 오토로드와 함께 돈다.
- 확인 항목 이름은 한국어로 "무엇이 어떻게 되어야 하는지"를 쓴다.

## Godot 명령의 함정 (확인됨)

- `godot --check-only --script res://x.gd`는 쓰지 않는다. 오토로드를 몰라 정상 코드도 `Identifier not found: Events`로 실패하고, 실제 파싱 오류가 있어도 종료 코드 0이다.
- `ResourceLoader.load()`로 씬을 불러오면 `ext_resource` 경로가 깨져도 씬이 반환된다. 그래서 `check_scripts.gd`가 의존 파일 존재를 따로 확인한다.
- 실행 중인 스크립트 자신을 `CACHE_MODE_IGNORE`로 다시 불러오면 엔진이 signal 11로 죽는다. `check_scripts.gd`는 자기 자신을 건너뛴다.
- `Engine.time_scale`을 바꾼 테스트는 끝나기 전에 1.0으로 되돌린다.

## 확인할 수 없는 것 (현재 한계)

- 렌더링 결과(색, 배치, 스프라이트), 실제 키보드·마우스 입력, 프레임 성능.
- 멀티플레이: 네트워크 코드가 아직 없다.
- 장시간 플레이(여러 날, 보스 밤) 밸런스.

## 향후 도입할 검증

| 검증 | 시점 | 비고 |
| --- | --- | --- |
| 멀티 인스턴스 접속 테스트 | M1 (멀티플레이 시작) | headless 호스트 1 + 클라이언트 1을 띄워 접속·동기화 확인하는 스크립트 |
| GUT 또는 gdUnit4 | 로직 테스트가 수십 개를 넘을 때 | D-007. 도입 전 사용자와 상의 |
| CI (GitHub Actions 등에서 `run_all.sh`) | git 저장소 + 원격 저장소 생성 후 | 현재 이 폴더는 git 저장소가 아니다 |
| 스크린샷 비교 | 픽셀아트 적용 후 필요하면 | headless에서는 렌더링이 없으므로 별도 방법 필요 |
