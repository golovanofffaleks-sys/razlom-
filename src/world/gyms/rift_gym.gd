extends "res://src/world/gyms/combat_gym.gd"

const SEAL_ACTION: StringName = &"interact"
const LOW_HEALTH_LINE: String = "Ну давай, не подведи меня сейчас, я знаю, ты тоже этого не хочешь..."
const RIFT_CLOSED_LINE: String = "Вот так. Тихо. Ещё один шрам на мире затянули..."

@onready var _rift: RiftSpawner = $RiftSpawner


func _input(event: InputEvent) -> void:
	if event.is_action_released(SEAL_ACTION):
		_rift.update_seal(false, _controls_active())
	super._input(event)


func _bind_hud() -> void:
	_lina.animations.configure_actions(_combat.tuning)
	(_hud as RiftGymHud).bind_rift(_rift, _lina.health, _combat.stamina)
	_lina.health.health_changed.connect(_on_lina_health_changed)
	EventBus.rift_closed.connect(_on_rift_closed)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_rift.update_seal(Input.is_action_pressed(SEAL_ACTION), _controls_active())


func _controls_active() -> bool:
	return super._controls_active() and _lina.health.current_health > 0.0


func _reset_targets() -> void:
	(_hud as RiftGymHud).clear_monologue()
	_rift.reset()


func _release_controls() -> void:
	super._release_controls()
	_rift.update_seal(false, false)


func _on_lina_health_changed(current: float, maximum: float, damage: float) -> void:
	var threshold: float = maximum * 0.40
	if current < threshold and current + damage >= threshold:
		EventBus.lina_monologue(LOW_HEALTH_LINE)


func _on_rift_closed(rift_id: String) -> void:
	if rift_id == _rift.rift_id:
		EventBus.lina_monologue(RIFT_CLOSED_LINE)
