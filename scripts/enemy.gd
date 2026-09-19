extends CharacterBody2D

@export var speed := 45.0
@export var max_health := 30.0

var health := max_health

var route: Array[Vector2] = []
var route_index := 0

func _ready() -> void:
	add_to_group("enemies")
	health = max_health

func take_damage(amount: float) -> void:
	health = maxf(health - amount, 0.0)
	if health <= 0.0:
		queue_free()

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
