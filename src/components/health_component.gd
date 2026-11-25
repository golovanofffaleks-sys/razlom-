class_name HealthComponent
extends Node

signal health_changed(current: float, maximum: float, damage: float)
signal rally_changed(available: float)
signal rally_recovered

@export_range(1.0, 1000.0, 1.0) var max_health: float = 100.0
@export_range(0.0, 10.0, 0.1) var rally_window: float = 0.0

var current_health: float
var recoverable_health: float = 0.0
var _rally_clock: float = 0.0
# Порции урона хранятся от самой старой к новой: остаток HP и момент истечения.
var _rally_losses: Array[Vector2] = []


func _ready() -> void:
	reset()


func take_damage(amount: float) -> float:
	if amount <= 0.0 or not is_finite(amount) or current_health <= 0.0:
		return 0.0
	var applied: float = minf(amount, current_health)
	current_health -= applied
	health_changed.emit(current_health, max_health, applied)
	if current_health <= 0.0:
		_clear_rally()
	elif rally_window > 0.0:
		_rally_losses.append(Vector2(applied, _rally_clock + rally_window))
		_set_recoverable(recoverable_health + applied)
		set_process(true)
	return applied


func heal(amount: float) -> float:
	if current_health <= 0.0 or amount <= 0.0 or not is_finite(amount):
		return 0.0
	var restored: float = minf(amount, max_health - current_health)
	if restored > 0.0:
		current_health += restored
		health_changed.emit(current_health, max_health, 0.0)
		_spend_rally(restored)
	return restored


func recover_rally(amount: float) -> float:
	var restored: float = heal(minf(amount, recoverable_health))
	if restored > 0.0:
		rally_recovered.emit()
	return restored


func reset() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health, 0.0)
	_clear_rally()


func _process(delta: float) -> void:
	_rally_clock += delta / Engine.time_scale
	var expired: float = 0.0
	while not _rally_losses.is_empty() and _rally_losses[0].y <= _rally_clock:
		var loss: Vector2 = _rally_losses.pop_front()
		expired += loss.x
	if expired > 0.0:
		_set_recoverable(recoverable_health - expired)


func _spend_rally(amount: float) -> void:
	var spent: float = minf(amount, recoverable_health)
	var left: float = spent
	while left > 0.0 and not _rally_losses.is_empty():
		var loss: Vector2 = _rally_losses[0]
		if left < loss.x:
			loss.x -= left
			_rally_losses[0] = loss
			break
		left -= loss.x
		_rally_losses.pop_front()
	if spent > 0.0:
		_set_recoverable(recoverable_health - spent)


func _set_recoverable(amount: float) -> void:
	recoverable_health = 0.0 if _rally_losses.is_empty() else maxf(amount, 0.0)
	if _rally_losses.is_empty():
		set_process(false)
	rally_changed.emit(recoverable_health)


func _clear_rally() -> void:
	_rally_clock = 0.0
	_rally_losses.clear()
	_set_recoverable(0.0)
