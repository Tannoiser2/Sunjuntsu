## Tavolo ONLINE (companion) — Senjutsu, Tappa 4.1.
##
## È la vista HOST: costruisce la board 3D, crea una stanza sul relay, mostra il
## CODICE, possiede il motore (`MatchHost`) e DISEGNA lo stato pubblico (posizioni,
## ferite, animazioni di combattimento) man mano che i due TELEFONI decidono. Qui non
## ci sono mano/HUD di scelta: quelli stanno sui telefoni.
extends Node3D

const TILE_GROUP := "hex_tile"
@export var map_radius: int = 3
@export var hex_size: float = 3.0
@export var map_world_size: float = 44.0
@export var map_offset: Vector2 = Vector2(0.0, 0.5)

var state: GameState
var host: MatchHost
var channel: WebSocketChannel
var _tiles: Dictionary = {}
var _pawns: Array[Node3D] = []
var _joined: Dictionary = {}
var _started := false
var _visuals := true

var _cam_pivot: Node3D
var _cam_yaw: float = 0.0
var _cam_pitch: float = 0.62
var _cam_dist: float = 34.0
var _dragging := false

var _code_lbl: Label
var _status_lbl: Label
var _players_lbl: Label
var _help_lbl: Label
var _url_edit: LineEdit
var _connect_btn: Button
var _room_code: String = ""
var _attempts: int = 0
var _finished := false

var _played_panel: PanelContainer
var _played_box: HBoxContainer
var _played_tex: Array = []
var _order_lbl: Label
var _log_lbl: Label
var _log_lines: Array = []
var _setup_panel: PanelContainer
var _title_lbl: Label
var _conn_row: HBoxContainer

const NET_CFG := "user://net.cfg"


func _ready() -> void:
	_visuals = DisplayServer.get_name() != "headless"
	_load_ws_url()
	state = GameState.new()
	state.map_radius = map_radius
	_build_world()
	_build_map()
	_spawn_pawns()
	_build_hud()
	_start_online()


## Carica l'ultimo indirizzo relay usato (così non lo ridigiti ogni volta).
func _load_ws_url() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(NET_CFG) == OK:
		Domain.ws_url = str(cfg.get_value("net", "ws_url", Domain.ws_url))


func _save_ws_url(url: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(NET_CFG)
	cfg.set_value("net", "ws_url", url)
	cfg.save(NET_CFG)


func _start_online() -> void:
	channel = WebSocketChannel.new()
	add_child(channel)
	host = MatchHost.new(state, channel)
	host.protocol.public_event.connect(_on_public)
	host.protocol.duel.combat_event.connect(_on_combat)
	channel.created.connect(func(code):
		_room_code = code
		_attempts = 0
		_code_lbl.text = "Codice stanza:  %s" % code
		_status_lbl.text = "Connesso. In attesa dei due giocatori…"
		_help_lbl.text = "Sul telefono apri  %s/  e inserisci il codice." % _http_hint())
	channel.peer.connect(_on_peer)
	channel.closed.connect(_on_channel_closed)
	host.protocol.finished.connect(func(w):
		_finished = true
		var who := "Pareggio" if w < 0 else "%s vince!" % state.fighters[w].character
		_status_lbl.text = "⚔ Duello terminato — %s" % who)
	_connect(false)


## (Ri)connette al relay all'URL corrente. In riconnessione ricrea la STESSA stanza.
func _connect(reconnect: bool) -> void:
	var url: String = Domain.ws_url
	var initial := {"t": "create"}
	if _room_code != "":
		initial["code"] = _room_code   # mantiene lo stesso codice per i telefoni
	_status_lbl.text = "Connessione a %s…" % url
	if reconnect:
		channel.reopen(initial)
	else:
		channel.open(url, initial)


func _on_channel_closed() -> void:
	if _finished:
		return
	_attempts += 1
	var delay: float = minf(1.0 * _attempts, 5.0)
	_status_lbl.text = "Connessione al server persa — riprovo… (%d)" % _attempts
	_help_lbl.text = "Avvia il relay:  cd server && npm start  · poi premi «Connetti»." \
		+ ("\n(Su web in HTTPS serve un relay wss://, non ws://)" if OS.has_feature("web") else "")
	var t := get_tree().create_timer(delay)
	t.timeout.connect(func():
		if is_instance_valid(self) and not _finished:
			_connect(true))


## Suggerimento HTTP per il telefono (stesso host del WebSocket).
func _http_hint() -> String:
	var u: String = Domain.ws_url
	u = u.replace("wss://", "https://").replace("ws://", "http://")
	return u


## Premuto «Connetti»: usa l'URL digitato, lo salva e (ri)connette.
func _on_connect_pressed() -> void:
	var url := _url_edit.text.strip_edges()
	if url == "":
		return
	Domain.ws_url = url
	_save_ws_url(url)
	_attempts = 0
	_connect(true)


func _on_peer(event: String, seat: int) -> void:
	if event == "join":
		_joined[seat] = true
	elif event == "leave":
		_joined.erase(seat)
	_players_lbl.text = "Giocatori: %s" % ("—" if _joined.is_empty() else ", ".join(_joined_names()))
	if not _started and _joined.has(0) and _joined.has(1):
		_started = true
		_status_lbl.text = "Partita iniziata!"
		_collapse_setup()   # via il pannello codice/connessione → tavolo a pieno schermo
		host.start()


func _joined_names() -> Array:
	var out: Array = []
	for s in [0, 1]:
		if _joined.has(s):
			out.append("Giocatore %d" % (s + 1))
	return out


# ─── Rendering dello stato pubblico ──────────────────────────────────────────

func _on_public(kind: String, data: Dictionary) -> void:
	match kind:
		"board":
			_sync_pawns()
			_refresh_status(data)
		"turn_of":
			var step: String = {
				"plan": "programma (coperta)", "resolve": "muove / agisce / attacca",
				"instant_replace": "valuta una sostituzione", "instant_play": "valuta un'istantanea",
			}.get(str(data.get("step", "")), str(data.get("step", "")))
			var who := int(data.get("seat", 0)) + 1
			if str(data.get("step", "")) == "plan":
				_status_lbl.text = "Programmazione — i giocatori scelgono la carta (coperta)"
			else:
				_status_lbl.text = "⚡ Iniziativa — tocca al Giocatore %d: %s" % [who, step]
		"revealed":
			_status_lbl.text = "Carte rivelate — risoluzione per iniziativa (alta → bassa)"
			_show_played(data.get("planned", {}), int(data.get("replaced", -1)))
			if int(data.get("replaced", -1)) == -1:
				_log("— Rivelazione —")
			else:
				_log("Giocatore %d sostituisce la carta (istantanea)" % (int(data.get("replaced", -1)) + 1))
		"order":
			var parts: Array = []
			var n := 1
			for o in data.get("order", []):
				var sp := int(o.get("speed", -1))
				parts.append("%d) G%d %s%s" % [n, int(o.get("i", 0)) + 1, _short_type(str(o.get("type", ""))), (" ⚡%d" % sp) if sp >= 0 else ""])
				n += 1
			_order_lbl.text = ("Ordine iniziativa:  " + "   ".join(parts)) if not parts.is_empty() else ""
		"choice":
			_log("Giocatore %d %s" % [int(data.get("seat", 0)) + 1, str(data.get("text", ""))])
		"combat":
			var lbl: String = {"hit": "colpo a segno", "blocked": "parato", "counter": "contrattacco", "collision": "urto"}.get(str(data.get("kind", "")), str(data.get("kind", "")))
			_log("⚔ %s → Giocatore %d" % [lbl, int(data.get("target", 0)) + 1])
		"turn":
			_sync_pawns()
			for line in data.get("log", []):
				_log(str(line))
			_log("— Nuovo turno —")
			_order_lbl.text = ""
			_hide_played()


func _refresh_status(board: Dictionary) -> void:
	var fs: Array = board.get("fighters", [])
	if fs.size() < 2:
		return
	var a: Dictionary = fs[0]; var b: Dictionary = fs[1]
	_players_lbl.text = "Round %d   ·   G1 %s ❤%d/%d ◈%d [%s] mano%d mazzo%d   —   G2 %s ❤%d/%d ◈%d [%s] mano%d mazzo%d" % [
		int(board.get("round", 1)),
		a.get("name", "?"), a.get("wounds", 0), a.get("limit", 0), a.get("focus", 0), a.get("kamae", ""), a.get("hand", 0), a.get("deck", 0),
		b.get("name", "?"), b.get("wounds", 0), b.get("limit", 0), b.get("focus", 0), b.get("kamae", ""), b.get("hand", 0), b.get("deck", 0)]


func _sync_pawns() -> void:
	for i in range(mini(_pawns.size(), state.fighters.size())):
		var dest := HexGrid.hex_to_world(state.fighters[i].cell, hex_size)
		if _pawns[i].position.distance_to(dest) > 0.01:
			var tw := create_tween()
			tw.tween_property(_pawns[i], "position", dest, 0.22).set_trans(Tween.TRANS_SINE)
		_pawns[i].call("face", _facing_angle(state.fighters[i].cell, state.fighters[i].facing))


func _facing_angle(cell: Vector2i, facing: int) -> float:
	var a := HexGrid.hex_to_world(cell, hex_size)
	var bw := HexGrid.hex_to_world(cell + HexGrid.DIRS[facing % 6], hex_size)
	var d := bw - a
	return atan2(d.x, d.z)


# ─── Animazioni di combattimento (come nell'arena locale) ────────────────────

func _on_combat(kind: String, attacker: int, target: int, _info: Dictionary) -> void:
	if not _visuals or target >= state.fighters.size():
		return
	var cell := state.fighters[target].cell
	match kind:
		"hit":
			_lunge(attacker, cell); _impact(cell, Color(1.0, 0.32, 0.2), 1.4); _shake(0.05)
		"blocked":
			_lunge(attacker, cell); _impact(cell, Color(0.55, 0.8, 1.0), 1.1); _shake(0.025)
		"counter":
			_impact(cell, Color(1.0, 0.5, 0.15), 1.2); _shake(0.04)
		"collision":
			_impact(cell, Color(1.0, 0.75, 0.2), 1.6); _shake(0.08)


func _lunge(idx: int, toward_cell: Vector2i) -> void:
	if idx < 0 or idx >= _pawns.size():
		return
	var pawn := _pawns[idx]
	var start: Vector3 = pawn.position
	var peak := start.lerp(HexGrid.hex_to_world(toward_cell, hex_size), 0.4)
	peak.y = start.y
	var tw := create_tween()
	tw.tween_property(pawn, "position", peak, 0.10).set_trans(Tween.TRANS_SINE)
	tw.tween_property(pawn, "position", start, 0.13).set_trans(Tween.TRANS_SINE)


func _impact(cell: Vector2i, color: Color, peak: float) -> void:
	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new(); sph.radius = hex_size * 0.45; sph.height = hex_size * 0.9
	mi.mesh = sph
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true; m.emission = color
	var c := color; c.a = 0.8; m.albedo_color = c
	mi.material_override = m
	add_child(mi)
	mi.position = HexGrid.hex_to_world(cell, hex_size) + Vector3(0, hex_size * 0.9, 0)
	mi.scale = Vector3.ONE * 0.3
	var tw := create_tween(); tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * peak, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.3)
	tw.chain().tween_callback(mi.queue_free)


func _shake(amt: float) -> void:
	var cam: Camera3D = _cam_pivot.get_node("Camera3D")
	var tw := create_tween()
	for k in range(5):
		tw.tween_property(cam, "h_offset", randf_range(-amt, amt), 0.035)
	tw.tween_property(cam, "h_offset", 0.0, 0.05)


# ─── Costruzione scena (board lean) ──────────────────────────────────────────

func _build_world() -> void:
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
	cam.current = true
	_cam_pivot.add_child(cam)
	_update_camera()


func _build_map() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(map_world_size, map_world_size)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	var tex := _load_texture("res://assets/maps/arena.webp")
	if tex != null: gm.albedo_texture = tex
	else: gm.albedo_color = Color(0.15, 0.16, 0.14)
	gm.roughness = 1.0
	ground.material_override = gm
	ground.position = Vector3(map_offset.x, -0.01, map_offset.y)
	add_child(ground)
	for cell in HexGrid.hexes_in_range(Vector2i.ZERO, map_radius):
		var tile := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = hex_size * 0.92; mesh.bottom_radius = hex_size * 0.92
		mesh.height = 0.04; mesh.radial_segments = 6
		tile.mesh = mesh
		tile.rotation_degrees.y = 30.0
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var alt := ((cell.x + cell.y) & 1) != 0
		m.albedo_color = Color(0.85, 0.9, 1.0, 0.18) if alt else Color(0.55, 0.7, 0.9, 0.14)
		tile.material_override = m
		tile.position = HexGrid.hex_to_world(cell, hex_size)
		tile.position.y = 0.03
		tile.add_to_group(TILE_GROUP)
		add_child(tile)
		_tiles[cell] = tile


func _spawn_pawns() -> void:
	var Pawn := preload("res://scenes/Pawn.gd")
	var starts := [Vector2i(-3, 1), Vector2i(3, -1)]
	var chars := Domain.PLAYABLE
	var colors := [Color(0.85, 0.2, 0.2), Color(0.2, 0.4, 0.9)]
	for i in range(2):
		var f := state.add_fighter(chars[i], starts[i])
		f.is_ai = false
		f.draw_pile = CardDB.draw_pile_for(String(chars[i]).to_lower())
		f.draw_pile.shuffle()
		var cs := CardDB.character_stats(chars[i])
		if not cs.is_empty():
			f.wound_limit = int(cs.get("wound_limit", f.wound_limit))
			f.hand_limit = int(cs.get("hand_limit", f.hand_limit))
		var pawn: Node3D = Pawn.new()
		pawn.set("tint", colors[i])
		var slug: String = String(chars[i]).to_lower()
		var glb := "res://assets/miniatures/%s.glb" % slug
		pawn.set("mesh_path", glb if ResourceLoader.exists(glb) else "res://assets/miniatures/%s.obj" % slug)
		pawn.set("cell_size", hex_size)
		add_child(pawn)
		pawn.position = HexGrid.hex_to_world(f.cell, hex_size)
		_pawns.append(pawn)
	state.fighters[0].facing = AI.facing_toward(state.fighters[0].cell, state.fighters[1].cell)
	state.fighters[1].facing = AI.facing_toward(state.fighters[1].cell, state.fighters[0].cell)
	for i in range(2):
		var tree := CardDB.kamae_tree_for(state.fighters[i].character.to_lower())
		state.fighters[i].stance = Domain.STANCE_FROM_SLUG.get(tree.get("start", "neutral"), Domain.Stance.NEUTRAL)
		_pawns[i].call("face", _facing_angle(state.fighters[i].cell, state.fighters[i].facing))


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_setup_panel = PanelContainer.new()
	_setup_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_setup_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_setup_panel)
	var vb := VBoxContainer.new()
	_setup_panel.add_child(vb)
	_title_lbl = Label.new()
	_title_lbl.text = "Tavolo online — i giocatori usano il telefono  ·  F = schermo intero"
	_title_lbl.add_theme_font_size_override("font_size", 16)
	vb.add_child(_title_lbl)
	_code_lbl = Label.new()
	_code_lbl.add_theme_font_size_override("font_size", 28)
	vb.add_child(_code_lbl)
	_players_lbl = Label.new()
	vb.add_child(_players_lbl)
	_status_lbl = Label.new()
	_status_lbl.add_theme_font_size_override("font_size", 18)
	vb.add_child(_status_lbl)
	_order_lbl = Label.new()
	_order_lbl.add_theme_font_size_override("font_size", 15)
	_order_lbl.modulate = Color(1, 0.92, 0.6)
	vb.add_child(_order_lbl)
	# Riga connessione: indirizzo del relay modificabile + «Connetti».
	_conn_row = HBoxContainer.new()
	vb.add_child(_conn_row)
	var lab := Label.new(); lab.text = "Server:"
	_conn_row.add_child(lab)
	_url_edit = LineEdit.new()
	_url_edit.text = Domain.ws_url
	_url_edit.custom_minimum_size = Vector2(320, 0)
	_url_edit.tooltip_text = "Es. ws://192.168.1.10:8080 (IP del PC con il relay)"
	_conn_row.add_child(_url_edit)
	_connect_btn = Button.new()
	_connect_btn.text = "Connetti"
	_connect_btn.pressed.connect(_on_connect_pressed)
	_conn_row.add_child(_connect_btn)
	_help_lbl = Label.new()
	_help_lbl.add_theme_font_size_override("font_size", 13)
	_help_lbl.modulate = Color(1, 1, 1, 0.75)
	vb.add_child(_help_lbl)

	# ── Carte giocate (rivelazione) ──
	var played_panel := PanelContainer.new()
	played_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	played_panel.anchor_left = 1.0; played_panel.anchor_right = 1.0
	played_panel.offset_left = -260; played_panel.offset_right = -8; played_panel.offset_top = 8
	played_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(played_panel)
	var pv := VBoxContainer.new(); played_panel.add_child(pv)
	pv.add_child(_mk_label("Carte giocate", 14))
	_played_box = HBoxContainer.new(); pv.add_child(_played_box)
	for i in range(2):
		var col := VBoxContainer.new(); _played_box.add_child(col)
		col.add_child(_mk_label("Giocatore %d" % (i + 1), 12))
		var tr := TextureRect.new()
		tr.custom_minimum_size = Vector2(108, 150)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		col.add_child(tr)
		_played_tex.append(tr)
	played_panel.visible = false
	_played_panel = played_panel

	# ── Registro pubblico (cosa succede) ──
	var log_panel := PanelContainer.new()
	log_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	log_panel.anchor_top = 1.0; log_panel.anchor_bottom = 1.0
	log_panel.offset_left = 8; log_panel.offset_right = 380; log_panel.offset_top = -210; log_panel.offset_bottom = -8
	log_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(log_panel)
	var lv := VBoxContainer.new(); log_panel.add_child(lv)
	lv.add_child(_mk_label("Registro", 14))
	_log_lbl = Label.new()
	_log_lbl.add_theme_font_size_override("font_size", 13)
	_log_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lv.add_child(_log_lbl)


func _mk_label(t: String, sz: int) -> Label:
	var l := Label.new(); l.text = t; l.add_theme_font_size_override("font_size", sz)
	return l


## A partita iniziata: collassa il setup (codice/connessione) e va a schermo intero,
## così il tavolo 3D occupa tutta l'area.
func _collapse_setup() -> void:
	_title_lbl.visible = false
	_code_lbl.visible = false
	_conn_row.visible = false
	_help_lbl.visible = false
	if _visuals:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _toggle_fullscreen() -> void:
	var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)


## Mostra le due carte rivelate (immagini reali) con animazione.
## `replaced` = seat appena sostituito (flip), oppure -1 = comparsa normale.
func _show_played(planned, replaced: int = -1) -> void:
	if _played_panel == null:
		return
	_played_panel.modulate.a = 1.0
	_played_panel.visible = true
	for i in range(2):
		var cid: int = -1
		if typeof(planned) == TYPE_DICTIONARY:
			cid = int(planned.get(i, planned.get(str(i), -1)))
		var file: String = CardDB.image_for(cid) if cid != -1 else ""
		var tex: TextureRect = _played_tex[i]
		tex.pivot_offset = tex.size * 0.5
		if not _visuals:
			tex.texture = (_load_texture("res://assets/cards/" + file) if file != "" else null)
			continue
		if replaced == i:
			# Sostituzione: capovolgi (flip orizzontale) e cambia immagine a metà.
			var tw := create_tween()
			tw.tween_property(tex, "scale:x", 0.0, 0.12)
			tw.tween_callback(func(): tex.texture = (_load_texture("res://assets/cards/" + file) if file != "" else null))
			tw.tween_property(tex, "scale:x", 1.0, 0.12)
		elif replaced == -1:
			# Comparsa: dissolvenza + leggero ingrandimento.
			tex.texture = (_load_texture("res://assets/cards/" + file) if file != "" else null)
			tex.modulate.a = 0.0
			tex.scale = Vector2(0.82, 0.82)
			var tw := create_tween().set_parallel(true)
			tw.tween_property(tex, "modulate:a", 1.0, 0.22)
			tw.tween_property(tex, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Nasconde le carte giocate a fine turno: animazione di SCARTO (sfuma e scende).
func _hide_played() -> void:
	if _played_panel == null or not _played_panel.visible:
		return
	if not _visuals:
		_played_panel.visible = false
		return
	var tw := create_tween()
	tw.tween_property(_played_panel, "modulate:a", 0.0, 0.28)
	tw.tween_callback(func():
		_played_panel.visible = false
		_played_panel.modulate.a = 1.0)


## Tipo abbreviato per la riga dell'ordine.
func _short_type(t: String) -> String:
	var r: String = {"attack": "Att", "defence": "Dif", "meditation": "Med", "core": "Base"}.get(t, t)
	return r


## Aggiunge una riga al registro pubblico (tiene le ultime ~10).
func _log(line: String) -> void:
	if _log_lbl == null or line.strip_edges() == "":
		return
	_log_lines.append(line)
	while _log_lines.size() > 10:
		_log_lines.pop_front()
	_log_lbl.text = "\n".join(_log_lines)


# ─── Camera orbitale ─────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		_toggle_fullscreen()
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_cam_dist = maxf(8.0, _cam_dist - 1.0); _update_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_cam_dist = minf(55.0, _cam_dist + 1.0); _update_camera()
	elif event is InputEventMouseMotion and _dragging:
		_cam_yaw -= event.relative.x * 0.005
		_cam_pitch = clampf(_cam_pitch - event.relative.y * 0.005, 0.2, 1.4)
		_update_camera()


func _update_camera() -> void:
	var cam: Camera3D = _cam_pivot.get_node("Camera3D")
	var x := _cam_dist * sin(_cam_pitch) * sin(_cam_yaw)
	var y := _cam_dist * cos(_cam_pitch)
	var z := _cam_dist * sin(_cam_pitch) * cos(_cam_yaw)
	cam.position = Vector3(x, y, z)
	cam.look_at(Vector3.ZERO, Vector3.UP)


static func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null
