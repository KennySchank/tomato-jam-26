extends Area2D

@export var speed := 300.0
@export var damage := 10.0
@export var spin_speed := 12.0

var direction := Vector2.RIGHT
var target: Node2D
var target_position := Vector2.ZERO
var impact_callback: Callable
var has_target_position := false
var source: Node
var spin_rotation := 0.0

func set_source(new_source: Node) -> void:
	source = new_source

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Wheelbarrow boon scales every projectile's damage once at spawn so live
	# projectiles keep the value they were fired with even if the multiplier
	# changes mid-flight.
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null:
		damage *= float(game_state.tower_damage_multiplier)

func set_target(new_target: Node2D) -> void:
	target = new_target
	if is_instance_valid(new_target):
		set_target_position(new_target.global_position)

func set_target_position(new_target_position: Vector2) -> void:
	target_position = new_target_position
	has_target_position = true
	direction = global_position.direction_to(target_position)
	rotation = direction.angle() + spin_rotation

func _physics_process(delta: float) -> void:
	spin_rotation += spin_speed * delta
	if is_instance_valid(target):
		target_position = target.global_position
		direction = global_position.direction_to(target_position)
		rotation = direction.angle() + spin_rotation
	if has_target_position and global_position.distance_to(target_position) <= speed * delta:
		_hit_target()
		return
	global_position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body == source:
		return
	if body.is_in_group("enemies"):
		body.call("take_damage", damage)
		queue_free()

func _hit_target() -> void:
	if is_instance_valid(target) and target.has_method("take_damage"):
		target.take_damage()
	if impact_callback.is_valid():
		impact_callback.call()
	queue_free()
