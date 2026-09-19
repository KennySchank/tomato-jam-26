extends CharacterBody2D

@export var speed := 45.0
@export var max_health := 30.0

var health := max_health

var route: Array[Vector2] = []
var route_index := 0
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
