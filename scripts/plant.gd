extends Node2D

@export var growth_duration := 10.0

var is_mature := false
var damage_tween: Tween
# Plants take 1 hit to die by default. Watering Can bumps this by 1 for future
# plants via `GameState.plant_bonus_hp`.
var hit_points := 1

@onready var sway_pivot: Node2D = $SwayPivot
@onready var sprite: AnimatedSprite2D = $SwayPivot/AnimatedSprite2D
@onready var sprite_position := sprite.position

func _ready() -> void:
	sprite.stop()
	sprite.frame = 0
	# Fertilizer boon lives in GameState.plant_growth_multiplier. Dividing here
	# gives faster growth without changing this scene's authored default.
	var multiplier := 1.0
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null and float(game_state.plant_growth_multiplier) > 0.0:
		multiplier = float(game_state.plant_growth_multiplier)
	var effective_duration: float = growth_duration / multiplier
	if game_state != null:
		hit_points = 1 + int(game_state.plant_bonus_hp)
	var growth := create_tween()
	growth.finished.connect(_on_growth_finished)
	growth.tween_method(_update_growth_sprite, 0.0, 1.0, effective_duration)

	var sway_duration := randf_range(1.0, 1.4)
	var sway_amount := randf_range(0.025, 0.04)
	var sway := create_tween().set_loops()
	sway.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sway.tween_property(sway_pivot, "rotation", sway_amount, sway_duration)
	sway.parallel().tween_property(sway_pivot, "skew", sway_amount * 0.55, sway_duration)
	sway.tween_property(sway_pivot, "rotation", -sway_amount, sway_duration)
	sway.parallel().tween_property(sway_pivot, "skew", -sway_amount * 0.55, sway_duration)

func _update_growth_sprite(progress: float) -> void:
	var frame_count := sprite.sprite_frames.get_frame_count(sprite.animation)
	if frame_count <= 1:
		return
	var next_frame := mini(int(progress * float(frame_count)), frame_count - 1)
	sprite.frame = next_frame
	if next_frame == frame_count - 1:
		is_mature = true

func _on_growth_finished() -> void:
	is_mature = true

func can_harvest() -> bool:
	return is_mature

func is_alive() -> bool:
	return hit_points > 0

func take_damage() -> void:
	hit_points -= 1
	if hit_points > 0:
		_play_damage_flash()
	else:
		_play_damage_death()

func _play_damage_flash() -> void:
	# Non-fatal hit: same shake/tint as death, minus the queue_free at the end.
	if damage_tween != null and damage_tween.is_valid():
		damage_tween.kill()
	sprite.position = sprite_position
	var original_modulate := sprite.modulate
	damage_tween = create_tween()
	damage_tween.tween_property(sprite, "modulate", Color(1.0, 0.15, 0.15), 0.04)
	damage_tween.parallel().tween_property(sprite, "position", sprite_position + Vector2(2.0, 0.0), 0.025)
	damage_tween.tween_property(sprite, "position", sprite_position + Vector2(-2.0, 0.0), 0.05)
	damage_tween.tween_property(sprite, "position", sprite_position, 0.025)
	damage_tween.parallel().tween_property(sprite, "modulate", original_modulate, 0.08)

func _play_damage_death() -> void:
	if damage_tween != null and damage_tween.is_valid():
		damage_tween.kill()
	sprite.position = sprite_position
	var original_modulate := sprite.modulate
	damage_tween = create_tween()
	damage_tween.tween_property(sprite, "modulate", Color(1.0, 0.15, 0.15), 0.04)
	damage_tween.parallel().tween_property(sprite, "position", sprite_position + Vector2(2.0, 0.0), 0.025)
	damage_tween.tween_property(sprite, "position", sprite_position + Vector2(-2.0, 0.0), 0.05)
	damage_tween.tween_property(sprite, "position", sprite_position, 0.025)
	damage_tween.parallel().tween_property(sprite, "modulate", original_modulate, 0.08)
	damage_tween.finished.connect(queue_free)
