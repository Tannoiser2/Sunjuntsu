## Pedina 3D — Senjutsu
##
## Carica la miniatura .obj indicata (Tabelle_Materiali/Senjutsu/Miniature) e la
## dimensiona sull'esagono (`cell_size`): modello + base proporzionati così la
## pedina è "grande come l'esagono". Le .obj non hanno texture (.mtl mancanti),
## quindi applica una tinta. Fallback a capsula se il modello manca.
extends Node3D

@export var tint: Color = Color(0.8, 0.2, 0.2)
@export var mesh_path: String = ""        ## es. "res://assets/miniatures/warrior.obj"
@export var cell_size: float = 3.0        ## raggio esagono: dimensiona la pedina
@export var height_ratio: float = 2.4    ## altezza modello = cell_size * height_ratio (pedina grande ~ esagono)

var _built_size: float = 0.0


func _ready() -> void:
	_built_size = cell_size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 0.7

	# Modelli .glb/.gltf: mantengono i PROPRI materiali/texture (miniature a colori).
	var scene_node := _load_model_scene(mesh_path)
	if scene_node != null:
		_add_scene_model(scene_node)
	else:
		var mesh: Mesh = _load_mesh(mesh_path)
		if mesh != null:
			_add_model(mesh, mat)   # .obj senza texture: tinta piatta
		else:
			_add_placeholder(mat)
	_add_base()
	_add_facing_indicator()


## Carica un modello con materiali propri (PackedScene da .glb/.gltf). null se non c'è.
func _load_model_scene(path: String) -> Node3D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var res = load(path)
	if res is PackedScene:
		var inst = res.instantiate()
		if inst is Node3D:
			return inst
		inst.queue_free()
	return null


## Aggiunge il modello texturizzato, normalizzato sull'altezza dell'esagono, base a y=0.
func _add_scene_model(node: Node3D) -> void:
	add_child(node)
	var aabb := _scene_aabb(node, Transform3D.IDENTITY)
	var h: float = maxf(0.001, aabb.size.y)
	var s: float = (cell_size * height_ratio) / h
	node.scale = Vector3(s, s, s)
	# Centra in X/Z e appoggia la base a terra (y=0).
	var center := aabb.position + aabb.size * 0.5
	node.position = Vector3(-center.x * s, -aabb.position.y * s, -center.z * s)


## AABB combinata di tutte le MeshInstance3D nel sottoalbero (spazio locale del modello).
func _scene_aabb(node: Node, xform: Transform3D) -> AABB:
	var out := AABB()
	var have := false
	var t: Transform3D = xform
	if node is Node3D:
		t = xform * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		out = t * (node as MeshInstance3D).mesh.get_aabb()
		have = true
	for c in node.get_children():
		var sub := _scene_aabb(c, t)
		if sub.size != Vector3.ZERO:
			out = sub if not have else out.merge(sub)
			have = true
	return out


## Ruota la pedina (attorno a Y) verso l'angolo mondo indicato.
func face(angle: float) -> void:
	rotation.y = angle


## Riscala la pedina quando cambia la dimensione degli esagoni (calibrazione).
func rescale(new_cell: float) -> void:
	if _built_size > 0.0:
		var k: float = new_cell / _built_size
		scale = Vector3(k, k, k)


func _load_mesh(path: String) -> Mesh:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var res = load(path)
	if res is Mesh:
		return res
	if res is PackedScene:
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
	# I .obj sono Y-up con base a y~0: normalizza sull'altezza voluta.
	var aabb := mesh.get_aabb()
	var h: float = maxf(0.001, aabb.size.y)
	var s: float = (cell_size * height_ratio) / h
	mi.scale = Vector3(s, s, s)
	mi.position.y = -aabb.position.y * s
	add_child(mi)


func _add_placeholder(mat: StandardMaterial3D) -> void:
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = cell_size * 0.35
	capsule.height = cell_size * height_ratio
	body.mesh = capsule
	body.material_override = mat
	body.position.y = cell_size * height_ratio * 0.5
	add_child(body)


func _add_base() -> void:
	var base := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = cell_size * 0.88
	disc.bottom_radius = cell_size * 0.92
	disc.height = cell_size * 0.05
	base.mesh = disc
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = tint.darkened(0.45)
	base_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	base_mat.albedo_color.a = 0.7
	base.material_override = base_mat
	base.position.y = cell_size * 0.03
	add_child(base)


func _add_facing_indicator() -> void:
	var nose := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = cell_size * 0.14
	cone.height = cell_size * 0.32
	nose.mesh = cone
	nose.rotation_degrees = Vector3(90, 0, 0)   # punta verso +Z (avanti)
	nose.position = Vector3(0, cell_size * 0.12, cell_size * 0.7)
	var m := StandardMaterial3D.new()
	m.albedo_color = tint.lightened(0.3)
	m.emission_enabled = true
	m.emission = tint
	nose.material_override = m
	add_child(nose)
