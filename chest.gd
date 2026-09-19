extends Area2D

signal opened

const BORDER_SIZE := Vector2(58.0, 58.0)

@onready var map: TileMapLayer = get_parent().get_node("Map")
@onready var player: CharacterBody2D = get_parent().get_node("Player")
@onready var highlight: InteractableHighlight = $InteractableHighlight

func _ready() -> void:
	add_to_group("interactable")
	highlight.configure(map, player)
	var chest_tile := map.local_to_map(map.to_local(global_position))
	highlight.set_target_tile(chest_tile, Rect2(-BORDER_SIZE * 0.5, BORDER_SIZE), true)

func can_interact_at(world_position: Vector2) -> bool:
	var chest_tile := map.local_to_map(map.to_local(global_position))
	var clicked_tile := map.local_to_map(map.to_local(world_position))
	return clicked_tile == chest_tile

func can_player_interact(player: Node2D) -> bool:
	var chest_tile := map.local_to_map(map.to_local(global_position))
	return highlight.is_in_range(chest_tile)

func interact() -> void:
	opened.emit()

func _process(_delta: float) -> void:
	highlight.set_target_tile(
		map.local_to_map(map.to_local(global_position)),
		Rect2(-BORDER_SIZE * 0.5, BORDER_SIZE),
		can_interact_at(get_global_mouse_position())
	)
