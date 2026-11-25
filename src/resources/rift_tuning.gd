class_name RiftTuning
extends Resource

@export_range(1.0, 5.0, 0.1) var enemy_speed: float = 2.8
@export_range(0.3, 8.0, 0.1) var wave_interval: float = 2.0
@export_range(0.5, 5.0, 0.1) var seal_duration: float = 1.5

@export_group("Minion")
@export var detection_radius: float = 10.5
@export var strike_radius: float = 2.15
@export var strike_half_angle: float = 62.0
@export var strike_damage: float = 18.0
@export var strike_windup: float = 0.72
@export var strike_recovery: float = 1.10
@export var endurance_xp_per_hp: float = 1.0

@export_group("Posture")
@export var parry_posture: float = 0.50
@export var windup_arrow_posture: float = 0.35
@export var core_arrow_posture: float = 0.50
@export var posture_decay_delay: float = 3.0
@export var posture_decay_per_second: float = 0.12
@export var posture_break_duration: float = 2.5

@export_group("Rift")
@export var opening_delay: float = 1.4
@export var seal_radius: float = 2.45
@export var balance_xp: float = 50.0
