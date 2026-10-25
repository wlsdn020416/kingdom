class_name BuildMenu
extends Control
## 건설 메뉴 (B). 건물을 고르면 그 건물의 설치 모드로 들어간다. 게임은 멈추지 않는다.

var _build_mode: BuildMode
var _kingdom: Kingdom
var _player: Player
var _list: VBoxContainer


func setup(build_mode: BuildMode, kingdom: Kingdom, player: Player) -> void:
	_build_mode = build_mode
	_kingdom = kingdom
	_player = player
	var box := UiKit.dialog(self, "건설", 520.0)
	box.add_child(UiKit.note("지을 건물을 고르세요. 비용은 가방에서 먼저, 모자라면 왕국 창고에서 냅니다. 게임은 멈추지 않습니다."))
	_list = VBoxContainer.new()
	box.add_child(_list)
	box.add_child(UiKit.button("닫기 (B)", hide))
	hide()


func open() -> void:
	show()
	_refresh()


func choose(type_id: String) -> void:
	hide()
	_build_mode.start(type_id)


func _refresh() -> void:
	for child in _list.get_children():
		child.queue_free()
	for type_id: String in BuildingDB.ORDER:
		var info: Dictionary = BuildingDB.TYPES[type_id]
		var cost: Dictionary = info["cost"]
		var text := "%s   ·   %s   ·   체력 %d" % [info["name"], Balance.format_cost(cost), info["hp"]]
		if not _kingdom.can_afford(cost, _player.inventory):
			text += "   (자원 부족)"
		var button := UiKit.button(text, choose.bind(type_id))
		button.icon = Building.icon_texture(type_id)
		button.custom_minimum_size.y = 64
		button.add_theme_constant_override("h_separation", 10)
		if not _kingdom.can_afford(cost, _player.inventory):
			button.add_theme_color_override("font_color", UiKit.DANGER)
		_list.add_child(button)
