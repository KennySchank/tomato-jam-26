extends CharacterBody2D
@onready var player_sprite = $AnimatedSprite2D

func _ready() -> void:
	queue_redraw()

func _physics_process(delta: float) -> void:
	if velocity.x > 0.0:
		player_sprite.flip_h = true
	elif velocity.x < 0.0:
		player_sprite.flip_h = false
