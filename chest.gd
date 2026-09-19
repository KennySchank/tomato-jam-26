extends Area2D

signal opened

const TARGET_BORDER_COLOR := Color(1.0, 0.95, 0.45, 0.95)
const BORDER_SIZE := Vector2(58.0, 58.0)
const INTERACTION_RANGE_TILES := 1

@onready var map: TileMapLayer = get_parent().get_node("Map")
@onready var player: CharacterBody2D = get_parent().get_node("Player")

func _ready() -> void:
	add_to_group("interactable")
	queue_redraw()

func can_interact_at(world_position: Vector2) -> bool:
	var chest_tile := map.local_to_map(map.to_local(global_position))
	var clicked_tile := map.local_to_map(map.to_local(world_position))
	return clicked_tile == chest_tile

func can_player_interact(player: Node2D) -> bool:
	var chest_tile := map.local_to_map(map.to_local(global_position))
	var player_tile := map.local_to_map(map.to_local(player.global_position))
	return max(abs(chest_tile.x - player_tile.x), abs(chest_tile.y - player_tile.y)) <= INTERACTION_RANGE_TILES

func interact() -> void:
	opened.emit()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var mouse_position := get_global_mouse_position()
	if can_interact_at(mouse_position) and can_player_interact(player):
		draw_rect(Rect2(-BORDER_SIZE * 0.5, BORDER_SIZE), TARGET_BORDER_COLOR, false, 4.0)
