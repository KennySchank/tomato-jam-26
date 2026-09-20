extends Boon

## Watering Can — every future tomato spawns with an extra hit point. Existing
## plants keep whatever HP they were spawned with; only newly planted tomatoes
## read the higher `GameState.plant_bonus_hp` in their `_ready`.
func apply_effect() -> void:
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		return
	game_state.plant_bonus_hp += 1
