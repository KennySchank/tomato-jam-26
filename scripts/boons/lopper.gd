extends Boon

## Lopper — increases tower projectile damage. This composes additively with
## Wheelbarrow because both effects use the shared run modifier.
const DAMAGE_BONUS := 0.20

func apply_effect() -> void:
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		return
	game_state.tower_damage_multiplier += DAMAGE_BONUS
