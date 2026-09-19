extends Area2D

@export var speed := 300.0

var target: Node2D

func set_target(new_target: Node2D) -> void:
	target = new_target

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		queue_free()
		return

	var offset := target.global_position - global_position
	if offset.length() <= 8.0:
		queue_free()
		return

	global_position += offset.normalized() * speed * delta
	rotation = offset.angle()
