class_name ItemDB
extends RefCounted
## 장비 목록. "skill"이 있는 장비만 스킬을 쓴다. 무기 스킬은 우클릭, 나머지 장비 스킬은 스킬바(1~4)에 올라간다 (D-027).
## 무기: "melee"가 true면 근거리(range 픽셀, arc 각도), 아니면 투사체(speed). "family"는 무기 종류(숙련 패시브, PassiveDB.FAMILY_MASTERY).
## 투사체 무기의 추가 효과: shots·spread(여러 발), pierce, lifetime, splash_radius, slow_factor·slow_time, knockback, pierce_ramp, chain(D-028).
## 근접 무기의 "knockback"은 맞은 적을 미는 힘 (없으면 Melee.KNOCKBACK, 무기별 타격감 D-029).
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
	# --- 무기 트리 (D-028): 0단계 기본 무기 4종 → 제작대 1단계에서 갈래로 나뉘고 2·3단계에서 그 갈래를 강화한다.
	# 강화는 이전 단계 무기를 소모한다(RecipeDB "from"). "concept"는 갈래의 성격, 3단계에는 갈래 특성이 하나 더 붙는다. 수치는 임시.
	# 검: 대검(느리고 넓은 한 방) · 쌍검(빠른 연타와 돌진) · 수호검(체력과 반격)
	"rusty_sword": {
		"name": "낡은 검", "slot": "weapon", "concept": "검의 기본기. 제작대 1단계에서 대검·쌍검·수호검으로 나뉜다",
		"weapon": {"family": "sword", "damage": 15.0, "rate": 2.5, "melee": true, "range": 52.0, "arc": 120.0},
	},
	"greatsword": {
		"name": "대검", "slot": "weapon", "concept": "대검 · 느리지만 넓고 무거운 한 방",
		"weapon": {"family": "sword", "damage": 34.0, "rate": 1.4, "melee": true, "range": 66.0, "arc": 150.0, "knockback": 420.0},
		"skill": {"id": "slam", "name": "내려찍기", "cooldown": 7.0, "damage": 40.0, "radius": 90.0},
	},
	"steel_greatsword": {
		"name": "강철 대검", "slot": "weapon", "concept": "대검 · 느리지만 넓고 무거운 한 방",
		"weapon": {"family": "sword", "damage": 50.0, "rate": 1.5, "melee": true, "range": 70.0, "arc": 155.0, "knockback": 460.0},
		"skill": {"id": "slam", "name": "내려찍기", "cooldown": 6.5, "damage": 60.0, "radius": 100.0},
	},
	"obsidian_blade": {
		"name": "흑요석 대검", "slot": "weapon", "concept": "대검 · 느리지만 넓고 무거운 한 방. 특성: 내려찍기가 적을 기절시킨다",
		"weapon": {"family": "sword", "damage": 72.0, "rate": 1.6, "melee": true, "range": 74.0, "arc": 160.0, "knockback": 500.0},
		"skill": {"id": "slam", "name": "내려찍기", "cooldown": 6.0, "damage": 85.0, "radius": 115.0, "stun": 1.2},
	},
	"twin_blades": {
		"name": "쌍검", "slot": "weapon", "concept": "쌍검 · 빠른 연타와 돌진",
		"weapon": {"family": "sword", "damage": 11.0, "rate": 5.0, "melee": true, "range": 46.0, "arc": 90.0, "knockback": 110.0},
		"skill": {"id": "dash_slash", "name": "돌진 베기", "cooldown": 5.0, "damage": 30.0, "distance": 150.0},
	},
	"steel_twin_blades": {
		"name": "강철 쌍검", "slot": "weapon", "concept": "쌍검 · 빠른 연타와 돌진",
		"weapon": {"family": "sword", "damage": 15.0, "rate": 5.5, "melee": true, "range": 48.0, "arc": 95.0, "knockback": 110.0},
		"skill": {"id": "dash_slash", "name": "돌진 베기", "cooldown": 4.5, "damage": 45.0, "distance": 160.0},
	},
	"shadow_blades": {
		"name": "그림자 쌍검", "slot": "weapon", "concept": "쌍검 · 빠른 연타와 돌진. 특성: 돌진 경로를 한 번 더 벤다",
		"weapon": {"family": "sword", "damage": 20.0, "rate": 6.0, "melee": true, "range": 50.0, "arc": 100.0, "knockback": 120.0},
		"skill": {"id": "dash_slash", "name": "돌진 베기", "cooldown": 4.0, "damage": 60.0, "distance": 170.0, "hits": 2},
	},
	"guard_sword": {
		"name": "수호검", "slot": "weapon", "hp": 20.0, "concept": "수호검 · 단단한 몸으로 버티다 되갚는다",
		"weapon": {"family": "sword", "damage": 18.0, "rate": 2.2, "melee": true, "range": 54.0, "arc": 120.0},
		"skill": {"id": "counter", "name": "반격 자세", "cooldown": 10.0, "duration": 1.5, "damage": 25.0, "per_block": 15.0, "radius": 110.0},
	},
	"knight_sword": {
		"name": "기사검", "slot": "weapon", "hp": 40.0, "concept": "수호검 · 단단한 몸으로 버티다 되갚는다",
		"weapon": {"family": "sword", "damage": 26.0, "rate": 2.3, "melee": true, "range": 56.0, "arc": 120.0},
		"skill": {"id": "counter", "name": "반격 자세", "cooldown": 9.0, "duration": 1.6, "damage": 35.0, "per_block": 20.0, "radius": 120.0},
	},
	"royal_guard_sword": {
		"name": "왕실 수호검", "slot": "weapon", "hp": 70.0, "concept": "수호검 · 단단한 몸으로 버티다 되갚는다. 특성: 막은 공격마다 체력 회복",
		"weapon": {"family": "sword", "damage": 36.0, "rate": 2.4, "melee": true, "range": 58.0, "arc": 125.0},
		"skill": {"id": "counter", "name": "반격 자세", "cooldown": 8.0, "duration": 1.8, "damage": 50.0, "per_block": 30.0, "radius": 150.0, "heal_per_block": 8.0},
	},
	# 활: 장궁(느리고 강한 관통 저격) · 연사궁(빠른 연사와 화살비)
	"old_bow": {
		"name": "낡은 활", "slot": "weapon", "concept": "활의 기본기. 제작대 1단계에서 장궁·연사궁으로 나뉜다",
		"weapon": {"family": "bow", "damage": 10.0, "rate": 4.0, "speed": 620.0},
	},
	"longbow": {
		"name": "장궁", "slot": "weapon", "concept": "장궁 · 느리지만 강하게 꿰뚫는 화살",
		"weapon": {"family": "bow", "damage": 26.0, "rate": 1.6, "speed": 900.0, "pierce": true, "lifetime": 1.1, "knockback": 140.0},
		"skill": {"id": "snipe", "name": "저격", "cooldown": 5.0, "damage": 90.0},
	},
	"yew_longbow": {
		"name": "주목 장궁", "slot": "weapon", "concept": "장궁 · 느리지만 강하게 꿰뚫는 화살",
		"weapon": {"family": "bow", "damage": 38.0, "rate": 1.7, "speed": 950.0, "pierce": true, "lifetime": 1.15, "knockback": 150.0},
		"skill": {"id": "snipe", "name": "저격", "cooldown": 4.5, "damage": 130.0},
	},
	"dragonbone_longbow": {
		"name": "용골 장궁", "slot": "weapon", "concept": "장궁 · 느리지만 강하게 꿰뚫는 화살. 특성: 꿰뚫을 때마다 피해 증가",
		"weapon": {"family": "bow", "damage": 52.0, "rate": 1.8, "speed": 1000.0, "pierce": true, "lifetime": 1.2, "knockback": 160.0, "pierce_ramp": 0.3},
		"skill": {"id": "snipe", "name": "저격", "cooldown": 4.0, "damage": 180.0, "pierce_ramp": 0.3},
	},
	"rapid_bow": {
		"name": "연사궁", "slot": "weapon", "concept": "연사궁 · 약하지만 쉬지 않는 연사",
		"weapon": {"family": "bow", "damage": 6.0, "rate": 8.0, "speed": 650.0},
		"skill": {"id": "arrow_rain", "name": "화살비", "cooldown": 7.0, "damage": 18.0, "radius": 70.0, "waves": 3},
	},
	"hunter_bow": {
		"name": "사냥꾼 연사궁", "slot": "weapon", "concept": "연사궁 · 약하지만 쉬지 않는 연사",
		"weapon": {"family": "bow", "damage": 8.0, "rate": 9.0, "speed": 680.0},
		"skill": {"id": "arrow_rain", "name": "화살비", "cooldown": 6.5, "damage": 26.0, "radius": 80.0, "waves": 3},
	},
	"storm_bow": {
		"name": "폭풍 연사궁", "slot": "weapon", "concept": "연사궁 · 약하지만 쉬지 않는 연사. 특성: 한 번에 두 발",
		"weapon": {"family": "bow", "damage": 11.0, "rate": 10.0, "speed": 700.0, "shots": 2, "spread": 6.0},
		"skill": {"id": "arrow_rain", "name": "화살비", "cooldown": 6.0, "damage": 36.0, "radius": 90.0, "waves": 4},
	},
	# 석궁: 산탄(가까이서 퍼붓기) · 공성(맞으면 터지는 볼트)
	"wooden_crossbow": {
		"name": "나무 석궁", "slot": "weapon", "concept": "석궁의 기본기. 제작대 1단계에서 산탄·공성 석궁으로 나뉜다",
		"weapon": {"family": "crossbow", "damage": 14.0, "rate": 2.0, "speed": 700.0},
	},
	"scatter_crossbow": {
		"name": "산탄 석궁", "slot": "weapon", "concept": "산탄 석궁 · 가까이서 여러 발을 퍼붓는다",
		"weapon": {"family": "crossbow", "damage": 7.0, "rate": 2.0, "speed": 600.0, "shots": 3, "spread": 7.0, "lifetime": 0.5},
		"skill": {"id": "shotgun", "name": "산탄", "cooldown": 4.0, "damage": 9.0, "count": 12},
	},
	"heavy_scatter_crossbow": {
		"name": "대형 산탄 석궁", "slot": "weapon", "concept": "산탄 석궁 · 가까이서 여러 발을 퍼붓는다",
		"weapon": {"family": "crossbow", "damage": 9.0, "rate": 2.1, "speed": 600.0, "shots": 4, "spread": 7.0, "lifetime": 0.5},
		"skill": {"id": "shotgun", "name": "산탄", "cooldown": 3.5, "damage": 12.0, "count": 14},
	},
	"dragon_scatter_crossbow": {
		"name": "용린 산탄 석궁", "slot": "weapon", "concept": "산탄 석궁 · 가까이서 여러 발을 퍼붓는다. 특성: 맞은 적을 밀어낸다",
		"weapon": {"family": "crossbow", "damage": 12.0, "rate": 2.2, "speed": 620.0, "shots": 5, "spread": 7.0, "lifetime": 0.5, "knockback": 160.0},
		"skill": {"id": "shotgun", "name": "산탄", "cooldown": 3.0, "damage": 16.0, "count": 16, "knockback": 220.0},
	},
	"siege_crossbow": {
		"name": "공성 석궁", "slot": "weapon", "concept": "공성 석궁 · 맞으면 터지는 무거운 볼트",
		"weapon": {"family": "crossbow", "damage": 20.0, "rate": 1.3, "speed": 620.0, "splash_radius": 40.0, "knockback": 120.0},
		"skill": {"id": "blast_bolt", "name": "폭발 볼트", "cooldown": 6.0, "damage": 70.0, "radius": 100.0},
	},
	"iron_siege_crossbow": {
		"name": "철제 공성 석궁", "slot": "weapon", "concept": "공성 석궁 · 맞으면 터지는 무거운 볼트",
		"weapon": {"family": "crossbow", "damage": 30.0, "rate": 1.4, "speed": 640.0, "splash_radius": 50.0, "knockback": 130.0},
		"skill": {"id": "blast_bolt", "name": "폭발 볼트", "cooldown": 5.5, "damage": 100.0, "radius": 110.0},
	},
	"obsidian_siege_crossbow": {
		"name": "흑요석 공성 석궁", "slot": "weapon", "concept": "공성 석궁 · 맞으면 터지는 무거운 볼트. 특성: 폭발 볼트가 한 번 더 터진다",
		"weapon": {"family": "crossbow", "damage": 42.0, "rate": 1.5, "speed": 660.0, "splash_radius": 60.0, "knockback": 140.0},
		"skill": {"id": "blast_bolt", "name": "폭발 볼트", "cooldown": 5.0, "damage": 140.0, "radius": 120.0, "second": true},
	},
	# 지팡이: 화염(범위 피해) · 서리(감속과 빙결) · 번개(튀는 연쇄)
	"apprentice_staff": {
		"name": "견습 지팡이", "slot": "weapon", "concept": "지팡이의 기본기. 제작대 1단계에서 화염·서리·번개로 나뉜다",
		"weapon": {"family": "staff", "damage": 9.0, "rate": 2.5, "speed": 520.0},
	},
	"fire_staff": {
		"name": "화염 지팡이", "slot": "weapon", "concept": "화염 · 맞은 적 주변까지 태우는 범위 피해",
		"weapon": {"family": "staff", "damage": 13.0, "rate": 3.0, "speed": 520.0, "splash_radius": 30.0},
		"skill": {"id": "fireball", "name": "화염구", "cooldown": 2.5, "damage": 45.0},
	},
	"blaze_staff": {
		"name": "업화 지팡이", "slot": "weapon", "concept": "화염 · 맞은 적 주변까지 태우는 범위 피해",
		"weapon": {"family": "staff", "damage": 19.0, "rate": 3.1, "speed": 530.0, "splash_radius": 40.0},
		"skill": {"id": "fireball", "name": "화염구", "cooldown": 2.4, "damage": 70.0},
	},
	"inferno_staff": {
		"name": "겁화 지팡이", "slot": "weapon", "concept": "화염 · 맞은 적 주변까지 태우는 범위 피해. 특성: 화염구가 지나가며 주변을 태운다",
		"weapon": {"family": "staff", "damage": 26.0, "rate": 3.2, "speed": 540.0, "splash_radius": 50.0},
		"skill": {"id": "fireball", "name": "화염구", "cooldown": 2.3, "damage": 100.0, "splash_radius": 90.0},
	},
	"frost_staff": {
		"name": "서리 지팡이", "slot": "weapon", "concept": "서리 · 맞은 적을 느리게 한다",
		"weapon": {"family": "staff", "damage": 10.0, "rate": 2.6, "speed": 520.0, "slow_factor": 0.6, "slow_time": 1.5},
		"skill": {"id": "frost_ring", "name": "서리 고리", "cooldown": 8.0, "damage": 20.0, "radius": 140.0, "slow": 0.35, "slow_time": 3.0},
	},
	"glacier_staff": {
		"name": "빙하 지팡이", "slot": "weapon", "concept": "서리 · 맞은 적을 느리게 한다",
		"weapon": {"family": "staff", "damage": 14.0, "rate": 2.7, "speed": 520.0, "slow_factor": 0.5, "slow_time": 1.8},
		"skill": {"id": "frost_ring", "name": "서리 고리", "cooldown": 7.5, "damage": 30.0, "radius": 160.0, "slow": 0.3, "slow_time": 3.5},
	},
	"winter_staff": {
		"name": "혹한 지팡이", "slot": "weapon", "concept": "서리 · 맞은 적을 느리게 한다. 특성: 서리 고리가 적을 얼린다",
		"weapon": {"family": "staff", "damage": 19.0, "rate": 2.8, "speed": 530.0, "slow_factor": 0.4, "slow_time": 2.0},
		"skill": {"id": "frost_ring", "name": "서리 고리", "cooldown": 7.0, "damage": 45.0, "radius": 180.0, "slow": 0.0, "slow_time": 1.5},
	},
	"thunder_staff": {
		"name": "번개 지팡이", "slot": "weapon", "concept": "번개 · 맞은 적에서 근처 적으로 튀는 연쇄",
		"weapon": {"family": "staff", "damage": 11.0, "rate": 2.4, "speed": 600.0, "chain": 2},
		"skill": {"id": "lightning", "name": "낙뢰", "cooldown": 5.0, "damage": 55.0, "radius": 70.0, "strikes": 1},
	},
	"storm_staff": {
		"name": "폭풍 지팡이", "slot": "weapon", "concept": "번개 · 맞은 적에서 근처 적으로 튀는 연쇄",
		"weapon": {"family": "staff", "damage": 15.0, "rate": 2.5, "speed": 620.0, "chain": 3},
		"skill": {"id": "lightning", "name": "낙뢰", "cooldown": 4.5, "damage": 80.0, "radius": 80.0, "strikes": 1},
	},
	"tempest_staff": {
		"name": "뇌신 지팡이", "slot": "weapon", "concept": "번개 · 맞은 적에서 근처 적으로 튀는 연쇄. 특성: 낙뢰가 세 번 떨어진다",
		"weapon": {"family": "staff", "damage": 20.0, "rate": 2.6, "speed": 640.0, "chain": 4},
		"skill": {"id": "lightning", "name": "낙뢰", "cooldown": 4.5, "damage": 100.0, "radius": 85.0, "strikes": 3},
	},
	# --- 무기 외 장비 ---
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
	if item.has("concept"):
		parts.append(item.concept)
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
