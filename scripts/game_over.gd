extends StaticBody2D

const NEW_RECORD_COLOR := Color(0.35, 1.0, 0.55, 1.0)
const BEST_COLOR := Color(0.98, 0.85, 0.35, 1.0)
const CONTINUE_HOVER_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const CONTINUE_IDLE_COLOR := Color(0.86, 0.9, 0.94, 0.85)

## Small guard so the very click that killed the player doesn't immediately
## dismiss the game-over screen.
const INPUT_ARM_DELAY := 0.35

@onready var title_label: Label = $Title
@onready var record_line: Label = $RecordLine
@onready var run_tomatoes_label: Label = $RunTomatoes
@onready var run_boons_label: Label = $RunBoons
@onready var run_rounds_label: Label = $RunRounds
@onready var lifetime_tomatoes_label: Label = $LifetimeTomatoes
@onready var lifetime_boons_label: Label = $LifetimeBoons
@onready var lifetime_rounds_label: Label = $LifetimeRounds
@onready var deaths_label: Label = $Deaths
@onready var prompt: Label = $Prompt
@onready var continue_label: Label = $Continue
@onready var collision_shape: CollisionShape2D = $"Death Page Shape"

var _input_armed: bool = false
var _restart_in_flight: bool = false

func _ready() -> void:
	top_level = true
	z_index = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if collision_shape != null:
		collision_shape.disabled = true
	_configure_continue_label()

func _configure_continue_label() -> void:
	if continue_label == null:
		return
	continue_label.mouse_filter = Control.MOUSE_FILTER_STOP
	continue_label.modulate = CONTINUE_IDLE_COLOR
	if not continue_label.gui_input.is_connected(_on_continue_gui_input):
		continue_label.gui_input.connect(_on_continue_gui_input)
	if not continue_label.mouse_entered.is_connected(_on_continue_hover):
		continue_label.mouse_entered.connect(_on_continue_hover)
	if not continue_label.mouse_exited.is_connected(_on_continue_unhover):
		continue_label.mouse_exited.connect(_on_continue_unhover)

## Pauses gameplay and displays the game over overlay with the run summary and
## session-wide totals. Clicking `Continue` (or anywhere on the overlay after a
## brief arming delay) restarts the run from scratch.
##
## `report` is the `RunStats.DeathReport` snapshot produced by
## `RunStats.record_death()`. Callers should pass it in so the labels reflect
## the frozen post-run values (not the tracker's mutable state, which resets
## per-run counters immediately on death).
func show_game_over(report) -> void:
	_populate_labels(report)
	_center_in_viewport()
	visible = true
	_restart_in_flight = false
	# Keep collisions off - this is UI, not a physics obstacle.
	if collision_shape != null:
		collision_shape.disabled = true
	get_tree().paused = true
	_input_armed = false
	_arm_input_after_delay()

func _arm_input_after_delay() -> void:
	# Uses an unpaused timer so the guard still counts down while the tree is
	# paused underneath this overlay.
	var timer := get_tree().create_timer(INPUT_ARM_DELAY, true, false, true)
	await timer.timeout
	_input_armed = true

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not _input_armed:
		return
	# Any click anywhere on the overlay restarts, matching the "Continue..."
	# prompt. Keyboard confirm also works so this is reachable without a mouse.
	if event is InputEventMouseButton and event.pressed:
		_restart_game()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			_restart_game()
			get_viewport().set_input_as_handled()

func _on_continue_gui_input(event: InputEvent) -> void:
	if not _input_armed:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_restart_game()
		get_viewport().set_input_as_handled()

func _on_continue_hover() -> void:
	if continue_label != null:
		continue_label.modulate = CONTINUE_HOVER_COLOR

func _on_continue_unhover() -> void:
	if continue_label != null:
		continue_label.modulate = CONTINUE_IDLE_COLOR

## Fully resets the run: clears `GameState` (which wipes inventories, tomato
## counters, and boon-granted items sitting in storage) and reloads the main
## scene so the `WaveManager` rebuilds at wave 0 (its easiest difficulty).
## Lifetime session stats on `RunStats` are intentionally preserved.
func _restart_game() -> void:
	if _restart_in_flight:
		return
	_restart_in_flight = true
	visible = false
	get_tree().paused = false
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null and game_state.has_method("reset_run"):
		game_state.reset_run()
	get_tree().reload_current_scene()

func _populate_labels(report) -> void:
	if report == null:
		_populate_default_labels()
		return
	run_tomatoes_label.text = "Tomatoes: %d" % report.tomatoes_this_run
	run_boons_label.text = "Boons: %d" % report.boons_this_run
	run_rounds_label.text = "Rounds: %d" % report.rounds_this_run
	lifetime_tomatoes_label.text = "Total tomatoes: %d" % report.lifetime_tomatoes
	lifetime_boons_label.text = "Total boons: %d" % report.lifetime_boons
	lifetime_rounds_label.text = "Total rounds: %d" % report.lifetime_rounds
	deaths_label.text = "Deaths: %d" % report.deaths_total
	if report.beat_record:
		record_line.text = "★ NEW RECORD: %d tomatoes! ★" % report.new_best
		record_line.modulate = NEW_RECORD_COLOR
	else:
		record_line.text = "Best run: %d tomatoes" % report.new_best
		record_line.modulate = BEST_COLOR

## Fallback used if the overlay is somehow shown without a DeathReport — reads
## whatever is currently on the RunStats autoload so the screen is never blank.
func _populate_default_labels() -> void:
	var run_stats := get_node_or_null("/root/RunStats")
	if run_stats == null:
		return
	run_tomatoes_label.text = "Tomatoes: %d" % run_stats.current_run_tomatoes
	run_boons_label.text = "Boons: %d" % run_stats.current_run_boons
	run_rounds_label.text = "Rounds: %d" % run_stats.current_run_rounds
	lifetime_tomatoes_label.text = "Total tomatoes: %d" % run_stats.lifetime_tomatoes_collected
	lifetime_boons_label.text = "Total boons: %d" % run_stats.lifetime_boons_collected
	lifetime_rounds_label.text = "Total rounds: %d" % run_stats.lifetime_rounds_completed
	deaths_label.text = "Deaths: %d" % run_stats.deaths
	record_line.text = "Best run: %d tomatoes" % run_stats.best_tomatoes_in_run
	record_line.modulate = BEST_COLOR

func _center_in_viewport() -> void:
	var viewport_size := get_viewport_rect().size
	global_position = viewport_size * 0.5 - Vector2(370.0, 287.0)
