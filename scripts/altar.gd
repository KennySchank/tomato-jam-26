extends StaticBody2D

signal opened

const BORDER_SIZE := Vector2(58.0, 58.0)

## Tiles within this Chebyshev distance of the altar tile cannot host towers.
@export_range(0, 8) var tower_exclusion_radius_tiles: int = 2

## Minimum seconds between Crow God animation replays.
@export var crow_god_min_interval: float = 6.0
## Maximum seconds between Crow God animation replays.
@export var crow_god_max_interval: float = 14.0

@onready var map: TileMapLayer = get_parent().get_node("Map")
@onready var player: CharacterBody2D = get_parent().get_node("Player")
@onready var highlight: InteractableHighlight = $InteractableHighlight
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var crow_god: AnimatedSprite2D = $"Crow God"

var _crow_god_timer: Timer

func _ready() -> void:
	add_to_group("interactable")
	highlight.configure(map, player)
	var altar_tile := _interaction_tile()
	highlight.set_target_tile(altar_tile, Rect2(-BORDER_SIZE * 0.5, BORDER_SIZE), true)
	_setup_crow_god_animation()

func _setup_crow_god_animation() -> void:
	if crow_god == null:
		return
	_crow_god_timer = Timer.new()
	_crow_god_timer.one_shot = true
	_crow_god_timer.timeout.connect(_play_crow_god_animation)
	add_child(_crow_god_timer)
	crow_god.animation_finished.connect(_on_crow_god_animation_finished)
	_play_crow_god_animation()

func _play_crow_god_animation() -> void:
	if crow_god == null:
		return
	crow_god.frame = 0
	crow_god.play("default")

func _on_crow_god_animation_finished() -> void:
	if _crow_god_timer == null:
		return
	var interval := randf_range(crow_god_min_interval, crow_god_max_interval)
	_crow_god_timer.start(interval)

func can_interact_at(world_position: Vector2) -> bool:
	# Accept any click that lands on the altar's collision footprint so the whole
	# visible altar body opens the deposit UI, not just its origin tile.
	var footprint := _global_footprint()
	if footprint.has_point(world_position):
		return true
	var altar_tile := _interaction_tile()
	var clicked_tile := map.local_to_map(map.to_local(world_position))
	return clicked_tile == altar_tile

func can_player_interact(player_node: Node2D) -> bool:
	var altar_tile := _interaction_tile()
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
	var half := shape.size * 0.5 * collision_shape.global_scale.abs()
	var center: Vector2 = collision_shape.global_position
	return Rect2(center - half, half * 2.0)

func _interaction_tile() -> Vector2i:
	return map.local_to_map(map.to_local(collision_shape.global_position))

func interact() -> void:
	opened.emit()

func _process(_delta: float) -> void:
	highlight.set_target_tile(
		_interaction_tile(),
		Rect2(-BORDER_SIZE * 0.5, BORDER_SIZE),
		can_interact_at(get_global_mouse_position())
	)
