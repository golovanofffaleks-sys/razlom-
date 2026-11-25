extends LinaCombatControls

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
	super._bind_hud()
	(_hud as CombatGymHud).bind_combat(_combat.tuning, _lina.health, _combat.stamina)
	_combat.element_changed.connect((_hud as CombatGymHud).set_element)


func _reset() -> void:
	super._reset()
	_reset_targets()


func _reset_targets() -> void:
	for dummy: Node in $Dummies.get_children():
		(dummy as TrainingDummy).reset()
