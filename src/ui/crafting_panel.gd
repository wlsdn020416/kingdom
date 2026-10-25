class_name CraftingPanel
extends Control
## 제작대 창 (제작대 옆에서 E). 공개된 레시피로 장비를 만들고 제작대 단계를 올린다.
## 실제 처리는 KingdomSync를 거쳐 Kingdom.craft()·upgrade_workbench()만 호출한다. 제작대에서 멀어지면 닫힌다.

const LIST_HEIGHT := 330.0  # 레시피가 늘어도 창이 화면(720) 안에 들어오게 목록만 스크롤
const REFRESH_INTERVAL := 0.2

var _kingdom: Kingdom
var _commands: KingdomSync
var _player: Player
var _cell := World.NO_CELL
var _title: Label
var _upgrade: Button
var _recipes: VBoxContainer
var _hidden_note: Label
var _refresh_timer := 0.0
var _shown := []  # 마지막으로 그린 [단계, 알게 된 재료]. 바뀐 경우에만 버튼을 다시 만든다


func setup(kingdom: Kingdom, player: Player, commands: KingdomSync) -> void:
	_kingdom = kingdom
	_commands = commands
	_player = player
	var box := UiKit.dialog(self, "제작대", 600.0)
	_title = UiKit.heading("", 15, UiKit.ACCENT)
	box.add_child(_title)
	_upgrade = UiKit.button("", _on_upgrade)
	box.add_child(_upgrade)
	box.add_child(UiKit.note("만든 장비는 가방으로 들어갑니다 (I로 착용). 비용은 가방에서 먼저, 모자라면 왕국 창고에서 냅니다."))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = LIST_HEIGHT
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_recipes = VBoxContainer.new()
	_recipes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_recipes)
	_hidden_note = UiKit.note("")
	box.add_child(_hidden_note)
	box.add_child(UiKit.button("닫기 (E)", hide))
	hide()


func open(cell: Vector2i) -> void:
	_cell = cell
	show()
	_refresh()


func _process(delta: float) -> void:
	if visible and _kingdom.find_workbench_near(_player.global_position) != _cell:
		hide()
		return
	# 멀티플레이 참가자는 단계·레시피 공개가 호스트에게서 나중에 오므로 열려 있는 동안 가끔 확인한다
	_refresh_timer -= delta
	if visible and _refresh_timer <= 0.0:
		_refresh_timer = REFRESH_INTERVAL
		if [_kingdom.workbench_tier(), _kingdom.known_materials.size()] != _shown:
			_refresh()


func _on_upgrade() -> void:
	_commands.upgrade_workbench()
	_refresh()


func _on_craft(recipe_id: String) -> void:
	_commands.craft(recipe_id)
	_refresh()


func _refresh() -> void:
	if not visible or not _kingdom.buildings.has(_cell):
		return
	var tier := _kingdom.workbench_tier()
	_shown = [tier, _kingdom.known_materials.size()]
	_title.text = "현재 %d단계 / 최고 %d단계" % [tier, RecipeDB.max_tier()]
	if tier >= RecipeDB.max_tier():
		_upgrade.text = "최고 단계입니다"
		_upgrade.disabled = true
	else:
		var cost: Dictionary = RecipeDB.UPGRADES[tier]
		_upgrade.text = "%d단계로 업그레이드   ·   %s" % [tier + 1, Balance.format_cost(cost)]
		_upgrade.disabled = false
		_paint(_upgrade, _kingdom.can_afford(cost, _player.inventory))
	for child in _recipes.get_children():
		child.queue_free()
	var hidden := 0
	for id: String in RecipeDB.RECIPES:
		if not RecipeDB.is_revealed(id, _kingdom.known_materials):
			hidden += 1
			continue
		var recipe: Dictionary = RecipeDB.RECIPES[id]
		var text := "%s   ·   %s\n%s" % [ItemDB.ITEMS[id]["name"], Balance.format_cost(recipe["cost"]), ItemDB.describe(id)]
		var button := UiKit.button(text, _on_craft.bind(id))
		if tier < recipe["tier"]:
			button.text = "[%d단계 필요] " % recipe["tier"] + text
			button.disabled = true
		else:
			_paint(button, _kingdom.can_afford(recipe["cost"], _player.inventory))
		_recipes.add_child(button)
	_hidden_note.text = "아직 모르는 레시피 %d개 · 새 재료를 얻으면 나타납니다" % hidden if hidden > 0 else ""


func _paint(button: Button, affordable: bool) -> void:
	if affordable:
		button.remove_theme_color_override("font_color")
	else:
		button.add_theme_color_override("font_color", UiKit.DANGER)
