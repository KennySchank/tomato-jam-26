extends CanvasLayer

@onready var start_button: Button = $Backdrop/Panel/Margin/Column/StartButton


func _ready() -> void:
	# Keep the onboarding UI responsive while the rest of the scene is paused so
	# the player can still click "Start Farming" to dismiss it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	start_button.pressed.connect(_close)
	start_button.grab_focus()
	# Pause the tree so the wave manager, harvest timer, player, etc. don't
	# start ticking until the player dismisses the onboarding overlay.
	get_tree().paused = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()


func _close() -> void:
	hide()
	set_process_unhandled_input(false)
	start_button.release_focus()
	get_tree().paused = false
