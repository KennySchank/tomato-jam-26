extends StaticBody2D

@export var countdown: float = 120.0

var time_remaining: float = 0.0

@onready var tomato_count_label: Label = $TomatoCount
@onready var timer_label: Label = $Timer
@onready var game_state: Node = get_node("/root/GameState")


func _ready() -> void:
	time_remaining = countdown
	game_state.tomato_count_changed.connect(_on_tomato_count_changed)
	_refresh_tomato_label(game_state.tomato_count, game_state.tomato_goal)
	_refresh_timer_label()


func _process(delta: float) -> void:
	if time_remaining > 0.0:
		time_remaining = max(0.0, time_remaining - delta)
		_refresh_timer_label()


func _on_tomato_count_changed(count: int, goal: int) -> void:
	_refresh_tomato_label(count, goal)


func _refresh_tomato_label(count: int, goal: int) -> void:
	tomato_count_label.text = "%d / %d" % [count, goal]


func _refresh_timer_label() -> void:
	var seconds_left := int(ceil(time_remaining))
	timer_label.text = "%d:%02d" % [seconds_left / 60, seconds_left % 60]
