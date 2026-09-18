extends Node2D

const PLAYER_SPEED := 120.0

var destination := Vector2(576, 324)
var navigation_ready := false

@onready var player: CharacterBody2D = $Player
@onready var navigation_agent: NavigationAgent2D = $Player/NavigationAgent2D

func _ready() -> void:
	player.position = destination
	_navigation_setup.call_deferred()

func _navigation_setup() -> void:
	await get_tree().physics_frame
	navigation_ready = true
	navigation_agent.target_position = destination

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		destination = event.position
		if navigation_ready:
			navigation_agent.target_position = destination

func _physics_process(_delta: float) -> void:
	if not navigation_ready or navigation_agent.is_navigation_finished():
		player.velocity = Vector2.ZERO
		return

	var next_path_position := navigation_agent.get_next_path_position()
	var offset := next_path_position - player.global_position
	if offset.length() <= 1.0:
		player.velocity = Vector2.ZERO
		return

	player.velocity = offset.normalized() * PLAYER_SPEED
	player.move_and_slide()
