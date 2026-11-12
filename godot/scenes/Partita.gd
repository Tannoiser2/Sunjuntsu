extends Node
## Tavolo di gioco: tabellone 3D con pedine, schede dei combattenti, mano di carte
## e risoluzione guidata. Funziona con mouse e con il tocco (iPad).

const CARTA_MANO := Vector2(124, 173)
const CARTA_TAV := Vector2(128, 178)

var g: Game
var bot: Bot
var sincro: Sincro = null
var io := 0
var req: Dictionary = {}

# mondo 3D
var mondo: Node3D
var perno: Node3D
var cam: Camera3D
var yaw := 0.0
var pitch := 1.02
var dist := 13.0
var celle_mat: Dictionary = {}
var pedine: Array = []
var evid: Dictionary = {}      ## cella -> colore (opzioni)
var lampi: Dictionary = {}     ## cella -> colore (attacchi/blocchi)
var opz_celle: Dictionary = {} ## cella -> Array di [orientamento, indice opzione]
var sel_cella = null
var sel_k := 0

# hud
var hud: Control
var schede: Array = []
var lbl_turno: Label
var lbl_banner: Label
var cronaca: RichTextLabel
var lbl_richiesta: Label
var box_bottoni: HFlowContainer
var box_mano: HBoxContainer
var pan_richiesta: PanelContainer
var anteprima: PanelContainer
var ant_img: TextureRect
var ant_txt: RichTextLabel
var ant_azione: Button
var ant_idx := -1
var fine_pan: PanelContainer
var b_rivincita: Button
var tex_cache: Dictionary = {}

# input
var tocchi: Dictionary = {}
var tap_inizio := Vector2.ZERO
var tap_mosso := false
var mouse_sx := false
var mouse_dx := false
var mouse_mosso := false
var cam_toccata := false


func _ready() -> void:
	_mondo()
	_hud()
	_nuova()


# ─────────────────────────── Partita ───────────────────────────

func _nuova() -> void:
	g = Game.new()
	var mio: String = Sessione.setup.get("io", "warrior")
	var suo: String = Sessione.setup.get("avv", "ronin")
	if suo == mio:
		suo = "ronin" if mio != "ronin" else "warrior"
	io = 0
	bot = Bot.new(1, randi())
	var online: bool = Sessione.setup.get("modo", "solo") == "online"
	if not online:
		g.ask.connect(_su_richiesta)
	g.logged.connect(_su_log)
	g.event.connect(_su_evento)
	g.ritmo = _ritmo
	cronaca.text = ""
	fine_pan.visible = false
	for p in pedine:
		p.queue_free()
	pedine = []
	var solo: bool = Sessione.setup.get("modo", "solo") == "solo"
	if online:
		var pt: Dictionary = Sessione.setup.partita
		io = int(Sessione.setup.posto)
		g.prepara({"seed": int(pt.seed), "players": [{"char": pt.pers[0]}, {"char": pt.pers[1]}]})
		sincro = Sincro.new()
		sincro.rete = Sessione.rete
		sincro.codice = Sessione.setup.codice
		sincro.posto = io
		add_child(sincro)
		lbl_richiesta.text = "Collegamento alla stanza %s…" % sincro.codice
		await sincro.avvia(g)
		sincro.tocca_a_me.connect(func(r):
			req = r
			_mostra_richiesta())
		sincro.attesa.connect(func(t):
			lbl_richiesta.text = t
			_aggiorna())
	else:
		g.prepara({"seed": randi(), "players": [{"char": mio},
			{"char": suo, "solo": solo, "incubo": Sessione.setup.get("incubo", false)}]})
	for i in 2:
		pedine.append(_crea_pedina(i))
	_aggiorna()
	_partita()


func _partita() -> void:
	await g._piazzamento()
	await g._preparazione()
	while not g.over:
		await g._turno()
	g.fase = "fine"
	_aggiorna()
	_mostra_fine()


func _ritmo(tipo: String) -> void:
	if sincro != null and sincro.recupero:
		return
	var t: float = {"reveal": 1.4, "init": 1.0, "resolve": 1.2, "move": 0.6, "attack": 0.9, "hit": 0.7, "end": 0.6}.get(tipo, 0.4)
	await get_tree().create_timer(t).timeout


func _su_log(t: String) -> void:
	cronaca.append_text(t + "\n")


func _su_evento(e: Dictionary) -> void:
	match e.t:
		"move":
			_muovi_pedina(e.p, true)
		"attack":
			_lampo(e.cells, Color(0.85, 0.1, 0.05, 0.6))
		"block":
			_lampo(e.cells, Color(0.15, 0.4, 0.9, 0.55))
		"damage":
			_scuoti(e.p)
		"resolve":
			lbl_banner.text = "Iniziativa %d — %s: %s" % [int(e.init), g.F[e.p].name, Carte.nome(int(e.card))]
		"view":
			if e.p == io:
				var nomi: Array = []
				for c in e.cards:
					nomi.append(Carte.nome(int(c)))
				cronaca.append_text("[color=#27456b]Carte viste: %s.[/color]\n" % ", ".join(nomi))
		"turn":
			lbl_banner.text = ""
	_aggiorna()


func _su_richiesta(r: Dictionary) -> void:
	if r.p != io:
		lbl_richiesta.text = "%s sta decidendo…" % g.F[r.p].name
		await get_tree().create_timer(0.5).timeout
		g.answer(bot.decidi(g, r))
		return
	req = r
	_mostra_richiesta()


func _rispondi(idx: int) -> void:
	if req.is_empty():
		return
	req = {}
	evid.clear()
	opz_celle.clear()
	sel_cella = null
	anteprima.visible = false
	_svuota(box_bottoni)
	lbl_richiesta.text = ""
	_ridisegna_celle()
	if sincro != null:
		lbl_richiesta.text = "Invio…"
		sincro.rispondi(idx)
	else:
		g.answer(idx)
	_aggiorna()


func _mostra_richiesta() -> void:
	_svuota(box_bottoni)
	lbl_richiesta.text = req.text
	match req.kind:
		"place", "move", "hex":
			opz_celle.clear()
			for i in req.opts.size():
				var o: Dictionary = req.opts[i]
				if not opz_celle.has(o.pos):
					opz_celle[o.pos] = []
				opz_celle[o.pos].append([o.face, i])
			for c in opz_celle:
				evid[c] = Color(0.95, 0.75, 0.1, 0.5)
			lbl_richiesta.text += "\nTocca una casella evidenziata."
			if req.kind == "move" and opz_celle.has(g.F[io].pos):
				_seleziona_cella(g.F[io].pos)
			_ridisegna_celle()
		"card":
			var in_mano := true
			for o in req.opts:
				if not g.F[io].hand.has(o.card):
					in_mano = false
			if in_mano:
				lbl_richiesta.text += "\nTocca una carta della tua mano."
			else:
				for i in req.opts.size():
					var b := Tema.bottone(Carte.nome(req.opts[i].card), 200)
					b.pressed.connect(_apri_anteprima.bind(int(req.opts[i].card), i))
					box_bottoni.add_child(b)
		_:
			for i in req.opts.size():
				var b2 := Tema.bottone(req.opts[i].label, 120)
				b2.pressed.connect(_rispondi.bind(i))
				box_bottoni.add_child(b2)
			if req.has("card"):
				var b3 := Tema.bottone("Vedi la carta", 150)
				b3.pressed.connect(_apri_anteprima.bind(int(req.card), -1))
				box_bottoni.add_child(b3)
			else:
				for o in req.opts:
					if o.has("card") and int(o.card) >= 0 and req.kind != "replace":
						var b4 := Tema.bottone("Vedi «%s»" % Carte.nome(o.card), 150)
						b4.pressed.connect(_apri_anteprima.bind(int(o.card), -1))
						box_bottoni.add_child(b4)
	_aggiorna()


func _seleziona_cella(c: Vector2i) -> void:
	if req.is_empty() or not opz_celle.has(c):
		return
	var lista: Array = opz_celle[c]
	if req.kind == "hex":
		_rispondi(lista[0][1])
		return
	lista.sort_custom(func(a, b): return a[0] < b[0])
	sel_cella = c
	sel_k = 0
	var voglio: int = g.F[io].face
	if req.kind == "place":
		voglio = Hex.verso(c, Hex.da_offset(3, 0))
	var meglio := 99
	for k in lista.size():
		var d: int = absi(int(lista[k][0]) - voglio)
		d = mini(d, 6 - d)
		if d < meglio:
			meglio = d
			sel_k = k
	_anteprima_mossa()


func _anteprima_mossa() -> void:
	var lista: Array = opz_celle[sel_cella]
	_posa_pedina(io, sel_cella, int(lista[sel_k][0]), true)
	_svuota(box_bottoni)
	if lista.size() > 1:
		var bs := Tema.bottone("Ruota a sinistra", 170)
		bs.pressed.connect(_ruota_sel.bind(-1))
		box_bottoni.add_child(bs)
		var bd := Tema.bottone("Ruota a destra", 170)
		bd.pressed.connect(_ruota_sel.bind(1))
		box_bottoni.add_child(bd)
	var bc := Tema.bottone("Conferma", 150)
	bc.pressed.connect(func(): _rispondi(opz_celle[sel_cella][sel_k][1]))
	box_bottoni.add_child(bc)
	evid.clear()
	for c in opz_celle:
		evid[c] = Color(0.95, 0.75, 0.1, 0.5)
	evid[sel_cella] = Color(0.2, 0.8, 0.3, 0.6)
	_ridisegna_celle()


func _ruota_sel(v: int) -> void:
	var n: int = opz_celle[sel_cella].size()
	sel_k = (sel_k + v + n) % n
	_anteprima_mossa()


func _mostra_fine() -> void:
	var t := "Pareggio"
	if g.winner >= 0:
		t = "Hai vinto!" if g.winner == io else "%s ti ha sconfitto" % g.F[g.winner].name
	fine_pan.get_node("V/Titolo").text = t
	if sincro != null:
		b_rivincita.visible = false
		Sessione.rete.remember_room("")
	fine_pan.visible = true
	lbl_richiesta.text = "Partita conclusa."


# ─────────────────────────── Mondo 3D ───────────────────────────

func _mondo() -> void:
	mondo = Node3D.new()
	add_child(mondo)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("14110f")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 1, 1)
	e.ambient_light_energy = 0.85
	we.environment = e
	mondo.add_child(we)
	var sole := DirectionalLight3D.new()
	sole.rotation_degrees = Vector3(-55, 35, 0)
	sole.light_energy = 1.2
	mondo.add_child(sole)
	var m: Dictionary = Carte.db().maps.villaggio
	var k: float = 1.0 / float(m.hex_px)
	var pm := PlaneMesh.new()
	pm.size = Vector2(1594.0 * k, 1600.0 * k)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/maps/" + m.img)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.position = Vector3((797.0 - float(m.origin_px[0])) * k, -0.02, (800.0 - float(m.origin_px[1])) * k)
	mondo.add_child(mi)
	var esag := _mesh_esagono(0.93)
	for c in m.cells:
		var cell := Hex.da_offset(int(c[0]), int(c[1]))
		var ci := MeshInstance3D.new()
		ci.mesh = esag
		var cm := StandardMaterial3D.new()
		cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		cm.cull_mode = BaseMaterial3D.CULL_DISABLED
		cm.albedo_color = Color(1, 1, 1, 0)
		ci.material_override = cm
		var p := Hex.centro(cell)
		ci.position = Vector3(p.x, 0.01, p.y)
		mondo.add_child(ci)
		celle_mat[cell] = cm
	perno = Node3D.new()
	mondo.add_child(perno)
	cam = Camera3D.new()
	cam.fov = 42
	perno.add_child(cam)
	_inquadra()
	get_viewport().size_changed.connect(func():
		if not cam_toccata:
			_inquadra())


## Inquadra tutto il campo nello spazio libero fra le schede laterali e la mano.
func _inquadra() -> void:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var libero: float = maxf(0.3, (vs.x - 640.0) / vs.x)
	var mezza: float = tan(deg_to_rad(cam.fov * 0.5)) * vs.x / vs.y
	yaw = 0.0
	pitch = 1.12
	dist = clampf(12.2 / (libero * 2.0 * mezza), 8.0, 30.0)
	perno.position = Vector3(4.5, 0, 0.45 + dist * 0.105)
	_aggiorna_cam()


func _mesh_esagono(r: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 6:
		var a0 := deg_to_rad(60.0 * i)
		var a1 := deg_to_rad(60.0 * (i + 1))
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3.ZERO)
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(cos(a0) * r, 0, sin(a0) * r))
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(cos(a1) * r, 0, sin(a1) * r))
	return st.commit()


func _aggiorna_cam() -> void:
	pitch = clampf(pitch, 0.45, 1.5)
	dist = clampf(dist, 5.0, 32.0)
	perno.position.x = clampf(perno.position.x, -1.0, 10.0)
	perno.position.z = clampf(perno.position.z, -5.0, 5.0)
	var o := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
	cam.position = o
	cam.look_at(perno.global_position, Vector3.UP)


func _crea_pedina(i: int) -> Node3D:
	var f: Dictionary = g.F[i]
	var n := Node3D.new()
	var base := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.6
	cil.bottom_radius = 0.64
	cil.height = 0.1
	base.mesh = cil
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Tema.GIOCATORI[i]
	base.material_override = bm
	base.position.y = 0.05
	n.add_child(base)
	# triangolo del fronte (verso +Z locale)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in [Vector3(-0.22, 0, 0.6), Vector3(0.22, 0, 0.6), Vector3(0, 0, 0.98)]:
		st.set_normal(Vector3.UP)
		st.add_vertex(v)
	var tri := MeshInstance3D.new()
	tri.mesh = st.commit()
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Tema.ORO
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.cull_mode = BaseMaterial3D.CULL_DISABLED
	tri.material_override = tm
	tri.position.y = 0.06
	n.add_child(tri)
	var ps: PackedScene = null
	if f.cd.model != "":
		ps = load("res://assets/miniatures/" + f.cd.model)
	else:
		# nessuna miniatura 3D: sagoma in piedi con il ritratto
		var sag := Sprite3D.new()
		sag.texture = _tex("res://assets/portraits/" + f.cd.portrait)
		sag.pixel_size = 1.5 / float(sag.texture.get_height())
		sag.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sag.shaded = false
		sag.position.y = 0.87
		n.add_child(sag)
	if ps != null:
		var mod: Node3D = ps.instantiate()
		var holder := Node3D.new()
		holder.name = "Modello"
		holder.add_child(mod)
		n.add_child(holder)
		var bb := _aabb(mod, Transform3D.IDENTITY)
		if bb.size.y > 0.0001:
			var s: float = 1.55 / bb.size.y
			mod.scale = Vector3.ONE * s
			var c := bb.get_center() * s
			mod.position = Vector3(-c.x, 0.1 - bb.position.y * s, -c.z)
	mondo.add_child(n)
	n.visible = false
	return n


func _aabb(n: Node, t: Transform3D) -> AABB:
	var out := AABB()
	var primo := true
	var tt := t
	if n is Node3D:
		tt = t * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out = tt * (n as MeshInstance3D).mesh.get_aabb()
		primo = false
	for ch in n.get_children():
		var b := _aabb(ch, tt)
		if b.size == Vector3.ZERO:
			continue
		out = b if primo else out.merge(b)
		primo = false
	return out


func _angolo(face: int) -> float:
	var d := Hex.centro(Hex.DIRS[face])
	return atan2(d.x, d.y)


func _posa_pedina(i: int, cell: Vector2i, face: int, anima: bool) -> void:
	var n: Node3D = pedine[i]
	if cell.x > 50:
		n.visible = false
		return
	var p := Hex.centro(cell)
	var dest := Vector3(p.x, 0, p.y)
	var ang := _angolo(face)
	if not n.visible or not anima:
		n.visible = true
		n.position = dest
		n.rotation.y = ang
		return
	var tw := create_tween().set_parallel(true)
	tw.tween_property(n, "position", dest, 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(n, "rotation:y", n.rotation.y + wrapf(ang - n.rotation.y, -PI, PI), 0.35)


func _muovi_pedina(i: int, anima: bool) -> void:
	_posa_pedina(i, g.F[i].pos, g.F[i].face, anima)


func _scuoti(i: int) -> void:
	var n: Node3D = pedine[i]
	if not n.visible:
		return
	var tw := create_tween()
	for k in 4:
		tw.tween_property(n, "position:y", 0.25 if k % 2 == 0 else 0.0, 0.07)
	if g.F[i].dead:
		tw.tween_property(n, "rotation:x", -PI / 2.2, 0.5)


func _lampo(celle: Array, col: Color) -> void:
	for c in celle:
		lampi[c] = col
	_ridisegna_celle()
	await get_tree().create_timer(1.1).timeout
	for c in celle:
		lampi.erase(c)
	_ridisegna_celle()


func _ridisegna_celle() -> void:
	for c in celle_mat:
		var col := Color(1, 1, 1, 0)
		if evid.has(c):
			col = evid[c]
		if lampi.has(c):
			col = lampi[c]
		celle_mat[c].albedo_color = col


func _cella_da_schermo(p: Vector2):
	var o := cam.project_ray_origin(p)
	var d := cam.project_ray_normal(p)
	if absf(d.y) < 0.0001:
		return null
	var t := -o.y / d.y
	if t < 0:
		return null
	var w := o + d * t
	var q := 2.0 / 3.0 * w.x
	var r := -1.0 / 3.0 * w.x + sqrt(3.0) / 3.0 * w.z
	var s := -q - r
	var rq := roundf(q)
	var rr := roundf(r)
	var rs := roundf(s)
	var dq := absf(rq - q)
	var dr := absf(rr - r)
	var ds := absf(rs - s)
	if dq > dr and dq > ds:
		rq = -rr - rs
	elif dr > ds:
		rr = -rq - rs
	return Vector2i(int(rq), int(rr))


func _tocco(p: Vector2) -> void:
	if anteprima.visible:
		anteprima.visible = false
		return
	var c = _cella_da_schermo(p)
	if c != null and not req.is_empty():
		_seleziona_cella(c)


func _pan(rel: Vector2) -> void:
	cam_toccata = true
	var destra := Vector3(cos(yaw), 0, -sin(yaw))
	var avanti := Vector3(sin(yaw), 0, cos(yaw))
	perno.position += (-destra * rel.x - avanti * rel.y) * dist * 0.0014
	_aggiorna_cam()


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		if ev.pressed:
			tocchi[ev.index] = ev.position
			if tocchi.size() == 1:
				tap_inizio = ev.position
				tap_mosso = false
		else:
			tocchi.erase(ev.index)
			if tocchi.is_empty() and not tap_mosso:
				_tocco(ev.position)
	elif ev is InputEventScreenDrag:
		var prima: Vector2 = tocchi.get(ev.index, ev.position)
		tocchi[ev.index] = ev.position
		if tocchi.size() == 1:
			if ev.position.distance_to(tap_inizio) > 14:
				tap_mosso = true
			if tap_mosso:
				_pan(ev.relative)
		elif tocchi.size() >= 2:
			tap_mosso = true
			var altro := Vector2.ZERO
			for k in tocchi:
				if k != ev.index:
					altro = tocchi[k]
					break
			var d0: float = prima.distance_to(altro)
			var d1: float = ev.position.distance_to(altro)
			if d0 > 1.0:
				dist *= d0 / maxf(d1, 1.0)
			yaw -= wrapf((ev.position - altro).angle() - (prima - altro).angle(), -PI, PI)
			cam_toccata = true
			_aggiorna_cam()
	elif ev is InputEventMouseButton and ev.device != InputEvent.DEVICE_ID_EMULATION:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_toccata = true
			dist *= 0.92
			_aggiorna_cam()
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_toccata = true
			dist *= 1.08
			_aggiorna_cam()
		elif ev.button_index == MOUSE_BUTTON_LEFT:
			mouse_sx = ev.pressed
			if ev.pressed:
				tap_inizio = ev.position
				mouse_mosso = false
			elif not mouse_mosso:
				_tocco(ev.position)
		elif ev.button_index == MOUSE_BUTTON_RIGHT or ev.button_index == MOUSE_BUTTON_MIDDLE:
			mouse_dx = ev.pressed
	elif ev is InputEventMouseMotion and ev.device != InputEvent.DEVICE_ID_EMULATION:
		if mouse_dx:
			cam_toccata = true
			yaw -= ev.relative.x * 0.008
			pitch += ev.relative.y * 0.006
			_aggiorna_cam()
		elif mouse_sx:
			if ev.position.distance_to(tap_inizio) > 8:
				mouse_mosso = true
			if mouse_mosso:
				_pan(ev.relative)
	elif ev is InputEventMagnifyGesture:
		dist /= ev.factor
		_aggiorna_cam()


# ─────────────────────────── HUD ───────────────────────────

func _tex(percorso: String) -> Texture2D:
	if not tex_cache.has(percorso):
		tex_cache[percorso] = load(percorso)
	return tex_cache[percorso]


func _tex_carta(id: int) -> Texture2D:
	if id == -2:
		return _tex("res://assets/cards/status/veleno_debilitante.webp")
	if id < 0:
		return _tex("res://assets/cards/status/stordimento.webp")
	return _tex("res://assets/cards/" + Carte.carta(id).img)


func _svuota(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


func _hud() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	hud = Control.new()
	hud.theme = Tema.tema()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(hud)
	for i in 2:
		schede.append(_scheda(i))
	# intestazione al centro
	var testa := VBoxContainer.new()
	testa.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	testa.offset_left = -230
	testa.offset_right = 230
	testa.offset_top = 8
	testa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(testa)
	lbl_turno = Tema.etichetta("", 26, Tema.CARTA, true)
	lbl_turno.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_turno.add_theme_color_override("font_outline_color", Tema.INCHIOSTRO)
	lbl_turno.add_theme_constant_override("outline_size", 8)
	testa.add_child(lbl_turno)
	lbl_banner = Tema.etichetta("", 21, Tema.ORO)
	lbl_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_banner.custom_minimum_size = Vector2(460, 0)
	lbl_banner.add_theme_color_override("font_outline_color", Tema.INCHIOSTRO)
	lbl_banner.add_theme_constant_override("outline_size", 8)
	testa.add_child(lbl_banner)
	var bmenu := Tema.bottone("Menu", 90)
	bmenu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bmenu.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Menu.tscn"))
	testa.add_child(bmenu)
	# fascia in basso: richiesta + mano
	var basso := VBoxContainer.new()
	basso.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	basso.offset_left = 10
	basso.offset_right = -10
	basso.offset_bottom = -6
	basso.grow_vertical = Control.GROW_DIRECTION_BEGIN
	basso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	basso.add_theme_constant_override("separation", 6)
	hud.add_child(basso)
	pan_richiesta = PanelContainer.new()
	basso.add_child(pan_richiesta)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	pan_richiesta.add_child(hb)
	lbl_richiesta = Tema.etichetta("", 21)
	lbl_richiesta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_richiesta.custom_minimum_size = Vector2(380, 34)
	lbl_richiesta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_richiesta.size_flags_stretch_ratio = 1.0
	hb.add_child(lbl_richiesta)
	box_bottoni = HFlowContainer.new()
	box_bottoni.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box_bottoni.size_flags_stretch_ratio = 1.3
	box_bottoni.custom_minimum_size = Vector2(380, 0)
	box_bottoni.alignment = FlowContainer.ALIGNMENT_END
	box_bottoni.add_theme_constant_override("h_separation", 8)
	box_bottoni.add_theme_constant_override("v_separation", 6)
	hb.add_child(box_bottoni)
	box_mano = HBoxContainer.new()
	box_mano.alignment = BoxContainer.ALIGNMENT_CENTER
	box_mano.custom_minimum_size = Vector2(0, CARTA_MANO.y)
	box_mano.mouse_filter = Control.MOUSE_FILTER_IGNORE
	basso.add_child(box_mano)
	# anteprima carta + testo interpretato
	anteprima = PanelContainer.new()
	anteprima.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	anteprima.grow_horizontal = Control.GROW_DIRECTION_BOTH
	anteprima.grow_vertical = Control.GROW_DIRECTION_BOTH
	anteprima.visible = false
	hud.add_child(anteprima)
	var ah := HBoxContainer.new()
	ah.add_theme_constant_override("separation", 14)
	anteprima.add_child(ah)
	ant_img = TextureRect.new()
	ant_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ant_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ant_img.custom_minimum_size = Vector2(388, 540)
	ah.add_child(ant_img)
	var av := VBoxContainer.new()
	av.custom_minimum_size = Vector2(380, 0)
	ah.add_child(av)
	av.add_child(Tema.etichetta("Come la applica il gioco", 20, Tema.VERMIGLIO, true))
	ant_txt = RichTextLabel.new()
	ant_txt.custom_minimum_size = Vector2(380, 400)
	ant_txt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	av.add_child(ant_txt)
	var ab := HBoxContainer.new()
	ab.alignment = BoxContainer.ALIGNMENT_END
	ab.add_theme_constant_override("separation", 8)
	av.add_child(ab)
	ant_azione = Tema.bottone("Gioca", 190)
	ant_azione.pressed.connect(func(): _rispondi(ant_idx))
	ab.add_child(ant_azione)
	var chiudi := Tema.bottone("Chiudi", 110)
	chiudi.pressed.connect(func(): anteprima.visible = false)
	ab.add_child(chiudi)
	# fine partita
	fine_pan = PanelContainer.new()
	fine_pan.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	fine_pan.grow_horizontal = Control.GROW_DIRECTION_BOTH
	fine_pan.grow_vertical = Control.GROW_DIRECTION_BOTH
	fine_pan.visible = false
	hud.add_child(fine_pan)
	var fv := VBoxContainer.new()
	fv.name = "V"
	fv.add_theme_constant_override("separation", 16)
	fine_pan.add_child(fv)
	var ft := Tema.etichetta("", 40, Tema.VERMIGLIO, true)
	ft.name = "Titolo"
	ft.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ft.custom_minimum_size = Vector2(460, 0)
	fv.add_child(ft)
	var fh := HBoxContainer.new()
	fh.alignment = BoxContainer.ALIGNMENT_CENTER
	fh.add_theme_constant_override("separation", 12)
	fv.add_child(fh)
	var b1 := Tema.bottone("Rivincita", 170)
	b_rivincita = b1
	b1.pressed.connect(_nuova)
	fh.add_child(b1)
	var b2 := Tema.bottone("Menu", 130)
	b2.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Menu.tscn"))
	fh.add_child(b2)


func _scheda(i: int) -> Dictionary:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(300, 0)
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if i == 0:
		col.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		col.position = Vector2(10, 10)
	else:
		col.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		col.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		col.offset_right = -10
		col.offset_left = -310
		col.offset_top = 10
	hud.add_child(col)
	var pan := PanelContainer.new()
	pan.add_theme_stylebox_override("panel", Tema.riquadro(Tema.CARTA, Tema.GIOCATORI[i], 4, 8, 10, 8))
	col.add_child(pan)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	pan.add_child(h)
	var rit := TextureRect.new()
	rit.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rit.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rit.custom_minimum_size = Vector2(76, 96)
	h.add_child(rit)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 1)
	h.add_child(v)
	var nome := Tema.etichetta("", 21, Tema.GIOCATORI[i], true)
	nome.custom_minimum_size = Vector2(190, 0)
	v.add_child(nome)
	var pips := Control.new()
	pips.custom_minimum_size = Vector2(190, 50)
	pips.draw.connect(_disegna_pips.bind(pips, i))
	v.add_child(pips)
	var info := Tema.etichetta("", 17)
	info.custom_minimum_size = Vector2(190, 0)
	v.add_child(info)
	var stato := Tema.etichetta("", 17, Tema.VERMIGLIO)
	stato.custom_minimum_size = Vector2(190, 0)
	stato.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(stato)
	# carta giocata + albero Kamae
	var riga := HBoxContainer.new()
	riga.add_theme_constant_override("separation", 8)
	riga.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(riga)
	var giocata := TextureButton.new()
	giocata.ignore_texture_size = true
	giocata.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	giocata.custom_minimum_size = CARTA_TAV
	riga.add_child(giocata)
	var dorso := Panel.new()
	dorso.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dorso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dorso.add_theme_stylebox_override("panel", Tema.riquadro(Tema.INCHIOSTRO, Tema.ORO, 3, 8))
	giocata.add_child(dorso)
	var dl := Tema.etichetta("", 17, Tema.ORO, true)
	dl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dorso.add_child(dl)
	var kam := TextureButton.new()
	kam.ignore_texture_size = true
	kam.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	kam.custom_minimum_size = CARTA_TAV
	riga.add_child(kam)
	var anello := Control.new()
	anello.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	anello.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anello.draw.connect(_disegna_anello.bind(anello, i))
	kam.add_child(anello)
	var d := {"col": col, "rit": rit, "nome": nome, "pips": pips, "info": info, "stato": stato,
		"giocata": giocata, "dorso": dorso, "dl": dl, "kam": kam, "anello": anello}
	giocata.pressed.connect(func():
		var id: int = g.F[i].play.get("id", -99)
		if id != -99 and (i == io or g.fase != "scelta"):
			_apri_anteprima(id, -1))
	if i == 1:
		var pc := PanelContainer.new()
		col.add_child(pc)
		cronaca = RichTextLabel.new()
		cronaca.bbcode_enabled = true
		cronaca.scroll_following = true
		cronaca.custom_minimum_size = Vector2(280, 190)
		pc.add_child(cronaca)
	return d


func _disegna_pips(c: Control, i: int) -> void:
	if g == null or g.F.size() <= i:
		return
	var f: Dictionary = g.F[i]
	var font: Font = Tema.testo
	c.draw_string(font, Vector2(0, 17), "Ferite", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Tema.INCHIOSTRO)
	var lim := int(f.lim)
	var passo := 24 if lim <= 5 else 17
	for k in lim:
		var p := Vector2(66 + k * passo, 12)
		if k < f.wounds:
			c.draw_circle(p, 9, Tema.VERMIGLIO)
		elif k < f.wounds + f.bleeds:
			c.draw_circle(p, 9, Color("5a0d0d"))
			c.draw_circle(p, 4, Tema.VERMIGLIO)
		else:
			c.draw_arc(p, 8, 0, TAU, 20, Tema.INCHIOSTRO, 1.5)
	if f.ai:
		return
	c.draw_string(font, Vector2(0, 42), "Focus", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Tema.INCHIOSTRO)
	for k in Game.MAX_FOCUS:
		var p2 := Vector2(66 + k * 24, 37)
		var pts := PackedVector2Array([p2 + Vector2(0, -9), p2 + Vector2(9, 0), p2 + Vector2(0, 9), p2 + Vector2(-9, 0)])
		if k < f.focus:
			c.draw_colored_polygon(pts, Color("7b3fa0"))
		else:
			pts.append(pts[0])
			c.draw_polyline(pts, Tema.INCHIOSTRO, 1.5)


func _disegna_anello(c: Control, i: int) -> void:
	if g == null or g.F.size() <= i:
		return
	var f: Dictionary = g.F[i]
	var n: Array = f.cd.kamae.nodes[f.kamae]
	# l'immagine è centrata mantenendo le proporzioni
	var r := Rect2(Vector2.ZERO, c.size)
	var asp := 463.0 / 645.0
	var w := minf(r.size.x, r.size.y * asp)
	var hgt := w / asp
	var o := (r.size - Vector2(w, hgt)) / 2.0
	var p := o + Vector2(float(n[0]) * w, float(n[1]) * hgt)
	c.draw_arc(p, w * 0.13, 0, TAU, 28, Tema.GIOCATORI[i], 5.0)
	c.draw_arc(p, w * 0.13 + 3.5, 0, TAU, 28, Tema.ORO, 2.0)


func _apri_anteprima(id: int, idx: int) -> void:
	ant_img.texture = _tex_carta(id)
	if id == -2:
		ant_txt.text = "Veleno Debilitante\n\nSe ce l'hai in mano quando scegli la carta, devi giocare questo: iniziativa 0, nessun effetto, poi torna nella riserva."
	elif id < 0:
		ant_txt.text = "Stordimento\n\nNon si può scartare e conta nel limite di mano. Puoi giocarlo al posto di una carta: iniziativa 0, nessun effetto, poi torna nella riserva.\nSe gli stordimenti in mano raggiungono il limite di mano sei sconfitto."
	else:
		ant_txt.text = Carte.testo(Carte.carta(id))
	ant_idx = idx
	ant_azione.visible = idx >= 0
	if idx >= 0:
		var az := "Gioca questa carta"
		if req.get("scarto", false):
			az = "Scarta questa carta"
		elif req.get("dal_mazzo", false):
			az = "Prendi questa carta"
		ant_azione.text = az
	anteprima.visible = true


func _tocco_carta_mano(id: int) -> void:
	var idx := -1
	if not req.is_empty() and req.kind == "card":
		for i in req.opts.size():
			if int(req.opts[i].card) == id:
				idx = i
	_apri_anteprima(id, idx)


func _aggiorna() -> void:
	if g == null or g.F.is_empty():
		return
	var fasi := {"setup": "Preparazione", "piazzamento": "Schieramento", "preparazione": "Preparazione",
		"pesca": "Pesca", "scelta": "Scelta della carta", "rivela": "Rivelazione",
		"risolvi": "Risoluzione", "scarto": "Scarto", "fine": "Fine"}
	lbl_turno.text = ("Turno %d — " % g.turn if g.turn > 0 else "") + fasi.get(g.fase, "")
	for i in 2:
		var f: Dictionary = g.F[i]
		var s: Dictionary = schede[i]
		s.rit.texture = _tex("res://assets/portraits/" + f.cd.portrait)
		s.nome.text = f.name
		s.pips.queue_redraw()
		s.anello.queue_redraw()
		s.info.text = "%s\nMano %d · Mazzo %d · Scarti %d" % [Carte.KAMAE[f.kamae], g.conta_mano(f), f.deck.size(), f.discard.size()]
		if f.ai:
			s.info.text = "Avvicina da: %s\nAtteggiamento: %s\nDistanza preferita %d · Mazzo %d" % [
				Carte.COMPORTAMENTI[f.comp], "Offensivo" if f.post == "off" else "Difensivo", int(f.raggio), f.deck.size()]
		s.kam.visible = not f.ai
		var st: Array = []
		if g.adv[0] == i:
			st.append("Vantaggio")
		if g.conta_stun(f) > 0:
			st.append("Stordimenti %d" % g.conta_stun(f))
		if f.ai and f.stun_lato > 0:
			st.append("Stordimenti %d/%d" % [f.stun_lato, f.lim])
		if f.hobbles.size() > 0:
			st.append("Azzoppato x%d" % f.hobbles.size())
		if f.armour:
			st.append("Armatura Pesante")
		if f.get("occ", false):
			st.append("Occultato")
		if f.dead:
			st = ["SCONFITTO"]
		s.stato.text = " · ".join(st)
		s.kam.texture_normal = _tex("res://assets/cards/" + f.cd.kamae_img)
		var id: int = f.play.get("id", -99)
		var coperta: bool = id != -99 and g.fase == "scelta" and i != io
		s.giocata.texture_normal = null if (id == -99 or coperta) else _tex_carta(id)
		s.dorso.visible = id == -99 or coperta
		s.dl.text = "" if id == -99 else "Carta coperta"
		if id != -99 and not coperta and f.play.has("init"):
			s.giocata.tooltip_text = "Iniziativa %d" % int(f.play.init)
		if not pedine.is_empty() and pedine[i].visible == false and f.pos.x < 50:
			_muovi_pedina(i, false)
	_aggiorna_mano()
	pan_richiesta.visible = lbl_richiesta.text != "" or box_bottoni.get_child_count() > 0


func _aggiorna_mano() -> void:
	_svuota(box_mano)
	var f: Dictionary = g.F[io]
	var scelte := {}
	if not req.is_empty() and req.kind == "card":
		for o in req.opts:
			scelte[int(o.card)] = true
	var mano: Array = f.hand.duplicate()
	mano.sort()
	box_mano.add_theme_constant_override("separation", 6 if mano.size() <= 8 else -30)
	for id in mano:
		var b := TextureButton.new()
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.custom_minimum_size = CARTA_MANO
		b.texture_normal = _tex_carta(id)
		b.pressed.connect(_tocco_carta_mano.bind(id))
		if not scelte.is_empty():
			if scelte.has(id):
				var bordo := Panel.new()
				bordo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				bordo.mouse_filter = Control.MOUSE_FILTER_IGNORE
				bordo.add_theme_stylebox_override("panel", Tema.riquadro(Color(0, 0, 0, 0), Tema.ORO, 4, 8))
				b.add_child(bordo)
			else:
				b.modulate = Color(0.45, 0.45, 0.45)
		box_mano.add_child(b)
