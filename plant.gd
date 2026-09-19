extends Node2D

@export var growth_duration := 90.0

@onready var sway_pivot: Node2D = $SwayPivot
@onready var sprite: Sprite2D = $SwayPivot/Sprite2D

func _ready() -> void:
	sprite.modulate = Color(0.9, 0.12, 0.12)
	var growth := create_tween()
	growth.tween_property(sprite, "modulate", Color(0.15, 0.9, 0.2), growth_duration)

	var sway_duration := randf_range(1.0, 1.4)
	var sway_amount := randf_range(0.025, 0.04)
	var sway := create_tween().set_loops()
	sway.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sway.tween_property(sway_pivot, "rotation", sway_amount, sway_duration)
	sway.parallel().tween_property(sway_pivot, "skew", sway_amount * 0.55, sway_duration)
	sway.tween_property(sway_pivot, "rotation", -sway_amount, sway_duration)
	sway.parallel().tween_property(sway_pivot, "skew", -sway_amount * 0.55, sway_duration)
