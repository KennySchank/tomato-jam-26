extends CharacterBody2D

@export var speed := 75.0

var route: Array[Vector2] = []
var route_index := 0

func set_route(new_route: Array[Vector2]) -> void:
	route = new_route
	route_index = 0
	if route.size() > 0:
		global_position = route[0]

func _physics_process(_delta: float) -> void:
	if route_index >= route.size():
		velocity = Vector2.ZERO
		return

	var offset := route[route_index] - global_position
	if offset.length() <= 2.0:
		route_index += 1
		if route_index >= route.size():
			velocity = Vector2.ZERO
			return
		offset = route[route_index] - global_position

	velocity = offset.normalized() * speed
	move_and_slide()
