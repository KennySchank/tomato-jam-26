extends CharacterBody2D
@onready var player_sprite = $AnimatedSprite2D
@onready var hat_sprite: Sprite2D = $HatSprite

func _ready() -> void:
	queue_redraw()
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null:
		# Refresh cosmetic overlays whenever any boon activates. Cheap enough
		# to just re-check every field since boons resolve one-at-a-time.
		if not game_state.boon_activated.is_connected(_refresh_cosmetics):
			game_state.boon_activated.connect(_refresh_cosmetics)
		_refresh_cosmetics()

func _physics_process(delta: float) -> void:
	if velocity.x > 0.0:
		player_sprite.flip_h = true
	elif velocity.x < 0.0:
		player_sprite.flip_h = false
	if hat_sprite != null and hat_sprite.visible:
		hat_sprite.flip_h = player_sprite.flip_h

func _refresh_cosmetics(_boon_id: String = "") -> void:
	if hat_sprite == null:
		return
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		return
	hat_sprite.visible = bool(game_state.wearing_cowboy_hat)
