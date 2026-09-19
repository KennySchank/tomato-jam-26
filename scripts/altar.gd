extends StaticBody2D

signal opened

const BORDER_SIZE := Vector2(58.0, 58.0)

## Tiles within this Chebyshev distance of the altar tile cannot host towers.
@export_range(0, 8) var tower_exclusion_radius_tiles: int = 2

@onready var map: TileMapLayer = get_parent().get_node("Map")
@onready var player: CharacterBody2D = get_parent().get_node("Player")
@onready var highlight: InteractableHighlight = $InteractableHighlight
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("interactable")
	highlight.configure(map, player)
	var altar_tile := map.local_to_map(map.to_local(global_position))
	highlight.set_target_tile(altar_tile, Rect2(-BORDER_SIZE * 0.5, BORDER_SIZE), true)

func can_interact_at(world_position: Vector2) -> bool:
	# Accept any click that lands on the altar's collision footprint so the whole
	# visible altar body opens the deposit UI, not just its origin tile.
	var footprint := _global_footprint()
	if footprint.has_point(world_position):
		return true
	var altar_tile := map.local_to_map(map.to_local(global_position))
	var clicked_tile := map.local_to_map(map.to_local(world_position))
	return clicked_tile == altar_tile

func can_player_interact(player_node: Node2D) -> bool:
	var altar_tile := map.local_to_map(map.to_local(global_position))
	return highlight.is_in_range(altar_tile)

## True when the given map tile is within the altar's tower exclusion radius.
func blocks_tower_at(tile: Vector2i) -> bool:
	var altar_tile := map.local_to_map(map.to_local(global_position))
	var delta: Vector2i = tile - altar_tile
	return maxi(absi(delta.x), absi(delta.y)) <= tower_exclusion_radius_tiles

func _global_footprint() -> Rect2:
	var shape := collision_shape.shape as RectangleShape2D
	if shape == null:
		return Rect2(global_position, Vector2.ZERO)
	var half := shape.size * 0.5 * collision_shape.scale.abs()
	var center: Vector2 = collision_shape.global_position
	return Rect2(center - half, half * 2.0)

func interact() -> void:
	opened.emit()

func _process(_delta: float) -> void:
	highlight.set_target_tile(
		map.local_to_map(map.to_local(global_position)),
		Rect2(-BORDER_SIZE * 0.5, BORDER_SIZE),
		can_interact_at(get_global_mouse_position())
	)
