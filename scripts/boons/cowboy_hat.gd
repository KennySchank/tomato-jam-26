extends Boon

## Cowboy Hat — flips `GameState.wearing_cowboy_hat` on for the run. The player
## scene watches this state (via the `boon_activated` signal) and reveals its
## `HatSprite` child accordingly.
func apply_effect() -> void:
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		return
	game_state.wearing_cowboy_hat = true
