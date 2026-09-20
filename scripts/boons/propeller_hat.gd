extends Boon

## Propeller Hat — periodically blows nearby enemies backward along their route.
func apply_effect() -> void:
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		return
	game_state.has_propeller_hat = true
