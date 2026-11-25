class_name RiftSpawner
extends Node3D

signal encounter_changed(state: State, wave: int, total: int, living: int)
signal seal_progress_changed(available: bool, progress: float)

enum State { ACTIVE, VULNERABLE, CLOSED }

const MINION: PackedScene = preload("res://src/enemies/rift_minion.tscn")
const ACTIVE_COLOR: Color = Color(0.67, 0.24, 0.98)
const VULNERABLE_COLOR: Color = Color(0.26, 0.96, 0.77)

@export var rift_id: String = "small_rift"
@export var target: LinaController
@export var tuning: RiftTuning
@export_range(1, 8, 1) var wave_count: int = 2
@export var activation_radius: float = 0.0

var _state: State = State.ACTIVE
var _wave: int = 0
var _living: int = 0
var _between_waves: float = 0.0
var _seal_started_ms: int = -1
var _seal_progress: float = 0.0
var _seal_available: bool = false
var _close_flash: Tween
var _activated: bool = false

@onready var _minions: Node3D = $Minions
@onready var _crack: Node3D = $Crack
@onready var _crack_material: ShaderMaterial = $Crack/Face.material_override
@onready var _light: OmniLight3D = $OmniLight3D
@onready var _veins: CPUParticles3D = $Veins
@onready var _burst: CPUParticles3D = $Burst
@onready var _seal_sound: AudioStreamPlayer3D = $SealSound
@onready var _hum: AudioStreamPlayer3D = $Hum
@onready var _hint: Label3D = $Hint
@onready var _sigil_material: StandardMaterial3D = $Sigil.material_override


func _ready() -> void:
	reset()


func reset_unsealed() -> void:
	if _state != State.CLOSED:
		reset()


func reset() -> void:
	for minion: Node in _minions.get_children():
		_minions.remove_child(minion)
		minion.queue_free()
	if _close_flash != null and _close_flash.is_valid():
		_close_flash.kill()
	_state = State.ACTIVE
	_activated = activation_radius <= 0.0
	_wave = 0
	_living = 0
	_between_waves = 0.0
	_seal_started_ms = -1
	_set_seal_progress(false, 0.0)
	_crack.scale = Vector3.ONE
	_crack.show()
	_light.light_energy = 2.5
	_light.show()
	_veins.emitting = true
	_burst.emitting = false
	_seal_sound.stop()
	_hum.pitch_scale = 1.0
	_hum.play()
	_set_color(ACTIVE_COLOR)
	encounter_changed.emit(_state, _wave, wave_count, _living)


func _physics_process(delta: float) -> void:
	if _state != State.ACTIVE or _living > 0 or not is_instance_valid(target) or target.health.current_health <= 0.0 or target.in_sanctuary:
		return
	if not _activated:
		if global_position.distance_squared_to(target.global_position) > activation_radius * activation_radius:
			return
		_activated = true
	_between_waves += delta
	var interval: float = tuning.opening_delay if _wave == 0 else tuning.wave_interval
	if _between_waves >= interval:
		_spawn_wave()


func _process(_delta: float) -> void:
	if _state == State.CLOSED:
		return
	var pulse: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.006)
	_light.light_energy = 2.5 + pulse * 1.1 + _seal_progress * 3.0
	_crack_material.set_shader_parameter(&"charge", _seal_progress)
	_hum.pitch_scale = 1.0 + _seal_progress * 0.24


func can_seal() -> bool:
	return _state == State.VULNERABLE and is_instance_valid(target) and target.health.current_health > 0.0 and target.global_position.distance_squared_to(global_position) <= tuning.seal_radius * tuning.seal_radius


func get_encounter_state() -> State:
	return _state


func get_wave() -> int:
	return _wave


func get_living_count() -> int:
	return _living


func get_seal_progress() -> float:
	return _seal_progress


func update_seal(held: bool, controls_active: bool) -> void:
	var available: bool = controls_active and can_seal()
	if not available or not held:
		_seal_started_ms = -1
		_set_seal_progress(available, 0.0)
		return
	var now: int = Time.get_ticks_msec()
	if _seal_started_ms < 0:
		_seal_started_ms = now
	var elapsed: float = float(now - _seal_started_ms) / 1000.0
	var progress: float = clampf(elapsed / tuning.seal_duration, 0.0, 1.0)
	_set_seal_progress(true, progress)
	if progress >= 1.0:
		_close()


func _spawn_wave() -> void:
	_wave += 1
	var rotation_angle: float = float(_wave - 1) * PI * 0.83
	_spawn_minion(Vector3(-2.50, 0.06, 0.80).rotated(Vector3.UP, rotation_angle))
	_spawn_minion(Vector3(2.70, 0.06, -1.30).rotated(Vector3.UP, rotation_angle))
	encounter_changed.emit(_state, _wave, wave_count, _living)


func _spawn_minion(offset: Vector3) -> void:
	if (global_transform * offset).distance_squared_to(target.global_position) < 1.0:
		offset = offset.rotated(Vector3.UP, PI * 0.5)
	var minion: RiftMinion = MINION.instantiate() as RiftMinion
	minion.target = target
	minion.tuning = tuning
	minion.position = offset
	minion.defeated.connect(_on_minion_defeated, CONNECT_ONE_SHOT)
	_living += 1
	_minions.add_child(minion)


func _on_minion_defeated() -> void:
	_living -= 1
	if _living == 0:
		_between_waves = 0.0
		if _wave == wave_count:
			_state = State.VULNERABLE
			_set_color(VULNERABLE_COLOR)
	encounter_changed.emit(_state, _wave, wave_count, _living)


func _set_seal_progress(available: bool, progress: float) -> void:
	if available == _seal_available and progress == _seal_progress:
		return
	_seal_available = available
	_seal_progress = progress
	_hint.visible = available and progress == 0.0
	seal_progress_changed.emit(available, progress)


func _set_color(color: Color) -> void:
	_crack_material.set_shader_parameter(&"rift_color", color)
	_light.light_color = color
	_veins.color = color
	_sigil_material.emission = color


func _close() -> void:
	_state = State.CLOSED
	_set_seal_progress(false, 0.0)
	_veins.emitting = false
	_burst.restart()
	_burst.emitting = true
	_hum.stop()
	_seal_sound.play()
	_light.light_color = Color(0.73, 1.0, 0.88)
	_light.light_energy = 10.0
	_sigil_material.emission = Color(0.09, 0.17, 0.14)
	_close_flash = create_tween().set_parallel(true).set_ignore_time_scale(true)
	_close_flash.tween_property(_crack, "scale", Vector3(0.02, 0.16, 0.02), 0.24).set_trans(Tween.TRANS_CUBIC)
	_close_flash.tween_callback(_crack.hide).set_delay(0.24)
	_close_flash.tween_property(_light, "light_energy", 0.0, 0.58).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	encounter_changed.emit(_state, _wave, wave_count, _living)
	StatsManager.add_xp("balance_magic", tuning.balance_xp)
	EventBus.rift_closed.emit(rift_id)
