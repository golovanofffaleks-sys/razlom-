class_name LinaTuning
extends Resource

@export_range(2.0, 10.0, 0.1) var run_speed: float = 5.5
@export_range(8.0, 24.0, 0.5) var dash_speed: float = 14.0
@export_range(0.20, 1.00, 0.05) var aim_time_scale: float = 0.40

@export var run_acceleration: float = 50.0
@export var run_deceleration: float = 60.0
@export var dash_duration: float = 0.18
@export var dash_cooldown: float = 0.35
@export var aim_movement_factor: float = 0.65
