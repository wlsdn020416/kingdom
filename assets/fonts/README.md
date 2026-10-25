# Kingdom Dot

게임의 픽셀 UI용 한국어 파생 글꼴이다. 한글 자형의 원작은 Lee Minseo(quiple)의 Galmuri11이며, 한글을 새로 그린 독자 글꼴은 아니다.

- `kingdom_dot.ttf`: 게임에서 사용하는 파생 글꼴. 한글 완성형 11,172자와 원본의 호환 자모·영문을 보존했다.
- 새로 그린 부분: 고정폭 8칸 숫자 10개(한글과 같은 11칸 높이), 왕관 U+E000·검 U+E001·방패 U+E002, 체크·오른쪽 화살표·가운뎃점. 내부 이름은 Kingdom Dot으로 변경했다.
- `sources/Galmuri11.ttf`: 재현용 공식 원본. `.gdignore`로 중복 임포트를 막는다.
- `OFL.md`: 원저작권과 SIL Open Font License 1.1 전문. 파생 글꼴도 같은 라이선스이며 재배포 시 함께 포함한다.
- 제작: `tools/build_kingdom_font.py` (개발용 Python + fonttools). 런타임 의존성은 없으며 게임 코드는 GDScript다.

공식 원본: https://github.com/quiple/galmuri, 파일: https://raw.githubusercontent.com/quiple/galmuri/main/dist/Galmuri11.ttf (2026-10-26 다운로드). 글꼴 구조와 라이선스는 원본의 메타데이터를 보존한다.

`project.godot`의 `gui/theme/custom_font`로 전체 Control UI에 적용한다. 메뉴 전용 Theme도 같은 글꼴을 쓰고 직접 그리는 하단 스킬바는 `UiKit.GAME_FONT`를 참조한다. 제목·본문·작은 설명의 크기 구분은 기존 UI 값을 따른다. 1280×720·960×600 실제 렌더링을 확인했으며 작은 창 가독성은 플레이 확인 대상으로 남긴다.
