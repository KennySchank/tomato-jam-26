extends Boon

## Nail — the frog periodically hurts enemies within a couple of tiles. The
## timer + AoE scan live on the player scene; picking this boon just enables
## the switch that scene watches.
func apply_effect() -> void:
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		return
	game_state.has_nail = true
