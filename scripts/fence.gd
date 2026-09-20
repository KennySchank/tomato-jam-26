extends Node2D

## Fence — a single-hit-per-attack shield placed just south of the plot. While
## it has hit points, `main.gd` redirects incoming enemy projectiles at it
## instead of the tomatoes. Breaks after `max_hit_points` hits.
class_name Fence

@export var max_hit_points := 4

var hit_points := 4
var damage_tween: Tween

@onready var body: Node2D = $Body

func _ready() -> void:
	add_to_group("fence")
	hit_points = max_hit_points

func is_alive() -> bool:
	return hit_points > 0

## Called by the projectile on impact. Zero-argument to match the plant/enemy
## contract so `projectile.gd::_hit_target` can call it uniformly.
func take_damage() -> void:
	hit_points -= 1
	_play_damage_flash()
	if hit_points <= 0:
		_play_break_and_free()

func _play_damage_flash() -> void:
	if damage_tween != null and damage_tween.is_valid():
		damage_tween.kill()
	var start_color: Color = body.modulate
	damage_tween = create_tween()
	damage_tween.tween_property(body, "modulate", Color(1.6, 0.6, 0.6, 1.0), 0.05)
	damage_tween.tween_property(body, "modulate", start_color, 0.1)

func _play_break_and_free() -> void:
	# Fade out, then remove. No death animation asset yet.
	var fade := create_tween()
	fade.tween_property(body, "modulate:a", 0.0, 0.2)
	fade.finished.connect(queue_free)
