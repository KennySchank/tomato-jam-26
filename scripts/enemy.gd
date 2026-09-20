extends CharacterBody2D

signal attack_requested(global_position: Vector2)

@export var speed := 45.0
@export var max_health := 30.0
@export var attack_interval := 1.0
@export var turn_speed_deg := 540.0
## Angle the sprite art naturally faces when unrotated.
## 0 = right, 90 = down, -90 = up, 180 = left.
@export var sprite_facing_deg := -90.0

var health := max_health

var route: Array[Vector2] = []
var route_index := 0
var attack_cooldown := 0.0
var damage_tween: Tween

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var sprite_position := sprite.position
@onready var sprite_modulate := sprite.modulate

func _ready() -> void:
	add_to_group("enemies")
	health = max_health

func take_damage(amount: float) -> void:
	health = maxf(health - amount, 0.0)
	_play_damage_animation()
	if health <= 0.0:
		queue_free()

func apply_difficulty(speed_multiplier: float, health_multiplier: float, attack_interval_multiplier: float) -> void:
	speed *= speed_multiplier
	max_health *= health_multiplier
	attack_interval = maxf(0.25, attack_interval * attack_interval_multiplier)
	health = max_health

func _play_damage_animation() -> void:
	if damage_tween != null and damage_tween.is_valid():
		damage_tween.kill()
	sprite.position = sprite_position
	sprite.modulate = sprite_modulate
	damage_tween = create_tween()
	damage_tween.tween_property(sprite, "modulate", Color(1.0, 0.15, 0.15), 0.04)
	damage_tween.parallel().tween_property(sprite, "position", sprite_position + Vector2(2.0, 0.0), 0.025)
	damage_tween.tween_property(sprite, "position", sprite_position + Vector2(-2.0, 0.0), 0.05)
	damage_tween.tween_property(sprite, "position", sprite_position, 0.025)
	damage_tween.parallel().tween_property(sprite, "modulate", sprite_modulate, 0.08)

func set_route(new_route: Array[Vector2]) -> void:
	route = new_route
	route_index = 0
	attack_cooldown = 0.0
	if route.size() > 0:
		global_position = route[0]
		# Face the first segment immediately so we don't whip around on spawn.
		if route.size() > 1:
			var initial_dir := route[1] - route[0]
			if not initial_dir.is_zero_approx():
				sprite.rotation = initial_dir.angle() - deg_to_rad(sprite_facing_deg)

func _physics_process(_delta: float) -> void:
	if route_index >= route.size():
		velocity = Vector2.ZERO
		_process_endpoint_attack(_delta)
		return

	var offset := route[route_index] - global_position
	if offset.length() <= 2.0:
		route_index += 1
		if route_index >= route.size():
			velocity = Vector2.ZERO
			_process_endpoint_attack(_delta)
			return
		offset = route[route_index] - global_position

	velocity = offset.normalized() * speed
	move_and_slide()
	_face_movement_direction(_delta)

func _face_movement_direction(delta: float) -> void:
	if velocity.is_zero_approx():
		return
	var target_angle := velocity.angle() - deg_to_rad(sprite_facing_deg)
	var turn_rate := deg_to_rad(turn_speed_deg)
	sprite.rotation = rotate_toward(sprite.rotation, target_angle, turn_rate * delta)

func _process_endpoint_attack(delta: float) -> void:
	attack_cooldown -= delta
	if attack_cooldown > 0.0:
		return
	attack_requested.emit(global_position)
	attack_cooldown = attack_interval
