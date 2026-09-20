extends Node2D

const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")

@export var range := 220.0
@export var fire_interval := 0.8

var fire_cooldown := 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var idle_animation := &"idle"
var shooting_animation := &"shooting"

func _ready() -> void:
	idle_animation = _find_animation([&"Idle", &"idle"])
	shooting_animation = _find_animation([&"Shooting", &"shooting", &"Shoot", &"shoot", &"Attack", &"attack"])
	if shooting_animation != &"":
		sprite.sprite_frames.set_animation_loop(shooting_animation, false)
	if idle_animation != &"":
		$Sprite2D.visible = false
		_play_idle()
	else:
		push_warning("Tower has no Idle animation frames; showing fallback sprite.")

func _process(delta: float) -> void:
	fire_cooldown -= delta
	if fire_cooldown > 0.0:
		return

	var target := _find_target()
	if target == null:
		return

	sprite.flip_h = target.global_position.x < global_position.x
	var projectile := PROJECTILE_SCENE.instantiate()
	projectile.global_position = global_position
	projectile.set_target(target)
	get_parent().add_child(projectile)
	_play_shooting()
	fire_cooldown = fire_interval

func _find_animation(names: Array[StringName]) -> StringName:
	for animation_name in names:
		if sprite.sprite_frames.has_animation(animation_name):
			return animation_name
	return &""

func _play_idle() -> void:
	if idle_animation != &"":
		sprite.play(idle_animation)
	else:
		sprite.stop()

func _play_shooting() -> void:
	if shooting_animation != &"":
		sprite.play(shooting_animation)

func _on_animated_sprite_2d_animation_finished() -> void:
	if sprite.animation == shooting_animation:
		_play_idle()

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
