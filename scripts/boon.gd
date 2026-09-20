class_name Boon
extends StaticBody2D

## Base class for boon cards. Instances of `res://scenes/boon_card.tscn` (and
## anything that inherits it) get this script, giving them:
##   - rarity (drives draw odds in `round_end.gd`)
##   - hover lift + tint on mouse over
##   - `chosen` signal fired when the card is clicked
##
## To make a new boon:
##   1. Duplicate `scenes/boon_card.tscn` into `scenes/boons/<name>.tscn` (or
##      copy an existing boon like `cowboy_hat.tscn`).
##   2. In the inspector, set `rarity`.
##   3. Override the Item Name / Description / Bottom Text / Item Image nodes.
##   4. If the boon needs behavior, attach a subclass script that overrides
##      `apply_effect()` (see `scripts/boons/` for examples).
##
## The scene's resource path acts as the boon's unique ID. GameState records
## picked boons under that path so `round_end.gd` can filter already-owned
## boons out of future rerolls.

enum Rarity { COMMON, UNCOMMON, RARE, LEGENDARY }

signal chosen(boon: Boon)

@export var rarity: Rarity = Rarity.COMMON

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

## Applies this boon's effects. The base implementation does nothing; concrete
## boons override this method in a subclass script placed under
## `scripts/boons/`.
func apply_effect() -> void:
	pass
