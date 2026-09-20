extends CanvasLayer

const ONBOARDING_TITLE := "WELCOME, GARDENER"
const ONBOARDING_BUTTON := "START FARMING"
const PAUSE_TITLE := "TAKE A BREATH, GARDENER"
const PAUSE_BUTTON := "GET BACK TO IT"

## Persists across scene reloads (e.g. after death → `reload_current_scene`)
## so the welcome overlay only auto-opens the first time the main scene loads
## this process. Reopening it as a pause overlay via hotkey is unaffected.
static var _has_shown_onboarding: bool = false

@onready var start_button: Button = $Backdrop/Panel/Margin/Column/StartButton
@onready var title_label: Label = $Backdrop/Panel/Margin/Column/Title


func _ready() -> void:
	# Keep the onboarding/pause overlay responsive while the rest of the scene
	# is paused so the player can still click the resume button.
	process_mode = Node.PROCESS_MODE_ALWAYS
	start_button.pressed.connect(_close)
	if _has_shown_onboarding:
		# Post-death reload (or any other scene reload): don't re-pause the game
		# with the welcome screen. Player can still summon the pause overlay
		# manually with the pause hotkey.
		hide()
		return
	_has_shown_onboarding = true
	_show_overlay(ONBOARDING_TITLE, ONBOARDING_BUTTON)


## Uses `_input` (not `_unhandled_input`) so the pause hotkey is caught before
## the wave manager's ui_accept binding turns a Space press into a prep-skip.
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key_event := event as InputEventKey
	if key_event.keycode == KEY_P or key_event.keycode == KEY_SPACE:
		_toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if visible and event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


func _toggle_pause() -> void:
	if visible:
		_close()
	else:
		_show_overlay(PAUSE_TITLE, PAUSE_BUTTON)


func _show_overlay(title_text: String, button_text: String) -> void:
	title_label.text = title_text
	start_button.text = button_text
	show()
	get_tree().paused = true
	start_button.grab_focus()


func _close() -> void:
	hide()
	start_button.release_focus()
	get_tree().paused = false
