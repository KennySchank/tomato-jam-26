extends Node

signal inventory_changed
signal tomato_count_changed(count: int, goal: int)

const FROG_CAPACITY := 2
const CHEST_CAPACITY := 24
const ALTAR_CAPACITY := 12
const SEED_ITEM_ID := "tomato_seed"
const FRUIT_ITEM_ID := "tomato"
const CHEST_ITEM_ID := "godot_logo"

@export var tomato_goal: int = 10

var frog_inventory: Array[Dictionary] = []
var chest_inventory: Array[Dictionary] = []
var altar_inventory: Array[Dictionary] = []
var tomato_count: int = 0
var total_tomatoes_deposited: int = 0

var _last_altar_tomato_count: int = 0

func _ready() -> void:
	reset_run()

func reset_run() -> void:
	frog_inventory.clear()
	chest_inventory.clear()
	altar_inventory.clear()
	for _i in FROG_CAPACITY:
		frog_inventory.append({})
	for _i in CHEST_CAPACITY:
		chest_inventory.append({})
	for _i in ALTAR_CAPACITY:
		altar_inventory.append({})
	frog_inventory[0] = {"id": SEED_ITEM_ID, "quantity": 10}
	chest_inventory[0] = {"id": CHEST_ITEM_ID, "quantity": 1}
	total_tomatoes_deposited = 0
	_last_altar_tomato_count = 0
	_recount_tomatoes()
	inventory_changed.emit()
	tomato_count_changed.emit(tomato_count, tomato_goal)

## Clear the altar between rounds without disturbing the cumulative tally.
func reset_altar_for_new_round() -> void:
	for index in altar_inventory.size():
		altar_inventory[index] = {}
	_last_altar_tomato_count = 0
	_recount_tomatoes()
	inventory_changed.emit()

func _recount_tomatoes() -> void:
	var total := 0
	for item: Dictionary in altar_inventory:
		if not item.is_empty() and item.get("id") == FRUIT_ITEM_ID:
			total += int(item.get("quantity", 0))
	var delta: int = total - _last_altar_tomato_count
	if delta > 0:
		total_tomatoes_deposited += delta
		var run_stats := get_node_or_null("/root/RunStats")
		if run_stats != null and run_stats.has_method("record_tomato_deposit"):
			run_stats.record_tomato_deposit(delta)
	_last_altar_tomato_count = total
	tomato_count = total
	tomato_count_changed.emit(tomato_count, tomato_goal)

func _inventory_for(name: String) -> Array[Dictionary]:
	match name:
		"frog":
			return frog_inventory
		"chest":
			return chest_inventory
		"altar":
			return altar_inventory
		_:
			return frog_inventory

func consume_frog_item(slot_index: int, amount: int = 1) -> bool:
	if slot_index < 0 or slot_index >= frog_inventory.size():
		return false
	var item := frog_inventory[slot_index]
	if item.is_empty() or int(item.get("quantity", 0)) < amount:
		return false
	item["quantity"] = int(item["quantity"]) - amount
	if item["quantity"] <= 0:
		frog_inventory[slot_index] = {}
	inventory_changed.emit()
	return true

func frog_slot_has_item(slot_index: int, item_id: String) -> bool:
	return slot_index >= 0 and slot_index < frog_inventory.size() and frog_inventory[slot_index].get("id") == item_id and int(frog_inventory[slot_index].get("quantity", 0)) > 0

func add_frog_item(item_id: String, amount: int = 1) -> bool:
	return _add_item(frog_inventory, item_id, amount)

func add_chest_item(item_id: String, amount: int = 1) -> bool:
	return _add_item(chest_inventory, item_id, amount)

## Add items to the first available storage: frog slot(s) first, then the chest.
## Returns the number of items that could not be placed anywhere.
func grant_item(item_id: String, amount: int) -> int:
	if amount <= 0:
		return 0
	var remaining := amount
	var frog_space := _capacity_for(frog_inventory, item_id)
	var to_frog: int = mini(remaining, frog_space)
	if to_frog > 0 and add_frog_item(item_id, to_frog):
		remaining -= to_frog
	var chest_space := _capacity_for(chest_inventory, item_id)
	var to_chest: int = mini(remaining, chest_space)
	if to_chest > 0 and add_chest_item(item_id, to_chest):
		remaining -= to_chest
	return remaining

func _capacity_for(inventory: Array[Dictionary], item_id: String) -> int:
	var available := 0
	for item: Dictionary in inventory:
		if item.is_empty():
			available += 10
		elif item.get("id") == item_id:
			available += 10 - int(item.get("quantity", 0))
	return available

func _add_item(inventory: Array[Dictionary], item_id: String, amount: int) -> bool:
	if amount <= 0:
		return false
	if _capacity_for(inventory, item_id) < amount:
		return false
	var remaining := amount
	for index in inventory.size():
		var item: Dictionary = inventory[index]
		if not item.is_empty() and item.get("id") == item_id and int(item.get("quantity", 0)) < 10:
			var space := 10 - int(item["quantity"])
			var added := mini(space, remaining)
			item["quantity"] = int(item["quantity"]) + added
			remaining -= added
	for index in inventory.size():
		if remaining <= 0:
			break
		if inventory[index].is_empty():
			var added := mini(remaining, 10)
			inventory[index] = {"id": item_id, "quantity": added}
			remaining -= added
	if remaining > 0:
		return false
	inventory_changed.emit()
	return true

func move_item(source: String, source_index: int, destination: String, destination_index: int) -> bool:
	# Altar is one-way, tomato-only: nothing leaves it, nothing but tomatoes enters.
	if source == "altar":
		return false
	var source_inventory := _inventory_for(source)
	var destination_inventory := _inventory_for(destination)
	if source_index < 0 or source_index >= source_inventory.size():
		return false
	if destination_index < 0 or destination_index >= destination_inventory.size():
		return false
	if source_inventory[source_index].is_empty():
		return false

	var source_item: Dictionary = source_inventory[source_index]
	if destination == "altar" and source_item.get("id") != FRUIT_ITEM_ID:
		return false
	var destination_item: Dictionary = destination_inventory[destination_index]
	if destination_item.is_empty():
		destination_inventory[destination_index] = source_item.duplicate()
		source_inventory[source_index] = {}
	elif destination_item.get("id") == source_item.get("id") and int(destination_item.get("quantity", 0)) < 10:
		var space := 10 - int(destination_item["quantity"])
		var moved := mini(space, int(source_item["quantity"]))
		destination_item["quantity"] = int(destination_item["quantity"]) + moved
		source_item["quantity"] = int(source_item["quantity"]) - moved
		if source_item["quantity"] <= 0:
			source_inventory[source_index] = {}
	else:
		# The altar never returns anything, so refuse swaps that would push a
		# destination item back out of it.
		if destination == "altar":
			return false
		var swapped := destination_item.duplicate()
		destination_inventory[destination_index] = source_item.duplicate()
		source_inventory[source_index] = swapped
	_recount_tomatoes()
	inventory_changed.emit()
	return true
