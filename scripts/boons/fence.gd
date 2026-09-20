extends Boon

## Fence — spawns a Fence entity spanning the south edge of the plot. The
## fence absorbs any enemy attack aimed at the plot until it breaks (4 hits).
func apply_effect() -> void:
	var main := get_tree().current_scene
	if main == null or not main.has_method("spawn_fence"):
		push_warning("Fence boon: current scene has no `spawn_fence` handler.")
		return
	main.spawn_fence()
