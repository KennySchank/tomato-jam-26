extends Boon

## Rubber Boots — bumps the frog's move speed by 10% for the rest of the run.
## `main.gd` multiplies its base `PLAYER_SPEED` by this factor when driving the
## player each physics tick.
const SPEED_BONUS := 0.10

func apply_effect() -> void:
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		return
	game_state.player_speed_multiplier += SPEED_BONUS
