extends CanvasLayer

@onready var start_button: Button = $Backdrop/Panel/Margin/Column/StartButton


func _ready() -> void:
	start_button.pressed.connect(_close)
	start_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()


func _close() -> void:
	hide()
	set_process_unhandled_input(false)
	start_button.release_focus()
