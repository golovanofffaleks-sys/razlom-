class_name StaminaComponent
extends Node

signal stamina_changed(current: float, maximum: float)

var tuning: LinaCombatTuning
var current: float
var _regen_delay: float


func reset() -> void:
	_regen_delay = 0.0
	_set_current(tuning.max_stamina)


func spend(amount: float) -> bool:
	if amount > current:
		return false
	if amount > 0.0:
		_regen_delay = tuning.stamina_regen_delay
		_set_current(current - amount)
		StatsManager.add_xp("agility", amount)
	return true


func regenerate(delta: float, blocking: bool) -> void:
	var regen_delta: float = maxf(0.0, delta - _regen_delay)
	_regen_delay = maxf(0.0, _regen_delay - delta)
	if regen_delta > 0.0 and current < tuning.max_stamina:
		var rate: float = tuning.stamina_regen * (tuning.block_regen_factor if blocking else 1.0)
		_set_current(minf(tuning.max_stamina, current + rate * regen_delta))


func _set_current(value: float) -> void:
	current = value
	stamina_changed.emit(current, tuning.max_stamina)
