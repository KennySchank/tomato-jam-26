extends CharacterBody2D

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	# Simple player badge behind the Godot icon.
	draw_circle(Vector2.ZERO, 29.0, Color(0.08, 0.12, 0.18, 0.82))
	draw_arc(Vector2.ZERO, 29.0, 0.0, TAU, 40, Color("#f2c66d"), 3.0)
