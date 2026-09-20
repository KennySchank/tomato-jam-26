extends Boon

## Pumpkin Seeds — spawns a Pumpkin Wall on the last tile of the shortest
## enemy route. Enemies stop and attack it there instead of walking on to the
## plot, until the wall is destroyed.
func apply_effect() -> void:
	var main := get_tree().current_scene
	if main == null or not main.has_method("spawn_pumpkin_wall"):
		push_warning("Pumpkin Seeds boon: current scene has no `spawn_pumpkin_wall` handler.")
		return
	main.spawn_pumpkin_wall()
