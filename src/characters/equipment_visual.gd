class_name EquipmentVisual
extends Node2D
## 몸 스프라이트 위에 착용 장비를 겹쳐 그린다. 장착·능력치·공격 판정은 바꾸지 않는다.
## 로컬과 원격 캐릭터가 같은 방향·걷기 시트를 공유하며 몸의 반동과 숨김을 상속한다.

const TEXTURE := preload("res://assets/characters/equipment_worn.png")
const FRAME_SIZE := 24
const LAYERS := ["boots", "armor", "head", "charm", "offhand"]
var _body: Sprite2D
var _items := {}


func setup(body: Sprite2D) -> void:
	_body = body
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func set_items(items: Dictionary) -> void:
	_items.clear()
	for slot: String in LAYERS:
		var id: String = str(items.get(slot, ""))
		if ItemArtDB.WORN_ORDER.has(id) and ItemDB.ITEMS[id]["slot"] == slot:
			_items[slot] = id
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(_body):
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1, 1) if _body.flip_h else Vector2.ONE)
	for slot: String in LAYERS:
		if not _items.has(slot):
			continue
		var row := ItemArtDB.WORN_ORDER.find(_items[slot])
		var frame := clampi(_body.frame, 0, ItemArtDB.WORN_FRAMES - 1)
		draw_texture_rect_region(TEXTURE, Rect2(-12, -12, 24, 24), Rect2(frame * FRAME_SIZE, row * FRAME_SIZE, FRAME_SIZE, FRAME_SIZE))
