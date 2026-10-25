# 메뉴·패시브 그래픽

모든 시트는 PNG와 편집 가능한 Aseprite 원본을 함께 제공한다. 픽셀 아이콘·프레임은 Aseprite Lua로 제작했다.

| 파일 | 구성 |
| --- | --- |
| passive_icons | 32×32, 가로 8칸, 총 55개 아이콘. 순서는 data/passive_art.gd의 ICON_ORDER. Aseprite는 ID별 단일 프레임 태그 |
| passive_nodes | 56×56, locked·available·learned·selected·complete 5상태 |
| menu_chrome | 384×192 아틀라스. 패널·버튼 기본/호버/누름/포커스·중앙 왕관·싱글/멀티 아이콘. 영역은 MenuArt 상수 |

시작 배경: `assets/branding/title_background.png` 및 `.aseprite`(원본 그림 한 레이어). 내장 image_gen으로 생성했으며 로고와 문자는 별도로 합성한다.

배경 제작 프롬프트: 중세 협동 생존 왕국 디펜스 게임 KINGDOM SYSTEM의 16:9 타이틀 배경. 정교한 픽셀아트, 어두운 남색 전나무 숲과 산악 계곡, 황혼의 금빛 수평선, 오른쪽에 횃불이 켜진 돌 성과 남색 금색 깃발, 계곡의 강과 다리, 성으로 이어지는 길. 왼쪽 40%는 로고와 메뉴를 위한 어둡고 여백이 있는 숲과 안개. 아름다운 원근감, 제한된 남색·청록·호박색 팔레트, 하드 픽셀 가장자리, 게임 화면 같은 통일된 디테일. 텍스트·로고·버튼·UI·사람·워터마크 없이 불투명 배경.

## 건설·전체 장비 그래픽

- `equipment_items.aseprite`·PNG: 48×48, 5열×3행, ItemArtDB.ORDER의 장비 15종. 기존 무기 5종·폭탄은 같은 무기 원본 픽셀을 재사용하고 나머지 9종은 고유 아이콘을 추가했다.
- `construction_materials.aseprite`·PNG: 24×24 3칸, 석탄·송진·보스 정수. 앞의 재료 12종은 기존 material_icons를 그대로 쓴다.
- B 건설 도감은 MenuArt의 패널/버튼과 실제 건물 아틀라스로 카드·상세·설계 격자를 구성한다. 잠긴 건물도 외형을 확인할 수 있고 실제 설치는 기존 명령 경로다.
- 착용 원본은 assets/characters/equipment_worn.aseprite, 건물 원본은 assets/kingdom/buildings_expanded.aseprite.
