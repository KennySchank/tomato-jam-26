extends Node2D

@export var growth_duration := 90.0

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:

	sprite.modulate = Color(0.9, 0.12, 0.12)
	var growth := create_tween()
	growth.tween_property(sprite, "modulate", Color(0.15, 0.9, 0.2), growth_duration)
