class_name LinaGymControls
extends LinaPlayControls

@onready var _hud: LinaGymHud = $LinaGymHud
var _session: GymSession = GymSession.new()


func _handle_shortcut(key: Key) -> bool:
	_session.hud = _hud
	return _session.handle_shortcut(self, key)


func _process(delta: float) -> void:
	super._process(delta)
	_hud.update_metrics(_lina.get_real_velocity(), Engine.time_scale)


func _on_aiming_changed(aiming: bool) -> void:
	super._on_aiming_changed(aiming)
	_hud.set_aiming(aiming)


func _bind_hud() -> void:
	_hud.bind(_lina.tuning)
