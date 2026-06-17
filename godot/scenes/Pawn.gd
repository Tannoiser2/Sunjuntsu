## Pedina 3D — Senjutsu
##
## Segnaposto procedurale (corpo + base) per un guerriero. Quando le miniature
## .obj saranno integrate (vedi assets/README.md), basterà istanziare la mesh
## importata al posto della capsula generata qui.
extends Node3D

@export var tint: Color = Color(0.8, 0.2, 0.2)


func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 0.6

	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.28
	capsule.height = 1.1
	body.mesh = capsule
	body.material_override = mat
	body.position.y = 0.65
	add_child(body)

	var base := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.4
	disc.bottom_radius = 0.45
	disc.height = 0.12
	base.mesh = disc
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = tint.darkened(0.4)
	base.material_override = base_mat
	base.position.y = 0.06
	add_child(base)

	# Indicatore di direzione (facing).
	var nose := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.12
	cone.height = 0.3
	nose.mesh = cone
	nose.rotation_degrees = Vector3(90, 0, 0)
	nose.position = Vector3(0, 0.5, 0.4)
	nose.material_override = base_mat
	add_child(nose)
