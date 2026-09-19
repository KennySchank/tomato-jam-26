extends Node2D

const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")

@export var range := 220.0
@export var fire_interval := 0.8

var fire_cooldown := 0.0

func _process(delta: float) -> void:
	fire_cooldown -= delta
	if fire_cooldown > 0.0:
		return

	var target := _find_target()
	if target == null:
		return

	var projectile := PROJECTILE_SCENE.instantiate()
	projectile.global_position = global_position
	projectile.set_target(target)
	get_parent().add_child(projectile)
	fire_cooldown = fire_interval

func _find_target() -> Node2D:
	var closest_target: Node2D = null
	var closest_distance := range
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(candidate) or not candidate is Node2D:
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance <= closest_distance:
			closest_distance = distance
			closest_target = candidate
	return closest_target
