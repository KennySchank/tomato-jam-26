extends Node

signal inventory_changed

const FROG_CAPACITY := 1
const CHEST_CAPACITY := 24
const SEED_ITEM_ID := "tomato_seed"
const CHEST_ITEM_ID := "godot_logo"

var frog_inventory: Array[Dictionary] = []
var chest_inventory: Array[Dictionary] = []

func _ready() -> void:
	reset_run()

func reset_run() -> void:
	frog_inventory.clear()
	chest_inventory.clear()
	for _i in FROG_CAPACITY:
		frog_inventory.append({})
	for _i in CHEST_CAPACITY:
		chest_inventory.append({})
	frog_inventory[0] = {"id": SEED_ITEM_ID, "quantity": 10}
	chest_inventory[0] = {"id": CHEST_ITEM_ID, "quantity": 1}
	inventory_changed.emit()

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

func move_item(source: String, source_index: int, destination: String, destination_index: int) -> bool:
	var source_inventory := frog_inventory if source == "frog" else chest_inventory
	var destination_inventory := frog_inventory if destination == "frog" else chest_inventory
	if source_index < 0 or source_index >= source_inventory.size():
		return false
	if destination_index < 0 or destination_index >= destination_inventory.size():
		return false
	if source_inventory[source_index].is_empty():
		return false

	var source_item: Dictionary = source_inventory[source_index]
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
		var swapped := destination_item.duplicate()
		destination_inventory[destination_index] = source_item.duplicate()
		source_inventory[source_index] = swapped
	inventory_changed.emit()
	return true
