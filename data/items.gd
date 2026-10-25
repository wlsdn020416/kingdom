class_name ItemDB
extends RefCounted
## 장비 목록. "skill"이 있는 장비만 스킬바(1~4)에 올라간다.
## 무기: "melee"가 true면 근거리(range 픽셀, arc 각도), 아니면 투사체(speed).
## 새 장비는 ITEMS에 한 줄 추가하면 상자에서 나온다. 새 스킬 효과는 Skills.cast()에 추가한다.

## 슬롯 순서 = 스킬바 정렬 순서 (기획 미정, 임시 규칙)
const SLOTS := ["weapon", "offhand", "head", "armor", "boots", "charm"]
const SLOT_NAMES := {
	"weapon": "무기", "offhand": "보조", "head": "머리",
	"armor": "갑옷", "boots": "신발", "charm": "장신구",
}

const STARTING_EQUIPMENT := {
	"weapon": "rusty_sword", "head": "leather_cap",
}

const ITEMS := {
	"rusty_sword": {
		"name": "낡은 검", "slot": "weapon",
		"weapon": {"damage": 15.0, "rate": 2.5, "melee": true, "range": 52.0, "arc": 120.0},
	},
	"obsidian_blade": {
		"name": "흑요석 검", "slot": "weapon",
		"weapon": {"damage": 32.0, "rate": 2.5, "melee": true, "range": 62.0, "arc": 130.0},
	},
	"old_bow": {
		"name": "낡은 활", "slot": "weapon",
		"weapon": {"damage": 10.0, "rate": 4.0, "speed": 620.0},
	},
	"scatter_crossbow": {
		"name": "산탄 석궁", "slot": "weapon",
		"weapon": {"damage": 9.0, "rate": 3.0, "speed": 600.0},
		"skill": {"id": "shotgun", "name": "산탄", "cooldown": 4.0, "damage": 9.0, "count": 12},
	},
	"fire_staff": {
		"name": "화염 지팡이", "slot": "weapon",
		"weapon": {"damage": 13.0, "rate": 3.0, "speed": 520.0},
		"skill": {"id": "fireball", "name": "화염구", "cooldown": 2.5, "damage": 45.0},
	},
	"bomb_bag": {
		"name": "폭탄 주머니", "slot": "offhand",
		"skill": {"id": "bomb", "name": "폭탄", "cooldown": 6.0, "damage": 60.0, "radius": 80.0},
	},
	"wooden_shield": {"name": "나무 방패", "slot": "offhand", "hp": 20.0},
	"leather_cap": {"name": "가죽 모자", "slot": "head", "hp": 10.0},
	"iron_helm": {"name": "철 투구", "slot": "head", "hp": 30.0},
	"guardian_armor": {
		"name": "수호의 갑옷", "slot": "armor", "hp": 20.0,
		"skill": {"id": "shield", "name": "보호막", "cooldown": 12.0, "duration": 2.5},
	},
	"chain_mail": {"name": "사슬 갑옷", "slot": "armor", "hp": 40.0},
	"flame_armor": {"name": "화염 갑옷", "slot": "armor", "hp": 80.0},
	"cloth_shoes": {"name": "천 신발", "slot": "boots", "speed_bonus": 0.15},
	"life_charm": {
		"name": "생명의 부적", "slot": "charm",
		"skill": {"id": "heal", "name": "치유", "cooldown": 15.0, "amount": 40.0},
	},
	"war_horn": {
		"name": "전쟁 뿔피리", "slot": "charm",
		"skill": {"id": "rally", "name": "함성", "cooldown": 18.0, "damage": 25.0, "radius": 170.0},
	},
}


## 장비창에 보여줄 한 줄 설명
static func describe(id: String) -> String:
	var item: Dictionary = ITEMS[id]
	var parts := PackedStringArray()
	if item.has("weapon"):
		if item.weapon.get("melee", false):
			parts.append("근거리 공격 %s · 초당 %s회" % [_num(item.weapon.damage), _num(item.weapon.rate)])
		else:
			parts.append("원거리 공격 %s · 초당 %s발" % [_num(item.weapon.damage), _num(item.weapon.rate)])
	if item.has("hp"):
		parts.append("체력 +%s" % _num(item.hp))
	if item.has("speed_bonus"):
		parts.append("이동속도 +%d%%" % roundi(item.speed_bonus * 100))
	if item.has("skill"):
		parts.append("스킬: %s (%s초)" % [item.skill.name, _num(item.skill.cooldown)])
	return " · ".join(parts)


static func _num(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else str(value)
