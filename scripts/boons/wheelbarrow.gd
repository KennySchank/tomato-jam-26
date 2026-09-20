extends Boon

## Wheelbarrow — every tower projectile deals 10% more damage for the rest of
## the run. Projectiles read `GameState.tower_damage_multiplier` in `_ready`
## and scale their exported `damage` value once at spawn.
const DAMAGE_BONUS := 0.10

func apply_effect() -> void:
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		return
	game_state.tower_damage_multiplier += DAMAGE_BONUS
