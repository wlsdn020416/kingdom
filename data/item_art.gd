class_name ItemArtDB
extends RefCounted
## 모든 장비·건설 재료 아이콘과 착용 시트의 배치. 능력치와 장착 규칙은 ItemDB·Equipment를 따른다.

const ICONS := preload("res://assets/ui/equipment_items.png")
const MATERIALS := preload("res://assets/ui/material_icons.png")
const EXTRA_MATERIALS := preload("res://assets/ui/construction_materials.png")
const ICON_SIZE := 48
const ICON_COLUMNS := 5
const WORN_FRAMES := 12
const ORDER := ["rusty_sword", "obsidian_blade", "old_bow", "scatter_crossbow", "fire_staff", "bomb_bag", "wooden_shield", "leather_cap", "iron_helm", "guardian_armor", "chain_mail", "flame_armor", "cloth_shoes", "life_charm", "war_horn"]
const MATERIAL_ORDER := ["wood", "stone", "hardwood", "copper", "iron_ore", "moss", "obsidian", "tough_hide", "venom_sting", "ice_crystal", "swamp_ooze", "fire_core", "coal", "resin", "boss_essence"]
const WORN_ORDER := ["bomb_bag", "wooden_shield", "leather_cap", "iron_helm", "guardian_armor", "chain_mail", "flame_armor", "cloth_shoes", "life_charm", "war_horn"]


static func icon(id: String) -> AtlasTexture:
	var index := ORDER.find(id)
	if index < 0:
		return null
	var texture := AtlasTexture.new()
	texture.atlas = ICONS
	texture.region = Rect2(Vector2(index % ICON_COLUMNS, index / ICON_COLUMNS) * ICON_SIZE, Vector2.ONE * ICON_SIZE)
	return texture


static func material_icon(kind: String) -> AtlasTexture:
	var index := MATERIAL_ORDER.find(kind)
	if index < 0:
		return null
	var texture := AtlasTexture.new()
	texture.atlas = MATERIALS if index < 12 else EXTRA_MATERIALS
	texture.region = Rect2((index if index < 12 else index - 12) * 24, 0, 24, 24)
	return texture
