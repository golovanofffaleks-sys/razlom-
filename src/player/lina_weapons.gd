class_name LinaWeapons
extends Node3D

@onready var bow: Node3D = $BowHand/Bow
@onready var sword: Node3D = $SwordHand/Sword
@onready var muzzle: Marker3D = $BowHand/Bow/Muzzle
@onready var _arrow: Node3D = $BowHand/Bow/Muzzle/Arrow
@onready var _arrow_point: MeshInstance3D = $BowHand/Bow/Muzzle/Arrow/Point
@onready var _blade: MeshInstance3D = $SwordHand/Sword/Blade
@onready var _blade_point: MeshInstance3D = $SwordHand/Sword/BladePoint
@onready var _front_fuller: MeshInstance3D = $SwordHand/Sword/FrontFuller
@onready var _back_fuller: MeshInstance3D = $SwordHand/Sword/BackFuller
@onready var _top_string: MeshInstance3D = $BowHand/Bow/TopString
@onready var _bottom_string: MeshInstance3D = $BowHand/Bow/BottomString


func show_action(state: StringName, roll_bow_visible: bool = false) -> void:
	bow.visible = state == &"Aim" or state == &"BowShot" or roll_bow_visible
	sword.visible = state in [&"Sword", &"SwordFollow", &"Block", &"Parry"]
	_arrow.visible = state == &"Aim"


func set_bow_charge(charge: CombatElements.Charge) -> void:
	_arrow_point.material_override = CombatElements.glow(charge)


func set_sword_charge(charge: CombatElements.Charge) -> void:
	var rune: StandardMaterial3D
	var steel: StandardMaterial3D
	if charge != CombatElements.Charge.NONE:
		rune = CombatElements.glow(charge)
		steel = _blade.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
		steel.emission_enabled = true
		steel.emission = CombatElements.COLORS[charge]
		steel.emission_energy_multiplier = 0.48
	_front_fuller.material_override = rune
	_back_fuller.material_override = rune
	_blade.material_override = steel
	_blade_point.material_override = steel


func set_draw(progress: float) -> void:
	_arrow.position.z = lerpf(-0.26, 0.018, progress)
	var nock: Vector3 = Vector3(0.0, 0.0, lerpf(0.113, 0.39, progress))
	_shape_string(_top_string, Vector3(0.0, 0.653, 0.097), nock)
	_shape_string(_bottom_string, Vector3(0.0, -0.653, 0.097), nock)


func _shape_string(mesh: MeshInstance3D, end: Vector3, nock: Vector3) -> void:
	var direction: Vector3 = nock - end
	var orientation: Basis = Basis(Quaternion(Vector3.UP, direction.normalized()))
	var width: Vector3 = Vector3(1.0, direction.length() / (mesh.mesh as CylinderMesh).height, 1.0)
	mesh.transform = Transform3D(orientation.scaled_local(width), (end + nock) * 0.5)
