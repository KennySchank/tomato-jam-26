class_name InteractableHighlight
extends Node2D

@export var interaction_range_tiles := 1
@export var border_color := Color(1.0, 0.95, 0.45, 0.95)
@export var border_width := 4.0
@export var silhouette_sprite_path: NodePath

var map: TileMapLayer
var player: Node2D
var target_tile := Vector2i.ZERO
var target_rect := Rect2()
var target_visible := false
var silhouette_sprite: Sprite2D

func _ready() -> void:
	if not silhouette_sprite_path.is_empty():
		silhouette_sprite = get_node_or_null(silhouette_sprite_path) as Sprite2D

func configure(interaction_map: TileMapLayer, interaction_player: Node2D) -> void:
	map = interaction_map
	player = interaction_player

func set_target_tile(tile: Vector2i, rect: Rect2, visible: bool) -> void:
	target_tile = tile
	target_rect = rect
	target_visible = visible
	if silhouette_sprite != null and silhouette_sprite.material is ShaderMaterial:
		silhouette_sprite.material.set_shader_parameter("outline_enabled", visible and is_in_range(tile))
	queue_redraw()

func is_in_range(tile: Vector2i) -> bool:
	if map == null or player == null:
		return false
	var player_tile := map.local_to_map(map.to_local(player.global_position))
	return max(abs(tile.x - player_tile.x), abs(tile.y - player_tile.y)) <= interaction_range_tiles

func is_hovering(world_position: Vector2) -> bool:
	if map == null:
		return false
	return map.local_to_map(map.to_local(world_position)) == target_tile

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if target_visible and is_in_range(target_tile):
		draw_rect(target_rect, border_color, false, border_width)
