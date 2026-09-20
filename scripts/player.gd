extends CharacterBody2D
@onready var player_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hat_sprite: Sprite2D = $HatSprite
@onready var propeller_hat_sprite: Sprite2D = $PropellerHatSprite

## Per-frame vertical offsets (in unscaled pixels) that match the frog head's
## bob across the six frames of `stompWalk`. Negative moves the hat up.
## Multiplied by `player_sprite.scale.y` at runtime so it stays in sync with
## the sprite's zoom. Tweak these values if the head art changes.
const HAT_BOB_OFFSETS := [0, 4, 0, -6, -6, -4]

## Per-frame horizontal lean offsets. Positive leans toward the direction the
## frog is currently facing (flipped automatically when `flip_h` is set).
## Multiplied by `player_sprite.scale.x` at runtime.
const HAT_LEAN_OFFSETS := [0, 1, 2, 3, 3, 2]

## Extra upward offset (unscaled pixels) applied while the frog is standing
## still. Compensates for the head sitting slightly higher in the idle pose.
const HAT_IDLE_LIFT := 2.0

## Base scale for the propeller hat. Held constant — no spin animation.
const PROPELLER_BASE_SCALE := Vector2(1.5, 1.5)

var _hat_base_x: float = 0.0
var _hat_base_y: float = 0.0

func _ready() -> void:
	queue_redraw()
	if hat_sprite != null:
		_hat_base_x = hat_sprite.position.x
		_hat_base_y = hat_sprite.position.y
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null:
		# Refresh cosmetic overlays whenever any boon activates. Cheap enough
		# to just re-check every field since boons resolve one-at-a-time.
		if not game_state.boon_activated.is_connected(_refresh_cosmetics):
			game_state.boon_activated.connect(_refresh_cosmetics)
		_refresh_cosmetics()
	if player_sprite != null and not player_sprite.frame_changed.is_connected(_on_frog_frame_changed):
		player_sprite.frame_changed.connect(_on_frog_frame_changed)
	_on_frog_frame_changed()

func _physics_process(_delta: float) -> void:
	if velocity.x > 0.0:
		player_sprite.flip_h = true
	elif velocity.x < 0.0:
		player_sprite.flip_h = false
	if hat_sprite != null and hat_sprite.visible:
		hat_sprite.flip_h = player_sprite.flip_h
		_update_hat_offset()
	if propeller_hat_sprite != null and propeller_hat_sprite.visible:
		_update_propeller_hat(_delta)

func _refresh_cosmetics(_boon_id: String = "") -> void:
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		return
	if hat_sprite != null:
		hat_sprite.visible = bool(game_state.wearing_cowboy_hat)
	if propeller_hat_sprite != null:
		propeller_hat_sprite.visible = bool(game_state.has_propeller_hat)
		if propeller_hat_sprite.visible:
			# Snap into the correct spot right away so it doesn't render at the
			# origin for one frame before `_physics_process` fires.
			_update_propeller_hat(0.0)

## Called every time the frog's animation frame changes. Updates the hat's
## y position so it rides along with the frog head's bob.
func _on_frog_frame_changed() -> void:
	_update_hat_offset()

## Positions the hat according to the current animation frame and facing.
## Splits the per-frame offset into a vertical bob and a horizontal lean; the
## lean is mirrored when the frog is facing left so it always tilts forward.
func _update_hat_offset() -> void:
	if hat_sprite == null or player_sprite == null:
		return
	var frame_index: int = player_sprite.frame
	if frame_index < 0 or frame_index >= HAT_BOB_OFFSETS.size():
		hat_sprite.position = Vector2(_hat_base_x, _hat_base_y)
		return
	var y_offset: float = float(HAT_BOB_OFFSETS[frame_index]) * player_sprite.scale.y
	var lean: float = float(HAT_LEAN_OFFSETS[frame_index]) * player_sprite.scale.x
	if not player_sprite.flip_h:
		lean = -lean
	if velocity.length_squared() < 1.0:
		# Idle: hold the hat a hair higher and skip the walking lean.
		y_offset -= HAT_IDLE_LIFT * player_sprite.scale.y
		lean = 0.0
	hat_sprite.position = Vector2(_hat_base_x + lean, _hat_base_y + y_offset)

## Positions the propeller hat over the frog's head using the same bob/lean
## curves as the cowboy hat. Same anchor so the two boons share placement
## math.
func _update_propeller_hat(_delta: float) -> void:
	if propeller_hat_sprite == null or player_sprite == null:
		return
	var frame_index: int = player_sprite.frame
	var y_offset: float = 0.0
	var lean: float = 0.0
	if frame_index >= 0 and frame_index < HAT_BOB_OFFSETS.size():
		y_offset = float(HAT_BOB_OFFSETS[frame_index]) * player_sprite.scale.y
		lean = float(HAT_LEAN_OFFSETS[frame_index]) * player_sprite.scale.x
		if not player_sprite.flip_h:
			lean = -lean
	if velocity.length_squared() < 1.0:
		y_offset -= HAT_IDLE_LIFT * player_sprite.scale.y
		lean = 0.0
	propeller_hat_sprite.position = Vector2(_hat_base_x + lean, _hat_base_y + y_offset)
	propeller_hat_sprite.scale = PROPELLER_BASE_SCALE
