extends StaticBody2D

@onready var tomato_count_label: Label = $TomatoCount
@onready var timer_label: Label = $Timer
@onready var game_state: Node = get_node("/root/GameState")

var _wave_manager: WaveManager
var _run_ended: bool = false


func _ready() -> void:
	game_state.tomato_count_changed.connect(_on_tomato_count_changed)
	_refresh_tomato_label(game_state.tomato_count, game_state.tomato_goal)
	timer_label.text = "--:--"


## Called by main.gd after the WaveManager is present in the tree.
func bind_wave_manager(wave_manager: WaveManager) -> void:
	_wave_manager = wave_manager
	wave_manager.harvest_time_changed.connect(_on_harvest_time_changed)
	wave_manager.game_lost.connect(_on_game_lost)
	_on_harvest_time_changed(wave_manager.harvest_time_limit)


func _on_tomato_count_changed(count: int, goal: int) -> void:
	_refresh_tomato_label(count, goal)


func _refresh_tomato_label(count: int, goal: int) -> void:
	tomato_count_label.text = "%d / %d" % [count, goal]


func _on_harvest_time_changed(seconds_remaining: float) -> void:
	if _run_ended:
		return
	timer_label.text = _format_seconds(seconds_remaining)
	timer_label.add_theme_font_size_override("font_size", 16)

func _on_game_lost() -> void:
	_run_ended = true
	timer_label.add_theme_font_size_override("font_size", 12)
	timer_label.text = "Defeated"


func _format_seconds(seconds: float) -> String:
	var seconds_left := int(ceil(seconds))
	return "%d:%02d" % [seconds_left / 60, seconds_left % 60]
