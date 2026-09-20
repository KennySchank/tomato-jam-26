extends Boon

## Scarecrow — places a scarecrow on the center-most tomato plot. It absorbs
## enemy attacks aimed at the plot for 5 hits before falling.
func apply_effect() -> void:
	var main := get_tree().current_scene
	if main == null or not main.has_method("spawn_scarecrow"):
		push_warning("Scarecrow boon: current scene has no `spawn_scarecrow` handler.")
		return
	main.spawn_scarecrow()
