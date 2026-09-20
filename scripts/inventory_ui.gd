extends CanvasLayer

const INVENTORY_SLOT_SCENE := preload("res://scripts/inventory_slot.gd")
const SLOT_SIZE := Vector2(56, 56)
const SLOT_COLOR := Color("263247")
const SELECTED_COLOR := Color("f3c969")
const TOOLBAR_SLOT_COUNT := 8
## Fixed size for each seed-reserve button in the right-hand column so the UI
## looks tidy no matter how many reserves are unlocked. Sized to fit in the
## gap between the play area and the inventory toolbar; height allows for
## two wrapped lines of text ("Tomato Seeds" / "×10 / 30").
const SEED_RESERVE_BUTTON_SIZE := Vector2(108, 64)

var selected_source := ""
var selected_index := -1
var selected_frog_slot := 0
var open_storage := "chest"

@onready var chest: StaticBody2D = get_parent().get_node("Chest")
@onready var altar: StaticBody2D = get_parent().get_node("Altar")
@onready var player: Node2D = get_parent().get_node("Player")
@onready var game_state: Node = get_node("/root/GameState")
@onready var toolbar_slots: VBoxContainer = $InventoryToolbar/Scroll/Center/ToolbarSlots
@onready var chest_window: PanelContainer = $ChestWindow
@onready var frog_slots: HBoxContainer = $ChestWindow/Margin/Column/FrogSlots
@onready var chest_slots: GridContainer = $ChestWindow/Margin/Column/ChestSlots
@onready var window_title: Label = $ChestWindow/Margin/Column/Title
@onready var window_hint: Label = $ChestWindow/Margin/Column/Hint
@onready var seed_reserves: HBoxContainer = $SeedReserves

func _ready() -> void:
	game_state.inventory_changed.connect(_refresh)
	game_state.seed_count_changed.connect(_on_seed_count_changed)
	game_state.seed_types_changed.connect(_rebuild_seed_reserves)
	game_state.active_seed_changed.connect(_on_active_seed_changed)
	_refresh()
	_rebuild_seed_reserves()

func _process(_delta: float) -> void:
	if not chest_window.visible:
		return
	if open_storage == "altar":
		if not altar.can_player_interact(player):
			chest_window.hide()
	else:
		if not chest.can_player_interact(player):
			chest_window.hide()

func open_chest() -> void:
	open_storage = "chest"
	selected_source = ""
	selected_index = -1
	chest_window.show()
	_refresh()

func open_altar() -> void:
	open_storage = "altar"
	selected_source = ""
	selected_index = -1
	chest_window.show()
	_refresh()

## Hide any open storage window and cancel any in-progress item transfer.
## Used by round-end / game-over transitions so leftover UI doesn't sit on top
## of the overlay.
func close_all_windows() -> void:
	selected_source = ""
	selected_index = -1
	if chest_window != null:
		chest_window.hide()
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		chest_window.hide()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var slot: int = event.keycode - KEY_1
		if slot >= 0 and slot < TOOLBAR_SLOT_COUNT and slot < game_state.frog_inventory.size():
			_select_frog_slot(slot)

func _refresh() -> void:
	if not is_node_ready():
		return
	if frog_slots == null or chest_slots == null:
		return
	if window_title != null:
		window_title.text = "Altar" if open_storage == "altar" else "Chest"
	if window_hint != null:
		window_hint.text = (
			"Deposit tomatoes here. Once offered, they cannot be taken back."
			if open_storage == "altar"
			else "Drag items between slots, or click slots to move or swap items."
		)
	_clear(frog_slots)
	_clear(chest_slots)
	_clear(toolbar_slots)
	var storage_inventory: Array[Dictionary] = game_state.altar_inventory if open_storage == "altar" else game_state.chest_inventory
	for index in game_state.frog_inventory.size():
		_add_slot(frog_slots, "frog", index, game_state.frog_inventory[index])
		if index < TOOLBAR_SLOT_COUNT:
			_add_slot(toolbar_slots, "frog", index, game_state.frog_inventory[index])
	var visible_slot_count: int = _visible_storage_slot_count(storage_inventory)
	for index in visible_slot_count:
		_add_slot(chest_slots, open_storage, index, storage_inventory[index])

## The altar shows exactly one open drop slot: one icon per completed stack of
## 10 tomatoes plus a single empty slot for the next deposit, capped by the
## goal. All other storages render every backing slot.
func _visible_storage_slot_count(storage_inventory: Array[Dictionary]) -> int:
	if open_storage != "altar":
		return storage_inventory.size()
	var max_slots: int = mini(storage_inventory.size(), int(ceil(float(game_state.tomato_goal) / 10.0)))
	var visible: int = int(floor(float(game_state.tomato_count) / 10.0)) + 1
	return clampi(visible, 1, max_slots)

func _clear(container: Container) -> void:
	for child in container.get_children():
		child.queue_free()

func _add_slot(container: Container, inventory_name: String, index: int, item: Dictionary) -> void:
	var button := INVENTORY_SLOT_SCENE.new()
	button.custom_minimum_size = SLOT_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.modulate = SELECTED_COLOR if inventory_name == "frog" and index == selected_frog_slot else Color.WHITE
	button.text = _item_text(item)
	if not item.is_empty() and item.get("id") == game_state.CHEST_ITEM_ID:
		button.icon = load("res://icon.svg")
		button.expand_icon = true
	button.setup(inventory_name, index, item, _on_item_dropped)
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
	if item_id == game_state.FRUIT_ITEM_ID:
		return "Tomato\n×%d" % quantity
	return item_id

func _on_seed_count_changed(seed_id: String, count: int, maximum: int) -> void:
	if seed_reserves == null:
		return
	var button: Button = seed_reserves.get_node_or_null(_seed_button_name(seed_id))
	if button == null:
		# Reserve isn't shown yet (locked). `_rebuild_seed_reserves` handles it
		# when the unlock signal fires.
		return
	button.text = _seed_button_text(seed_id, count, maximum)

## Rebuild the reserve column from scratch. Cheap enough (a handful of
## buttons) that we can just tear down and re-add on every unlock instead of
## trying to diff.
func _rebuild_seed_reserves() -> void:
	if not is_node_ready() or seed_reserves == null:
		return
	_clear(seed_reserves)
	for seed_id in game_state.unlocked_seeds:
		var button := Button.new()
		button.name = _seed_button_name(seed_id)
		button.custom_minimum_size = SEED_RESERVE_BUTTON_SIZE
		button.focus_mode = Control.FOCUS_NONE
		# Wrap long labels (e.g. "Pumpkin Seeds") so the button stays inside
		# its column instead of pushing into the inventory toolbar.
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.clip_text = true
		button.text = _seed_button_text(
			seed_id,
			game_state.get_seed_count(seed_id),
			game_state.get_seed_max(seed_id),
		)
		button.modulate = SELECTED_COLOR if seed_id == game_state.active_seed_id else Color.WHITE
		button.pressed.connect(_on_seed_reserve_pressed.bind(seed_id))
		seed_reserves.add_child(button)

func _on_active_seed_changed(_seed_id: String) -> void:
	if seed_reserves == null:
		return
	for child in seed_reserves.get_children():
		if child is Button:
			var name_str: String = child.name
			var id: String = name_str.trim_prefix("Reserve_")
			child.modulate = SELECTED_COLOR if id == game_state.active_seed_id else Color.WHITE

func _on_seed_reserve_pressed(seed_id: String) -> void:
	game_state.set_active_seed(seed_id)

func _seed_button_name(seed_id: String) -> String:
	return "Reserve_%s" % seed_id

func _seed_button_text(seed_id: String, count: int, maximum: int) -> String:
	var display: String = game_state.SEED_DISPLAY_NAMES.get(seed_id, seed_id)
	return "%s\n×%d / %d" % [display, count, maximum]

func _on_slot_pressed(inventory_name: String, index: int) -> void:
	if inventory_name == "frog":
		_select_frog_slot(index)

	if selected_source.is_empty():
		# Altar items are one-way; never let a click promote one to a move source.
		if inventory_name == "altar":
			return
		var inventory: Array[Dictionary] = _inventory_for_ui(inventory_name)
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

func _inventory_for_ui(inventory_name: String) -> Array[Dictionary]:
	match inventory_name:
		"frog":
			return game_state.frog_inventory
		"altar":
			return game_state.altar_inventory
		_:
			return game_state.chest_inventory

func _select_frog_slot(index: int) -> void:
	if index < 0 or index >= game_state.frog_inventory.size():
		return
	selected_frog_slot = index
	_refresh()

func _on_item_dropped(source: String, source_index: int, destination: String, destination_index: int) -> void:
	if source == destination and source_index == destination_index:
		return
	if game_state.move_item(source, source_index, destination, destination_index):
		if destination == "frog":
			_select_frog_slot(destination_index)
		else:
			selected_source = ""
			selected_index = -1
