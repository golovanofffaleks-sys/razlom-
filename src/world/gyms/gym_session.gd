class_name GymSession
extends RefCounted

var hud: LinaGymHud


func handle_shortcut(controls: LinaPlayControls, key: Key) -> bool:
	match key:
		KEY_TAB:
			_set_panel(controls, not hud.is_panel_open())
		KEY_ESCAPE:
			_set_panel(controls, true)
		KEY_R:
			controls._reset()
		KEY_P:
			hud.save_tuning()
		KEY_O:
			hud.toggle_metrics()
		_:
			return false
	return true


func _set_panel(controls: LinaPlayControls, open: bool) -> void:
	if not OS.is_debug_build():
		return
	hud.set_panel_open(open)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED
	if open:
		controls._release_controls()
