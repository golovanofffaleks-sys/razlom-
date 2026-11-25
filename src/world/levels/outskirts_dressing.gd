extends Node3D

@export var needles: StandardMaterial3D
@export var bark: StandardMaterial3D
@export var stone: StandardMaterial3D
@export var brush: StandardMaterial3D


func _ready() -> void:
	for prop: Node in $Woodland.get_children():
		_surface_prop(prop)
	for prop: Node in $Hollow.get_children():
		if prop.name.begins_with("Outcrop"):
			_surface_prop(prop)


func _surface_prop(prop: Node) -> void:
	for mesh: MeshInstance3D in prop.find_children("*", "MeshInstance3D", true, false):
		match mesh.name:
			&"Leaves":
				mesh.material_override = needles
			&"Trunk", &"DeadBranch":
				mesh.material_override = bark
			&"Bush":
				mesh.material_override = brush
			_:
				mesh.material_override = stone
