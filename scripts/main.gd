extends Node2D

const PLAYER_SPEED := 120.0
const PLANTABLE_DATA := "plantable"
const BROWN_SOIL_ATLAS_COORDS := Vector2i(1, 0)
const BASE_LAND_ATLAS_COORDS := Vector2i(0, 0)
const ENEMY_PATH_DATA := "enemy_path"
# The 0-indexed frame (0, 1, 2, or 3) to show when stopped
const IDLE_FRAME: int = 1
const PLOT_CENTER := Vector2(576, 324)
const PLANT_SCENE := preload("res://scenes/plant.tscn")
const TOWER_SCENE := preload("res://scenes/tower.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const ENEMY_ATTACK_RADIUS_TILES := 4.0

const CARDINAL_DIRECTIONS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

@export var enemy_spawn_interval_min := 2.5
@export var enemy_spawn_interval_max := 5.0
@export var max_active_enemies := 12
@export var enemy_initial_spawn_delay := 2.0

var destination := PLOT_CENTER
var navigation_ready := false
var planted_tiles: Dictionary = {}
var tower_tiles: Dictionary = {}
var hovered_tile := Vector2i(999999, 999999)
var enemy_routes: Array[Array] = []
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
	enemy_routes = _build_enemy_routes()
	enemy_spawn_cooldown = enemy_initial_spawn_delay
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

func _build_enemy_routes() -> Array[Array]:
	var path_cells: Array[Vector2i] = []
	for cell in map.get_used_cells():
		if _is_enemy_path(cell):
			path_cells.append(cell)

	if path_cells.is_empty():
		push_warning("No enemy path tiles found in the map.")
		return [] as Array[Array]

	var path_set: Dictionary = {}
	for cell in path_cells:
		path_set[cell] = true

	var routes: Array[Array] = []
	for component in _path_components(path_cells, path_set):
		var component_set: Dictionary = {}
		for cell in component:
			component_set[cell] = true
		var target_cell: Vector2i = component[0]
		for cell in component:
			if _cell_center(cell).distance_to(PLOT_CENTER) < _cell_center(target_cell).distance_to(PLOT_CENTER):
				target_cell = cell
		for spawn_cell in component:
			if not _is_path_tile_on_window_edge(spawn_cell):
				continue
			var route_cells_for_spawn := _find_path_route(spawn_cell, target_cell, component_set)
			if route_cells_for_spawn.is_empty():
				continue
			var world_path: Array[Vector2] = []
			for cell in route_cells_for_spawn:
				world_path.append(_cell_center(cell))
			routes.append(world_path)
	if routes.is_empty():
		push_warning("No enemy path tiles intersect the game window.")
	return routes

func _is_path_tile_on_window_edge(cell: Vector2i) -> bool:
	var viewport_rect := get_viewport_rect()
	var tile_size := Vector2(map.tile_set.tile_size) * map.scale
	var tile_rect := Rect2(_cell_center(cell) - tile_size * 0.5, tile_size)
	return tile_rect.position.x <= viewport_rect.position.x \
		or tile_rect.end.x >= viewport_rect.end.x \
		or tile_rect.position.y <= viewport_rect.position.y \
		or tile_rect.end.y >= viewport_rect.end.y

func _find_path_route(start: Vector2i, target: Vector2i, path_set: Dictionary) -> Array[Vector2i]:
	var frontier: Array[Vector2i] = [start]
	var previous: Dictionary = {start: Vector2i(999999, 999999)}
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		if current == target:
			break
		for neighbor in _path_neighbors(current, path_set):
			if not previous.has(neighbor):
				previous[neighbor] = current
				frontier.append(neighbor)
	if not previous.has(target):
		return [] as Array[Vector2i]

	var route: Array[Vector2i] = []
	var current := target
	while current != Vector2i(999999, 999999):
		route.push_front(current)
		current = previous[current]
	return route

func _path_components(path_cells: Array[Vector2i], path_set: Dictionary) -> Array[Array]:
	var remaining: Dictionary = {}
	for cell in path_cells:
		remaining[cell] = true

	var components: Array[Array] = []
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
		components.append(component)
	return components

func _path_neighbors(cell: Vector2i, path_set: Dictionary) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	for direction: Vector2i in CARDINAL_DIRECTIONS:
		var neighbor: Vector2i = cell + direction
		if path_set.has(neighbor):
			neighbors.append(neighbor)
	return neighbors

func _spawn_enemy(enemy_scene: PackedScene = ENEMY_SCENE) -> void:
	if enemy_routes.is_empty() or get_tree().get_nodes_in_group("enemies").size() >= max_active_enemies:
		return
	var enemy := enemy_scene.instantiate()
	add_child(enemy)
	enemy.attack_requested.connect(_on_enemy_attack_requested.bind(enemy))
	enemy.set_route(enemy_routes.pick_random())

func _on_enemy_attack_requested(enemy_position: Vector2, enemy: Node) -> void:
	var target_tile := _find_enemy_target_tile(enemy_position)
	if target_tile == Vector2i(999999, 999999):
		return

	var projectile := PROJECTILE_SCENE.instantiate()
	projectile.global_position = enemy_position
	projectile.set_source(enemy)
	var plant: Node = planted_tiles.get(target_tile)
	if is_instance_valid(plant):
		projectile.set_target(plant)
		projectile.impact_callback = func() -> void:
			if planted_tiles.get(target_tile) == plant:
				planted_tiles.erase(target_tile)
	else:
		projectile.set_target_position(_cell_center(target_tile))
		projectile.impact_callback = func() -> void:
			_damage_land(target_tile)
	add_child(projectile)

func _find_enemy_target_tile(enemy_position: Vector2) -> Vector2i:
	var interaction_radius := Vector2(map.tile_set.tile_size).x * map.scale.x * ENEMY_ATTACK_RADIUS_TILES
	var nearest_tile := Vector2i(999999, 999999)
	var nearest_distance := INF
	for tile in planted_tiles:
		var distance := _cell_center(tile).distance_to(enemy_position)
		if distance <= interaction_radius and distance < nearest_distance:
			nearest_tile = tile
			nearest_distance = distance

	if nearest_tile != Vector2i(999999, 999999):
		return nearest_tile

	nearest_tile = Vector2i(999999, 999999)
	nearest_distance = INF
	for tile in map.get_used_cells():
		if map.get_cell_atlas_coords(tile) != BROWN_SOIL_ATLAS_COORDS:
			continue
		var distance := _cell_center(tile).distance_to(enemy_position)
		if distance <= interaction_radius and distance < nearest_distance:
			nearest_tile = tile
			nearest_distance = distance
	return nearest_tile

func _damage_land(tile: Vector2i) -> void:
	if map.get_cell_atlas_coords(tile) != BROWN_SOIL_ATLAS_COORDS:
		return
	_play_land_damage(tile)

func _play_land_damage(tile: Vector2i) -> void:
	var damage_overlay := Polygon2D.new()
	var half_size := Vector2(map.tile_set.tile_size) * 0.5 * map.scale
	damage_overlay.polygon = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
	])
	damage_overlay.position = _cell_center(tile)
	damage_overlay.z_index = -1
	damage_overlay.color = Color(1.0, 0.15, 0.15, 0.65)
	add_child(damage_overlay)

	var original_position := damage_overlay.position
	var damage_tween := create_tween()
	damage_tween.tween_property(damage_overlay, "color", Color(1.0, 0.15, 0.15, 0.9), 0.04)
	damage_tween.parallel().tween_property(damage_overlay, "position", original_position + Vector2(2.0, 0.0), 0.025)
	damage_tween.tween_property(damage_overlay, "position", original_position + Vector2(-2.0, 0.0), 0.05)
	damage_tween.tween_property(damage_overlay, "position", original_position, 0.025)
	damage_tween.tween_property(damage_overlay, "color", Color(1.0, 0.15, 0.15, 0.0), 0.08)
	damage_tween.finished.connect(func() -> void:
		map.set_cell(tile, 0, BASE_LAND_ATLAS_COORDS)
		damage_overlay.queue_free()
	)

func _next_enemy_spawn_delay() -> float:
	return randf_range(enemy_spawn_interval_min, enemy_spawn_interval_max)

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
		_spawn_enemy()
		enemy_spawn_cooldown = _next_enemy_spawn_delay()
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
