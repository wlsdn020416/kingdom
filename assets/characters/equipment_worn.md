# 착용 장비 오버레이

`equipment_worn.aseprite`는 24×24, 비무기 장비 10종×12자세의 태그/프레임 원본이다. PNG는 288×240, 가로 정면4·뒷면4·측면4, 세로 ItemArtDB.WORN_ORDER 순서다. 왼쪽은 좌우 반전한다.

폭탄 주머니·나무 방패·가죽 모자·철 투구·수호의 갑옷·사슬 갑옷·화염 갑옷·천 신발·생명의 부적·전쟁 뿔피리를 그렸다. Player와 RemotePlayer의 몸 Sprite2D에 EquipmentVisual이 자식으로 붙어 같은 걷기 칸·숨김·반동을 따른다. 아이콘은 assets/ui/equipment_items이며 능력치·스킬·공격 모션은 기존 구현을 유지한다. Aseprite Lua 제작.
