extends CanvasLayer

const SLOT_SIZE := Vector2(56, 56)
const SLOT_COLOR := Color("263247")
const SELECTED_COLOR := Color("f3c969")

var chest_window: PanelContainer
var frog_slots: HBoxContainer
var toolbar_slots: HBoxContainer
var chest_slots: GridContainer
var selected_source := ""
var selected_index := -1

@onready var chest: Area2D = get_parent().get_node("Chest")
@onready var player: Node2D = get_parent().get_node("Player")
@onready var game_state: Node = get_node("/root/GameState")

func _ready() -> void:
	_build_toolbar()
	_build_chest_window()
	game_state.inventory_changed.connect(_refresh)
	_refresh()

func _process(_delta: float) -> void:
	if chest_window.visible and not chest.can_player_interact(player):
		chest_window.hide()

func _build_toolbar() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(0, 648)
	panel.size = Vector2(1152, 72)
	panel.name = "InventoryToolbar"
	add_child(panel)
	var center := CenterContainer.new()
	panel.add_child(center)
	toolbar_slots = HBoxContainer.new()
	toolbar_slots.add_theme_constant_override("separation", 8)
	center.add_child(toolbar_slots)

func _build_chest_window() -> void:
	chest_window = PanelContainer.new()
	chest_window.position = Vector2(300, 120)
	chest_window.size = Vector2(552, 390)
	chest_window.name = "ChestWindow"
	chest_window.hide()
	add_child(chest_window)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	chest_window.add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	var title := Label.new()
	title.text = "Chest"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var hint := Label.new()
	hint.text = "Click a slot, then click another slot to move or swap items."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)
	frog_slots = HBoxContainer.new()
	frog_slots.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(frog_slots)
	var separator := HSeparator.new()
	column.add_child(separator)
	chest_slots = GridContainer.new()
	chest_slots.columns = 6
	chest_slots.add_theme_constant_override("h_separation", 8)
	chest_slots.add_theme_constant_override("v_separation", 8)
	column.add_child(chest_slots)

func open_chest() -> void:
	selected_source = ""
	selected_index = -1
	chest_window.show()
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		chest_window.hide()

func _refresh() -> void:
	if not is_node_ready():
		return
	if frog_slots == null or chest_slots == null:
		return
	_clear(frog_slots)
	_clear(chest_slots)
	_clear(toolbar_slots)
	for index in game_state.frog_inventory.size():
		_add_slot(frog_slots, "frog", index, game_state.frog_inventory[index])
		_add_slot(toolbar_slots, "frog", index, game_state.frog_inventory[index])
	for index in game_state.chest_inventory.size():
		_add_slot(chest_slots, "chest", index, game_state.chest_inventory[index])

func _clear(container: Container) -> void:
	for child in container.get_children():
		child.queue_free()

func _add_slot(container: Container, inventory_name: String, index: int, item: Dictionary) -> void:
	var button := Button.new()
	button.custom_minimum_size = SLOT_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.modulate = SELECTED_COLOR if selected_source == inventory_name and selected_index == index else Color.WHITE
	button.text = _item_text(item)
	if not item.is_empty() and item.get("id") == game_state.CHEST_ITEM_ID:
		button.icon = load("res://icon.svg")
		button.expand_icon = true
	button.pressed.connect(_on_slot_pressed.bind(inventory_name, index))
	container.add_child(button)

func _item_text(item: Dictionary) -> String:
	if item.is_empty():
		return ""
	var item_id: String = item.get("id", "")
	var quantity: int = item.get("quantity", 0)
	if item_id == game_state.CHEST_ITEM_ID:
		return "Godot\n×%d" % quantity
	if item_id == game_state.SEED_ITEM_ID:
		return "Seeds\n×%d" % quantity
	return item_id

func _on_slot_pressed(inventory_name: String, index: int) -> void:
	if selected_source.is_empty():
		var inventory: Array[Dictionary] = game_state.frog_inventory if inventory_name == "frog" else game_state.chest_inventory
		if not inventory[index].is_empty():
			selected_source = inventory_name
			selected_index = index
			_refresh()
		return
	if selected_source == inventory_name and selected_index == index:
		selected_source = ""
		selected_index = -1
		_refresh()
		return
	game_state.move_item(selected_source, selected_index, inventory_name, index)
	selected_source = ""
	selected_index = -1
	_refresh()
