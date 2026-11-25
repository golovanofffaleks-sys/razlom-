class_name LinaCombatTuning
extends Resource

@export_range(12.0, 45.0, 0.5) var arrow_speed: float = 28.0
@export_range(5.0, 60.0, 1.0) var arrow_damage: float = 22.0
@export_range(0.0, 50.0, 1.0) var archery_xp: float = 25.0
@export_range(5.0, 75.0, 1.0) var sword_damage: float = 35.0
@export_range(1.0, 3.5, 0.1) var sword_reach: float = 2.0

@export_group("Stamina and dodge")
@export_range(5.0, 50.0, 1.0) var stamina_regen: float = 24.0
@export_range(5.0, 50.0, 1.0) var dodge_cost: float = 26.0
@export_range(0.0, 0.60, 0.01) var dodge_iframes: float = 0.35
@export var max_stamina: float = 100.0
@export var stamina_regen_delay: float = 0.8
@export var block_regen_factor: float = 0.35
@export var block_damage_factor: float = 0.25
@export var bow_stamina_per_second: float = 18.0
@export var sword_stamina_cost: float = 32.0
@export var dodge_duration: float = 0.60
@export var dodge_speed: float = 5.6
@export var acrobatic_aim_duration: float = 1.2
@export var acrobatic_aim_scale: float = 0.25

@export_group("Attack timing and flight")
@export var arrow_gravity_scale: float = 0.45
@export var arrow_lifetime: float = 4.0
@export var bow_cooldown: float = 0.32
@export var bow_draw_time: float = 0.30
@export var sword_windup: float = 0.24
@export var sword_active: float = 0.14
@export var sword_recovery: float = 0.38
@export var follow_windup_factor: float = 0.82
@export var follow_damage_factor: float = 1.42
@export var follow_stamina_cost: float = 40.0
@export var parry_window: float = 0.22
@export var parry_cost: float = 8.0
@export var block_stamina_factor: float = 0.75
@export var riposte_damage_factor: float = 3.0

@export_group("Rally")
@export_range(0.0, 1.0, 0.05) var rally_damage_fraction: float = 0.50
@export var point_blank_range: float = 3.0
