extends Node2D

const PLAYER_SPEED := 120.0

var destination := Vector2(576, 324)

@onready var player: CharacterBody2D = $Player

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
	else:
		player.velocity = Vector2.ZERO
