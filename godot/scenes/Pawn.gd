## Pedina 3D — Senjutsu
##
## Carica la miniatura .obj indicata (Tabelle_Materiali/Senjutsu/Miniature),
## normalizzandone la scala all'altezza voluta. Le .obj non hanno texture
## (.mtl mancanti), quindi applica una tinta per distinguere i combattenti.
## Se il modello non è disponibile, ripiega su una capsula segnaposto.
extends Node3D

@export var tint: Color = Color(0.8, 0.2, 0.2)
@export var mesh_path: String = ""        ## es. "res://assets/miniatures/warrior.obj"
@export var target_height: float = 1.4    ## altezza in unità mondo

const FACING_COLORS := true


func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 0.7
	mat.metallic = 0.0

	var mesh: Mesh = _load_mesh(mesh_path)
	if mesh != null:
		_add_model(mesh, mat)
	else:
		_add_placeholder(mat)
	_add_base()


func _load_mesh(path: String) -> Mesh:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var res = load(path)
	if res is Mesh:
		return res
	if res is PackedScene:
		# Import "scena": estrai la prima Mesh.
		var inst = res.instantiate()
		var m := _first_mesh(inst)
		inst.queue_free()
		return m
	return null


func _first_mesh(node: Node) -> Mesh:
	if node is MeshInstance3D and node.mesh != null:
		return node.mesh
	for c in node.get_children():
		var m := _first_mesh(c)
		if m != null:
			return m
	return null


func _add_model(mesh: Mesh, mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	# Normalizza la scala sull'altezza (i .obj sono Y-up con base a y~0).
	var aabb := mesh.get_aabb()
	var h: float = maxf(0.001, aabb.size.y)
	var s: float = target_height / h
	mi.scale = Vector3(s, s, s)
	mi.position.y = -aabb.position.y * s
	add_child(mi)


func _add_placeholder(mat: StandardMaterial3D) -> void:
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.28
	capsule.height = 1.1
	body.mesh = capsule
	body.material_override = mat
	body.position.y = 0.65
	add_child(body)


func _add_base() -> void:
	var base := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.42
	disc.bottom_radius = 0.46
	disc.height = 0.1
	base.mesh = disc
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = tint.darkened(0.5)
	base.material_override = base_mat
	base.position.y = 0.05
	add_child(base)
