extends Node2D

@export var radius := 220.0
@export var fill_color := Color(0.95, 0.75, 0.2, 0.12)
@export var outline_color := Color(1.0, 0.82, 0.25, 0.85)
@export var outline_width := 2.0

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, fill_color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 96, outline_color, outline_width, true)
