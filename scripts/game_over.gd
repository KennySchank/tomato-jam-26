extends StaticBody2D

@onready var title_label: Label = $Title
@onready var total_label: Label = $TotalCollected
@onready var prompt: Label = $Prompt
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	top_level = true
	z_index = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	collision_shape.disabled = true

## Pauses gameplay and displays the game over overlay with the run's cumulative
## tomato tally. This screen cannot be dismissed; the run is over.
func show_game_over(total_tomatoes: int) -> void:
	total_label.text = "Tomatoes collected: %d" % total_tomatoes
	_center_in_viewport()
	visible = true
	# Keep collisions off - this is UI, not a physics obstacle.
	collision_shape.disabled = true
	get_tree().paused = true

func _center_in_viewport() -> void:
	var viewport_size := get_viewport_rect().size
	global_position = viewport_size * 0.5 - Vector2(370.0, 287.0)
