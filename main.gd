extends Node2D

const PLAYER_SPEED := 120.0
const PLANTABLE_DATA := "plantable"
const BROWN_SOIL_ATLAS_COORDS := Vector2i(1, 0)
const PLANTING_RANGE_TILES := 1
const TARGET_BORDER_COLOR := Color(1.0, 0.95, 0.45, 0.95)
# The 0-indexed frame (0, 1, 2, or 3) to show when stopped
const IDLE_FRAME: int = 1
const PLOT_CENTER := Vector2(576, 324)
const PLANT_SCENE := preload("res://scenes/plant.tscn")

var destination := PLOT_CENTER
var navigation_ready := false
var planted_tiles: Dictionary = {}
var hovered_tile := Vector2i(999999, 999999)

@onready var player: CharacterBody2D = $Player
@onready var sprite: AnimatedSprite2D = $Player/AnimatedSprite2D
@onready var navigation_agent: NavigationAgent2D = $Player/NavigationAgent2D
@onready var map: TileMapLayer = $Map

func _ready() -> void:
	var start_cell := map.local_to_map(map.to_local(PLOT_CENTER))
	destination = _cell_center(start_cell)
	player.position = destination
	queue_redraw()
	_navigation_setup.call_deferred()

func _navigation_setup() -> void:
	await get_tree().physics_frame
	navigation_ready = true
	navigation_agent.target_position = destination

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hovered_tile = map.local_to_map(map.to_local(event.position))
		queue_redraw()
		return
	if event is InputEventMouseButton and event.pressed:
		var clicked_cell := map.local_to_map(map.to_local(event.position))
		hovered_tile = clicked_cell
		if event.button_index == MOUSE_BUTTON_LEFT:
			destination = _cell_center(clicked_cell)
			if navigation_ready:
				navigation_agent.target_position = destination
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_try_plant(clicked_cell)
		queue_redraw()

func _cell_center(cell: Vector2i) -> Vector2:
	return map.to_global(map.map_to_local(cell))

func _is_plantable(tile: Vector2i) -> bool:
	var tile_data := map.get_cell_tile_data(tile)
	if tile_data == null:
		return false
	var is_plantable: bool = tile_data.get_custom_data(PLANTABLE_DATA)
	var is_brown_soil := map.get_cell_atlas_coords(tile) == BROWN_SOIL_ATLAS_COORDS
	return is_plantable or is_brown_soil

func _is_in_planting_range(tile: Vector2i) -> bool:
	var player_tile := map.local_to_map(map.to_local(player.global_position))
	return max(abs(tile.x - player_tile.x), abs(tile.y - player_tile.y)) <= PLANTING_RANGE_TILES

func _draw_tile_border(tile: Vector2i, color: Color, width: float) -> void:
	var half_size := Vector2(map.tile_set.tile_size) * 0.5 * map.scale
	var center := _cell_center(tile)
	draw_rect(Rect2(to_local(center) - half_size, half_size * 2.0), color, false, width)

func _draw() -> void:
	if not is_node_ready():
		return
	if _is_plantable(hovered_tile) and _is_in_planting_range(hovered_tile):
		_draw_tile_border(hovered_tile, TARGET_BORDER_COLOR, 4.0)

func _try_plant(tile: Vector2i) -> void:
	if not _is_in_planting_range(tile):
		return
	if planted_tiles.has(tile):
		return
	if not _is_plantable(tile):
		return

	var plant := PLANT_SCENE.instantiate()
	plant.global_position = _cell_center(tile)
	add_child(plant)
	planted_tiles[tile] = plant

func _physics_process(_delta: float) -> void:
	queue_redraw()
	# If navigation isn't ready yet, fall back to direct mouse steering
	if not navigation_ready:
		var offset := destination - player.position
		if offset.length() > 4.0:
			player.velocity = offset.normalized() * PLAYER_SPEED
			player.move_and_slide()

			# Play the stompWalk animation while moving
			if not sprite.is_playing() or sprite.animation != "stompWalk":
				sprite.play("stompWalk")
		else:
			player.velocity = Vector2.ZERO
			# Freeze on the chosen frame when stopped
			sprite.stop()
			sprite.frame = IDLE_FRAME
		return

	# Use navigation agent when available
	if navigation_agent.is_navigation_finished():
		player.velocity = Vector2.ZERO
		sprite.stop()
		sprite.frame = IDLE_FRAME
		return

	var next_path_position := navigation_agent.get_next_path_position()
	var offset := next_path_position - player.global_position
	if offset.length() <= 1.0:
		player.velocity = Vector2.ZERO
		sprite.stop()
		sprite.frame = IDLE_FRAME
		return

	player.velocity = offset.normalized() * PLAYER_SPEED
	player.move_and_slide()
	if not sprite.is_playing() or sprite.animation != "stompWalk":
		sprite.play("stompWalk")
