## Editor visuale di geometria/effetti — Senjutsu (Fase 4)
##
## "Gemello digitale" editabile della faccia di una carta: si ricostruisce la
## struttura TRASCINANDO le icone del gioco.
##  - Nido d'ape (modello a 6 direzioni, come il motore): si trascinano ferite /
##    esecuzione / sanguinamento sugli esagoni d'attacco e scudi su quelli di
##    difesa. Ogni cella è un (d, k) → direzione relativa 0-5, anello 1-2.
##  - Movimento: si trascinano frecce di passo NERE (obbligatorie) o BIANCHE
##    (facoltative) e rotazioni, in una o più sequenze alternative ("OPPURE").
##  - Kamae richiesto: token colorati (aggressione / equilibrio / determinazione).
##  - counter (iniziative di contrattacco) e note.
##
## Gli `effects` esistenti sono PRESERVATI così come sono (editor dedicato in una
## fase successiva). Serializza/deserializza lo Schema v2 (GEOMETRY_SCHEMA.md).
class_name GeometryEditor
extends VBoxContainer

signal changed

const RINGS := 2          ## anelli mostrati (vicinato completo entro distanza 2)
const HEX_R := 21.0       ## raggio esagono in px
const HEX_PIX := 25.0     ## scala unità-mondo → px per la disposizione del nido d'ape

# Colori icone.
const COL_WOUND := Color(0.86, 0.30, 0.24)
const COL_WOUND2 := Color(0.72, 0.13, 0.13)
const COL_EXEC := Color(0.12, 0.12, 0.14)
const COL_BLEED := Color(0.55, 0.30, 0.70)
const COL_SHIELD := Color(0.30, 0.55, 0.85)
const COL_TARGET := Color(0.45, 0.45, 0.5)
const COL_PAWN := Color(0.85, 0.70, 0.30)

const KAMAE_COLORS := {
	"aggression": Color(0.86, 0.40, 0.30),
	"balance": Color(0.40, 0.70, 0.45),
	"determination": Color(0.45, 0.55, 0.85),
}
const KAMAE_LABELS := {
	"aggression": "Aggressività", "balance": "Equilibrio", "determination": "Determinazione",
}
const WHEN_OPTS := ["", "on_hit", "always"]
const KAMAE_OPTS := ["", "aggression", "balance", "determination"]

# ─── Modello dati ────────────────────────────────────────────────────────────
var _type: String = "attack"
var _attack: Dictionary = {}   ## Vector2i(d,k) -> ferite (int | "exec" | "bleed")
var _defence: Dictionary = {}  ## Vector2i(d,k) -> valore blocco (int)
var _opts: Array = []          ## Array[ Array[ {t,dir,n,opt} ] ]  (sequenze "OPPURE")
var _kamae_req: String = ""
var _counter: Array = []
var _note: String = ""
var _effects: Array = []       ## passthrough (non editati qui)
var _name: String = ""

# ─── Widget ──────────────────────────────────────────────────────────────────
var _honey: Control
var _hex_cells: Dictionary = {}   ## Vector2i(d,k) -> HexCell
var _moves_box: VBoxContainer
var _effects_box: VBoxContainer
var _kamae_label: Label
var _counter_edit: LineEdit
var _note_edit: TextEdit
var _built := false


# ─── API pubblica ────────────────────────────────────────────────────────────

## Carica la geometria di una carta (o {} per crearne una nuova).
func load_geometry(card_type: String, geom: Dictionary) -> void:
	_type = card_type if card_type != "" else str(geom.get("type", "attack"))
	_name = str(geom.get("name", ""))
	_attack = _cells_from(geom.get("attack", {}), "w")
	_defence = _cells_from(geom.get("defence", {}), "v")
	_opts = []
	for opt in geom.get("move", {}).get("opts", []):
		var atoms: Array = []
		for a in opt.get("atoms", []):
			atoms.append({
				"t": str(a.get("t", "step")),
				"dir": int(a.get("dir", 0)),
				"n": int(a.get("n", 1)),
				"opt": bool(a.get("opt", false)),
			})
		_opts.append(atoms)
	_kamae_req = str(geom.get("kamae_req", ""))
	_counter = []
	for x in geom.get("counter", []):
		_counter.append(int(x))
	_effects = []
	for e in geom.get("effects", []):
		if typeof(e) == TYPE_DICTIONARY:
			_effects.append(_norm_effect(e))
	_note = str(geom.get("note", ""))
	if not _built:
		_build_ui()
	_refresh_all()


## Serializza lo stato corrente nello Schema v2 (campi vuoti omessi).
func to_geometry() -> Dictionary:
	var g := {}
	if _name != "":
		g["name"] = _name
	g["type"] = _type
	if _kamae_req != "":
		g["kamae_req"] = _kamae_req
	var opts := []
	for atoms in _opts:
		if atoms.is_empty():
			continue
		var out_atoms := []
		for a in atoms:
			var atom := {"t": a["t"]}
			if a["t"] == "step":
				atom["dir"] = a["dir"]
			atom["n"] = a["n"]
			atom["opt"] = a["opt"]
			out_atoms.append(atom)
		opts.append({"atoms": out_atoms})
	if not opts.is_empty():
		g["move"] = {"opts": opts}
	var acells := _cells_to(_attack, "w")
	if not acells.is_empty():
		g["attack"] = {"cells": acells}
	var dcells := _cells_to(_defence, "v")
	if not dcells.is_empty():
		g["defence"] = {"cells": dcells}
	if not _counter.is_empty():
		g["counter"] = _counter
	var effs := []
	for e in _effects:
		var ce := {"do": str(e.get("do", ""))}
		if ce["do"] == "":
			continue   # un effetto senza verbo è ignorato
		if int(e.get("n", 0)) > 0:
			ce["n"] = int(e["n"])
		if str(e.get("when", "")) != "":
			ce["when"] = str(e["when"])
		if str(e.get("kamae", "")) != "":
			ce["kamae"] = str(e["kamae"])
		if str(e.get("to", "")) != "":
			ce["to"] = str(e["to"])
		if int(e.get("focus_cost", 0)) > 0:
			ce["focus_cost"] = int(e["focus_cost"])
		if str(e.get("alt", "")) != "":
			ce["alt"] = str(e["alt"])
		effs.append(ce)
	if not effs.is_empty():
		g["effects"] = effs
	if _note != "":
		g["note"] = _note
	return g


# Mutatori pubblici (usati dal drag-drop e dai test headless). Coordinate
# assiali (q,r) relative alla pedina con facing 0 (es. fronte adiacente = (1,0)).
func set_attack_cell(q: int, r: int, w) -> void:
	_attack[Vector2i(q, r)] = w
	_after_change(Vector2i(q, r))

func set_defence_cell(q: int, r: int, v: int) -> void:
	_defence[Vector2i(q, r)] = v
	_after_change(Vector2i(q, r))

func clear_cell(q: int, r: int) -> void:
	_attack.erase(Vector2i(q, r))
	_defence.erase(Vector2i(q, r))
	_after_change(Vector2i(q, r))

func add_opt() -> int:
	_opts.append([])
	_rebuild_moves()
	return _opts.size() - 1

func add_move_atom(opt_idx: int, atom: Dictionary) -> void:
	while _opts.size() <= opt_idx:
		_opts.append([])
	_opts[opt_idx].append(atom)
	_rebuild_moves()
	changed.emit()

func set_kamae_req(slug: String) -> void:
	_kamae_req = slug
	if _kamae_label:
		_update_kamae_label()
	changed.emit()


# ─── Costruzione UI ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	_built = true
	add_theme_constant_override("separation", 6)

	# Kamae richiesto: valore corrente (si imposta dai token nella palette).
	_add_subtitle("Kamae richiesto")
	var kr := HBoxContainer.new()
	kr.add_theme_constant_override("separation", 6)
	_kamae_label = Label.new()
	_kamae_label.add_theme_font_size_override("font_size", 12)
	_kamae_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kr.add_child(_kamae_label)
	var none := Button.new()
	none.text = "azzera"
	none.pressed.connect(func(): set_kamae_req(""))
	kr.add_child(none)
	add_child(kr)

	# Nido d'ape completo (tutti gli esagoni entro distanza 2): bersaglio del drag.
	_add_subtitle("Combattimento")
	_honey = Control.new()
	_honey.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_child(_honey)

	# Movimento: sequenze (le righe sono bersaglio del drag delle frecce).
	_add_subtitle("Movimento")
	_moves_box = VBoxContainer.new()
	_moves_box.add_theme_constant_override("separation", 4)
	add_child(_moves_box)
	var add_opt_btn := Button.new()
	add_opt_btn.text = "+ sequenza"
	add_opt_btn.pressed.connect(func(): add_opt())
	add_child(add_opt_btn)

	# Effetti.
	_add_subtitle("Effetti")
	_effects_box = VBoxContainer.new()
	_effects_box.add_theme_constant_override("separation", 3)
	add_child(_effects_box)
	var add_eff := Button.new()
	add_eff.text = "+ effetto"
	add_eff.pressed.connect(func(): add_effect())
	add_child(add_eff)

	# Counter + note.
	_add_subtitle("Contrattacco / note")
	_counter_edit = LineEdit.new()
	_counter_edit.placeholder_text = "es. 8, 6"
	_counter_edit.text_changed.connect(_on_counter_changed)
	add_child(_counter_edit)
	_note_edit = TextEdit.new()
	_note_edit.custom_minimum_size = Vector2(0, 50)
	_note_edit.placeholder_text = "annotazioni / incertezze di trascrizione"
	_note_edit.text_changed.connect(func(): _note = _note_edit.text; changed.emit())
	add_child(_note_edit)

	_build_honeycomb()


## Palette dei sorgenti TRASCINABILI (combattimento, movimento, kamae), da
## collocare fuori dal canvas (colonna destra dell'editor). Il drag-drop
## funziona attraverso l'albero della scena. Richiede che il canvas sia già
## costruito (così gli esagoni esistono come bersagli).
func build_palette() -> Control:
	if not _built:
		_build_ui()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.custom_minimum_size = Vector2(150, 0)
	var title := Label.new()
	title.text = "Palette"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.7, 0.78, 0.9))
	col.add_child(title)
	var legend := Label.new()
	legend.text = "Combattimento: clic sull'esagono per scorrere ferita/doppia/esecuzione/sanguina/difesa.  Clic destro = svuota."
	legend.add_theme_font_size_override("font_size", 11)
	legend.add_theme_color_override("font_color", Color(0.6, 0.66, 0.74))
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(legend)
	var ml := Label.new()
	ml.text = "Movimento (trascina)"
	ml.add_theme_font_size_override("font_size", 12)
	col.add_child(ml)
	col.add_child(_build_move_palette())
	var kl := Label.new()
	kl.text = "Kamae (clic per impostare)"
	kl.add_theme_font_size_override("font_size", 12)
	col.add_child(kl)
	var km := HBoxContainer.new()
	km.add_theme_constant_override("separation", 6)
	for slug in ["aggression", "balance", "determination"]:
		var tok := DragIcon.new()
		tok.setup(self, "kamae_" + slug, slug)
		tok.custom_minimum_size = Vector2(2 * HEX_R, 2 * HEX_R)
		tok.gui_input.connect(_on_kamae_token_input.bind(slug))
		km.add_child(tok)
	col.add_child(km)
	return col


func _build_combat_palette() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	var l := Label.new()
	l.text = "Attacco"
	l.add_theme_font_size_override("font_size", 12)
	col.add_child(l)
	var grid := GridContainer.new()
	grid.columns = 3
	for spec in [["w1", 1], ["w2", 2], ["exec", "exec"], ["bleed", "bleed"], ["w0", 0]]:
		grid.add_child(_palette_icon(spec[0], spec[1]))
	col.add_child(grid)
	var l2 := Label.new()
	l2.text = "Difesa"
	l2.add_theme_font_size_override("font_size", 12)
	col.add_child(l2)
	col.add_child(_palette_icon("shield", 1))
	return col


func _build_move_palette() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for spec in [["step", false], ["step", true], ["rot", false], ["rot", true]]:
		var di := DragIcon.new()
		var kind: String = spec[0] + ("_opt" if spec[1] else "")
		di.setup(self, kind, null)
		di.custom_minimum_size = Vector2(2 * HEX_R, 2 * HEX_R)
		row.add_child(di)
	return row


func _palette_icon(kind: String, value) -> DragIcon:
	var di := DragIcon.new()
	di.setup(self, kind, value)
	di.custom_minimum_size = Vector2(2 * HEX_R, 2 * HEX_R)
	return di


func _build_honeycomb() -> void:
	_hex_cells.clear()
	for ch in _honey.get_children():
		ch.queue_free()
	# Tutti gli esagoni del vicinato entro distanza RINGS (centro + anello 1 e 2).
	var cells := HexGrid.hexes_in_range(Vector2i.ZERO, RINGS)
	var maxr := 0.0
	for ax in cells:
		maxr = maxf(maxr, _hex_pixel(ax).length())
	var side := (maxr + HEX_R) * 2.0 + 6.0
	_honey.custom_minimum_size = Vector2(side, side)
	_honey.size = Vector2(side, side)
	var center := Vector2(side, side) * 0.5
	for ax in cells:
		_add_hex_cell(center + _hex_pixel(ax), ax, ax == Vector2i.ZERO)


func _add_hex_cell(center_px: Vector2, ax: Vector2i, is_pawn: bool) -> void:
	var cell := HexCell.new()
	cell.setup(self, ax, HEX_R, is_pawn)
	cell.position = center_px - Vector2(HEX_R, HEX_R)
	cell.custom_minimum_size = Vector2(2 * HEX_R, 2 * HEX_R)
	cell.size = cell.custom_minimum_size
	_honey.add_child(cell)
	if not is_pawn:
		_hex_cells[ax] = cell


## Posizione in px (centro del controllo) di un esagono assiale. Esagoni a LATO
## PIATTO IN ALTO, col FRONTE (DIRS[0]) verso l'alto: il reticolo è lineare nelle
## coordinate assiali, screen = q·Sq + r·Sr con basi scelte per orientare DIRS[0]
## a Nord (le 6 direzioni cadono a 60° l'una dall'altra).
static func _hex_pixel(ax: Vector2i) -> Vector2:
	var d := HEX_R * 1.78   # distanza tra centri adiacenti (quasi a contatto)
	var sq := Vector2(0.0, -d)
	var sr := Vector2(-0.8660254 * d, -0.5 * d)
	return sq * ax.x + sr * ax.y


func _add_subtitle(text: String) -> void:
	add_child(HSeparator.new())
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(0.6, 0.66, 0.74))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(120, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(l)


# ─── Refresh ─────────────────────────────────────────────────────────────────

func _refresh_all() -> void:
	if not _built:
		return
	for key in _hex_cells:
		_refresh_cell(key)
	_rebuild_moves()
	_rebuild_effects()
	_update_kamae_label()
	_counter_edit.text = ", ".join(_counter.map(func(x): return str(x)))
	_note_edit.text = _note


func _refresh_cell(key: Vector2i) -> void:
	var cell: HexCell = _hex_cells.get(key)
	if cell == null:
		return
	cell.atk = _attack.get(key, null)
	cell.dfn = _defence.get(key, null)
	cell.queue_redraw()


func _update_kamae_label() -> void:
	if _kamae_req == "":
		_kamae_label.text = "kamae richiesto: nessuno"
	else:
		_kamae_label.text = "kamae richiesto: %s" % KAMAE_LABELS.get(_kamae_req, _kamae_req)


func _rebuild_moves() -> void:
	if _moves_box == null:
		return
	for ch in _moves_box.get_children():
		ch.queue_free()
	for i in _opts.size():
		_moves_box.add_child(_build_opt_row(i))


func _build_opt_row(opt_idx: int) -> Control:
	var row := MoveOptRow.new()
	row.setup(self, opt_idx)
	row.add_theme_constant_override("separation", 4)
	var tag := Label.new()
	tag.text = ("seq %d:" % (opt_idx + 1)) if _opts.size() > 1 else "passi:"
	tag.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	row.add_child(tag)
	for ai in _opts[opt_idx].size():
		row.add_child(_build_atom_chip(opt_idx, ai))
	var hint := Label.new()
	hint.text = "  ⟵ trascina qui"
	hint.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))
	hint.add_theme_font_size_override("font_size", 11)
	row.add_child(hint)
	return row


func _build_atom_chip(opt_idx: int, atom_idx: int) -> Control:
	var a: Dictionary = _opts[opt_idx][atom_idx]
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 2)

	var glyph := Button.new()
	glyph.custom_minimum_size = Vector2(40, 30)
	glyph.add_theme_color_override("font_color", Color.BLACK if not a["opt"] else Color(0.2, 0.2, 0.2))
	if a["t"] == "step":
		glyph.text = "%s d%d" % ["▲" if not a["opt"] else "△", a["dir"]]
		glyph.pressed.connect(_cycle_dir.bind(opt_idx, atom_idx))
	else:
		glyph.text = "↻" if not a["opt"] else "↺"
	chip.add_child(glyph)

	var sp := SpinBox.new()
	sp.min_value = 1; sp.max_value = 6; sp.value = a["n"]
	sp.value_changed.connect(func(v): _opts[opt_idx][atom_idx]["n"] = int(v); changed.emit())
	chip.add_child(sp)

	var opt_chk := CheckBox.new()
	opt_chk.text = "opz"
	opt_chk.button_pressed = a["opt"]
	opt_chk.toggled.connect(func(p): _opts[opt_idx][atom_idx]["opt"] = p; _rebuild_moves(); changed.emit())
	chip.add_child(opt_chk)

	var rm := Button.new()
	rm.text = "x"
	rm.pressed.connect(func():
		_opts[opt_idx].remove_at(atom_idx)
		_rebuild_moves(); changed.emit())
	chip.add_child(rm)
	return chip


# ─── Effetti ─────────────────────────────────────────────────────────────────

static func _norm_effect(e: Dictionary) -> Dictionary:
	return {
		"do": str(e.get("do", "")), "n": int(e.get("n", 0)),
		"when": str(e.get("when", "")), "kamae": str(e.get("kamae", "")),
		"to": str(e.get("to", "")), "focus_cost": int(e.get("focus_cost", 0)),
		"alt": str(e.get("alt", "")),
	}


## Aggiunge un effetto (vuoto o pre-popolato). Usato dal bottone e dai test.
func add_effect(e := {}) -> void:
	_effects.append(_norm_effect(e))
	_rebuild_effects()
	changed.emit()


func _rebuild_effects() -> void:
	if _effects_box == null:
		return
	for ch in _effects_box.get_children():
		ch.queue_free()
	for i in _effects.size():
		_effects_box.add_child(_build_effect_row(i))


## Una riga effetto su DUE righe compatte (sta nella colonna senza scroll
## orizzontale): riga 1 = verbo + n + rimuovi; riga 2 = when/kamae/to/focus/alt.
func _build_effect_row(i: int) -> Control:
	var e: Dictionary = _effects[i]
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)

	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 3)
	var do_opt := OptionButton.new()
	do_opt.clip_text = true
	do_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	do_opt.add_item("(verbo…)")
	for v in CardValidator.EFFECT_VERBS:
		do_opt.add_item(v)
	do_opt.selected = CardValidator.EFFECT_VERBS.find(str(e.get("do", ""))) + 1
	do_opt.item_selected.connect(func(idx):
		_effects[i]["do"] = "" if idx == 0 else CardValidator.EFFECT_VERBS[idx - 1]
		changed.emit())
	r1.add_child(do_opt)
	r1.add_child(_lbl("n"))
	r1.add_child(_eff_spin(int(e.get("n", 0)), 0, 9, func(v): _effects[i]["n"] = v))
	var rm := Button.new()
	rm.text = "x"
	rm.pressed.connect(func(): _effects.remove_at(i); _rebuild_effects(); changed.emit())
	r1.add_child(rm)
	box.add_child(r1)

	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 3)
	r2.add_child(_eff_opt(WHEN_OPTS, str(e.get("when", "")), func(v): _effects[i]["when"] = v))
	r2.add_child(_eff_opt(KAMAE_OPTS, str(e.get("kamae", "")), func(v): _effects[i]["kamae"] = v))
	r2.add_child(_eff_opt(KAMAE_OPTS, str(e.get("to", "")), func(v): _effects[i]["to"] = v))
	r2.add_child(_lbl("F"))
	r2.add_child(_eff_spin(int(e.get("focus_cost", 0)), 0, 3, func(v): _effects[i]["focus_cost"] = v))
	var alt := LineEdit.new()
	alt.custom_minimum_size = Vector2(34, 0)
	alt.placeholder_text = "alt"
	alt.text = str(e.get("alt", ""))
	alt.text_changed.connect(func(t): _effects[i]["alt"] = t.strip_edges(); changed.emit())
	r2.add_child(alt)
	box.add_child(r2)
	box.add_child(HSeparator.new())
	return box


func _lbl(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	l.add_theme_font_size_override("font_size", 11)
	return l


func _eff_spin(val: int, mn: int, mx: int, on_set: Callable) -> SpinBox:
	var sp := SpinBox.new()
	sp.min_value = mn; sp.max_value = mx; sp.value = val
	sp.value_changed.connect(func(v): on_set.call(int(v)); changed.emit())
	return sp


func _eff_opt(values: Array, cur: String, on_set: Callable) -> OptionButton:
	var o := OptionButton.new()
	var found := -1
	for i in values.size():
		o.add_item("—" if values[i] == "" else str(values[i]))
		if values[i] == cur:
			found = i
	o.selected = maxi(found, 0)
	o.clip_text = true
	o.custom_minimum_size = Vector2(62, 0)
	o.item_selected.connect(func(idx): on_set.call(values[idx]); changed.emit())
	return o


# ─── Handler ─────────────────────────────────────────────────────────────────

## Stati ciclici di un esagono di combattimento (clic per avanzare).
const CELL_CYCLE := ["empty", "w1", "w2", "exec", "bleed", "shield"]

func _on_cell_cycle(cell) -> void:
	var ax: Vector2i = cell.ax
	var nxt := (_cell_state_index(ax) + 1) % CELL_CYCLE.size()
	_attack.erase(ax)
	_defence.erase(ax)
	match CELL_CYCLE[nxt]:
		"w1": _attack[ax] = 1
		"w2": _attack[ax] = 2
		"exec": _attack[ax] = "exec"
		"bleed": _attack[ax] = "bleed"
		"shield": _defence[ax] = 1
	_after_change(ax)


func _cell_state_index(ax: Vector2i) -> int:
	if _defence.has(ax):
		return CELL_CYCLE.find("shield")
	if _attack.has(ax):
		var w = _attack[ax]
		if typeof(w) == TYPE_STRING:
			return maxi(1, CELL_CYCLE.find(str(w)))   # "exec" / "bleed"
		return CELL_CYCLE.find("w2") if int(w) == 2 else CELL_CYCLE.find("w1")
	return 0


func _on_cell_clear(cell) -> void:
	clear_cell(cell.ax.x, cell.ax.y)


func _on_move_drop(opt_idx: int, data: Dictionary) -> void:
	var kind: String = data.get("kind", "")
	var is_opt := kind.ends_with("_opt")
	var t := "rot" if kind.begins_with("rot") else "step"
	add_move_atom(opt_idx, {"t": t, "dir": 0, "n": 1, "opt": is_opt})


func _on_kamae_token_input(event: InputEvent, slug: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		set_kamae_req("" if _kamae_req == slug else slug)


func _on_counter_changed(text: String) -> void:
	_counter = []
	for tok in text.split(","):
		var s := tok.strip_edges()
		if s.is_valid_int():
			_counter.append(int(s))
	changed.emit()


func _cycle_dir(opt_idx: int, atom_idx: int) -> void:
	var order := [0, 1, 2, 3, 4, 5, -1]
	var cur: int = _opts[opt_idx][atom_idx]["dir"]
	var i := order.find(cur)
	_opts[opt_idx][atom_idx]["dir"] = order[(i + 1) % order.size()]
	_rebuild_moves()
	changed.emit()


func _after_change(key: Vector2i) -> void:
	_refresh_cell(key)
	changed.emit()


# ─── Conversione celle dict ↔ schema ─────────────────────────────────────────

## Legge le celle in coordinate assiali (q,r). Accetta sia lo schema nuovo
## {q,r,...} sia quello legacy a 6 direzioni {d,k,...} (convertito: DIRS[d]*k).
func _cells_from(section: Dictionary, value_key: String) -> Dictionary:
	var out := {}
	for cell in section.get("cells", []):
		var key: Vector2i
		if cell.has("q"):
			key = Vector2i(int(cell.get("q", 0)), int(cell.get("r", 0)))
		else:
			key = HexGrid.DIRS[int(cell.get("d", 0)) % 6] * maxi(1, int(cell.get("k", 1)))
		out[key] = _coerce(cell.get(value_key, 1))
	return out


## Scrive le celle in coordinate assiali piene {q,r,...}, ordinate stabilmente.
func _cells_to(cells: Dictionary, value_key: String) -> Array:
	var keys: Array = cells.keys()
	keys.sort_custom(func(a, b): return a.y < b.y if a.y != b.y else a.x < b.x)
	var out := []
	for key in keys:
		out.append({"q": key.x, "r": key.y, value_key: _coerce(cells[key])})
	return out


## Le ferite/blocco sono interi (`int`) tranne i marcatori string "exec"/"bleed".
## JSON può restituire i numeri come float: normalizziamo a int per JSON puliti.
static func _coerce(v):
	return v if typeof(v) == TYPE_STRING else int(v)


# ─── Disegno icone (condiviso da celle e palette) ────────────────────────────

static func draw_icon(ci: CanvasItem, kind: String, c: Vector2, r: float, value) -> void:
	var font := ThemeDB.fallback_font
	match kind:
		"w1", "w2", "w0":
			var col := COL_WOUND
			var txt := "1"
			if kind == "w2": col = COL_WOUND2; txt = "2"
			elif kind == "w0": col = COL_TARGET; txt = ""
			ci.draw_circle(c, r * 0.62, col)
			if txt != "":
				_draw_centered(ci, font, c, txt, Color.WHITE, int(r))
			else:
				ci.draw_circle(c, r * 0.16, Color.WHITE)
		"exec":
			ci.draw_circle(c, r * 0.62, COL_EXEC)
			var d := r * 0.30
			ci.draw_line(c + Vector2(-d, -d), c + Vector2(d, d), Color.WHITE, maxf(2.0, r * 0.12))
			ci.draw_line(c + Vector2(-d, d), c + Vector2(d, -d), Color.WHITE, maxf(2.0, r * 0.12))
		"bleed":
			ci.draw_circle(c, r * 0.62, COL_BLEED)
			var dp := r * 0.30
			ci.draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -dp * 1.5), c + Vector2(-dp, dp * 0.2), c + Vector2(dp, dp * 0.2)]), Color.WHITE)
			ci.draw_circle(c + Vector2(0, dp * 0.35), dp * 0.75, Color.WHITE)
		"shield":
			_draw_shield(ci, c, r * 0.72, COL_SHIELD)
			_draw_centered(ci, font, c + Vector2(0, -r * 0.05), str(value), Color.WHITE, int(r * 0.8))
		"kamae_aggression", "kamae_balance", "kamae_determination":
			var slug := kind.substr(6)
			ci.draw_circle(c, r * 0.62, KAMAE_COLORS.get(slug, Color.GRAY))
			ci.draw_arc(c, r * 0.62, 0, TAU, 24, Color.WHITE, 2.0)
		"step", "step_opt":
			var filled := kind == "step"
			ci.draw_circle(c, r * 0.62, Color.BLACK if filled else Color(0.92, 0.92, 0.92))
			_draw_triangle_up(ci, c, r * 0.42, Color.WHITE if filled else Color.BLACK)
		"rot", "rot_opt":
			var filled := kind == "rot"
			ci.draw_circle(c, r * 0.62, Color.BLACK if filled else Color(0.92, 0.92, 0.92))
			var ac := Color.WHITE if filled else Color.BLACK
			ci.draw_arc(c, r * 0.34, deg_to_rad(-30), deg_to_rad(210), 18, ac, maxf(2.0, r * 0.1))
			var tip := c + Vector2(r * 0.34, 0).rotated(deg_to_rad(-30))
			ci.draw_line(tip, tip + Vector2(-r * 0.18, -r * 0.02), ac, maxf(2.0, r * 0.1))
			ci.draw_line(tip, tip + Vector2(-r * 0.02, -r * 0.18), ac, maxf(2.0, r * 0.1))


static func _draw_triangle_up(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, -s), c + Vector2(-s * 0.9, s * 0.8), c + Vector2(s * 0.9, s * 0.8)]), col)


static func _draw_shield(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([
		c + Vector2(-s * 0.8, -s * 0.7), c + Vector2(s * 0.8, -s * 0.7),
		c + Vector2(s * 0.8, s * 0.05), c + Vector2(0, s * 0.9), c + Vector2(-s * 0.8, s * 0.05)]), col)


static func _draw_centered(ci: CanvasItem, font: Font, c: Vector2, text: String, col: Color, fs: int) -> void:
	if font == null:
		return
	var sz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	ci.draw_string(font, c - sz * 0.5 + Vector2(0, sz.y * 0.35), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


# ─── Inner class: esagono droppabile ─────────────────────────────────────────

class HexCell extends Control:
	var ed: GeometryEditor
	var ax: Vector2i   ## coordinata assiale (q, r) relativa alla pedina (facing 0)
	var r: float       ## raggio in px
	var is_pawn: bool
	var atk = null   ## ferite (int|String) o null
	var dfn = null   ## valore blocco (int) o null

	func setup(editor: GeometryEditor, axial: Vector2i, rr: float, pawn: bool) -> void:
		ed = editor; ax = axial; r = rr; is_pawn = pawn
		mouse_filter = Control.MOUSE_FILTER_STOP
		tooltip_text = "pedina" if pawn else "q %d · r %d · dist %d" % [ax.x, ax.y, _hex_dist(ax)]

	static func _hex_dist(a: Vector2i) -> int:
		return (absi(a.x) + absi(a.y) + absi(a.x + a.y)) / 2

	func _draw() -> void:
		var c := Vector2(r, r)
		var pts := PackedVector2Array()
		for i in range(6):
			pts.append(c + Vector2.from_angle(deg_to_rad(-60 + 60 * i)) * r * 0.95)   # lato piatto in alto
		var bg := Color(0.18, 0.18, 0.22)
		if is_pawn:
			bg = Color(0.22, 0.20, 0.12)
		elif atk != null or dfn != null:
			bg = Color(0.24, 0.24, 0.30)
		draw_colored_polygon(pts, bg)
		pts.append(pts[0])
		draw_polyline(pts, Color(0.45, 0.45, 0.5), 1.5)
		if is_pawn:
			var tri := PackedVector2Array([c + Vector2(0, -r * 0.4), c + Vector2(-r * 0.4, r * 0.35), c + Vector2(r * 0.4, r * 0.35)])
			draw_colored_polygon(tri, GeometryEditor.COL_PAWN)
			return
		if atk != null:
			var kind := "w1"
			if typeof(atk) == TYPE_STRING:
				kind = "exec" if atk == "exec" else ("bleed" if atk == "bleed" else "w1")
			else:
				var n := int(atk)
				kind = "w2" if n == 2 else ("w0" if n == 0 else "w1")
			GeometryEditor.draw_icon(self, kind, c if dfn == null else c - Vector2(0, r * 0.32), r * (1.0 if dfn == null else 0.6), atk)
		if dfn != null:
			GeometryEditor.draw_icon(self, "shield", c if atk == null else c + Vector2(0, r * 0.32), r * (1.0 if atk == null else 0.6), int(dfn))

	## Clic sinistro = avanza il ciclo (vuoto→ferita→doppia→esec→sanguina→difesa);
	## clic destro = svuota. Niente trascinamento (più comodo su touch).
	func _gui_input(event: InputEvent) -> void:
		if is_pawn or not (event is InputEventMouseButton and event.pressed):
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			ed._on_cell_cycle(self)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			ed._on_cell_clear(self)


# ─── Inner class: icona trascinabile (palette / token) ───────────────────────

class DragIcon extends Control:
	var ed: GeometryEditor
	var kind: String
	var value

	func setup(editor: GeometryEditor, k: String, v) -> void:
		ed = editor; kind = k; value = v
		mouse_filter = Control.MOUSE_FILTER_STOP
		tooltip_text = k

	func _draw() -> void:
		GeometryEditor.draw_icon(self, kind, size * 0.5, minf(size.x, size.y) * 0.5, value)

	func _get_drag_data(_pos: Vector2):
		var prev := DragIcon.new()
		prev.setup(ed, kind, value)
		prev.custom_minimum_size = size
		prev.size = size
		set_drag_preview(prev)
		return {"kind": kind, "value": value}


# ─── Inner class: riga di una sequenza di movimento (drop target) ────────────

class MoveOptRow extends HBoxContainer:
	var ed: GeometryEditor
	var opt_idx: int

	func setup(editor: GeometryEditor, idx: int) -> void:
		ed = editor; opt_idx = idx
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _can_drop_data(_pos: Vector2, data) -> bool:
		return data is Dictionary and str(data.get("kind", "")).begins_with("step") \
			or data is Dictionary and str(data.get("kind", "")).begins_with("rot")

	func _drop_data(_pos: Vector2, data) -> void:
		ed._on_move_drop(opt_idx, data)
