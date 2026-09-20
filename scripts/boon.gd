class_name Boon
extends StaticBody2D

## Base class for boon cards. Instances of `res://scenes/boon_card.tscn` (and
## anything that inherits it) get this script, giving them:
##   - rarity + data-driven effect knobs
##   - hover lift + tint on mouse over
##   - `chosen` signal fired when the card is clicked
##
## To make a new boon:
##   1. Duplicate `scenes/boon_card.tscn` into `scenes/boons/<name>.tscn` (or
##      copy an existing boon like `cowboy_hat.tscn`).
##   2. In the inspector, set `rarity` and any effect knobs (e.g. `bonus_seeds`).
##   3. Override the Item Name / Description / Bottom Text / Item Image nodes.
##
## For effects that don't fit the built-in knobs, extend this script (see
## `scripts/boons/cowboy_hat.gd` for the pattern) and override `apply_effect()`.

enum Rarity { COMMON, UNCOMMON, RARE, LEGENDARY }

signal chosen(boon: Boon)

@export var rarity: Rarity = Rarity.COMMON

@export_group("Effects")
## Seeds granted when this boon is chosen. Filled into the frog inventory
## first, then the chest. Overflow is dropped with a warning.
@export_range(0, 100) var bonus_seeds: int = 0

const HOVER_LIFT := Vector2(0, -8)
const HOVER_TINT := Color(1.15, 1.15, 1.05, 1.0)
const HOVER_Z := 10

var _base_position: Vector2 = Vector2.ZERO
var _base_modulate: Color = Color.WHITE
var _base_z_index: int = 0
var _hover_state_captured: bool = false

func _ready() -> void:
	input_pickable = true
	# Position may still be assigned after _ready in some flows; capture on the
	# next idle frame so the hover lift restores to the correct spot.
	call_deferred("_capture_hover_baseline")
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)

func _capture_hover_baseline() -> void:
	_base_position = position
	_base_modulate = modulate
	_base_z_index = z_index
	_hover_state_captured = true

func _input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		chosen.emit(self)
		get_viewport().set_input_as_handled()

func _on_mouse_entered() -> void:
	if not _hover_state_captured:
		_capture_hover_baseline()
	position = _base_position + HOVER_LIFT
	modulate = HOVER_TINT
	z_index = _base_z_index + HOVER_Z

func _on_mouse_exited() -> void:
	if not _hover_state_captured:
		return
	position = _base_position
	modulate = _base_modulate
	z_index = _base_z_index

## Applies this boon's effects. Data-driven boons should just tweak the
## exported effect knobs; boons with bespoke logic should override this method
## in a subclass and call `super.apply_effect()` if they still want the
## exported knobs to fire.
func apply_effect() -> void:
	if bonus_seeds > 0:
		var game_state := get_node_or_null("/root/GameState")
		if game_state != null and game_state.has_method("grant_item"):
			var leftover: int = game_state.grant_item(game_state.SEED_ITEM_ID, bonus_seeds)
			if leftover > 0:
				push_warning("Boon reward overflow: %d seeds could not be stored." % leftover)
