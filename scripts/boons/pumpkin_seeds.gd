extends Boon

## Pumpkin Seeds — unlocks the Pumpkin Seed reserve and grants a starting
## stack. The player plants them on enemy path tiles to drop a Pumpkin Wall
## that enemies attack instead of the plot.
const SEED_GRANT := 5

func apply_effect() -> void:
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		return
	game_state.unlock_seed_type(game_state.PUMPKIN_SEED_ID)
	game_state.add_seeds(SEED_GRANT, game_state.PUMPKIN_SEED_ID)
