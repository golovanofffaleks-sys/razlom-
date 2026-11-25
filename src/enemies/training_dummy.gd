class_name TrainingDummy
extends StaticBody3D

const STRIKE_RADIUS: float = 2.35
const STRIKE_WINDUP: float = 0.65
const STRIKE_RECOVERY: float = 1.20
const STRIKE_DAMAGE: float = 18.0

@export var attack_target: LinaController

var _feedback: Tween
var _windup_left: float = 0.0
var _recovery_left: float = 0.0

@onready var health: HealthComponent = $Health
@onready var _visual: Node3D = $Visual
@onready var _health_viewport: SubViewport = $HealthViewport
@onready var _health_display: Sprite3D = $HealthDisplay
@onready var _bar: ProgressBar = _health_viewport.get_node("Bar")
@onready var _health_label: Label = _health_viewport.get_node("Value")
@onready var _damage_label: Label3D = $Damage
@onready var _damage_origin: Vector3 = _damage_label.position
@onready var _strike_ring: MeshInstance3D = $StrikeRing


func _ready() -> void:
	_health_display.texture = _health_viewport.get_texture()
	health.health_changed.connect(_on_health_changed)
	reset()


func reset() -> void:
	_windup_left = 0.0
	_recovery_left = 0.0
	_strike_ring.hide()
	($Hurtbox as HurtboxComponent).clear_elements()
	health.reset()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(attack_target) or health.current_health <= 0.0:
		return
	var tempo: float = delta * ($Hurtbox as HurtboxComponent).effect_speed()
	var in_range: bool = global_position.distance_squared_to(attack_target.global_position) <= STRIKE_RADIUS * STRIKE_RADIUS
	if _windup_left > 0.0:
		_windup_left = maxf(0.0, _windup_left - tempo)
		if _windup_left == 0.0:
			_strike_ring.hide()
			_recovery_left = STRIKE_RECOVERY
			if in_range:
				attack_target.defense.receive_strike(STRIKE_DAMAGE, global_position)
	elif _recovery_left > 0.0:
		_recovery_left = maxf(0.0, _recovery_left - tempo)
	elif in_range and attack_target.health.current_health > 0.0:
		_windup_left = STRIKE_WINDUP
		_strike_ring.show()


func _on_health_changed(current: float, maximum: float, damage: float) -> void:
	_bar.max_value = maximum
	_bar.value = current
	_health_label.text = "%d / %d" % [roundi(current), roundi(maximum)]
	if _feedback != null:
		_feedback.kill()
	_visual.rotation_degrees.x = -13.0 if current <= 0.0 else 0.0
	if current <= 0.0:
		_strike_ring.hide()
	_damage_label.visible = damage > 0.0
	if damage <= 0.0:
		return
	_damage_label.position = _damage_origin
	_damage_label.modulate.a = 1.0
	_damage_label.text = "−%d" % roundi(damage)
	_feedback = create_tween().set_parallel(true).set_ignore_time_scale(true)
	_feedback.tween_property(_damage_label, "position:y", _damage_origin.y + 0.65, 0.70)
	_feedback.tween_property(_damage_label, "modulate:a", 0.0, 0.40).set_delay(0.30)
	if current > 0.0:
		_visual.rotation_degrees.x = -7.0
		_feedback.tween_property(_visual, "rotation_degrees:x", 0.0, 0.23).set_trans(Tween.TRANS_BACK)
