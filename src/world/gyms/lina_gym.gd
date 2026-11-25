extends LinaGymControls

var _target_phase: float = 0.0

@onready var _target: Node3D = $Range/MovingTarget
@onready var _target_origin: Vector3 = _target.position


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_target_phase = fposmod(_target_phase + delta * 1.25, TAU)
	_target.position.x = _target_origin.x + sin(_target_phase) * 2.5


func _reset() -> void:
	super._reset()
	_target_phase = 0.0
	_target.position = _target_origin
