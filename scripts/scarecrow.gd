extends Node2D

## Scarecrow — a single-tile shield placed on the plot's center-most tomato
## plot. Absorbs any enemy attack aimed at the plot until its hit points are
## depleted.
class_name Scarecrow

@export var max_hit_points := 5

## Path of the boon scene that spawned this scarecrow. Set by `main.gd` at
## spawn time. Cleared from `GameState.active_boons` when the scarecrow breaks.
var owning_boon_id: String = ""

var hit_points := 5
var damage_tween: Tween

@onready var body: Node2D = $Body

func _ready() -> void:
	add_to_group("scarecrow")
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
	fade.finished.connect(_on_break_finished)

func _on_break_finished() -> void:
	if not owning_boon_id.is_empty():
		var game_state := get_node_or_null("/root/GameState")
		if game_state != null:
			game_state.deactivate_boon(owning_boon_id)
	queue_free()
