extends Node2D

const PLAYER_SPEED := 120.0
const PLANTABLE_DATA := "plantable"
const BROWN_SOIL_ATLAS_COORDS := Vector2i(1, 0)
const ENEMY_PATH_DATA := "enemy_path"
# The 0-indexed frame (0, 1, 2, or 3) to show when stopped
const IDLE_FRAME: int = 1
const PLOT_CENTER := Vector2(576, 324)
const PLANT_SCENE := preload("res://scenes/plant.tscn")
const TOWER_SCENE := preload("res://scenes/tower.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")

const CARDINAL_DIRECTIONS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

@export var enemy_spawn_interval := 4.0

var destination := PLOT_CENTER
var navigation_ready := false
var planted_tiles: Dictionary = {}
var tower_tiles: Dictionary = {}
var hovered_tile := Vector2i(999999, 999999)
var enemy_path: Array[Vector2] = []
var enemy_spawn_cooldown := 0.0

@onready var player: CharacterBody2D = $Player
@onready var sprite: AnimatedSprite2D = $Player/AnimatedSprite2D
@onready var navigation_agent: NavigationAgent2D = $Player/NavigationAgent2D
@onready var map: TileMapLayer = $Map
@onready var chest: StaticBody2D = $Chest
@onready var highlight: InteractableHighlight = $InteractableHighlight
@onready var placement_preview: Sprite2D = $PlacementPreview
@onready var placement_range_preview: Node2D = $PlacementRangePreview
@onready var game_state: Node = get_node("/root/GameState")
@onready var inventory_ui: CanvasLayer = $InventoryUI

func _ready() -> void:
	var start_cell := map.local_to_map(map.to_local(PLOT_CENTER))
	destination = _cell_center(start_cell)
	player.position = destination
	highlight.configure(map, player)
	enemy_path = _build_enemy_path()
	_spawn_test_enemy()
	enemy_spawn_cooldown = enemy_spawn_interval
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
			var mouse_world_position := get_global_mouse_position()
			if chest.can_interact_at(mouse_world_position) and chest.can_player_interact(player):
				chest.interact()
			elif not _try_harvest(clicked_cell) and not _try_place_tower(clicked_cell):
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

func _is_enemy_path(tile: Vector2i) -> bool:
	var tile_data := map.get_cell_tile_data(tile)
	return tile_data != null and tile_data.get_custom_data(ENEMY_PATH_DATA) == true

func _build_enemy_path() -> Array[Vector2]:
	var path_cells: Array[Vector2i] = []
	for cell in map.get_used_cells():
		if _is_enemy_path(cell):
			path_cells.append(cell)

	if path_cells.is_empty():
		push_warning("No enemy path tiles found in the map.")
		return []

	var path_set: Dictionary = {}
	for cell in path_cells:
		path_set[cell] = true

	var route_cells := _largest_path_component(path_cells, path_set)
	var route_set: Dictionary = {}
	for cell in route_cells:
		route_set[cell] = true

	var endpoints: Array[Vector2i] = []
	for cell in route_cells:
		if _path_neighbors(cell, route_set).size() == 1:
			endpoints.append(cell)
	if endpoints.size() < 2:
		push_warning("Enemy path needs two endpoints to build a route to the plants.")
		return []

	var target_endpoint := endpoints[0]
	var spawn_endpoint := endpoints[0]
	for endpoint in endpoints:
		if _cell_center(endpoint).distance_to(PLOT_CENTER) < _cell_center(target_endpoint).distance_to(PLOT_CENTER):
			target_endpoint = endpoint
		if _cell_center(endpoint).distance_to(PLOT_CENTER) > _cell_center(spawn_endpoint).distance_to(PLOT_CENTER):
			spawn_endpoint = endpoint

	var ordered_cells: Array[Vector2i] = []
	var previous := Vector2i(999999, 999999)
	var current := spawn_endpoint
	while true:
		ordered_cells.append(current)
		if current == target_endpoint:
			break
		var next_cells: Array[Vector2i] = []
		for neighbor in _path_neighbors(current, route_set):
			if neighbor != previous and not ordered_cells.has(neighbor):
				next_cells.append(neighbor)
		if next_cells.is_empty():
			break
		previous = current
		current = next_cells[0]

	if current != target_endpoint:
		push_warning("Could not connect the enemy spawn point to the plants.")
		return []

	var world_path: Array[Vector2] = []
	for cell in ordered_cells:
		world_path.append(_cell_center(cell))
	return world_path

func _largest_path_component(path_cells: Array[Vector2i], path_set: Dictionary) -> Array[Vector2i]:
	var remaining: Dictionary = {}
	for cell in path_cells:
		remaining[cell] = true

	var largest: Array[Vector2i] = []
	while not remaining.is_empty():
		var component: Array[Vector2i] = []
		var frontier: Array[Vector2i] = [remaining.keys()[0]]
		while not frontier.is_empty():
			var cell: Vector2i = frontier.pop_back()
			if not remaining.has(cell):
				continue
			remaining.erase(cell)
			component.append(cell)
			for neighbor in _path_neighbors(cell, path_set):
				if remaining.has(neighbor):
					frontier.append(neighbor)
		if component.size() > largest.size():
			largest = component
	return largest

func _path_neighbors(cell: Vector2i, path_set: Dictionary) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	for direction: Vector2i in CARDINAL_DIRECTIONS:
		var neighbor: Vector2i = cell + direction
		if path_set.has(neighbor):
			neighbors.append(neighbor)
	return neighbors

func _spawn_test_enemy() -> void:
	if enemy_path.is_empty():
		return
	var enemy := ENEMY_SCENE.instantiate()
	add_child(enemy)
	enemy.set_route(enemy_path)

func _is_in_planting_range(tile: Vector2i) -> bool:
	return highlight.is_in_range(tile)

func _soil_highlight_rect(tile: Vector2i) -> Rect2:
	var half_size := Vector2(map.tile_set.tile_size) * 0.5 * map.scale
	var center := _cell_center(tile)
	return Rect2(to_local(center) - half_size, half_size * 2.0)

func _process(_delta: float) -> void:
	if not is_node_ready():
		return
	enemy_spawn_cooldown -= _delta
	if enemy_spawn_cooldown <= 0.0:
		_spawn_test_enemy()
		enemy_spawn_cooldown = enemy_spawn_interval
	var hover_is_valid := _is_plantable(hovered_tile)
	var hover_is_harvest_target := _is_in_planting_range(hovered_tile) and planted_tiles.has(hovered_tile)
	var preview_scale := Vector2.ZERO
	var tower_is_selected := false
	if inventory_ui != null and inventory_ui.is_node_ready():
		var selected_item: Dictionary = game_state.frog_inventory[inventory_ui.selected_frog_slot]
		if not selected_item.is_empty():
			var item_id: String = selected_item.get("id", "")
			tower_is_selected = item_id == game_state.FRUIT_ITEM_ID
			if not hover_is_harvest_target and (item_id == game_state.SEED_ITEM_ID or item_id == game_state.FRUIT_ITEM_ID):
				hover_is_valid = _can_place_item(hovered_tile, item_id)
				preview_scale = Vector2.ONE * (0.18 if item_id == game_state.SEED_ITEM_ID else 0.22)
	placement_preview.visible = hover_is_valid and preview_scale != Vector2.ZERO
	if placement_preview.visible:
		placement_preview.global_position = _cell_center(hovered_tile)
		placement_preview.scale = preview_scale
	placement_range_preview.visible = tower_is_selected and _can_place_item(hovered_tile, game_state.FRUIT_ITEM_ID)
	if placement_range_preview.visible:
		placement_range_preview.global_position = _cell_center(hovered_tile)
	highlight.set_target_tile(
		hovered_tile,
		_soil_highlight_rect(hovered_tile),
		hover_is_valid
	)
	queue_redraw()

func _can_place_item(tile: Vector2i, item_id: String) -> bool:
	if not _is_in_planting_range(tile) or map.get_cell_tile_data(tile) == null:
		return false
	if planted_tiles.has(tile) or tower_tiles.has(tile):
		return false
	if item_id == game_state.SEED_ITEM_ID:
		return _is_plantable(tile)
	if item_id == game_state.FRUIT_ITEM_ID:
		return not _is_enemy_path(tile)
	return false

func _try_plant(tile: Vector2i) -> void:
	if not _can_place_item(tile, game_state.SEED_ITEM_ID):
		return
	if not game_state.consume_frog_item(inventory_ui.selected_frog_slot):
		return

	var plant := PLANT_SCENE.instantiate()
	plant.global_position = _cell_center(tile)
	add_child(plant)
	planted_tiles[tile] = plant

func _try_harvest(tile: Vector2i) -> bool:
	if not _is_in_planting_range(tile) or not planted_tiles.has(tile):
		return false
	var plant: Node = planted_tiles[tile]
	if not plant.can_harvest():
		return true
	if not game_state.add_frog_item(game_state.FRUIT_ITEM_ID):
		return true
	planted_tiles.erase(tile)
	plant.queue_free()
	return true

func _try_place_tower(tile: Vector2i) -> bool:
	if not _can_place_item(tile, game_state.FRUIT_ITEM_ID):
		return false
	if not game_state.frog_slot_has_item(inventory_ui.selected_frog_slot, game_state.FRUIT_ITEM_ID):
		return false
	if not game_state.consume_frog_item(inventory_ui.selected_frog_slot):
		return false
	var tower := TOWER_SCENE.instantiate()
	tower.global_position = _cell_center(tile)
	add_child(tower)
	tower_tiles[tile] = tower
	return true

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
