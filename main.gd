extends Node2D

const PLAYER_SPEED := 120.0
# The 0-indexed frame (0, 1, 2, or 3) to show when stopped
const IDLE_FRAME: int = 1

var destination := Vector2(576, 324)

@onready var player: CharacterBody2D = $Player
@onready var sprite: AnimatedSprite2D = $Player/AnimatedSprite2D

func _ready() -> void:
	player.position = destination

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		destination = event.position

func _physics_process(_delta: float) -> void:
	var offset := destination - player.position
	if offset.length() > 4.0:
		player.velocity = offset.normalized() * PLAYER_SPEED
		player.move_and_slide()
		
		# Play the stompWalk animation while moving
		if not sprite.is_playing() or sprite.animation != "stompWalk":
			sprite.play("stompWalk")
	else:
		player.velocity = Vector2.ZERO
		
		# Freeze on the chosen frame when stopped
		sprite.stop()
		sprite.frame = IDLE_FRAME
