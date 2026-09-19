extends Area2D

@export var speed := 300.0
@export var damage := 10.0

var direction := Vector2.RIGHT

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func set_target(new_target: Node2D) -> void:
	if is_instance_valid(new_target):
		direction = global_position.direction_to(new_target.global_position)
		rotation = direction.angle()

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		body.call("take_damage", damage)
		queue_free()
