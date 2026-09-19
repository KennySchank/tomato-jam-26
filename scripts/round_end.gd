extends StaticBody2D

signal closed

@onready var prompt: Label = $Prompt
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	# Keep this overlay above world content and drive its own transform so the
	# camera/parent don't shift it.
	top_level = true
	z_index = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	collision_shape.disabled = true

## Pauses gameplay and shows the round-end overlay centered in the viewport.
func show_round_end() -> void:
	_center_in_viewport()
	visible = true
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
	if event is InputEventMouseButton and event.pressed:
		_close()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		_close()
		get_viewport().set_input_as_handled()

func _close() -> void:
	visible = false
	collision_shape.disabled = true
	get_tree().paused = false
	closed.emit()
