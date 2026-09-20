extends Node

signal inventory_changed
signal tomato_count_changed(count: int, goal: int)
signal boon_activated(boon_id: String)
## Emitted when a boon is removed mid-run (e.g. the hoe breaking after its
## last charge). Consumers such as `boon_tracker.gd` use this to drop the
## boon's icon from the HUD.
signal boon_deactivated(boon_id: String)
## Emitted whenever any seed reserve's count changes. `seed_id` identifies
## which reserve (see `TOMATO_SEED_ID`, `CORN_SEED_ID`, `PUMPKIN_SEED_ID`).
signal seed_count_changed(seed_id: String, count: int, maximum: int)
## Emitted when a new seed reserve is unlocked (or the set is reset), so the
## UI can rebuild its reserve buttons from scratch.
signal seed_types_changed
## Emitted when the player switches which reserve they'll plant from next.
signal active_seed_changed(seed_id: String)

const FROG_CAPACITY := 4
const CHEST_CAPACITY := 24
const ALTAR_CAPACITY := 12
const MAX_STACK_SIZE := 50
const SEED_ITEM_ID := "tomato_seed"
## Named aliases for each seed reserve. `SEED_ITEM_ID` stays as the canonical
## "tomato seed" identifier because it also doubles as the inventory item id
## for pickups; the *_SEED_ID constants below are the ids used by the seed
## reserve system (see `seed_counts`, `unlocked_seeds`).
const TOMATO_SEED_ID := SEED_ITEM_ID
const CORN_SEED_ID := "corn_seed"
const PUMPKIN_SEED_ID := "pumpkin_seed"
const SEED_DISPLAY_NAMES := {
	TOMATO_SEED_ID: "Tomato Seeds",
	CORN_SEED_ID: "Corn Seeds",
	PUMPKIN_SEED_ID: "Pumpkin Seeds",
}
## Short placement hints surfaced by the reserve buttons' tooltips so the
## player can discover where each seed can be planted without opening a card.
const SEED_PLACEMENT_HINTS := {
	TOMATO_SEED_ID: "Click a tilled soil tile to plant a tomato",
	CORN_SEED_ID: "Click a grass tile (off the enemy path) to plant",
	PUMPKIN_SEED_ID: "Click an enemy path tile to plant",
}
const FRUIT_ITEM_ID := "tomato"
const CHEST_ITEM_ID := "godot_logo"
const DEFAULT_TOMATO_GOAL := 10

## Debug: boon scene paths to auto-apply at the start of every run. Leave the
## array empty to disable. Applied by `main.gd::_ready` after autoloads are
## ready so `get_tree()`-dependent boons work identically to a live pick.
const DEBUG_STARTING_BOONS: Array[String] = [
	#"res://scenes/boons/corn_seeds.tscn",
	#"res://scenes/boons/pumpkin_seeds.tscn",
]

@export var tomato_goal: int = DEFAULT_TOMATO_GOAL

var frog_inventory: Array[Dictionary] = []
var chest_inventory: Array[Dictionary] = []
var altar_inventory: Array[Dictionary] = []
var tomato_count: int = 0
var total_tomatoes_deposited: int = 0
## Per-reserve seed counts, keyed by seed id (see `TOMATO_SEED_ID` etc.).
## Only reserves listed in `unlocked_seeds` are shown in the UI.
var seed_counts: Dictionary = {TOMATO_SEED_ID: 10}
## Seed reserves the player has unlocked this run. Tomato is always first so
## the UI has something to show even before boons are picked.
var unlocked_seeds: Array[String] = [TOMATO_SEED_ID]
## Which reserve the next plant/tower/wall drop will consume.
var active_seed_id: String = TOMATO_SEED_ID

## Boons the player has chosen this run. Keyed by the boon scene's resource
## path (e.g. `res://scenes/boons/cowboy_hat.tscn`) so we can look them up
## without having to hand-author IDs. Values are always `true` today, but
## the dict form leaves room for per-boon state (charges, stacks) later.
var active_boons: Dictionary = {}

# Per-run modifiers driven by boons. Each boon subclass mutates the field it
# owns; gameplay code reads these values instead of hard-coded constants so
# multiple effects can compose without every boon knowing about every system.
var wearing_cowboy_hat: bool = false
var player_speed_multiplier: float = 1.0
var plant_growth_multiplier: float = 1.0
var tower_damage_multiplier: float = 1.0
var bonus_seed_chance: float = 0.0
var plant_bonus_hp: int = 0
var has_sickle: bool = false
var has_nail: bool = false
var has_propeller_hat: bool = false
var hoe_charges: int = 0

var _last_altar_tomato_count: int = 0

## Increase the tribute requirement for the next round.
func increase_tomato_goal(amount: int = 2) -> void:
	if amount <= 0:
		return
	tomato_goal += amount

func _ready() -> void:
	reset_run()

func reset_run() -> void:
	tomato_goal = DEFAULT_TOMATO_GOAL
	frog_inventory.clear()
	chest_inventory.clear()
	altar_inventory.clear()
	for _i in FROG_CAPACITY:
		frog_inventory.append({})
	for _i in CHEST_CAPACITY:
		chest_inventory.append({})
	for _i in ALTAR_CAPACITY:
		altar_inventory.append({})
	seed_counts = {TOMATO_SEED_ID: 10}
	unlocked_seeds = [TOMATO_SEED_ID]
	active_seed_id = TOMATO_SEED_ID
	total_tomatoes_deposited = 0
	_last_altar_tomato_count = 0
	active_boons.clear()
	wearing_cowboy_hat = false
	player_speed_multiplier = 1.0
	plant_growth_multiplier = 1.0
	tower_damage_multiplier = 1.0
	bonus_seed_chance = 0.0
	plant_bonus_hp = 0
	has_sickle = false
	has_nail = false
	has_propeller_hat = false
	hoe_charges = 0
	_recount_tomatoes()
	inventory_changed.emit()
	tomato_count_changed.emit(tomato_count, tomato_goal)
	seed_types_changed.emit()
	active_seed_changed.emit(active_seed_id)
	for seed_id in unlocked_seeds:
		seed_count_changed.emit(seed_id, get_seed_count(seed_id), get_seed_max(seed_id))

## Returns the current count for a reserve. Reserves that have never been
## touched read as 0, which is safe for both locked and unlocked ids.
func get_seed_count(seed_id: String) -> int:
	return int(seed_counts.get(seed_id, 0))

## Every reserve currently shares the same cap. Kept as a function so we can
## specialize per seed later without touching every caller.
func get_seed_max(_seed_id: String) -> int:
	return MAX_STACK_SIZE

## Add seeds to a specific reserve. Defaults to tomato so the pre-existing
## `add_seeds(amount)` calls (wave rewards, harvest drops) keep working.
## Returns any overflow the reserve couldn't accept.
func add_seeds(amount: int, seed_id: String = TOMATO_SEED_ID) -> int:
	if amount <= 0:
		return 0
	var maximum := get_seed_max(seed_id)
	var current := get_seed_count(seed_id)
	var added: int = mini(amount, maximum - current)
	if added <= 0:
		return amount
	seed_counts[seed_id] = current + added
	seed_count_changed.emit(seed_id, seed_counts[seed_id], maximum)
	return amount - added

## Consume one seed from the given reserve. Returns false if the reserve is
## empty (or has never been unlocked), leaving the caller to bail out.
func consume_seed(seed_id: String = TOMATO_SEED_ID) -> bool:
	var current := get_seed_count(seed_id)
	if current <= 0:
		return false
	seed_counts[seed_id] = current - 1
	seed_count_changed.emit(seed_id, seed_counts[seed_id], get_seed_max(seed_id))
	return true

## Unlock a new seed reserve (typically from a boon). No-op if it's already
## unlocked so boons can be idempotent. Emits `seed_types_changed` so the UI
## can add the new reserve button.
func unlock_seed_type(seed_id: String) -> void:
	if seed_id.is_empty() or unlocked_seeds.has(seed_id):
		return
	unlocked_seeds.append(seed_id)
	if not seed_counts.has(seed_id):
		seed_counts[seed_id] = 0
	seed_types_changed.emit()
	seed_count_changed.emit(seed_id, seed_counts[seed_id], get_seed_max(seed_id))

## Switch which reserve the next planting action will draw from. Silently
## ignores unknown / locked reserves so the UI can't get us into a bad state.
func set_active_seed(seed_id: String) -> void:
	if seed_id == active_seed_id or not unlocked_seeds.has(seed_id):
		return
	active_seed_id = seed_id
	active_seed_changed.emit(active_seed_id)

## Records that the player has picked a boon. `boon_id` is the boon scene's
## resource path. Emits `boon_activated` so systems that care about permanent
## modifiers (player speed, growth rate, etc.) can refresh themselves.
func activate_boon(boon_id: String) -> void:
	if boon_id.is_empty():
		return
	active_boons[boon_id] = true
	boon_activated.emit(boon_id)

func has_boon(boon_id: String) -> bool:
	return active_boons.has(boon_id)

## Remove a previously-picked boon (e.g. the hoe once its last charge is
## spent). No-op if the boon wasn't active. Emits `boon_deactivated` so the
## boon tracker HUD can drop its icon.
func deactivate_boon(boon_id: String) -> void:
	if boon_id.is_empty() or not active_boons.has(boon_id):
		return
	active_boons.erase(boon_id)
	boon_deactivated.emit(boon_id)

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
	# Seeds never sit in the frog/chest inventory — they belong in the seed
	# reserves. Route any known seed id there and report any overflow back to
	# the caller so wave rewards still surface "you're capped" feedback.
	if seed_counts.has(item_id) or item_id == TOMATO_SEED_ID or item_id == CORN_SEED_ID or item_id == PUMPKIN_SEED_ID:
		return add_seeds(amount, item_id)
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
			available += MAX_STACK_SIZE
		elif item.get("id") == item_id:
			available += MAX_STACK_SIZE - int(item.get("quantity", 0))
	return available

func _add_item(inventory: Array[Dictionary], item_id: String, amount: int) -> bool:
	if amount <= 0:
		return false
	if _capacity_for(inventory, item_id) < amount:
		return false
	var remaining := amount
	for index in inventory.size():
		var item: Dictionary = inventory[index]
		if not item.is_empty() and item.get("id") == item_id and int(item.get("quantity", 0)) < MAX_STACK_SIZE:
			var space := MAX_STACK_SIZE - int(item["quantity"])
			var added := mini(space, remaining)
			item["quantity"] = int(item["quantity"]) + added
			remaining -= added
	for index in inventory.size():
		if remaining <= 0:
			break
		if inventory[index].is_empty():
			var added := mini(remaining, MAX_STACK_SIZE)
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
	var transfer_amount := int(source_item.get("quantity", 0))
	if destination == "altar":
		transfer_amount = mini(transfer_amount, maxi(0, tomato_goal - tomato_count))
		if transfer_amount <= 0:
			return false
	var destination_item: Dictionary = destination_inventory[destination_index]
	if destination_item.is_empty():
		destination_inventory[destination_index] = {"id": source_item.get("id"), "quantity": transfer_amount}
		source_item["quantity"] = int(source_item["quantity"]) - transfer_amount
		if source_item["quantity"] <= 0:
			source_inventory[source_index] = {}
	elif destination_item.get("id") == source_item.get("id") and int(destination_item.get("quantity", 0)) < MAX_STACK_SIZE:
		var space := MAX_STACK_SIZE - int(destination_item["quantity"])
		var moved := mini(space, transfer_amount)
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
