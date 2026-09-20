extends Node2D

## Pumpkin Wall — a path blocker placed on the last tile of the shortest enemy
## route. Enemies that reach the end stop and attack it (via the standard
## `_on_enemy_attack_requested` flow in main.gd) instead of the tomato plot.
class_name PumpkinWall

@export var max_hit_points := 10

var hit_points := 10
var damage_tween: Tween

@onready var body: Node2D = $Body

func _ready() -> void:
	add_to_group("pumpkin_wall")
	hit_points = max_hit_points

func is_alive() -> bool:
	return hit_points > 0

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
	var fade := create_tween()
	fade.tween_property(body, "modulate:a", 0.0, 0.2)
	fade.finished.connect(queue_free)
