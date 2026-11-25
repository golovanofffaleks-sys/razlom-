class_name LinaLifeMagic
extends Node3D

signal charges_changed(current: int, maximum: int)

@export var health: HealthComponent
@export_range(1, 8, 1) var max_charges: int = 3
@export_range(0.05, 1.0, 0.05) var heal_fraction: float = 0.35
@export var balance_xp: float = 15.0

var charges: int
var _flash: Tween

@onready var _particles: CPUParticles3D = $Sparks
@onready var _glow: OmniLight3D = $Glow
@onready var _ring: MeshInstance3D = $Ring
@onready var _sound: AudioStreamPlayer3D = $Sound


func _ready() -> void:
	refill()
	health.rally_recovered.connect(_emit_sparks)


func refill() -> void:
	charges = max_charges
	charges_changed.emit(charges, max_charges)


func cast() -> bool:
	if charges <= 0 or health.current_health <= 0.0 or health.current_health >= health.max_health:
		return false
	charges -= 1
	health.heal(health.max_health * heal_fraction)
	charges_changed.emit(charges, max_charges)
	StatsManager.add_xp("balance_magic", balance_xp)
	pulse()
	return true


func pulse() -> void:
	if _flash != null and _flash.is_valid():
		_flash.kill()
	_emit_sparks()
	_glow.light_color = Color(1.0, 0.67, 0.32)
	_glow.light_energy = 4.4
	_ring.scale = Vector3(0.12, 1.0, 0.12)
	_ring.transparency = 0.15
	_ring.show()
	_sound.play()
	_flash = create_tween().set_parallel(true)
	_flash.tween_property(_glow, "light_energy", 0.0, 0.72).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_flash.tween_property(_glow, "light_color", Color(0.62, 0.27, 1.0), 0.32)
	_flash.tween_property(_ring, "scale", Vector3(1.7, 1.0, 1.7), 0.60).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_flash.tween_property(_ring, "transparency", 1.0, 0.60)
	_flash.chain().tween_callback(_ring.hide)


func _emit_sparks() -> void:
	_particles.restart()
	_particles.emitting = true
