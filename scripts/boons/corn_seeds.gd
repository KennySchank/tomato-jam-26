extends Boon

## Corn Seeds — instantly plants a Corn Tower on a random empty tilled soil
## tile. Corn towers trade damage per shot for a wider engagement range (see
## `scenes/corn_tower.tscn`).
func apply_effect() -> void:
	var main := get_tree().current_scene
	if main == null or not main.has_method("spawn_corn_tower"):
		push_warning("Corn Seeds boon: current scene has no `spawn_corn_tower` handler.")
		return
	main.spawn_corn_tower()
