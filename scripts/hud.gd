extends CanvasLayer

@export var countdown: float = 120.0
@export var tomato_goal: int = 100

var tomato_count: int = 0
var time_remaining: float = 0.0

@onready var tomato_value: Label = %TomatoValue
@onready var timer_value: Label = %TimerValue


func _ready() -> void:
	time_remaining = countdown
	_refresh()


func _process(delta: float) -> void:
	if time_remaining > 0.0:
		time_remaining = max(0.0, time_remaining - delta)
		_refresh()


func set_tomato_count(count: int) -> void:
	tomato_count = count
	_refresh()


func _refresh() -> void:
	tomato_value.text = str(tomato_goal - tomato_count)
	var seconds_left := int(ceil(time_remaining))
	timer_value.text = "%d:%02d" % [seconds_left / 60, seconds_left % 60]
