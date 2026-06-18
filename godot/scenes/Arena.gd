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

@export var map_radius: int = 3    ## esagono di raggio 3 = 37 celle (colonne 4,5,6,7,6,5,4)
# ─── Calibrazione mappa↔griglia (regolabili nell'editor) ─────────────────────
@export var hex_size: float = 3.0          ## raggio esagono in unità mondo
@export var map_world_size: float = 44.0   ## lato del piano-mappa (la board occupa la parte centrale)
@export var map_offset: Vector2 = Vector2(0.0, 0.5)  ## scostamento mappa (x,z) per centrare gli esagoni
@export var map_y_rotation: float = 0.0    ## rotazione mappa attorno a Y (gradi)

var state: GameState
var _tiles: Dictionary = {}        ## Vector2i -> MeshInstance3D
var _pawns: Array[Node3D] = []
var _active_pawn: int = 0
var _highlighted: Array[Vector2i] = []

var _cam_pivot: Node3D
var _cam_yaw: float = 0.0
var _cam_pitch: float = 0.62
var _cam_dist: float = 34.0
var _dragging := false

var _hud: CanvasLayer
var _duel: Duel
var _attack_preview: Array[Vector2i] = []
var _selected_card: Dictionary = {}
var _move_used: bool = false       ## movimento della carta corrente già speso
var _move_states: Dictionary = {}  ## cella -> Array[int] facing legali (dalla carta)
var _kamae_used: bool = false      ## cambio kamae della carta corrente già fatto
var _ground: MeshInstance3D

## Fase dell'interazione: "planning" (programmi una carta) o "resolving"
## (tocca a te risolvere: muovi + attacca nell'ordine d'iniziativa).
var _phase_mode: String = "planning"
var _resolving_index: int = -1     ## chi sta risolvendo ora (-1 = nessuno)


func _ready() -> void:
	state = GameState.new()
	state.map_radius = map_radius
	_build_environment()
	_build_map()
	_spawn_pawns()
	_build_hud()
	_start_duel()


func _build_hud() -> void:
	_hud = preload("res://scenes/HUD.tscn").instantiate()
	add_child(_hud)
	_hud.card_played.connect(_on_card_played)


func _start_duel() -> void:
	_duel = Duel.new(state)
	_duel.interactive = true
	_duel.cards_revealed.connect(_on_cards_revealed)
	_duel.await_resolution.connect(_on_await_resolution)
	_duel.turn_resolved.connect(_on_turn_resolved)
	_duel.fighter_updated.connect(_on_fighter_updated)
	_duel.duel_over.connect(_on_duel_over)
	_hud.card_selected.connect(_on_card_selected)
	_hud.kamae_chosen.connect(_on_kamae_chosen)
	_duel.start()
	# Carta Kamae del giocatore + segnalino della posizione.
	var tree := CardDB.kamae_tree_for(state.fighters[0].character.to_lower())
	if tree.has("card"):
		_hud.setup_kamae_tree(tree["card"], tree.get("nodes", {}))
	_refresh_hand()
	_refresh_status()
	_apply_pawn_facing(0); _apply_pawn_facing(1)
	_hud.set_info("Pianificazione — scegli e programma una carta")
	_hud.set_hint("PIANIFICAZIONE: 1° click anteprima · 2° click PROGRAMMA. Poi rivelazione e risoluzione per iniziativa (muovi/attacca al tuo turno).")


## 2° click su una carta = PROGRAMMA la carta coperta (fase di pianificazione).
## Il movimento NON avviene ora: si farà in risoluzione, nell'ordine d'iniziativa.
func _on_card_played(card_data: Dictionary) -> void:
	if _phase_mode != "planning":
		return   # durante la risoluzione la mano è bloccata
	var id := int(card_data.get("id", -1))
	if id == -1:
		return
	var f := state.fighters[0]
	if not Duel.playable(f, id):
		var req: String = CardDB.geometry(id).get("kamae_req", "")
		_hud.set_hint("⛔ Non giocabile: richiede Kamae %s (sei in %s)" % [
			Domain.STANCE_NAMES.get(Domain.STANCE_FROM_SLUG.get(req, -1), req),
			Domain.STANCE_NAMES[f.stance]])
		return   # la carta resta in mano
	var cost: int = int(CardDB.card(id).get("focus", 0))
	if f.focus < cost:
		_hud.set_hint("◈ Focus insufficiente: servono %d, ne hai %d" % [cost, f.focus])
		return   # la carta resta in mano
	_selected_card = {}
	_clear_overlays()
	_hud.hide_kamae()
	_hud.set_info("Carta programmata (coperta). Rivelazione…")
	_duel.plan_card(0, id)   # → quando entrambi pronti parte begin_resolution()
	_refresh_hand()


func _on_fighter_updated(_i: int) -> void:
	_sync_pawns()
	_refresh_status()


## Entrambe le carte rivelate: mostra cosa ha giocato l'avversario.
func _on_cards_revealed(planned: Dictionary) -> void:
	var mine := int(planned.get(0, -1))
	var theirs := int(planned.get(1, -1))
	var my_name: String = CardDB.card(mine).get("name", "—")
	var their_name: String = CardDB.card(theirs).get("name", "—")
	_hud.set_info("Rivelazione — Tu: %s · Avversario: %s" % [my_name, their_name])


## Tocca a `i` risolvere (ordine d'iniziativa). Se sei tu, muovi e attacca;
## se è l'IA, agisce da sola.
func _on_await_resolution(i: int) -> void:
	_resolving_index = i
	if i == 0:
		_phase_mode = "resolving"
		_move_used = false
		_kamae_used = false
		_selected_card = CardDB.card(state.fighters[0].planned).duplicate()
		_selected_card["id"] = state.fighters[0].planned
		_refresh_overlays()
		_refresh_kamae_chooser()
		_hud.set_info("⚔ Tua risoluzione: %s" % _selected_card.get("name", "?"))
	else:
		_phase_mode = "ai"
		_clear_overlays()
		_hud.hide_kamae()
		_hud.set_info("L'avversario agisce…")
		_run_ai_resolution(i)


## L'IA muove verso il bersaglio, si orienta e poi risolve la sua carta.
func _run_ai_resolution(i: int) -> void:
	var f := state.fighters[i]
	var foe := state.opponent_of(f)
	if foe != null:
		var g := CardDB.geometry(f.planned)
		if g.has("move"):
			var dest := AI.move_target(state, f)
			if dest != f.cell and not state.is_blocked(dest):
				f.cell = dest
			f.facing = AI.facing_toward(f.cell, foe.cell)
			_sync_pawns(); _apply_pawn_facing(i)
	# Piccola pausa per leggibilità, poi applica la carta.
	var t := get_tree().create_timer(0.6)
	t.timeout.connect(func():
		if is_instance_valid(self) and _duel != null:
			_duel.resolve_current())


## Conferma la risoluzione della carta del giocatore (movimento già fatto).
func _confirm_resolution() -> void:
	if _phase_mode != "resolving" or _resolving_index != 0:
		return
	# Commit To Hit (regolamento p.10): se la carta attacco può colpire muovendoti
	# ma ora manca il bersaglio, devi prima provare a posizionarti per colpire.
	if not _duel.attack_hits_now(0) and not _move_used and _duel.attack_can_hit(0):
		_hud.set_hint("⚔ Commit to Hit: muoviti/ruota per colpire il bersaglio (esagoni rossi)")
		return
	_phase_mode = "wait"
	_clear_overlays()
	_hud.hide_kamae()
	_selected_card = {}
	_duel.resolve_current()


func _on_turn_resolved(log: Array) -> void:
	_phase_mode = "planning"
	_resolving_index = -1
	_selected_card = {}
	_clear_overlays()
	_hud.hide_kamae()
	_sync_pawns()
	_refresh_hand()
	_refresh_status()
	if not log.is_empty():
		_hud.set_hint(String("\n").join(log).left(220) + "\n— Programma la prossima carta —")


func _on_duel_over(winner: int) -> void:
	var who := "Pareggio" if winner < 0 else "%s vince!" % state.fighters[winner].character
	_hud.set_info("⚔ Duello terminato — %s" % who)
	_hud.show_hand([])
	_clear_overlays()
	_hud.hide_kamae()


## Costruisce la mano del giocatore (pedina 0) come schede dati.
func _refresh_hand() -> void:
	var entries: Array = []
	for id in state.fighters[0].hand:
		var c := CardDB.card(id).duplicate()
		if c.is_empty():
			continue
		var img := CardDB.image_for(id)
		if img != "":
			c["file"] = img   # mostra l'immagine reale della carta
		entries.append(c)
	_hud.show_hand(entries)


func _refresh_status() -> void:
	var p := state.fighters[0]
	var e := state.fighters[1]
	_hud.set_info("Round %d  |  TU %s ❤%d/%d ◈%d [%s] mazzo%d scarti%d  —  IA %s ❤%d/%d ◈%d [%s]" % [
		state.round_num,
		p.character, p.remaining_wounds(), p.wound_limit, p.focus, Domain.STANCE_NAMES[p.stance], p.draw_pile.size(), p.discard.size(),
		e.character, e.remaining_wounds(), e.wound_limit, e.focus, Domain.STANCE_NAMES[e.stance]])
	_hud.set_kamae_marker(Domain.STANCE_SLUG[p.stance])


func _sync_pawns() -> void:
	for i in range(state.fighters.size()):
		var dest := HexGrid.hex_to_world(state.fighters[i].cell, hex_size)
		if _pawns[i].position.distance_to(dest) > 0.01:
			var tw := create_tween()
			tw.tween_property(_pawns[i], "position", dest, 0.25).set_trans(Tween.TRANS_SINE)
		_apply_pawn_facing(i)
	_refresh_overlays()


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
	_build_ground()
	_build_tiles()


func _build_tiles() -> void:
	for cell in HexGrid.hexes_in_range(Vector2i.ZERO, map_radius):
		var tile := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = hex_size * 0.92
		mesh.bottom_radius = hex_size * 0.92
		mesh.height = 0.04
		mesh.radial_segments = 6
		tile.mesh = mesh
		tile.rotation_degrees.y = 30.0   # flat-top
		tile.material_override = _tile_mat(cell, "none")
		tile.position = HexGrid.hex_to_world(cell, hex_size)
		tile.position.y = 0.03            # appena sopra la mappa
		tile.add_to_group(TILE_GROUP)
		tile.set_meta("cell", cell)

		# Collisione per il picking col mouse.
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = hex_size * 0.92
		shape.height = 0.2
		col.shape = shape
		body.add_child(col)
		body.set_meta("cell", cell)
		tile.add_child(body)

		add_child(tile)
		_tiles[cell] = tile


## Piano con la texture della mappa reale (Tabelle_Materiali/Senjutsu/MAPPE).
func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(map_world_size, map_world_size)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	var tex := _load_texture("res://assets/maps/arena.webp")
	if tex != null:
		gm.albedo_texture = tex
	else:
		gm.albedo_color = Color(0.15, 0.16, 0.14)
	gm.roughness = 1.0
	ground.material_override = gm
	ground.position = Vector3(map_offset.x, -0.01, map_offset.y)
	ground.rotation_degrees.y = map_y_rotation
	add_child(ground)
	_ground = ground


## Materiale semi-trasparente della tessera. mode: "none" | "move" | "attack".
func _tile_mat(cell: Vector2i, mode: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	match mode:
		"move":
			m.albedo_color = Color(0.95, 0.82, 0.25, 0.5)
			m.emission = Color(0.5, 0.42, 0.1)
		"attack":
			m.albedo_color = Color(0.95, 0.25, 0.2, 0.55)
			m.emission = Color(0.5, 0.1, 0.08)
		_:
			m.emission_enabled = false
			var alt := ((cell.x + cell.y) & 1) != 0
			m.albedo_color = Color(0.85, 0.9, 1.0, 0.18) if alt else Color(0.55, 0.7, 0.9, 0.14)
	return m


static func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	var img := Image.new()
	if img.load(path) == OK:
		return ImageTexture.create_from_image(img)
	return null


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
		pawn.set("mesh_path", "res://assets/miniatures/%s.obj" % chars[i].to_lower())
		pawn.set("cell_size", hex_size)
		add_child(pawn)
		pawn.position = HexGrid.hex_to_world(f.cell, hex_size)
		pawn.set_meta("fighter_index", i)
		_pawns.append(pawn)
	# Orientamento iniziale: ciascuno verso l'avversario.
	state.fighters[0].facing = AI.facing_toward(state.fighters[0].cell, state.fighters[1].cell)
	state.fighters[1].facing = AI.facing_toward(state.fighters[1].cell, state.fighters[0].cell)
	# Posizione Kamae iniziale dall'albero del personaggio.
	for i in range(2):
		var tree := CardDB.kamae_tree_for(state.fighters[i].character.to_lower())
		var start_slug: String = tree.get("start", "neutral")
		state.fighters[i].stance = Domain.STANCE_FROM_SLUG.get(start_slug, Domain.Stance.NEUTRAL)


# ─── Selezione e movimento ───────────────────────────────────────────────────

func _clear_overlays() -> void:
	for cell in _highlighted:
		if _tiles.has(cell):
			(_tiles[cell] as MeshInstance3D).material_override = _tile_mat(cell, "none")
	for cell in _attack_preview:
		if _tiles.has(cell):
			(_tiles[cell] as MeshInstance3D).material_override = _tile_mat(cell, "none")
	_highlighted.clear()
	_attack_preview.clear()


## Evidenziazione a DUE FASI come sulla carta:
##  1) prima il MOVIMENTO consentito (giallo) — passi/rotazioni della carta;
##  2) dopo aver mosso (o se la carta non muove), i BERSAGLI d'attacco (rosso).
func _refresh_overlays() -> void:
	_clear_overlays()
	if _selected_card.is_empty():
		return
	var f := state.fighters[0]
	var id := int(_selected_card.get("id", -1))
	var g := CardDB.geometry(id)
	# Carta non giocabile nella Kamae attuale: nessun overlay.
	if not Duel.playable(f, id):
		var req: String = g.get("kamae_req", "")
		_hud.set_hint("⛔ %s: giocabile solo in Kamae %s (sei in %s)" % [
			_selected_card.get("name", "?"),
			Domain.STANCE_NAMES.get(Domain.STANCE_FROM_SLUG.get(req, -1), req),
			Domain.STANCE_NAMES[f.stance]])
		return
	# Celle di movimento (solo se non già mosso).
	var move_cells: Array = []
	if not _move_used:
		_move_states = {}
		if g.has("move"):
			_move_states = Move.reachable_by_cell(f.cell, f.facing, g["move"], state.is_blocked, Domain.STANCE_SLUG[f.stance])
			for cell in _move_states.keys():
				if cell != f.cell:
					move_cells.append(cell)
		elif int(g.get("steps", 0)) > 0:
			move_cells = HexGrid.reachable(f.cell, int(g.get("steps", 0)), state.is_blocked)
	var cost: int = int(CardDB.card(id).get("focus", 0))
	var sfx := (" · costo ◈%d (hai %d)" % [cost, f.focus]) if cost > 0 else ""
	sfx += _gated_note(g)
	if not move_cells.is_empty():
		# FASE 1 — movimento (giallo). SPAZIO per non muovere.
		for cell in move_cells:
			_highlighted.append(cell)
			if _tiles.has(cell):
				(_tiles[cell] as MeshInstance3D).material_override = _tile_mat(cell, "move")
		_hud.set_hint("Muovi (giallo) · Q/E ruota · SPAZIO = non muovere · INVIO = risolvi" + sfx)
	elif _selected_card.get("type", "") == "attack":
		# FASE 2 — bersagli attaccabili (rosso). Schema v2 (celle per-esagono).
		for cell in Duel.attack_v2_cells(f.cell, f.facing, g, 1):
			if _tiles.has(cell):
				_attack_preview.append(cell)
				(_tiles[cell] as MeshInstance3D).material_override = _tile_mat(cell, "attack")
		_hud.set_hint("Bersagli (rosso) · Q/E ruota · INVIO = attacca/risolvi" + sfx)
	else:
		_hud.set_hint("INVIO = risolvi · Q/E ruota" + sfx)


## Indica quali Kamae sbloccherebbero ulteriori movimenti della carta selezionata.
func _gated_note(g: Dictionary) -> String:
	if not g.has("move"):
		return ""
	var cur: String = Domain.STANCE_SLUG[state.fighters[0].stance]
	var locked := {}
	for opt in g["move"].get("opts", []):
		for a in opt.get("atoms", []):
			var k: String = a.get("kamae", "")
			if k != "" and k != cur:
				locked[k] = true
	if locked.is_empty():
		return ""
	var names: Array = []
	for k in locked:
		names.append(Domain.STANCE_NAMES[Domain.STANCE_FROM_SLUG[k]])
	return " · altri movimenti in: " + ", ".join(names)


# ─── Orientamento (facing) ───────────────────────────────────────────────────

## Angolo mondo (attorno a Y) per orientare la pedina nella direzione `facing`.
func _facing_angle(cell: Vector2i, facing: int) -> float:
	var a := HexGrid.hex_to_world(cell, hex_size)
	var b := HexGrid.hex_to_world(cell + HexGrid.DIRS[facing % 6], hex_size)
	var d := b - a
	return atan2(d.x, d.z)


## Selezione di una carta: mostra i passi consentiti e l'arco d'attacco.
func _on_card_selected(card_data: Dictionary) -> void:
	if _phase_mode != "planning":
		return   # durante la risoluzione la mano non cambia l'anteprima
	_selected_card = card_data
	_move_used = false
	_kamae_used = false
	_refresh_overlays()   # anteprima informativa (il movimento avverrà in risoluzione)
	_hud.hide_kamae()
	_hud.set_hint("Anteprima: giallo = mosse della carta, rosso = arco. 2° click = PROGRAMMA (coperta).")


## Mostra il selettore Kamae se la carta consente di cambiare posizione.
func _refresh_kamae_chooser() -> void:
	if _selected_card.is_empty() or _kamae_used:
		_hud.hide_kamae()
		return
	var g := CardDB.geometry(int(_selected_card.get("id", -1)))
	if not bool(g.get("change_kamae", false)):
		_hud.hide_kamae()
		return
	var f := state.fighters[0]
	# Il "cambia kamae" di alcune carte vale solo in una certa Kamae.
	var cg: String = g.get("change_kamae_gate", "")
	if cg != "" and cg != Domain.STANCE_SLUG[f.stance]:
		_hud.hide_kamae()
		return
	var tree := CardDB.kamae_tree_for(f.character.to_lower())
	var n: int = int(g.get("kamae_change", 1))   # "cambia fino a N rami" (default 1)
	var cur: String = Domain.STANCE_SLUG[f.stance]
	var targets := Kamae.change_targets(tree, cur, n)
	_hud.show_kamae(cur, targets)


## Il giocatore sceglie la nuova posizione Kamae (con focus dai rami rosa).
func _on_kamae_chosen(slug: String) -> void:
	if _kamae_used or _selected_card.is_empty():
		return
	var f := state.fighters[0]
	var g := CardDB.geometry(int(_selected_card.get("id", -1)))
	var tree := CardDB.kamae_tree_for(f.character.to_lower())
	var n: int = int(g.get("kamae_change", 1))
	var targets := Kamae.change_targets(tree, Domain.STANCE_SLUG[f.stance], n)
	if not targets.has(slug):
		return
	f.gain_focus(int(targets[slug]))          # focus dai rami rosa
	f.stance = Domain.STANCE_FROM_SLUG[slug]
	_kamae_used = true
	_hud.hide_kamae()
	_refresh_status()


## Ruota il giocatore solo tra i facing consentiti dalla carta selezionata.
func _rotate_player(delta: int) -> void:
	if _selected_card.is_empty():
		return
	var f := state.fighters[0]
	var facings: Array = (_move_states.get(f.cell, []) as Array).duplicate()
	if facings.is_empty():
		# Carta senza specifica `move` ma con rotazioni: rotazione libera (legacy).
		var g := CardDB.geometry(int(_selected_card.get("id", -1)))
		if not g.has("move") and int(g.get("rotates", 0)) > 0:
			f.facing = (f.facing + delta + 6) % 6
			_apply_pawn_facing(0)
			_refresh_overlays()
		return
	facings.sort()
	var idx: int = facings.find(f.facing)
	if idx == -1:
		idx = 0
	f.facing = int(facings[(idx + delta + facings.size()) % facings.size()])
	_apply_pawn_facing(0)
	_refresh_overlays()


func _apply_pawn_facing(i: int) -> void:
	_pawns[i].call("face", _facing_angle(state.fighters[i].cell, state.fighters[i].facing))


# ─── Calibrazione live griglia↔mappa ─────────────────────────────────────────

func _set_hex_size(v: float) -> void:
	hex_size = clampf(v, 1.0, 8.0)
	_rebuild_grid()
	_update_calib_hint()


func _nudge_map(d: Vector2) -> void:
	map_offset += d
	if _ground:
		_ground.position = Vector3(map_offset.x, -0.01, map_offset.y)
	_update_calib_hint()


func _rebuild_grid() -> void:
	for t in _tiles.values():
		t.queue_free()
	_tiles.clear()
	_highlighted.clear()
	_attack_preview.clear()
	_build_tiles()
	for i in range(_pawns.size()):
		_pawns[i].position = HexGrid.hex_to_world(state.fighters[i].cell, hex_size)
		_pawns[i].call("rescale", hex_size)
		_apply_pawn_facing(i)
	_refresh_overlays()


func _update_calib_hint() -> void:
	_hud.set_hint("Calibrazione: hex_size=%.1f  offset=(%.1f, %.1f)  ·  +/- scala · frecce sposta mappa · R reset camera" % [
		hex_size, map_offset.x, map_offset.y])


func _move_active_to(cell: Vector2i) -> void:
	# Il movimento è possibile solo durante la TUA risoluzione.
	if _phase_mode != "resolving" or _resolving_index != 0:
		return
	# Muovi solo verso le celle consentite dalla carta selezionata.
	if _move_used or not _highlighted.has(cell):
		return
	var f := state.fighters[0]
	f.cell = cell
	# Facing alla destinazione: tra quelli legali, il più vicino al "verso nemico".
	var facings: Array = _move_states.get(cell, [])
	var want: int = AI.facing_toward(cell, state.fighters[1].cell)
	if facings.is_empty():
		f.facing = want
	else:
		var best: int = int(facings[0])
		var best_d: int = 99
		for fc in facings:
			var dd: int = mini((int(fc) - want + 6) % 6, (want - int(fc) + 6) % 6)
			if dd < best_d:
				best_d = dd
				best = int(fc)
		f.facing = best
	var pawn := _pawns[0]
	var dest := HexGrid.hex_to_world(cell, hex_size)
	var tw := create_tween()
	tw.tween_property(pawn, "position", dest, 0.25).set_trans(Tween.TRANS_SINE)
	_move_used = true            # movimento della carta speso
	_apply_pawn_facing(0)
	_refresh_overlays()          # ora mostra solo l'arco d'attacco aggiornato


# ─── Input: camera orbitale + picking ────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# "+"/"-" via unicode (indipendente dal layout di tastiera).
		if event.unicode == 43:  # '+'
			_set_hex_size(hex_size + 0.05); return
		if event.unicode == 45:  # '-'
			_set_hex_size(hex_size - 0.05); return
		var my_turn := _phase_mode == "resolving" and _resolving_index == 0
		match event.keycode:
			KEY_Q:
				if my_turn: _rotate_player(-1)
				return
			KEY_E:
				if my_turn: _rotate_player(1)
				return
			KEY_SPACE:   # non muovere: passa alla fase bersagli
				if my_turn and not _move_used:
					_move_used = true
					_refresh_overlays()
				return
			KEY_ENTER, KEY_KP_ENTER:   # conferma: applica attacco/effetti
				if my_turn:
					_confirm_resolution()
				return
			# ── Calibrazione griglia↔mappa ──
			KEY_KP_ADD: _set_hex_size(hex_size + 0.05); return
			KEY_KP_SUBTRACT: _set_hex_size(hex_size - 0.05); return
			KEY_LEFT: _nudge_map(Vector2(-0.25, 0)); return
			KEY_RIGHT: _nudge_map(Vector2(0.25, 0)); return
			KEY_UP: _nudge_map(Vector2(0, -0.25)); return
			KEY_DOWN: _nudge_map(Vector2(0, 0.25)); return
			KEY_R: _cam_yaw = 0.0; _cam_pitch = 0.62; _cam_dist = 34.0; _update_camera(); return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_cam_dist = max(6.0, _cam_dist - 1.0); _update_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_cam_dist = min(55.0, _cam_dist + 1.0); _update_camera()
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
