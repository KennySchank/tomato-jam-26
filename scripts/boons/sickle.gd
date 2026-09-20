extends Boon

## Sickle — enables auto-harvest of any mature tomato within the player's
## harvest range. The actual harvest scan runs each frame in `main.gd` while
## `GameState.has_sickle` is true; the boon just flips the switch.
func apply_effect() -> void:
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		return
	game_state.has_sickle = true
