extends Boon

## Fertilizer — tomatoes grow 10% faster from here on out. Freshly-planted
## tomatoes read `GameState.plant_growth_multiplier` in their `_ready` and
## divide their growth duration by it. Existing plants keep their in-progress
## timer to avoid mid-tween jumps.
const GROWTH_BONUS := 0.10

func apply_effect() -> void:
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		return
	game_state.plant_growth_multiplier += GROWTH_BONUS
