extends Boon

## Hoe — banks three "plot repair" charges. Each time an enemy attack would
## destroy a tilled soil tile, one charge is consumed instead and the tile
## survives. The tool "breaks" after three saves.
const CHARGES := 3

func apply_effect() -> void:
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		return
	game_state.hoe_charges += CHARGES
