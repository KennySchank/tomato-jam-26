extends Boon

## Corn Seeds — unlocks the Corn Seed reserve and grants a starting stack.
## The player plants them from the reserve UI to place Corn Towers on the
## same tiles where tomato towers can go (see `main.gd::_can_place_item`).
const SEED_GRANT := 5

func apply_effect() -> void:
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		return
	game_state.unlock_seed_type(game_state.CORN_SEED_ID)
	game_state.add_seeds(SEED_GRANT, game_state.CORN_SEED_ID)
