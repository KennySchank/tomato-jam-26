extends StaticBody2D

@onready var tomato_count_label: Label = $TomatoCount
@onready var timer_label: Label = $Timer
@onready var game_state: Node = get_node("/root/GameState")

var _wave_manager: WaveManager


func _ready() -> void:
	game_state.tomato_count_changed.connect(_on_tomato_count_changed)
	_refresh_tomato_label(game_state.tomato_count, game_state.tomato_goal)
	timer_label.text = "--:--"


## Called by main.gd after the WaveManager is present in the tree.
func bind_wave_manager(wave_manager: WaveManager) -> void:
	_wave_manager = wave_manager
	wave_manager.prep_phase_started.connect(_on_prep_phase_started)
	wave_manager.prep_time_changed.connect(_on_prep_time_changed)
	wave_manager.wave_started.connect(_on_wave_started)
	wave_manager.wave_progress_changed.connect(_on_wave_progress_changed)
	wave_manager.all_waves_completed.connect(_on_all_waves_completed)
	wave_manager.game_won.connect(_on_game_won)
	wave_manager.game_lost.connect(_on_game_lost)


func _on_tomato_count_changed(count: int, goal: int) -> void:
	_refresh_tomato_label(count, goal)


func _refresh_tomato_label(count: int, goal: int) -> void:
	tomato_count_label.text = "%d / %d" % [count, goal]


func _on_prep_phase_started(wave_index: int, prep_time: float) -> void:
	_set_timer_text("W%d prep %s [Space]" % [wave_index + 1, _format_seconds(prep_time)])


func _on_prep_time_changed(seconds_remaining: float) -> void:
	if _wave_manager == null:
		return
	_set_timer_text("W%d prep %s [Space]" % [_wave_manager.current_wave_index + 1, _format_seconds(seconds_remaining)])


func _on_wave_started(wave_index: int, total_enemies: int) -> void:
	_set_timer_text("W%d 0/%d" % [wave_index + 1, total_enemies])


func _on_wave_progress_changed(spawned: int, alive: int, total: int) -> void:
	if _wave_manager == null:
		return
	var defeated: int = spawned - alive
	_set_timer_text("W%d %d/%d" % [_wave_manager.current_wave_index + 1, defeated, total])


func _on_all_waves_completed() -> void:
	_set_timer_text("Cleared!")


func _on_game_won() -> void:
	_set_timer_text("You Win!")


func _on_game_lost() -> void:
	_set_timer_text("Defeated")


func _set_timer_text(value: String) -> void:
	timer_label.text = value


func _format_seconds(seconds: float) -> String:
	var seconds_left := int(ceil(seconds))
	return "%d:%02d" % [seconds_left / 60, seconds_left % 60]
