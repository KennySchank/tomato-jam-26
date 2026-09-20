extends Node2D

const PLAYER_SPEED := 120.0
const PLANTABLE_DATA := "plantable"
const TILLED_SOIL_SOURCE_ID := 3
const GRASS_SOURCE_ID := 0
const GRASS_ATLAS_COORDS := Vector2i(4, 0)
const ENEMY_PATH_SOURCE_ID := 2
# The 0-indexed frame (0, 1, 2, or 3) to show when stopped
const IDLE_FRAME: int = 1
const PLOT_CENTER := Vector2(576, 324)
const PLANT_SCENE := preload("res://scenes/plant.tscn")
const TOWER_SCENE := preload("res://scenes/tower.tscn")
const CORN_TOWER_SCENE := preload("res://scenes/corn_tower.tscn")
const PUMPKIN_WALL_SCENE := preload("res://scenes/pumpkin_wall.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const ENEMY_SCENES: Array[PackedScene] = [
	preload("res://scenes/enemy.tscn"),
	preload("res://scenes/enemies/enemy_raccoon.tscn"),
]
const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const ENEMY_ATTACK_RADIUS_TILES := 4.5
const TILLED_SOIL_HITS := 3

# Nail boon knobs. Every NAIL_INTERVAL seconds any enemy within
# NAIL_RADIUS_TILES of the frog takes NAIL_DAMAGE HP.
const NAIL_INTERVAL := 15.0
const NAIL_RADIUS_TILES := 2.0
const NAIL_DAMAGE := 5.0

const CARDINAL_DIRECTIONS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

var destination := PLOT_CENTER
var navigation_ready := false
var planted_tiles: Dictionary = {}
var tower_tiles: Dictionary = {}
## Tracks Pumpkin Walls placed on enemy path tiles so we can block re-placing
## a wall on top of an existing one. Cleaned up when the wall queue_frees.
var wall_tiles: Dictionary = {}
var soil_damage: Dictionary = {}
var hovered_tile := Vector2i(999999, 999999)
var enemy_routes: Array[Array] = []
var brown_soil_count: int = 0
var plant_preview_scale := Vector2.ONE

@onready var player: CharacterBody2D = $Player
@onready var sprite: AnimatedSprite2D = $Player/AnimatedSprite2D
@onready var navigation_agent: NavigationAgent2D = $Player/NavigationAgent2D
@onready var map: TileMapLayer = $Map
@onready var chest: StaticBody2D = $Chest
@onready var altar: StaticBody2D = $Altar
@onready var highlight: InteractableHighlight = $InteractableHighlight
@onready var placement_preview: Sprite2D = $PlacementPreview
@onready var plant_preview: AnimatedSprite2D = $PlantPreview
@onready var placement_range_preview: Node2D = $PlacementRangePreview
@onready var game_state: Node = get_node("/root/GameState")
@onready var run_stats: Node = get_node("/root/RunStats")
@onready var inventory_ui: CanvasLayer = $InventoryUI
@onready var wave_manager: WaveManager = $WaveManager
@onready var hud: Node = $HUD
@onready var round_end: StaticBody2D = $RoundEnd
@onready var game_over: StaticBody2D = $GameOver

var _round_end_shown: bool = false
# Countdown until the next Nail-boon pulse. Only ticks while the boon is
# owned; resets to NAIL_INTERVAL after each pulse fires.
var _nail_cooldown: float = NAIL_INTERVAL

func _ready() -> void:
	var plant_scene_instance := PLANT_SCENE.instantiate()
	var plant_sprite: AnimatedSprite2D = plant_scene_instance.get_node("SwayPivot/AnimatedSprite2D")
	plant_preview.sprite_frames = plant_sprite.sprite_frames
	plant_preview.animation = plant_sprite.animation
	plant_preview.stop()
	var final_frame := plant_preview.sprite_frames.get_frame_count(plant_preview.animation) - 1
	plant_preview.set_frame_and_progress(final_frame, 0.0)
	plant_preview_scale = plant_sprite.scale
	plant_preview.scale = plant_preview_scale
	plant_scene_instance.free()

	var tower_scene_instance := TOWER_SCENE.instantiate()
	var tower_sprite: AnimatedSprite2D = tower_scene_instance.get_node("AnimatedSprite2D")
	var idle_animation := &"Idle"
	if tower_sprite.sprite_frames.has_animation(idle_animation):
		var tower_final_frame := tower_sprite.sprite_frames.get_frame_count(idle_animation) - 1
		placement_preview.texture = tower_sprite.sprite_frames.get_frame_texture(idle_animation, tower_final_frame)
	tower_scene_instance.free()

	var start_cell := map.local_to_map(map.to_local(PLOT_CENTER))
	destination = _cell_center(start_cell)
	player.position = destination
	highlight.configure(map, player)
	enemy_routes = _build_enemy_routes()
	brown_soil_count = _count_brown_soil_tiles()
	wave_manager.spawn_requested.connect(_on_wave_spawn_requested)
	wave_manager.wave_ended.connect(_on_wave_ended)
	wave_manager.harvest_time_expired.connect(_on_harvest_time_expired)
	wave_manager.game_lost.connect(_on_game_lost)
	game_state.tomato_count_changed.connect(_on_tomato_count_changed)
	round_end.closed.connect(_on_round_end_closed)
	if hud.has_method("bind_wave_manager"):
		hud.bind_wave_manager(wave_manager)
	queue_redraw()
	_navigation_setup.call_deferred()
	_apply_debug_starting_boons.call_deferred()

## Applies every boon listed in `GameState.DEBUG_STARTING_BOONS` at the start
## of the run. Deferred so it runs after `_ready` completes and the scene tree
## is settled — matches how `round_end.gd` applies a live pick.
func _apply_debug_starting_boons() -> void:
	if game_state.DEBUG_STARTING_BOONS.is_empty():
		return
	for boon_path in game_state.DEBUG_STARTING_BOONS:
		if game_state.has_boon(boon_path):
			continue
		var packed: PackedScene = load(boon_path)
		if packed == null:
			push_warning("Debug starting boon not found: %s" % boon_path)
			continue
		var boon: Node = packed.instantiate()
		# Hide and disable interaction so the card doesn't render or trap clicks
		# while it applies its effect.
		if boon is CanvasItem:
			(boon as CanvasItem).visible = false
		add_child(boon)
		game_state.activate_boon(boon_path)
		if boon.has_method("apply_effect"):
			boon.call("apply_effect")
		boon.queue_free()

func _on_wave_spawn_requested(enemy_scene: PackedScene) -> void:
	_spawn_enemy(enemy_scene)

func _on_wave_ended(_wave_index: int, wave: WaveDefinition) -> void:
	if wave == null or wave.reward_seeds <= 0:
		return
	var leftover: int = game_state.grant_item(game_state.SEED_ITEM_ID, wave.reward_seeds)
	if leftover > 0:
		push_warning("Wave reward overflow: %d seeds could not be stored." % leftover)

func _on_harvest_time_expired() -> void:
	if game_state.tomato_count < game_state.tomato_goal:
		wave_manager.trigger_loss()

func _on_tomato_count_changed(count: int, goal: int) -> void:
	if count >= goal and not _round_end_shown:
		_round_end_shown = true
		inventory_ui.close_all_windows()
		round_end.show_round_end()

func _on_round_end_closed() -> void:
	# The round is only "completed" once the player has picked a boon and
	# dismissed the round-end screen — record it here.
	if run_stats != null and run_stats.has_method("record_round_completed"):
		run_stats.record_round_completed()
	# Endless mode: reset the altar and restart the harvest countdown so the
	# player has a fresh deadline for the next tribute cycle.
	game_state.reset_altar_for_new_round()
	wave_manager.restart_harvest_timer()
	_round_end_shown = false

func _on_game_lost() -> void:
	inventory_ui.close_all_windows()
	# Finalize this run's stats before showing the game-over screen so any UI
	# that reads from RunStats sees the frozen post-run values.
	var report = null
	if run_stats != null and run_stats.has_method("record_death"):
		report = run_stats.record_death()
	game_over.show_game_over(report)

func _count_brown_soil_tiles() -> int:
	var count := 0
	for tile in map.get_used_cells():
		if _is_tilled_soil(tile):
			count += 1
	return count

func _check_loss_condition() -> void:
	# Losing means the player has nothing left to grow tomatoes on: no soil and no
	# living plants. Towers alone cannot produce tomatoes, so the run is unwinnable.
	if brown_soil_count > 0:
		return
	if not planted_tiles.is_empty():
		return
	wave_manager.trigger_loss()

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
			if altar.can_interact_at(mouse_world_position) and altar.can_player_interact(player):
				altar.interact()
			elif chest.can_interact_at(mouse_world_position) and chest.can_player_interact(player):
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
	return is_plantable or _is_tilled_soil(tile)

func _is_tilled_soil(tile: Vector2i) -> bool:
	return map.get_cell_source_id(tile) == TILLED_SOIL_SOURCE_ID

func _is_enemy_path(tile: Vector2i) -> bool:
	return map.get_cell_source_id(tile) == ENEMY_PATH_SOURCE_ID

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

func _spawn_enemy(enemy_scene: PackedScene = null) -> void:
	if enemy_routes.is_empty():
		return
	if enemy_scene == null:
		enemy_scene = ENEMY_SCENES.pick_random()
	var enemy := enemy_scene.instantiate()
	add_child(enemy)
	if enemy.has_method("apply_difficulty") and wave_manager.current_wave != null:
		enemy.apply_difficulty(
			wave_manager.current_wave.enemy_speed_multiplier,
			wave_manager.current_wave.enemy_health_multiplier,
			wave_manager.current_wave.enemy_attack_interval_multiplier
		)
	enemy.attack_requested.connect(_on_enemy_attack_requested.bind(enemy))
	enemy.set_route(enemy_routes.pick_random())

func _on_enemy_attack_requested(enemy_position: Vector2, enemy: Node) -> void:
	# Pumpkin wall takes priority: if the enemy is within attack range of the
	# wall, redirect the shot there and skip the plot-targeting logic below.
	var interaction_radius := Vector2(map.tile_set.tile_size).x * map.scale.x * ENEMY_ATTACK_RADIUS_TILES
	var pumpkin: Node = get_tree().get_first_node_in_group("pumpkin_wall")
	if is_instance_valid(pumpkin) and pumpkin is Node2D \
			and enemy_position.distance_to((pumpkin as Node2D).global_position) <= interaction_radius:
		_spawn_shield_projectile(enemy, enemy_position, pumpkin)
		return

	var target_tile := _find_enemy_target_tile(enemy_position)
	if target_tile == Vector2i(999999, 999999):
		return

	# Fence and scarecrow blanket-protect the plot: any incoming plot attack
	# is redirected to the fence first, then the scarecrow, until they break.
	var shield: Node = _get_plot_shield()
	if shield != null:
		_spawn_shield_projectile(enemy, enemy_position, shield)
		return

	var projectile := PROJECTILE_SCENE.instantiate()
	projectile.global_position = enemy_position
	projectile.set_source(enemy)
	var plant: Node = planted_tiles.get(target_tile)
	if is_instance_valid(plant):
		var plant_id := plant.get_instance_id()
		projectile.set_target(plant)
		projectile.impact_callback = func() -> void:
			var current_plant: Node = planted_tiles.get(target_tile)
			# The plant may have absorbed the hit (Watering Can). Only clean
			# up the tile entry if it actually died on impact.
			if is_instance_valid(current_plant) and current_plant.get_instance_id() == plant_id \
				and current_plant.has_method("is_alive") and not current_plant.is_alive():
				planted_tiles.erase(target_tile)
				_check_loss_condition()
	else:
		projectile.set_target_position(_cell_center(target_tile))
		projectile.impact_callback = func() -> void:
			_damage_land(target_tile)
	add_child(projectile)

## Spawns a projectile targeted at a shield entity (fence / scarecrow /
## pumpkin wall). The shield's `take_damage()` handles its own destruction, so
## no impact_callback is needed.
func _spawn_shield_projectile(enemy: Node, enemy_position: Vector2, shield: Node) -> void:
	var projectile := PROJECTILE_SCENE.instantiate()
	projectile.global_position = enemy_position
	projectile.set_source(enemy)
	projectile.set_target(shield)
	add_child(projectile)

## Returns the first living shield in the fence group, then the scarecrow
## group. Both apply blanket protection to the whole plot.
func _get_plot_shield() -> Node:
	var fence: Node = get_tree().get_first_node_in_group("fence")
	if is_instance_valid(fence) and fence.has_method("is_alive") and fence.is_alive():
		return fence
	var scarecrow: Node = get_tree().get_first_node_in_group("scarecrow")
	if is_instance_valid(scarecrow) and scarecrow.has_method("is_alive") and scarecrow.is_alive():
		return scarecrow
	return null

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
		if not _is_tilled_soil(tile):
			continue
		var distance := _cell_center(tile).distance_to(enemy_position)
		if distance <= interaction_radius and distance < nearest_distance:
			nearest_tile = tile
			nearest_distance = distance
	return nearest_tile

func _damage_land(tile: Vector2i) -> void:
	if not _is_tilled_soil(tile):
		return
	# Hoe boon spends a charge to save the plot before it turns to grass.
	if game_state.hoe_charges > 0:
		game_state.hoe_charges -= 1
		# Once the last charge is spent, the hoe breaks: drop it from the
		# active boons so the tracker hides it and future rerolls can offer
		# it again.
		if game_state.hoe_charges <= 0:
			game_state.deactivate_boon("res://scenes/boons/hoe.tscn")
		_play_land_repair(tile)
		return
	soil_damage[tile] = int(soil_damage.get(tile, 0)) + 1
	_play_land_damage(tile)

func _play_land_repair(tile: Vector2i) -> void:
	# Green flash so the player can tell the plot survived. Same shape as the
	# damage overlay so both animations feel like the same "hit" language.
	var repair_overlay := Polygon2D.new()
	var half_size := Vector2(map.tile_set.tile_size) * 0.5 * map.scale
	repair_overlay.polygon = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
	])
	repair_overlay.position = _cell_center(tile)
	repair_overlay.z_index = -1
	repair_overlay.color = Color(0.35, 0.9, 0.35, 0.65)
	add_child(repair_overlay)
	var tween := create_tween()
	tween.tween_property(repair_overlay, "color", Color(0.35, 0.9, 0.35, 0.0), 0.35)
	tween.finished.connect(repair_overlay.queue_free)

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
		if not _is_tilled_soil(tile):
			damage_overlay.queue_free()
			return
		if int(soil_damage.get(tile, 0)) < TILLED_SOIL_HITS:
			damage_overlay.queue_free()
			return
		map.set_cell(tile, GRASS_SOURCE_ID, GRASS_ATLAS_COORDS)
		soil_damage.erase(tile)
		damage_overlay.queue_free()
		brown_soil_count = maxi(0, brown_soil_count - 1)
		_check_loss_condition()
	)

func _is_in_planting_range(tile: Vector2i) -> bool:
	return highlight.is_in_range(tile)

func _soil_highlight_rect(tile: Vector2i) -> Rect2:
	var half_size := Vector2(map.tile_set.tile_size) * 0.5 * map.scale
	var center := _cell_center(tile)
	return Rect2(to_local(center) - half_size, half_size * 2.0)

func _process(_delta: float) -> void:
	if not is_node_ready():
		return
	var hover_is_valid := _is_plantable(hovered_tile)
	var hover_is_harvest_target := _is_in_planting_range(hovered_tile) and planted_tiles.has(hovered_tile)
	var preview_scale := Vector2.ZERO
	var preview_node: Node2D = placement_preview
	var tower_is_selected := false
	if inventory_ui != null and inventory_ui.is_node_ready():
		var selected_item: Dictionary = game_state.frog_inventory[inventory_ui.selected_frog_slot]
		if not selected_item.is_empty():
			var item_id: String = selected_item.get("id", "")
			tower_is_selected = item_id == game_state.FRUIT_ITEM_ID
			if not hover_is_harvest_target and item_id == game_state.SEED_ITEM_ID:
				hover_is_valid = _can_place_item(hovered_tile, item_id)
				preview_scale = Vector2.ONE * 0.18
				preview_node = plant_preview
			elif not hover_is_harvest_target and item_id == game_state.FRUIT_ITEM_ID:
				hover_is_valid = _can_place_item(hovered_tile, item_id)
				preview_scale = Vector2.ONE * 1.68
				preview_node = placement_preview
		elif game_state.get_seed_count(game_state.active_seed_id) > 0 and not hover_is_harvest_target:
			var active_id: String = game_state.active_seed_id
			hover_is_valid = _can_place_item(hovered_tile, active_id)
			if active_id == game_state.TOMATO_SEED_ID:
				preview_scale = Vector2.ONE * 0.18
				preview_node = plant_preview
			elif active_id == game_state.CORN_SEED_ID:
				# Corn plants a tower on the same non-tilled tiles as tomato
				# towers, so reuse the tower silhouette preview.
				preview_scale = Vector2.ONE * 1.68
				preview_node = placement_preview
			# Pumpkins don't get a preview sprite yet; the hover highlight is
			# enough of a signal that the tile is a valid path drop.
	placement_preview.visible = false
	plant_preview.visible = false
	preview_node.visible = hover_is_valid and preview_scale != Vector2.ZERO
	if preview_node.visible:
		preview_node.global_position = _cell_center(hovered_tile)
		if preview_node == placement_preview:
			preview_node.scale = preview_scale
		else:
			preview_node.scale = plant_preview_scale
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
	if planted_tiles.has(tile) or tower_tiles.has(tile) or wall_tiles.has(tile):
		return false
	if item_id == game_state.SEED_ITEM_ID:
		return _is_plantable(tile)
	if item_id == game_state.CORN_SEED_ID:
		# Corn Towers place exactly where tomato towers do: off the tilled
		# plot, off the enemy path, and not blocked by the altar.
		if altar.blocks_tower_at(tile):
			return false
		if _is_tilled_soil(tile):
			return false
		return not _is_enemy_path(tile)
	if item_id == game_state.PUMPKIN_SEED_ID:
		# Pumpkin Walls only drop on enemy path tiles so enemies path into
		# them instead of the plot.
		if altar.blocks_tower_at(tile):
			return false
		return _is_enemy_path(tile)
	if item_id == game_state.FRUIT_ITEM_ID:
		if altar.blocks_tower_at(tile):
			return false
		if _is_tilled_soil(tile):
			return false
		return not _is_enemy_path(tile)
	return false

func _try_plant(tile: Vector2i) -> void:
	var seed_id: String = game_state.active_seed_id
	if not _can_place_item(tile, seed_id):
		return
	if not game_state.consume_frog_item(inventory_ui.selected_frog_slot):
		return
	
	match seed_id:
		game_state.CORN_SEED_ID:
			_place_corn_tower(tile)
		game_state.PUMPKIN_SEED_ID:
			_place_pumpkin_wall(tile)
		_:
			var plant := PLANT_SCENE.instantiate()
			plant.global_position = _cell_center(tile)
			add_child(plant)
			planted_tiles[tile] = plant

func _place_corn_tower(tile: Vector2i) -> void:
	var tower := CORN_TOWER_SCENE.instantiate()
	tower.global_position = _cell_center(tile)
	add_child(tower)
	tower.died.connect(_on_tower_died.bind(tile))
	tower_tiles[tile] = tower

func _place_pumpkin_wall(tile: Vector2i) -> void:
	var wall := PUMPKIN_WALL_SCENE.instantiate()
	wall.global_position = _cell_center(tile)
	add_child(wall)
	wall_tiles[tile] = wall
	# Pumpkin walls queue_free themselves on break; clear the tile record so
	# the player can drop another one on the same path square later.
	wall.tree_exited.connect(_on_wall_removed.bind(tile))

func _on_wall_removed(tile: Vector2i) -> void:
	wall_tiles.erase(tile)

func _try_harvest(tile: Vector2i) -> bool:
	if not _is_in_planting_range(tile) or not planted_tiles.has(tile):
		return false
	var plant: Node = planted_tiles[tile]
	if not plant.can_harvest():
		return true
	if not game_state.add_frog_item(game_state.FRUIT_ITEM_ID):
		return true
	game_state.grant_item(game_state.SEED_ITEM_ID, 1)
	# Gloves boon: chance to drop an extra tomato seed.
	if game_state.bonus_seed_chance > 0.0 and randf() < game_state.bonus_seed_chance:
		game_state.grant_item(game_state.SEED_ITEM_ID, 1)
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
	tower.died.connect(_on_tower_died.bind(tile))
	tower_tiles[tile] = tower
	return true

func _on_tower_died(tile: Vector2i) -> void:
	tower_tiles.erase(tile)

## Spawns a Fence entity spanning the south edge of the tomato plot. Only one
## fence can exist at a time (the boon is deduped from re-picks).
func spawn_fence() -> bool:
	const FENCE_SCENE := preload("res://scenes/fence.tscn")
	var bounds := _tilled_soil_bounds()
	if bounds.size == Vector2i.ZERO:
		push_warning("Fence boon: no tilled soil found; cannot place fence.")
		return false
	var tile_size := Vector2(map.tile_set.tile_size) * map.scale
	var south_row_y := bounds.position.y + bounds.size.y # one row below the last plot row
	var world_x := (float(bounds.position.x) + float(bounds.size.x) * 0.5) * tile_size.x
	var world_y := _cell_center(Vector2i(bounds.position.x, south_row_y)).y
	var fence := FENCE_SCENE.instantiate()
	fence.global_position = Vector2(world_x, world_y)
	# Base fence polygon spans 192 px wide; scale x so it covers the full plot.
	fence.scale = Vector2(float(bounds.size.x) * tile_size.x / 192.0, 1.0)
	add_child(fence)
	return true

## Spawns a Scarecrow on the center-most tilled soil tile.
func spawn_scarecrow() -> bool:
	const SCARECROW_SCENE := preload("res://scenes/scarecrow.tscn")
	var tilled: Array[Vector2i] = []
	for tile in map.get_used_cells():
		if _is_tilled_soil(tile):
			tilled.append(tile)
	if tilled.is_empty():
		push_warning("Scarecrow boon: no tilled soil found.")
		return false
	var best_tile: Vector2i = tilled[0]
	var best_dist := INF
	for tile in tilled:
		var d := _cell_center(tile).distance_to(PLOT_CENTER)
		if d < best_dist:
			best_dist = d
			best_tile = tile
	var scarecrow := SCARECROW_SCENE.instantiate()
	scarecrow.global_position = _cell_center(best_tile)
	add_child(scarecrow)
	return true

## Spawns a Pumpkin Wall at the endpoint of the shortest enemy route so that
## enemies stop and attack it there rather than continuing to the plot.
## Kept as a debug/utility helper; the Pumpkin Seeds boon now grants seeds
## instead of calling this directly.
func spawn_pumpkin_wall() -> bool:
	if enemy_routes.is_empty():
		push_warning("spawn_pumpkin_wall: no enemy routes available.")
		return false
	var shortest: Array = enemy_routes[0]
	for route in enemy_routes:
		if route.size() < shortest.size():
			shortest = route
	if shortest.is_empty():
		return false
	var wall := PUMPKIN_WALL_SCENE.instantiate()
	wall.global_position = shortest.back()
	add_child(wall)
	return true

## Returns the tile-space bounding rect covering every tilled soil tile on the
## map. Size is zero when no tilled soil exists.
func _tilled_soil_bounds() -> Rect2i:
	var min_tile := Vector2i(0x7FFFFFFF, 0x7FFFFFFF)
	var max_tile := Vector2i(-0x7FFFFFFF, -0x7FFFFFFF)
	var any := false
	for tile in map.get_used_cells():
		if not _is_tilled_soil(tile):
			continue
		any = true
		min_tile.x = min(min_tile.x, tile.x)
		min_tile.y = min(min_tile.y, tile.y)
		max_tile.x = max(max_tile.x, tile.x)
		max_tile.y = max(max_tile.y, tile.y)
	if not any:
		return Rect2i()
	return Rect2i(min_tile, max_tile - min_tile + Vector2i.ONE)

func _physics_process(_delta: float) -> void:
	queue_redraw()

	var player_speed := _current_player_speed()

	# Sickle boon runs before movement so the harvest picks up plants at the
	# frog's current tile, not the tile it's about to leave.
	if game_state.has_sickle:
		_run_sickle_harvest()

	if game_state.has_nail:
		_tick_nail_pulse(_delta)

	# Keyboard/arrow input takes priority over click-to-move.
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_vector != Vector2.ZERO:
		# Cancel any pending click destination so nav doesn't resume when keys release.
		destination = player.global_position
		if navigation_ready:
			navigation_agent.target_position = player.global_position
		player.velocity = input_vector * player_speed
		player.move_and_slide()
		if not sprite.is_playing() or sprite.animation != "stompWalk":
			sprite.play("stompWalk")
		return

	# If navigation isn't ready yet, fall back to direct mouse steering
	if not navigation_ready:
		var offset := destination - player.position
		if offset.length() > 4.0:
			player.velocity = offset.normalized() * player_speed
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

	player.velocity = offset.normalized() * player_speed
	player.move_and_slide()
	if not sprite.is_playing() or sprite.animation != "stompWalk":
		sprite.play("stompWalk")

func _current_player_speed() -> float:
	# Scaled by any active boon that modifies frog speed (e.g. Rubber Boots).
	return PLAYER_SPEED * float(game_state.player_speed_multiplier)

func _run_sickle_harvest() -> void:
	# Duplicate the keys so we can mutate `planted_tiles` mid-iteration when a
	# harvest succeeds. Silently skip tiles whose harvest fails (e.g. frog
	# inventory full) so the sickle just resumes once the player deposits.
	for tile in planted_tiles.keys():
		if not _is_in_planting_range(tile):
			continue
		var plant: Node = planted_tiles.get(tile)
		if not is_instance_valid(plant) or not plant.can_harvest():
			continue
		if not game_state.add_frog_item(game_state.FRUIT_ITEM_ID):
			continue
		game_state.grant_item(game_state.SEED_ITEM_ID, 1)
		if game_state.bonus_seed_chance > 0.0 and randf() < game_state.bonus_seed_chance:
			game_state.grant_item(game_state.SEED_ITEM_ID, 1)
		planted_tiles.erase(tile)
		plant.queue_free()

func _tick_nail_pulse(delta: float) -> void:
	_nail_cooldown -= delta
	if _nail_cooldown > 0.0:
		return
	_nail_cooldown = NAIL_INTERVAL
	var tile_size_px: float = float(Vector2(map.tile_set.tile_size).x) * float(map.scale.x)
	var radius_px: float = tile_size_px * NAIL_RADIUS_TILES
	var origin := player.global_position
	var hit_any := false
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		if origin.distance_to((enemy as Node2D).global_position) > radius_px:
			continue
		if enemy.has_method("take_damage"):
			enemy.take_damage(NAIL_DAMAGE)
			hit_any = true
	if hit_any:
		_play_nail_pulse_effect(origin, radius_px)

func _play_nail_pulse_effect(origin: Vector2, radius_px: float) -> void:
	# Cheap tell that the pulse fired: expanding red ring drawn behind the
	# frog. No assets required.
	var ring := Node2D.new()
	ring.global_position = origin
	ring.z_index = -1
	add_child(ring)
	var flash_color := Color(1.0, 0.35, 0.35, 0.75)
	ring.set_meta("radius", 4.0)
	ring.set_meta("color", flash_color)
	ring.draw.connect(func() -> void:
		var r: float = float(ring.get_meta("radius", 4.0))
		var c: Color = ring.get_meta("color", flash_color)
		ring.draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, c, 3.0)
	)
	ring.queue_redraw()
	var tween := create_tween()
	tween.tween_method(func(value: float) -> void:
		ring.set_meta("radius", value)
		ring.queue_redraw(), 4.0, radius_px, 0.35)
	tween.parallel().tween_method(func(alpha: float) -> void:
		var c: Color = flash_color
		c.a = alpha
		ring.set_meta("color", c)
		ring.queue_redraw(), 0.75, 0.0, 0.35)
	tween.finished.connect(ring.queue_free)
