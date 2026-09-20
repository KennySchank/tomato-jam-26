extends StaticBody2D

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const FROG_DRIFT_DISTANCE := 120.0
const FROG_DRIFT_DURATION := 4.0
const FROG_PAUSE_CHANCE := 0.5
const FROG_PAUSE_MIN := 1.0
const FROG_PAUSE_MAX := 2.5
const FROG_IDLE_FRAME := 0

@onready var shadow_frog: AnimatedSprite2D = $"Screen Background/Shadow Frog"

func _ready() -> void:
	_queue_next_drift_segment(true)

func _queue_next_drift_segment(going_right: bool) -> void:
	if shadow_frog == null:
		return
	shadow_frog.flip_h = going_right
	shadow_frog.play()

	var start_x := shadow_frog.position.x
	var target_x := start_x + (FROG_DRIFT_DISTANCE if going_right else -FROG_DRIFT_DISTANCE)

	var tween := create_tween()
	tween.tween_property(shadow_frog, "position:x", target_x, FROG_DRIFT_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if randf() < FROG_PAUSE_CHANCE:
		var pause_time := randf_range(FROG_PAUSE_MIN, FROG_PAUSE_MAX)
		tween.tween_callback(_stop_frog_hopping)
		tween.tween_interval(pause_time)

	tween.tween_callback(_queue_next_drift_segment.bind(not going_right))

func _stop_frog_hopping() -> void:
	if shadow_frog == null:
		return
	shadow_frog.stop()
	shadow_frog.frame = FROG_IDLE_FRAME

func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)
