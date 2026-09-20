extends Boon

## Gardening Gloves — gives every future tomato harvest a 10% chance to yield
## an extra tomato seed straight to the chest. `main.gd::_try_harvest` reads
## `GameState.bonus_seed_chance` and rolls against it after a successful pick.
const CHANCE_BONUS := 0.10

func apply_effect() -> void:
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		return
	game_state.bonus_seed_chance += CHANCE_BONUS
