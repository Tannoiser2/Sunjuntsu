## Arena 3D — Senjutsu
##
## Costruisce proceduralmente una mappa esagonale (raggio configurabile),
## camera orbitale, illuminazione e due pedine. Click su un esagono = muovi la
## pedina attiva (entro la portata, celle libere).
##
## Questo è lo scaffold giocabile del "primo passaggio": dimostra mappa hex 3D
## + pedine + camera + interazione. La logica di duello completa vive in
## engine/Duel.gd e va collegata progressivamente (vedi DESIGN.md).
extends Node3D

const TILE_GROUP := "hex_tile"

@export var map_radius: int = 6
@export var move_budget: int = 3   ## passi consentiti per dimostrare il movimento

var state: GameState
var _tiles: Dictionary = {}        ## Vector2i -> MeshInstance3D
var _pawns: Array[Node3D] = []
var _active_pawn: int = 0
var _highlighted: Array[Vector2i] = []

var _cam_pivot: Node3D
var _cam_yaw: float = 0.6
var _cam_pitch: float = 0.9
var _cam_dist: float = 16.0
var _dragging := false

var _hud: CanvasLayer
var _duel: Duel


func _ready() -> void:
	state = GameState.new()
	state.map_radius = map_radius
	_build_environment()
	_build_map()
	_spawn_pawns()
	_select_pawn(0)
	_build_hud()
	_start_duel()


func _build_hud() -> void:
	_hud = preload("res://scenes/HUD.tscn").instantiate()
	add_child(_hud)
	_hud.card_played.connect(_on_card_played)


func _start_duel() -> void:
	_duel = Duel.new(state)
	_duel.turn_resolved.connect(_on_turn_resolved)
	_duel.fighter_updated.connect(_on_fighter_updated)
	_duel.duel_over.connect(_on_duel_over)
	_duel.start()
	_refresh_hand()
	_refresh_status()
	_hud.set_hint("Click su una carta = selezionala · secondo click = giocala · click su esagono illuminato = muovi")


func _on_card_played(card_data: Dictionary) -> void:
	var id := int(card_data.get("id", -1))
	if id == -1:
		return
	if _duel.plan_card(0, id):
		_refresh_hand()


func _on_fighter_updated(_i: int) -> void:
	_sync_pawns()
	_refresh_status()


func _on_turn_resolved(log: Array) -> void:
	_sync_pawns()
	_refresh_hand()
	_refresh_status()
	if not log.is_empty():
		_hud.set_hint(String("\n").join(log).left(220))


func _on_duel_over(winner: int) -> void:
	var who := "Pareggio" if winner < 0 else "%s vince!" % state.fighters[winner].character
	_hud.set_info("⚔ Duello terminato — %s" % who)
	_hud.show_hand([])
	_clear_highlight()


## Costruisce la mano del giocatore (pedina 0) come schede dati.
func _refresh_hand() -> void:
	var entries: Array = []
	for id in state.fighters[0].hand:
		var c := CardDB.card(id)
		if not c.is_empty():
			entries.append(c)
	_hud.show_hand(entries)


func _refresh_status() -> void:
	var p := state.fighters[0]
	var e := state.fighters[1]
	_hud.set_info("Round %d   |   TU %s: ❤%d/%d ◈%d   —   IA %s: ❤%d/%d ◈%d" % [
		state.round_num,
		p.character, p.remaining_wounds(), p.wound_limit, p.focus,
		e.character, e.remaining_wounds(), e.wound_limit, e.focus])


func _sync_pawns() -> void:
	for i in range(state.fighters.size()):
		var dest := HexGrid.hex_to_world(state.fighters[i].cell, Domain.HEX_SIZE)
		if _pawns[i].position.distance_to(dest) > 0.01:
			var tw := create_tween()
			tw.tween_property(_pawns[i], "position", dest, 0.25).set_trans(Tween.TRANS_SINE)
	if _active_pawn == 0:
		_select_pawn(0)


# ─── Costruzione scena ───────────────────────────────────────────────────────

func _build_environment() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.08, 0.09, 0.11)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.4, 0.42, 0.5)
	e.ambient_light_energy = 0.6
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -40, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)

	_cam_pivot = Node3D.new()
	add_child(_cam_pivot)
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	_cam_pivot.add_child(cam)
	_update_camera()


func _build_map() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.20, 0.34, 0.24)
	var mat_alt := StandardMaterial3D.new()
	mat_alt.albedo_color = Color(0.24, 0.40, 0.28)

	for cell in HexGrid.hexes_in_range(Vector2i.ZERO, map_radius):
		var tile := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = Domain.HEX_SIZE * 0.95
		mesh.bottom_radius = Domain.HEX_SIZE * 0.95
		mesh.height = Domain.HEX_HEIGHT
		mesh.radial_segments = 6
		tile.mesh = mesh
		tile.rotation_degrees.y = 30.0   # flat-top
		tile.material_override = mat_alt if ((cell.x + cell.y) & 1) else mat
		tile.position = HexGrid.hex_to_world(cell, Domain.HEX_SIZE)
		tile.add_to_group(TILE_GROUP)
		tile.set_meta("cell", cell)

		# Collisione per il picking col mouse.
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = Domain.HEX_SIZE * 0.95
		shape.height = Domain.HEX_HEIGHT
		col.shape = shape
		body.add_child(col)
		body.set_meta("cell", cell)
		tile.add_child(body)

		add_child(tile)
		_tiles[cell] = tile


func _spawn_pawns() -> void:
	var Pawn := preload("res://scenes/Pawn.gd")
	var starts := [Vector2i(-3, 1), Vector2i(3, -1)]
	var chars := Domain.PLAYABLE   ## ["Warrior", "Ronin"]
	var colors := [Color(0.85, 0.2, 0.2), Color(0.2, 0.4, 0.9)]
	for i in range(2):
		var f := state.add_fighter(chars[i], starts[i])
		# Mazzo di pesca dai dati autorevoli (foglio Custom Decks).
		f.draw_pile = CardDB.draw_pile_for(chars[i].to_lower())
		f.draw_pile.shuffle()
		f.is_ai = (i == 1)   # pedina 0 = giocatore, pedina 1 = IA solo
		# Limiti dalla carta personaggio (se trascritta).
		var cs := CardDB.character_stats(chars[i])
		if not cs.is_empty():
			f.wound_limit = int(cs.get("wound_limit", f.wound_limit))
			f.hand_limit = int(cs.get("hand_limit", f.hand_limit))
		var pawn: Node3D = Pawn.new()
		pawn.set("tint", colors[i])
		add_child(pawn)
		pawn.position = HexGrid.hex_to_world(f.cell, Domain.HEX_SIZE)
		pawn.set_meta("fighter_index", i)
		_pawns.append(pawn)


# ─── Selezione e movimento ───────────────────────────────────────────────────

func _select_pawn(index: int) -> void:
	_active_pawn = index
	_clear_highlight()
	var f := state.fighters[index]
	_highlighted = HexGrid.reachable(f.cell, move_budget, state.is_blocked)
	for cell in _highlighted:
		if _tiles.has(cell):
			(_tiles[cell] as MeshInstance3D).material_override = _highlight_mat()


func _highlight_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.85, 0.75, 0.3)
	m.emission_enabled = true
	m.emission = Color(0.5, 0.42, 0.1)
	return m


func _clear_highlight() -> void:
	for cell in _highlighted:
		if _tiles.has(cell):
			var alt := ((cell.x + cell.y) & 1) != 0
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.24, 0.40, 0.28) if alt else Color(0.20, 0.34, 0.24)
			(_tiles[cell] as MeshInstance3D).material_override = m
	_highlighted.clear()


func _move_active_to(cell: Vector2i) -> void:
	if not _highlighted.has(cell):
		return
	# Il giocatore riposiziona la propria pedina (pedina 0).
	state.fighters[0].cell = cell
	var pawn := _pawns[0]
	var dest := HexGrid.hex_to_world(cell, Domain.HEX_SIZE)
	var tw := create_tween()
	tw.tween_property(pawn, "position", dest, 0.25).set_trans(Tween.TRANS_SINE)
	_select_pawn(0)


# ─── Input: camera orbitale + picking ────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_cam_dist = max(6.0, _cam_dist - 1.0); _update_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_cam_dist = min(40.0, _cam_dist + 1.0); _update_camera()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_try_pick(event.position)
	elif event is InputEventMouseMotion and _dragging:
		_cam_yaw -= event.relative.x * 0.005
		_cam_pitch = clamp(_cam_pitch - event.relative.y * 0.005, 0.2, 1.4)
		_update_camera()


func _update_camera() -> void:
	var cam: Camera3D = _cam_pivot.get_node("Camera3D")
	var x := _cam_dist * sin(_cam_pitch) * sin(_cam_yaw)
	var y := _cam_dist * cos(_cam_pitch)
	var z := _cam_dist * sin(_cam_pitch) * cos(_cam_yaw)
	cam.position = Vector3(x, y, z)
	cam.look_at(Vector3.ZERO, Vector3.UP)


func _try_pick(screen_pos: Vector2) -> void:
	var cam: Camera3D = _cam_pivot.get_node("Camera3D")
	var from := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 1000.0)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return
	var collider = hit["collider"]
	if collider and collider.has_meta("cell"):
		_move_active_to(collider.get_meta("cell"))
