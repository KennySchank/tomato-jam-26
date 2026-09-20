extends StaticBody2D

signal closed

## Folder scanned for boon scenes. Every `.tscn` in here is treated as a valid
## boon and becomes eligible for the random pick shown at round end.
const BOONS_DIR := "res://scenes/boons"

## Names of the placeholder BoonCard nodes authored in `round_end.tscn`. Their
## positions are captured on _ready and reused every round as slot anchors.
const BOON_SLOT_NAMES: Array[String] = ["BoonCard1", "BoonCard2", "BoonCard3"]

## Relative draw weight per rarity. Higher = shows up more often. Tune here to
## rebalance without touching any scene files.
const RARITY_WEIGHTS := {
	Boon.Rarity.COMMON: 60,
	Boon.Rarity.UNCOMMON: 30,
	Boon.Rarity.RARE: 9,
	Boon.Rarity.LEGENDARY: 1,
}

@onready var collision_shape: CollisionShape2D = $ABCollision

# Each entry: { "packed": PackedScene, "rarity": int }.
var _boon_entries: Array = []
var _slot_positions: Array[Vector2] = []
var _active_boons: Array[Node] = []

func _ready() -> void:
	# Keep this overlay above world content and drive its own transform so the
	# camera/parent don't shift it.
	top_level = true
	z_index = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if collision_shape != null:
		collision_shape.disabled = true
	_cache_boon_scenes()
	_cache_slot_positions_and_remove_placeholders()

## Pauses gameplay, rerolls the random boon lineup, and shows the round-end
## overlay centered in the viewport.
func show_round_end() -> void:
	_center_in_viewport()
	_reroll_boons()
	visible = true
	if collision_shape != null:
		collision_shape.disabled = true
	get_tree().paused = true

func _center_in_viewport() -> void:
	var viewport_size := get_viewport_rect().size
	# The scene's sprite/collision are authored offset from the root; anchor the
	# root to the viewport center so the sprite sits roughly in the middle.
	global_position = viewport_size * 0.5 - Vector2(370.0, 287.0)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	# When boons are on screen the player must click one to advance; the boon's
	# own `chosen` signal will drive `_close()`. Only fall back to any-click
	# dismissal when no boons exist (e.g. empty catalogue in development).
	if not _active_boons.is_empty():
		return
	if event is InputEventMouseButton and event.pressed:
		_close()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		_close()
		get_viewport().set_input_as_handled()

func _close() -> void:
	visible = false
	if collision_shape != null:
		collision_shape.disabled = true
	# Free the current boon cards immediately so their colliders can't keep
	# intercepting mouse events after the overlay hides. `_reroll_boons()`
	# will spawn fresh instances next round.
	_clear_active_boons()
	get_tree().paused = false
	closed.emit()

func _clear_active_boons() -> void:
	for node in _active_boons:
		if is_instance_valid(node):
			node.queue_free()
	_active_boons.clear()

## Scans the boons folder once and caches every PackedScene it finds along with
## its authored rarity. Handles the `.remap` suffix that Godot appends in
## exported builds. Probes each scene by instantiating it briefly (never added
## to the tree, so `_ready` doesn't fire) to read the `rarity` export.
func _cache_boon_scenes() -> void:
	_boon_entries.clear()
	var dir := DirAccess.open(BOONS_DIR)
	if dir == null:
		push_warning("RoundEnd: could not open boons folder %s" % BOONS_DIR)
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var candidate: String = file_name
			if candidate.ends_with(".remap"):
				candidate = candidate.get_basename()
			if candidate.ends_with(".tscn"):
				var res_path := "%s/%s" % [BOONS_DIR, candidate]
				var packed: PackedScene = load(res_path)
				if packed != null:
					var rarity_val: int = _probe_rarity(packed)
					_boon_entries.append({"packed": packed, "rarity": rarity_val})
		file_name = dir.get_next()
	dir.list_dir_end()

func _probe_rarity(packed: PackedScene) -> int:
	var probe: Node = packed.instantiate()
	var rarity_val: int = Boon.Rarity.COMMON
	if probe is Boon:
		rarity_val = (probe as Boon).rarity
	# The probe never entered the tree, so free it immediately rather than
	# waiting for the deferred queue.
	probe.free()
	return rarity_val

## Records where each authored boon-card slot sits, then removes the
## placeholder cards. The recorded positions are reused every round to spawn
## fresh, randomly-chosen boon instances at the same spots.
func _cache_slot_positions_and_remove_placeholders() -> void:
	_slot_positions.clear()
	for slot_name in BOON_SLOT_NAMES:
		var slot: Node2D = get_node_or_null(slot_name) as Node2D
		if slot == null:
			continue
		_slot_positions.append(slot.position)
		slot.queue_free()

## Frees the previous round's boon nodes and instances a fresh random selection
## — one boon per slot, using rarity-weighted draws without replacement.
func _reroll_boons() -> void:
	_clear_active_boons()
	if _boon_entries.is_empty() or _slot_positions.is_empty():
		return
	var picks: Array[PackedScene] = _pick_random_boons(_slot_positions.size())
	for i in picks.size():
		var packed: PackedScene = picks[i]
		var instance: Node = packed.instantiate()
		# Assign position before add_child so the Boon's hover baseline is
		# captured against the correct spot.
		if instance is Node2D:
			(instance as Node2D).position = _slot_positions[i]
		add_child(instance)
		if instance is Boon:
			(instance as Boon).chosen.connect(_on_boon_chosen)
		_active_boons.append(instance)

## Draws `count` boons from the cache using rarity weights. Sampling is
## without-replacement within a single reroll; if the pool empties before we've
## filled every slot (fewer boons in catalogue than slots on screen) the pool
## refills so no slot is ever blank.
func _pick_random_boons(count: int) -> Array[PackedScene]:
	var results: Array[PackedScene] = []
	if _boon_entries.is_empty():
		return results
	var pool: Array = _boon_entries.duplicate()
	for _i in count:
		if pool.is_empty():
			pool = _boon_entries.duplicate()
		var pick_index: int = _weighted_pick_index(pool)
		results.append(pool[pick_index]["packed"])
		pool.remove_at(pick_index)
	return results

func _weighted_pick_index(pool: Array) -> int:
	var total_weight: int = 0
	for entry in pool:
		total_weight += _weight_for(entry["rarity"])
	if total_weight <= 0:
		return randi() % pool.size()
	var roll: int = randi() % total_weight
	var accumulator: int = 0
	for i in pool.size():
		accumulator += _weight_for(pool[i]["rarity"])
		if roll < accumulator:
			return i
	return pool.size() - 1

func _weight_for(rarity_val: int) -> int:
	return int(RARITY_WEIGHTS.get(rarity_val, 1))

func _on_boon_chosen(boon: Boon) -> void:
	if boon != null and boon.has_method("apply_effect"):
		boon.apply_effect()
	var run_stats := get_node_or_null("/root/RunStats")
	if run_stats != null and run_stats.has_method("record_boon_collected"):
		run_stats.record_boon_collected()
	_close()
