## Editor visuale di geometria/effetti — Senjutsu
##
## "Gemello digitale" editabile della faccia di una carta, costruito a WIDGET:
## la carta è una pila di widget, ognuno con un SELETTORE DI TIPO in cima che lo
## trasforma (Combattimento, Movimento, Kamae, Effetto, Contrattacco, Nota). Si
## possono avere PIÙ widget dello stesso tipo (es. più attacchi gated da kamae
## diversi, più sequenze di movimento, più effetti).
##
## - Combattimento: nido d'ape a clic-ciclo (vuoto→ferita→doppia→esec→sanguina→
##   difesa) + gate kamae opzionale (la variante d'attacco attiva in quella posa).
## - Movimento: una sequenza di atomi (passo con rosetta a 6 direzioni / libero,
##   rotazione), con passi, facoltativo, kamae, costo focus.
## - Kamae richiesto, Contrattacco (iniziative), Nota.
##
## Serializza/deserializza lo Schema v2 (GEOMETRY_SCHEMA.md), incluse le varianti
## `attacks`/`defences` gated da kamae. L'ordine dei widget si salva in `layout`
## (estetico, ignorato dal motore).
class_name GeometryEditor
extends VBoxContainer

signal changed

const RINGS := 2          ## anelli mostrati (vicinato completo entro distanza 2)
const HEX_R := 21.0       ## raggio esagono in px

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

# Tipi di widget selezionabili e loro etichette.
const WIDGET_TYPES := ["combat", "movement", "kamae", "effect", "counter", "note"]
const WIDGET_TITLES := {
	"combat": "Combattimento (att./dif.)", "movement": "Movimento",
	"kamae": "Kamae richiesto", "effect": "Effetto",
	"counter": "Contrattacco", "note": "Nota",
}
const SINGLETON_TYPES := ["kamae", "counter", "note"]   # al massimo uno per carta

# Stati ciclici di un esagono di combattimento (clic per avanzare).
const CELL_CYCLE := ["empty", "w1", "w2", "exec", "bleed", "shield"]

# ─── Modello dati ────────────────────────────────────────────────────────────
var _type: String = "attack"
var _name: String = ""
var _widgets: Array = []   ## lista ordinata di widget (Dictionary con "type" + dati)
var _built := false


# ─── API pubblica ────────────────────────────────────────────────────────────

func load_geometry(card_type: String, geom: Dictionary) -> void:
	_type = card_type if card_type != "" else str(geom.get("type", "attack"))
	_name = str(geom.get("name", ""))
	_widgets = _widgets_from(geom)
	if not _built:
		_build_ui()
	else:
		_rebuild_widgets()


## Ricostruisce la lista di widget dalla geometria (raggruppa le varianti di
## combattimento per kamae; un widget Movimento per opzione; un Effetto per
## effetto; singoli per kamae/counter/note). L'ordine segue `layout` se presente.
func _widgets_from(geom: Dictionary) -> Array:
	# Varianti d'attacco e difesa (schema nuovo `attacks`/`defences` o classico).
	var atk_vars := _read_variants(geom, "attack", "attacks", "w")
	var dfn_vars := _read_variants(geom, "defence", "defences", "v")
	var kamae_keys := []
	for v in atk_vars:
		if not (v["kamae"] in kamae_keys): kamae_keys.append(v["kamae"])
	for v in dfn_vars:
		if not (v["kamae"] in kamae_keys): kamae_keys.append(v["kamae"])
	var pool := {"combat": [], "movement": [], "kamae": [], "effect": [], "counter": [], "note": []}
	for k in kamae_keys:
		var cw := {"type": "combat", "kamae": k, "attack": {}, "defence": {}}
		for v in atk_vars:
			if v["kamae"] == k: cw["attack"] = v["cells"]; break
		for v in dfn_vars:
			if v["kamae"] == k: cw["defence"] = v["cells"]; break
		pool["combat"].append(cw)
	for opt in geom.get("move", {}).get("opts", []):
		var atoms := []
		for a in opt.get("atoms", []):
			atoms.append(_norm_atom(a))
		pool["movement"].append({"type": "movement", "atoms": atoms})
	if str(geom.get("kamae_req", "")) != "":
		pool["kamae"].append({"type": "kamae", "req": str(geom["kamae_req"])})
	for e in geom.get("effects", []):
		if typeof(e) == TYPE_DICTIONARY:
			pool["effect"].append(_effect_widget(e))
	var cvals := []
	for x in geom.get("counter", []):
		cvals.append(int(x))
	if not cvals.is_empty():
		pool["counter"].append({"type": "counter", "values": cvals})
	if str(geom.get("note", "")) != "":
		pool["note"].append({"type": "note", "text": str(geom["note"])})

	# Ordina secondo `layout` (consuma dai pool per tipo), poi il resto canonico.
	var out := []
	for t in geom.get("layout", []):
		if pool.has(t) and not pool[t].is_empty():
			out.append(pool[t].pop_front())
	for t in WIDGET_TYPES:
		for w in pool[t]:
			out.append(w)
	if out.is_empty():
		out = [_new_widget("combat")]   # carta nuova: parti dal Combattimento
	return out


## Legge le varianti di combattimento: lista di { cells: {axial:val}, kamae }.
func _read_variants(geom: Dictionary, single_key: String, array_key: String, vk: String) -> Array:
	var out := []
	if geom.has(array_key):
		for v in geom[array_key]:
			if v is Dictionary:
				out.append({"cells": _cells_from(v, vk), "kamae": str(v.get("kamae", ""))})
	elif geom.get(single_key, null) != null:
		out.append({"cells": _cells_from(geom[single_key], vk), "kamae": ""})
	return out


## Serializza lo stato corrente nello Schema v2 (campi vuoti omessi).
func to_geometry() -> Dictionary:
	var g := {}
	if _name != "":
		g["name"] = _name
	g["type"] = _type

	# Kamae richiesto (primo widget kamae).
	for w in _widgets:
		if w["type"] == "kamae" and str(w.get("req", "")) != "":
			g["kamae_req"] = str(w["req"]); break

	# Movimento → opzioni (una per widget movimento con atomi).
	var opts := []
	for w in _widgets:
		if w["type"] == "movement":
			var out_atoms := []
			for a in w.get("atoms", []):
				out_atoms.append(_atom_to(a))
			if not out_atoms.is_empty():
				opts.append({"atoms": out_atoms})
	if not opts.is_empty():
		g["move"] = {"opts": opts}

	# Combattimento → varianti attacco/difesa (gated da kamae se presenti).
	var atk_vars := []
	var dfn_vars := []
	for w in _widgets:
		if w["type"] != "combat":
			continue
		var ac := _cells_to(w.get("attack", {}), "w")
		if not ac.is_empty():
			var v := {"cells": ac}
			if str(w.get("kamae", "")) != "": v["kamae"] = str(w["kamae"])
			atk_vars.append(v)
		var dc := _cells_to(w.get("defence", {}), "v")
		if not dc.is_empty():
			var v2 := {"cells": dc}
			if str(w.get("kamae", "")) != "": v2["kamae"] = str(w["kamae"])
			dfn_vars.append(v2)
	_write_variants(g, "attack", "attacks", atk_vars)
	_write_variants(g, "defence", "defences", dfn_vars)

	# Contrattacco (primo widget counter).
	for w in _widgets:
		if w["type"] == "counter" and not (w.get("values", []) as Array).is_empty():
			g["counter"] = (w["values"] as Array).duplicate(); break

	# Effetti (ogni widget effect con verbo).
	var effs := []
	for w in _widgets:
		if w["type"] == "effect" and str(w.get("do", "")) != "":
			effs.append(_effect_to(w))
	if not effs.is_empty():
		g["effects"] = effs

	# Nota (primo widget note).
	for w in _widgets:
		if w["type"] == "note" and str(w.get("text", "")) != "":
			g["note"] = str(w["text"]); break

	# Disposizione dei widget (estetica; il motore la ignora).
	var layout := []
	for w in _widgets:
		if str(w.get("type", "")) != "":
			layout.append(w["type"])
	if not layout.is_empty():
		g["layout"] = layout
	return g


## Scrive le varianti: forma classica singola (`attack`) se una sola e senza
## gate kamae, altrimenti lista `attacks`.
func _write_variants(g: Dictionary, single_key: String, array_key: String, vars: Array) -> void:
	if vars.is_empty():
		return
	if vars.size() == 1 and not vars[0].has("kamae"):
		g[single_key] = {"cells": vars[0]["cells"]}
	else:
		g[array_key] = vars


# ─── Mutatori pubblici (drag-drop / test headless) ───────────────────────────

func _first_combat() -> Dictionary:
	for w in _widgets:
		if w["type"] == "combat":
			return w
	var cw := _new_widget("combat")
	_widgets.append(cw)
	if _built:
		_rebuild_widgets()
	return cw

func set_attack_cell(q: int, r: int, w) -> void:
	_first_combat()["attack"][Vector2i(q, r)] = w
	changed.emit()

func set_defence_cell(q: int, r: int, v: int) -> void:
	_first_combat()["defence"][Vector2i(q, r)] = v
	changed.emit()

func clear_cell(q: int, r: int) -> void:
	var cw := _first_combat()
	cw["attack"].erase(Vector2i(q, r))
	cw["defence"].erase(Vector2i(q, r))
	changed.emit()

func add_opt() -> int:
	_widgets.append(_new_widget("movement"))
	if _built:
		_rebuild_widgets()
	changed.emit()
	return _widgets.size() - 1

func add_move_atom(widget_idx: int, atom: Dictionary) -> void:
	if widget_idx < 0 or widget_idx >= _widgets.size():
		return
	_widgets[widget_idx]["atoms"].append(_norm_atom(atom))
	if _built:
		_rebuild_widgets()
	changed.emit()

func add_effect(e := {}) -> void:
	_widgets.append(_effect_widget(e))
	if _built:
		_rebuild_widgets()
	changed.emit()

func set_kamae_req(slug: String) -> void:
	var kw = null
	for w in _widgets:
		if w["type"] == "kamae":
			kw = w; break
	if kw == null:
		if slug == "":
			return
		kw = _new_widget("kamae")
		_widgets.append(kw)
	kw["req"] = slug
	if _built:
		_rebuild_widgets()
	changed.emit()


# ─── Costruzione del nuovo widget e normalizzazione ──────────────────────────

func _new_widget(type: String) -> Dictionary:
	match type:
		"combat": return {"type": "combat", "kamae": "", "attack": {}, "defence": {}}
		"movement": return {"type": "movement", "atoms": []}
		"kamae": return {"type": "kamae", "req": ""}
		"effect": return _effect_widget({})
		"counter": return {"type": "counter", "values": []}
		"note": return {"type": "note", "text": ""}
	return {"type": ""}


static func _effect_widget(e: Dictionary) -> Dictionary:
	return {
		"type": "effect",
		"do": str(e.get("do", "")), "n": int(e.get("n", 0)),
		"when": str(e.get("when", "")), "kamae": str(e.get("kamae", "")),
		"to": str(e.get("to", "")), "focus_cost": int(e.get("focus_cost", 0)),
		"alt": str(e.get("alt", "")),
	}


## Normalizza un atomo di movimento (preserva dirs/kamae/focus_cost; lo step
## tiene `dirs` = direzioni scelte e `free` = passo libero, dir -1).
static func _norm_atom(a: Dictionary) -> Dictionary:
	var atom := {
		"t": str(a.get("t", "step")),
		"n": int(a.get("n", 1)),
		"opt": bool(a.get("opt", false)),
		"kamae": str(a.get("kamae", "")),
		"focus_cost": int(a.get("focus_cost", 0)),
	}
	if atom["t"] == "step":
		if a.has("dirs"):
			var ds := []
			for x in a["dirs"]:
				ds.append(int(x))
			atom["dirs"] = ds
			atom["free"] = false
		else:
			var dd := int(a.get("dir", 0))
			atom["free"] = dd == -1
			atom["dirs"] = [] if dd == -1 else [dd]
	return atom


func _atom_to(a: Dictionary) -> Dictionary:
	var atom := {"t": a["t"]}
	if a["t"] == "step":
		if bool(a.get("free", false)):
			atom["dir"] = -1
		elif (a.get("dirs", []) as Array).size() == 1:
			atom["dir"] = int(a["dirs"][0])
		elif (a.get("dirs", []) as Array).size() > 1:
			atom["dirs"] = (a["dirs"] as Array).duplicate()
		else:
			atom["dir"] = 0
	atom["n"] = int(a["n"])
	atom["opt"] = bool(a["opt"])
	if str(a.get("kamae", "")) != "":
		atom["kamae"] = str(a["kamae"])
	if int(a.get("focus_cost", 0)) > 0:
		atom["focus_cost"] = int(a["focus_cost"])
	return atom


func _effect_to(e: Dictionary) -> Dictionary:
	var ce := {"do": str(e.get("do", ""))}
	if int(e.get("n", 0)) > 0: ce["n"] = int(e["n"])
	if str(e.get("when", "")) != "": ce["when"] = str(e["when"])
	if str(e.get("kamae", "")) != "": ce["kamae"] = str(e["kamae"])
	if str(e.get("to", "")) != "": ce["to"] = str(e["to"])
	if int(e.get("focus_cost", 0)) > 0: ce["focus_cost"] = int(e["focus_cost"])
	if str(e.get("alt", "")) != "": ce["alt"] = str(e["alt"])
	return ce


# ─── Costruzione UI ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	_built = true
	add_theme_constant_override("separation", 6)
	_rebuild_widgets()


func _rebuild_widgets() -> void:
	if not _built:
		return
	for ch in get_children():
		ch.queue_free()
	for i in _widgets.size():
		add_child(_build_widget(i))
	# "+ aggiungi widget" in fondo.
	var add := Button.new()
	add.text = "+ aggiungi widget"
	add.tooltip_text = "Aggiunge un widget; scegline il tipo dal menu in cima"
	add.pressed.connect(func():
		_widgets.append(_new_widget(""))
		_rebuild_widgets()
		changed.emit())
	add_child(add)


func _build_widget(idx: int) -> Control:
	var w: Dictionary = _widgets[idx]
	var panel := PanelContainer.new()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)

	# Intestazione: selettore di TIPO + sposta su/giù + rimuovi.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 3)
	var topt := OptionButton.new()
	topt.add_theme_font_size_override("font_size", 12)
	topt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topt.add_item("(tipo…)")
	for t in WIDGET_TYPES:
		topt.add_item(str(WIDGET_TITLES[t]))
	topt.selected = WIDGET_TYPES.find(str(w.get("type", ""))) + 1
	topt.item_selected.connect(func(i): _set_widget_type(idx, "" if i == 0 else WIDGET_TYPES[i - 1]))
	head.add_child(topt)
	var up := _mini_btn("su", "Sposta su")
	up.disabled = idx == 0
	up.pressed.connect(func(): _move_widget(idx, -1))
	head.add_child(up)
	var dn := _mini_btn("giù", "Sposta giù")
	dn.disabled = idx == _widgets.size() - 1
	dn.pressed.connect(func(): _move_widget(idx, 1))
	head.add_child(dn)
	var rm := _mini_btn("x", "Rimuovi widget")
	rm.pressed.connect(func(): _widgets.remove_at(idx); _rebuild_widgets(); changed.emit())
	head.add_child(rm)
	box.add_child(head)

	box.add_child(_build_widget_body(w))
	return panel


func _mini_btn(txt: String, tip: String) -> Button:
	var b := Button.new()
	b.text = txt
	b.tooltip_text = tip
	b.add_theme_font_size_override("font_size", 11)
	return b


func _set_widget_type(idx: int, type: String) -> void:
	if type != "" and type in SINGLETON_TYPES:
		for j in _widgets.size():
			if j != idx and _widgets[j]["type"] == type:
				_rebuild_widgets()   # singleton già presente: annulla la scelta
				return
	_widgets[idx] = _new_widget(type)
	_rebuild_widgets()
	changed.emit()


func _move_widget(idx: int, delta: int) -> void:
	var j := idx + delta
	if j < 0 or j >= _widgets.size():
		return
	var tmp = _widgets[idx]
	_widgets[idx] = _widgets[j]
	_widgets[j] = tmp
	_rebuild_widgets()
	changed.emit()


func _build_widget_body(w: Dictionary) -> Control:
	match str(w.get("type", "")):
		"combat": return _build_combat_body(w)
		"movement": return _build_movement_body(w)
		"kamae": return _build_kamae_body(w)
		"effect": return _build_effect_body(w)
		"counter": return _build_counter_body(w)
		"note": return _build_note_body(w)
	var hint := Label.new()
	hint.text = "Scegli un tipo dal menu in alto."
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.66))
	return hint


# ─── Corpo: Combattimento (nido d'ape a clic-ciclo + gate kamae) ─────────────

func _build_combat_body(w: Dictionary) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	var grow := HBoxContainer.new()
	grow.add_theme_constant_override("separation", 4)
	grow.add_child(_lbl("attivo in kamae"))
	grow.add_child(_eff_opt(KAMAE_OPTS, str(w.get("kamae", "")), func(val): w["kamae"] = val))
	v.add_child(grow)
	var hint := Label.new()
	hint.text = "clic = scorri icona · clic destro = svuota"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.55, 0.6, 0.68))
	v.add_child(hint)
	v.add_child(_build_honey(w))
	return v


func _build_honey(w: Dictionary) -> Control:
	var honey := Control.new()
	honey.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var cells := HexGrid.hexes_in_range(Vector2i.ZERO, RINGS)
	var maxr := 0.0
	for ax in cells:
		maxr = maxf(maxr, _hex_pixel(ax).length())
	var side := (maxr + HEX_R) * 2.0 + 6.0
	honey.custom_minimum_size = Vector2(side, side)
	honey.size = Vector2(side, side)
	var center := Vector2(side, side) * 0.5
	for ax in cells:
		var cell := HexCell.new()
		cell.setup(self, w, ax, HEX_R, ax == Vector2i.ZERO)
		cell.position = center + _hex_pixel(ax) - Vector2(HEX_R, HEX_R)
		cell.custom_minimum_size = Vector2(2 * HEX_R, 2 * HEX_R)
		cell.size = cell.custom_minimum_size
		honey.add_child(cell)
	return honey


func _cycle_cell(cw: Dictionary, ax: Vector2i) -> void:
	var nxt := (_cell_state_index(cw, ax) + 1) % CELL_CYCLE.size()
	cw["attack"].erase(ax)
	cw["defence"].erase(ax)
	match CELL_CYCLE[nxt]:
		"w1": cw["attack"][ax] = 1
		"w2": cw["attack"][ax] = 2
		"exec": cw["attack"][ax] = "exec"
		"bleed": cw["attack"][ax] = "bleed"
		"shield": cw["defence"][ax] = 1
	changed.emit()


func _clear_cell(cw: Dictionary, ax: Vector2i) -> void:
	cw["attack"].erase(ax)
	cw["defence"].erase(ax)
	changed.emit()


func _cell_state_index(cw: Dictionary, ax: Vector2i) -> int:
	if cw["defence"].has(ax):
		return CELL_CYCLE.find("shield")
	if cw["attack"].has(ax):
		var w = cw["attack"][ax]
		if typeof(w) == TYPE_STRING:
			return maxi(1, CELL_CYCLE.find(str(w)))   # "exec" / "bleed"
		return CELL_CYCLE.find("w2") if int(w) == 2 else CELL_CYCLE.find("w1")
	return 0


# ─── Corpo: Movimento (una sequenza di atomi) ────────────────────────────────

func _build_movement_body(w: Dictionary) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	var atoms: Array = w["atoms"]
	for ai in atoms.size():
		v.add_child(_build_atom_editor(w, ai))
	var add := HBoxContainer.new()
	add.add_theme_constant_override("separation", 4)
	var ap := Button.new()
	ap.text = "+ passo"
	ap.pressed.connect(func(): atoms.append(_norm_atom({"t": "step", "dir": 0, "n": 1, "opt": false})); _rebuild_widgets(); changed.emit())
	add.add_child(ap)
	var ar := Button.new()
	ar.text = "+ rotazione"
	ar.pressed.connect(func(): atoms.append(_norm_atom({"t": "rot", "n": 1, "opt": false})); _rebuild_widgets(); changed.emit())
	add.add_child(ar)
	v.add_child(add)
	return v


func _build_atom_editor(w: Dictionary, ai: int) -> Control:
	var a: Dictionary = w["atoms"][ai]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	if a["t"] == "step":
		var ros := DirRosette.new()
		ros.setup(self, a.get("dirs", []), bool(a.get("free", false)),
			func(dirs, free): a["dirs"] = dirs; a["free"] = free; changed.emit())
		row.add_child(ros)
	else:
		var rotc := Control.new()
		rotc.custom_minimum_size = Vector2(46, 46)
		rotc.draw.connect(func(): GeometryEditor.draw_icon(rotc, "rot" if not a["opt"] else "rot_opt", Vector2(23, 23), 20.0, 1))
		row.add_child(rotc)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 3)
	r1.add_child(_lbl("passi" if a["t"] == "step" else "entità"))
	var sp := SpinBox.new()
	sp.min_value = 1; sp.max_value = 6; sp.value = a["n"]
	sp.custom_minimum_size = Vector2(54, 0)
	sp.value_changed.connect(func(val): a["n"] = int(val); changed.emit())
	r1.add_child(sp)
	var chk := CheckBox.new()
	chk.text = "facolt."
	chk.button_pressed = a["opt"]
	chk.add_theme_font_size_override("font_size", 11)
	chk.toggled.connect(func(p): a["opt"] = p; _rebuild_widgets(); changed.emit())
	r1.add_child(chk)
	var rm := Button.new()
	rm.text = "x"
	rm.pressed.connect(func(): w["atoms"].remove_at(ai); _rebuild_widgets(); changed.emit())
	r1.add_child(rm)
	col.add_child(r1)
	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 3)
	r2.add_child(_lbl("kamae"))
	r2.add_child(_eff_opt(KAMAE_OPTS, str(a.get("kamae", "")), func(val): a["kamae"] = val))
	if a["t"] == "step":
		r2.add_child(_lbl("F"))
		var fs := SpinBox.new()
		fs.min_value = 0; fs.max_value = 3; fs.value = int(a.get("focus_cost", 0))
		fs.custom_minimum_size = Vector2(48, 0)
		fs.value_changed.connect(func(val): a["focus_cost"] = int(val); changed.emit())
		r2.add_child(fs)
	col.add_child(r2)
	row.add_child(col)
	return row


# ─── Corpo: Kamae richiesto / Contrattacco / Nota / Effetto ──────────────────

func _build_kamae_body(w: Dictionary) -> Control:
	var v := VBoxContainer.new()
	var krow := HBoxContainer.new()
	krow.add_theme_constant_override("separation", 6)
	for slug in ["aggression", "balance", "determination"]:
		var tok := DragIcon.new()
		tok.setup(self, "kamae_" + slug, slug)
		tok.custom_minimum_size = Vector2(2 * HEX_R, 2 * HEX_R)
		tok.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				w["req"] = "" if str(w.get("req", "")) == slug else slug
				_rebuild_widgets(); changed.emit())
		krow.add_child(tok)
	var az := Button.new()
	az.text = "azzera"
	az.pressed.connect(func(): w["req"] = ""; _rebuild_widgets(); changed.emit())
	krow.add_child(az)
	v.add_child(krow)
	var lbl := Label.new()
	var req := str(w.get("req", ""))
	lbl.text = "richiesto: %s" % (KAMAE_LABELS.get(req, req) if req != "" else "nessuno")
	lbl.add_theme_font_size_override("font_size", 12)
	v.add_child(lbl)
	return v


func _build_counter_body(w: Dictionary) -> Control:
	var le := LineEdit.new()
	le.placeholder_text = "iniziative di contrattacco, es. 8, 6"
	le.text = ", ".join((w.get("values", []) as Array).map(func(x): return str(x)))
	le.text_changed.connect(func(t: String):
		var vals := []
		for tok in t.split(","):
			var s := tok.strip_edges()
			if s.is_valid_int(): vals.append(int(s))
		w["values"] = vals
		changed.emit())
	return le


func _build_note_body(w: Dictionary) -> Control:
	var te := TextEdit.new()
	te.custom_minimum_size = Vector2(0, 50)
	te.placeholder_text = "annotazioni / incertezze di trascrizione"
	te.text = str(w.get("text", ""))
	te.text_changed.connect(func(): w["text"] = te.text; changed.emit())
	return te


## Effetto su due righe compatte: verbo + n ; when/kamae/to/focus/alt.
func _build_effect_body(w: Dictionary) -> Control:
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
	do_opt.selected = CardValidator.EFFECT_VERBS.find(str(w.get("do", ""))) + 1
	do_opt.item_selected.connect(func(i): w["do"] = "" if i == 0 else CardValidator.EFFECT_VERBS[i - 1]; changed.emit())
	r1.add_child(do_opt)
	r1.add_child(_lbl("n"))
	r1.add_child(_eff_spin(int(w.get("n", 0)), 0, 9, func(val): w["n"] = val))
	box.add_child(r1)
	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 3)
	r2.add_child(_eff_opt(WHEN_OPTS, str(w.get("when", "")), func(val): w["when"] = val))
	r2.add_child(_eff_opt(KAMAE_OPTS, str(w.get("kamae", "")), func(val): w["kamae"] = val))
	r2.add_child(_eff_opt(KAMAE_OPTS, str(w.get("to", "")), func(val): w["to"] = val))
	r2.add_child(_lbl("F"))
	r2.add_child(_eff_spin(int(w.get("focus_cost", 0)), 0, 3, func(val): w["focus_cost"] = val))
	var alt := LineEdit.new()
	alt.custom_minimum_size = Vector2(34, 0)
	alt.placeholder_text = "alt"
	alt.text = str(w.get("alt", ""))
	alt.text_changed.connect(func(t): w["alt"] = t.strip_edges(); changed.emit())
	r2.add_child(alt)
	box.add_child(r2)
	return box


# ─── Helper widget ───────────────────────────────────────────────────────────

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


# ─── Geometria del nido d'ape ────────────────────────────────────────────────

## Posizione in px (centro del controllo) di un esagono assiale. Esagoni a LATO
## PIATTO IN ALTO, col FRONTE (DIRS[0]) verso l'alto: reticolo lineare nelle
## coordinate assiali, screen = q·Sq + r·Sr con basi orientate a Nord.
static func _hex_pixel(ax: Vector2i) -> Vector2:
	var d := HEX_R * 1.78
	var sq := Vector2(0.0, -d)
	var sr := Vector2(-0.8660254 * d, -0.5 * d)
	return sq * ax.x + sr * ax.y


## Versore schermo della direzione `d` (0..5), col fronte (DIRS[0]) verso l'alto.
static func _dir_screen(d: int) -> Vector2:
	return _hex_pixel(HexGrid.DIRS[d % 6]).normalized()


# ─── Conversione celle dict ↔ schema ─────────────────────────────────────────

## Legge le celle in coordinate assiali (q,r). Accetta lo schema nuovo {q,r,...}
## e quello legacy a 6 direzioni {d,k,...} (convertito: DIRS[d]*k).
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


# ─── Inner class: esagono di combattimento (clic-ciclo sui dati del widget) ──

class HexCell extends Control:
	var ed: GeometryEditor
	var cw: Dictionary   ## widget combattimento di appartenenza
	var ax: Vector2i
	var r: float
	var is_pawn: bool

	func setup(editor: GeometryEditor, combat_widget: Dictionary, axial: Vector2i, rr: float, pawn: bool) -> void:
		ed = editor; cw = combat_widget; ax = axial; r = rr; is_pawn = pawn
		mouse_filter = Control.MOUSE_FILTER_STOP
		tooltip_text = "pedina" if pawn else "q %d · r %d · dist %d" % [ax.x, ax.y, _hex_dist(ax)]

	static func _hex_dist(a: Vector2i) -> int:
		return (absi(a.x) + absi(a.y) + absi(a.x + a.y)) / 2

	func _draw() -> void:
		var c := Vector2(r, r)
		var atk = null
		var dfn = null
		if not is_pawn:
			atk = cw.get("attack", {}).get(ax, null)
			dfn = cw.get("defence", {}).get(ax, null)
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

	## Clic sinistro = avanza il ciclo; clic destro = svuota.
	func _gui_input(event: InputEvent) -> void:
		if is_pawn or not (event is InputEventMouseButton and event.pressed):
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			ed._cycle_cell(cw, ax)
			queue_redraw()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			ed._clear_cell(cw, ax)
			queue_redraw()


# ─── Inner class: icona disegnata (token kamae) ──────────────────────────────

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


# ─── Inner class: rosetta direzioni del passo (6 direzioni + libero) ─────────

## Mostra le 6 direzioni attorno alla pedina (fronte in alto): clic per
## attivare/disattivare. Il centro = passo LIBERO (dir -1). Chiama
## on_change(dirs: Array, free: bool) a ogni modifica.
class DirRosette extends Control:
	var ed: GeometryEditor
	var dirs: Array = []
	var free: bool = false
	var on_change: Callable
	const RAD := 17.0

	func setup(editor: GeometryEditor, initial_dirs: Array, is_free: bool, cb: Callable) -> void:
		ed = editor
		dirs = (initial_dirs as Array).duplicate()
		free = is_free
		on_change = cb
		custom_minimum_size = Vector2(86, 86)
		mouse_filter = Control.MOUSE_FILTER_STOP
		tooltip_text = "Clic: attiva/disattiva direzione. Centro = passo libero."

	func _draw() -> void:
		var c := size * 0.5
		var ccol := GeometryEditor.COL_PAWN if free else Color(0.30, 0.30, 0.36)
		draw_circle(c, 9.0, ccol)
		var tri := PackedVector2Array([c + Vector2(0, -5), c + Vector2(-5, 4), c + Vector2(5, 4)])
		draw_colored_polygon(tri, Color(0.1, 0.1, 0.1) if free else Color(0.7, 0.7, 0.75))
		var font := ThemeDB.fallback_font
		for d in range(6):
			var p := c + GeometryEditor._dir_screen(d) * RAD * 1.7
			var on := d in dirs and not free
			draw_circle(p, 8.0, Color(0.40, 0.62, 0.95) if on else Color(0.24, 0.24, 0.30))
			draw_arc(p, 8.0, 0, TAU, 16, Color(0.5, 0.5, 0.55), 1.0)
			if font:
				var s := str(d)
				var sz := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
				draw_string(font, p - sz * 0.5 + Vector2(0, sz.y * 0.35), s,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE if on else Color(0.7, 0.7, 0.75))

	func _gui_input(event: InputEvent) -> void:
		if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			return
		var c := size * 0.5
		if event.position.distance_to(c) <= 11.0:
			free = not free
		else:
			var best := -1
			var bestd := 14.0
			for d in range(6):
				var p := c + GeometryEditor._dir_screen(d) * RAD * 1.7
				var dist: float = event.position.distance_to(p)
				if dist < bestd:
					bestd = dist; best = d
			if best == -1:
				return
			free = false
			if best in dirs:
				dirs.erase(best)
			else:
				dirs.append(best)
				dirs.sort()
		queue_redraw()
		on_change.call(dirs.duplicate(), free)
