extends Control
## Editor delle carte: la scansione a sinistra, a destra la carta riga per riga
## (come è stampata) e sotto il testo di come il gioco la applica.

const COND := [["", "Sempre"], ["aggression", "Aggressione"], ["balance", "Equilibrio"],
	["determination", "Determinazione"], ["balance|determination", "Equilibrio o Determ."],
	["f1", "Costo 1 focus"], ["f2", "Costo 2 focus"], ["o", "Occultato"], ["f1o", "1 focus + Occultato"], ["D", "Disperazione"]]
const TIPI := [["move", "Movimento"], ["atk", "Griglia d'attacco"], ["blk", "Griglia di blocco"],
	["fx", "Effetto"], ["ast", "Asterisco ="], ["ifs", "SE RIUSCITO:"], ["or", "— OPPURE —"],
	["div", "Divisore: nuova iniziativa"], ["alt", "Iniziativa alternativa"],
	["counter", "Contrattacco"], ["mod", "Ferite sanguinanti"], ["unblockable", "NON BLOCCABILE"], ["ranged", "Attacco a distanza"]]
const DIREZ := [["", "nessun passo"], ["0", "Fronte"], ["3", "Retro"], ["501", "Ventaglio avanti"],
	["432", "Ventaglio indietro"], ["51", "Diagonali avanti"], ["42", "Diagonali indietro"], ["513", "A ipsilon"], ["1245", "Quattro diagonali"], ["54", "Lato sinistro"],
	["01", "Fronte o Fronte-Dx"], ["012345", "Qualsiasi direzione"]]
const EFF := ["discard", "draw", "draw_exact", "focus", "lose_focus_all", "lose_focus_all_but", "switch",
	"change", "push", "t_stun", "t_hobble", "t_rot", "t_lose_focus", "t_switch", "t_discard_type",
	"self_stun", "self_hobble", "t_wound", "t_wound_to_bleed", "search", "reshuffle", "cancel_cards",
	"each_stun", "cancel_move", "advantage", "add_wound", "armour", "broad_block",
	"ai_change", "ai_reset", "ai_recycle", "t_discard", "search_discard", "search_top", "discard_stun",
	"bleed_to_wound", "view_hand", "steal_focus", "swap", "t_step", "nota", "all_draw", "t_poison",
	"t_draw", "pull_or_push", "conceal", "t_mill_wounds", "cancel_rot", "add_bleed", "illum_search", "search_illum", "wounds_to_stun", "discard_hobble", "t_stun_per_step", "push_steps", "contract_back", "lavoro_finito", "t_discard_rand", "self_wound", "draw_return", "search_stun"]
const CICLO_ATK := ["", "w1", "w2", "w3", "b", "x", "a", "w1a", "ba", "p", "pa"]
const SIGLE := {"w1": "1", "w2": "2", "b": "S", "x": "X", "a": "*", "w1a": "1*", "ba": "S*", "s": "B", "p": "V", "pa": "V*", "sa": "B*", "w3": "3"}
const CELLE := ["0", "1", "2", "3", "4", "5", "00", "01", "11", "12", "22", "23", "33", "34", "44", "45", "55", "50"]
const KAM := [["aggression", "Aggressione"], ["balance", "Equilibrio"], ["determination", "Determinazione"],
	["neutral", "Neutrale"], ["any", "qualsiasi"]]

var db: Dictionary
var ids: Array = []
var cur: Dictionary = {}
var righe: Array = []
var lista: ItemList
var img: TextureRect
var testo: RichTextLabel
var box_righe: VBoxContainer
var box_testa: HFlowContainer
var stato: Label


func _ready() -> void:
	theme = Tema.tema()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sf := ColorRect.new()
	sf.color = Tema.CARTA_SCURA
	sf.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sf)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for l in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + l, 10)
	add_child(m)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	m.add_child(h)
	# colonna 1: elenco
	var c1 := VBoxContainer.new()
	c1.custom_minimum_size = Vector2(250, 0)
	h.add_child(c1)
	c1.add_child(Tema.etichetta("Carte", 26, Tema.VERMIGLIO, true))
	lista = ItemList.new()
	lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lista.add_theme_font_size_override("font_size", 18)
	lista.add_theme_color_override("font_color", Tema.INCHIOSTRO)
	lista.add_theme_color_override("font_selected_color", Color.WHITE)
	lista.add_theme_stylebox_override("panel", Tema.riquadro(Tema.CARTA, Tema.INCHIOSTRO, 2, 6, 4, 4))
	lista.add_theme_stylebox_override("selected", Tema.riquadro(Tema.VERMIGLIO, Tema.VERMIGLIO, 0, 4, 4, 2))
	lista.add_theme_stylebox_override("selected_focus", Tema.riquadro(Tema.VERMIGLIO, Tema.VERMIGLIO, 0, 4, 4, 2))
	lista.item_selected.connect(func(i): _apri(ids[i]))
	c1.add_child(lista)
	var bm := Tema.bottone("Torna al menu", 200)
	bm.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Menu.tscn"))
	c1.add_child(bm)
	# colonna 2: scansione + interpretazione
	var c2 := VBoxContainer.new()
	c2.custom_minimum_size = Vector2(350, 0)
	h.add_child(c2)
	img = TextureRect.new()
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.custom_minimum_size = Vector2(350, 488)
	c2.add_child(img)
	c2.add_child(Tema.etichetta("Come la applica il gioco", 18, Tema.VERMIGLIO, true))
	var pt := PanelContainer.new()
	pt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c2.add_child(pt)
	testo = RichTextLabel.new()
	testo.custom_minimum_size = Vector2(330, 120)
	pt.add_child(testo)
	# colonna 3: editor
	var c3 := VBoxContainer.new()
	c3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c3.custom_minimum_size = Vector2(520, 0)
	h.add_child(c3)
	box_testa = HFlowContainer.new()
	box_testa.add_theme_constant_override("h_separation", 8)
	c3.add_child(box_testa)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	c3.add_child(sc)
	box_righe = VBoxContainer.new()
	box_righe.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box_righe.add_theme_constant_override("separation", 6)
	sc.add_child(box_righe)
	var piede := HFlowContainer.new()
	piede.add_theme_constant_override("h_separation", 8)
	c3.add_child(piede)
	for d in [["Aggiungi riga", _aggiungi], ["Salva la carta", _salva], ["Annulla modifiche", func(): _apri(int(cur.id))],
			["Copia tutte le carte (JSON)", _copia], ["Ripristina le carte originali", _ripristina]]:
		var b := Tema.bottone(d[0], 170)
		b.pressed.connect(d[1])
		piede.add_child(b)
	stato = Tema.etichetta("", 18, Tema.VERMIGLIO)
	stato.custom_minimum_size = Vector2(300, 0)
	c3.add_child(stato)
	_carica()


func _carica() -> void:
	Carte.ricarica()
	db = Carte.db()
	ids = []
	for k in db.cards:
		ids.append(int(k))
	ids.sort()
	lista.clear()
	for id in ids:
		lista.add_item("%03d  %s" % [id, db.cards[str(id)].name])
	lista.select(0)
	_apri(ids[0])


# ─────────────────────────── carta <-> righe ───────────────────────────

func _cond_di(l: Dictionary) -> String:
	if l.has("f"):
		return "f%d%s" % [int(l.f), "o" if l.get("o", false) else ""]
	if l.get("o", false):
		return "o"
	if l.get("d", false):
		return "D"
	if l.has("k"):
		return "|".join(l.k) if l.k is Array else str(l.k)
	return ""


func _riga_da(l: Dictionary) -> Dictionary:
	var r: Dictionary = l.duplicate(true)
	r.tipo = l.t
	if l.t == "grid":
		r.tipo = l.mode
	r.cond = _cond_di(l)
	return r


func _apri(id: int) -> void:
	cur = db.cards[str(id)].duplicate(true)
	righe = []
	for si in cur.segs.size():
		var s: Dictionary = cur.segs[si]
		if s.has("init"):
			righe.append({"tipo": "div", "v": s.init, "cond": ""})
		var pend: Dictionary = {}
		for l in s.lines:
			if l.t == "or":
				for oi in l.opts.size():
					if oi > 0:
						righe.append({"tipo": "or", "cond": ""})
					for li in l.opts[oi].size():
						var rr := _riga_da(l.opts[oi][li])
						if li > 0:
							rr["lega"] = true
						righe.append(rr)
			elif l.t == "move" and l.parts.size() == 1 and not pend.is_empty() and false:
				pass
			else:
				righe.append(_riga_da(l))
	img.texture = load("res://assets/cards/" + cur.img)
	stato.text = ""
	_testa()
	_disegna()


func _linea_da(r: Dictionary) -> Dictionary:
	var l := {}
	match r.tipo:
		"move":
			l = {"t": "move", "parts": r.get("parts", [])}
		"atk", "blk":
			l = {"t": "grid", "mode": r.tipo, "cells": r.get("cells", {})}
			if r.has("ak"):
				l["ak"] = r.ak
			if r.get("retro", false):
				l["retro"] = true
			if r.get("ad", false):
				l["ad"] = true
		"fx", "ast":
			l = {"t": r.tipo, "fx": r.get("fx", [])}
		"ranged":
			l = {"t": "ranged", "eff": r.get("eff", "w1"), "r": r.get("r", 1)}
			if r.has("fx"):
				l["fx"] = r.fx
		"alt":
			l = {"t": "alt", "v": int(r.get("v", 1))}
		"counter":
			l = {"t": "counter", "v": r.get("v", [])}
		_:
			l = {"t": r.tipo}
	var c: String = r.get("cond", "")
	if c == "D":
		l["d"] = true
		c = ""
	if c.ends_with("o"):
		l["o"] = true
		c = c.trim_suffix("o")
	if c.begins_with("f"):
		l["f"] = int(c.substr(1))
	elif c.contains("|"):
		l["k"] = Array(c.split("|"))
	elif c != "":
		l["k"] = c
	return l


func _componi() -> void:
	var segs: Array = [{"lines": []}]
	var aggancia := false
	for r in righe:
		var linee: Array = segs[-1].lines
		if r.tipo == "div":
			segs.append({"lines": [], "init": r.get("v", 1)})
			aggancia = false
		elif r.tipo == "or":
			if not linee.is_empty():
				var ult: Dictionary = linee.pop_back()
				if ult.t == "_g":
					ult = {"t": "or", "opts": [ult.ls]}
				elif ult.t != "or":
					ult = {"t": "or", "opts": [[ult]]}
				linee.append(ult)
				aggancia = true
		else:
			var l := _linea_da(r)
			if aggancia:
				linee[-1].opts.append([l])
				aggancia = false
			elif r.get("lega", false) and not linee.is_empty() and linee[-1].t == "or":
				linee[-1].opts[-1].append(l)
			elif r.get("lega", false) and not linee.is_empty() and linee[-1].t == "_g":
				linee[-1].ls.append(l)
			elif r.get("lega", false) and not linee.is_empty():
				linee.append({"t": "_g", "ls": [linee.pop_back(), l]})
			else:
				linee.append(l)
	for sg in segs:
		var piatte: Array = []
		for l in sg.lines:
			if l.t == "_g":
				piatte.append_array(l.ls)
			else:
				piatte.append(l)
		sg.lines = piatte
	cur.segs = segs
	testo.text = Carte.testo(cur)


# ─────────────────────────── interfaccia ───────────────────────────

func _opzione(voci: Array, valore: String, larg: int, su_cambio: Callable) -> OptionButton:
	var o := OptionButton.new()
	o.custom_minimum_size = Vector2(larg, 40)
	o.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	o.add_theme_font_size_override("font_size", 18)
	for i in voci.size():
		o.add_item(voci[i][1])
		if voci[i][0] == valore:
			o.select(i)
	o.item_selected.connect(func(i): su_cambio.call(voci[i][0]))
	return o


func _numero(v: int, minimo: int, massimo: int, su_cambio: Callable) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = minimo
	s.max_value = massimo
	s.value = v
	s.custom_minimum_size = Vector2(84, 40)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.value_changed.connect(func(x): su_cambio.call(int(x)))
	return s


func _campo(nome: String, w: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_child(Tema.etichetta(nome, 18))
	h.add_child(w)
	return h


func _testa() -> void:
	for c in box_testa.get_children():
		box_testa.remove_child(c)
		c.queue_free()
	var le := LineEdit.new()
	le.text = Carte.iniz_testo(cur)
	le.custom_minimum_size = Vector2(70, 40)
	le.text_changed.connect(func(t: String):
		if t.contains("-"):
			var p := t.split("-")
			cur.init = [int(p[0]), int(p[1])]
		elif t == "=":
			cur.init = "="
		elif t.is_valid_int():
			cur.init = int(t)
		_componi())
	box_testa.add_child(Tema.etichetta("%03d %s" % [int(cur.id), cur.name], 22, Tema.INCHIOSTRO, true))
	box_testa.add_child(_campo("Iniziativa", le))
	box_testa.add_child(_campo("Costo focus", _numero(int(cur.focus), 0, 3, func(v): cur.focus = v; _componi())))
	box_testa.add_child(_campo("Tipo", _opzione([["attack", "Attacco"], ["defence", "Difesa"], ["meditation", "Meditazione"], ["core", "Speciale"]],
		cur.type, 150, func(v): cur.type = v; _componi())))
	box_testa.add_child(_campo("Richiede", _opzione([["", "nessuna Kamae"]] + KAM.slice(0, 3), "|".join(cur.req) if cur.get("req", "") is Array else cur.get("req", ""), 170,
		func(v):
			if v == "":
				cur.erase("req")
			else:
				cur.req = v
			_componi())))
	box_testa.add_child(_campo("Istantanea", _opzione([["", "no"], ["rep", "Sostituzione"], ["add", "Aggiunta"]], cur.get("instant", ""), 150,
		func(v):
			if v == "":
				cur.erase("instant")
			else:
				cur.instant = v
			_componi())))


func _disegna() -> void:
	for c in box_righe.get_children():
		box_righe.remove_child(c)
		c.queue_free()
	for i in righe.size():
		box_righe.add_child(_widget_riga(i))
	_componi()


func _widget_riga(i: int) -> Control:
	var r: Dictionary = righe[i]
	var pan := PanelContainer.new()
	var colori := {"aggression": Color("f3c3ae"), "balance": Color("c9dcc0"), "determination": Color("f5dc9a"),
		"f1": Color("dcc3e6"), "f2": Color("dcc3e6")}
	pan.add_theme_stylebox_override("panel", Tema.riquadro(colori.get(r.get("cond", "").split("|")[0], Tema.CARTA), Tema.INCHIOSTRO, 1, 6, 8, 6))
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 6)
	pan.add_child(f)
	f.add_child(_opzione(TIPI, r.tipo, 210, func(v): _cambia_tipo(i, v)))
	if not ["ifs", "or", "div", "unblockable"].has(r.tipo):
		f.add_child(_opzione(COND, r.get("cond", ""), 185, func(v): r.cond = v; _disegna()))
	match r.tipo:
		"move":
			var st := {"m": "step", "dirs": [], "n": 1, "opt": true}
			var ro := {"m": "rot", "n": 0, "opt": true}
			for p in r.get("parts", []):
				if p.m == "step":
					st = p
				else:
					ro = p
			var chiave := ""
			for d in st.dirs:
				chiave += str(int(d))
			var agg := func():
				var parts: Array = []
				if not st.dirs.is_empty():
					parts.append(st)
				if int(ro.n) > 0:
					parts.append(ro)
				r.parts = parts
				_componi()
			f.add_child(_campo("Passo", _opzione(DIREZ, _trova_dir(chiave), 200, func(v: String):
				var a: Array = []
				for ch in v:
					a.append(int(ch))
				st.dirs = a
				agg.call())))
			f.add_child(_numero(int(st.n), 1, 3, func(v): st.n = v; agg.call()))
			f.add_child(_spunta("obbligatorio", not st.opt, func(v): st.opt = not v; agg.call()))
			f.add_child(_campo("Rotazione", _numero(int(ro.n), 0, 3, func(v): ro.n = v; agg.call())))
			f.add_child(_spunta("obbligatoria", not ro.opt, func(v): ro.opt = not v; agg.call()))
		"atk", "blk":
			if not r.has("cells"):
				r.cells = {}
			var gr := Control.new()
			gr.custom_minimum_size = Vector2(230, 200)
			gr.draw.connect(_disegna_griglia.bind(gr, r))
			gr.gui_input.connect(_tocco_griglia.bind(gr, r))
			f.add_child(gr)
			f.add_child(Tema.etichetta("Tocca un esagono per cambiarlo.\n1, 2 = ferite · S = sanguinante\nX = esecuzione · * = asterisco\nB = blocco" , 16))
		"fx", "ast":
			if not r.has("fx") or r.fx.is_empty():
				r.fx = [{"v": "draw", "n": 1}]
			for k in r.fx.size():
				f.add_child(_widget_effetto(r, k))
			var piu := Tema.bottone("+ effetto", 100)
			piu.pressed.connect(func(): r.fx.append({"v": "focus", "n": 1}); _disegna())
			f.add_child(piu)
		"alt", "div":
			if r.get("v", 1) is Array:
				f.add_child(Tema.etichetta("Iniziativa %d-%d" % [int(r.v[0]), int(r.v[1])], 18))
			else:
				f.add_child(_campo("Iniziativa", _numero(int(r.get("v", 1)), 0, 9, func(v): r.v = v; _componi())))
		"counter":
			var le := LineEdit.new()
			var a2: Array = []
			for v in r.get("v", []):
				a2.append(str(int(v)))
			le.text = ",".join(a2)
			le.custom_minimum_size = Vector2(120, 40)
			le.text_changed.connect(func(t: String):
				var a3: Array = []
				for p in t.split(",", false):
					if p.strip_edges().is_valid_int():
						a3.append(int(p))
				r.v = a3
				_componi())
			f.add_child(_campo("alle iniziative", le))
	if ["move", "fx"].has(r.tipo):
		var bl := Tema.bottone("", 150)
		bl.toggle_mode = true
		bl.button_pressed = r.get("lega", false)
		bl.text = "unita alla riga sopra" if r.get("lega", false) else "riga a sé"
		bl.toggled.connect(func(x: bool):
			r["lega"] = x
			_disegna())
		f.add_child(bl)
	for d in [["Su", -1], ["Giù", 1]]:
		var b := Tema.bottone(d[0], 56)
		b.pressed.connect(_sposta.bind(i, d[1]))
		f.add_child(b)
	var bx := Tema.bottone("Togli", 70)
	bx.pressed.connect(func(): righe.remove_at(i); _disegna())
	f.add_child(bx)
	return pan


func _trova_dir(chiave: String) -> String:
	for d in DIREZ:
		if d[0].length() == chiave.length():
			var tutti := true
			for ch in chiave:
				if not d[0].contains(ch):
					tutti = false
			if tutti:
				return d[0]
	return ""


func _spunta(t: String, v: bool, su: Callable) -> Button:
	var c := Tema.bottone("", 150)
	c.toggle_mode = true
	c.button_pressed = v
	c.text = t.to_upper() if v else "facoltativo"
	c.toggled.connect(func(x: bool):
		c.text = t.to_upper() if x else "facoltativo"
		su.call(x))
	return c


func _widget_effetto(r: Dictionary, k: int) -> Control:
	var e: Dictionary = r.fx[k]
	var h := HBoxContainer.new()
	var voci: Array = []
	for v in EFF:
		var es := {"v": v, "n": 1, "to": "aggression", "type": "defence", "rank": "Wood"}
		voci.append([v, Carte.effetto(es).replace(" 1 ", " N ").replace("+1", "+N").left(34)])
	h.add_child(_opzione(voci, e.v, 300, func(v): e.v = v; _disegna()))
	if ["discard", "draw", "draw_exact", "focus", "lose_focus_all_but", "change", "push", "t_rot", "t_lose_focus", "t_wound", "add_wound", "t_discard_type", "t_discard"].has(e.v):
		h.add_child(_numero(int(e.get("n", 1)), 1, 5, func(v): e.n = v; _componi()))
	if e.v == "switch" or e.v == "t_switch":
		h.add_child(_opzione(KAM, e.get("to", "aggression"), 160, func(v): e.to = v; _componi()))
		if not e.has("to"):
			e.to = "aggression"
	if e.v == "t_discard_type" and not e.has("type"):
		e.type = "defence"
	if ["search", "search_discard", "t_discard_type"].has(e.v):
		h.add_child(_opzione([["", "qualsiasi tipo"], ["attack", "Attacco"], ["defence", "Difesa"], ["meditation", "Meditazione"]], e.get("type", ""), 150,
			func(v):
				if v == "":
					e.erase("type")
				else:
					e.type = v
				_componi()))
	if e.v == "search" or e.v == "search_discard":
		if not e.has("rank"):
			e.rank = "Wood"
		var rk: String = "|".join(e.rank) if e.rank is Array else str(e.rank)
		h.add_child(_opzione([["Wood", "Legno"], ["Steel", "Acciaio"], ["Gold", "Oro"], ["Jade", "Giada"], ["Wood|Steel", "Legno o Acciaio"]], rk, 150,
			func(v: String):
				e.rank = Array(v.split("|")) if v.contains("|") else v
				_componi()))
	if r.fx.size() > 1:
		var bx := Tema.bottone("x", 40)
		bx.pressed.connect(func(): r.fx.remove_at(k); _disegna())
		h.add_child(bx)
	return h


func _centro_cella(c: Control, path: String) -> Vector2:
	var p := Hex.centro(Hex.walk(Vector2i.ZERO, 0, path), 26.0)
	return c.size / 2.0 + p + Vector2(0, 10)


func _disegna_griglia(c: Control, r: Dictionary) -> void:
	for path in [""] + CELLE:
		var p := _centro_cella(c, path)
		var pts := PackedVector2Array()
		for k in 7:
			pts.append(p + Vector2(cos(deg_to_rad(60.0 * k)), sin(deg_to_rad(60.0 * k))) * 24.0)
		var eff: String = r.cells.get(path, "")
		if path == "":
			c.draw_colored_polygon(pts, Tema.INCHIOSTRO)
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -12), p + Vector2(10, 9), p + Vector2(-10, 9)]), Tema.ORO)
			continue
		if eff != "":
			c.draw_colored_polygon(pts, Color("9db7e0") if eff == "s" else Color("e8a090"))
		c.draw_polyline(pts, Tema.INCHIOSTRO, 2.0)
		if eff != "":
			var s: String = SIGLE.get(eff, eff)
			c.draw_string(Tema.grassetto, p + Vector2(-20, 7), s, HORIZONTAL_ALIGNMENT_CENTER, 40, 20, Tema.INCHIOSTRO)


func _tocco_griglia(ev: InputEvent, c: Control, r: Dictionary) -> void:
	if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	for path in CELLE:
		if _centro_cella(c, path).distance_to(ev.position) < 21.0:
			var eff: String = r.cells.get(path, "")
			var nuovo := ""
			if r.tipo == "blk":
				nuovo = "" if eff == "s" else "s"
			else:
				nuovo = CICLO_ATK[(CICLO_ATK.find(eff) + 1) % CICLO_ATK.size()]
			if nuovo == "":
				r.cells.erase(path)
			else:
				r.cells[path] = nuovo
			c.queue_redraw()
			_componi()
			return


func _cambia_tipo(i: int, v: String) -> void:
	righe[i] = {"tipo": v, "cond": righe[i].get("cond", "")}
	_disegna()


func _sposta(i: int, d: int) -> void:
	var j := i + d
	if j < 0 or j >= righe.size():
		return
	var t = righe[i]
	righe[i] = righe[j]
	righe[j] = t
	_disegna()


func _aggiungi() -> void:
	righe.append({"tipo": "fx", "cond": "", "fx": [{"v": "draw", "n": 1}]})
	_disegna()


func _salva() -> void:
	_componi()
	var tutto: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"user://carte.json" if FileAccess.file_exists("user://carte.json") else "res://data/carte.json"))
	tutto.cards[str(int(cur.id))] = cur.duplicate(true)
	var fa := FileAccess.open("user://carte.json", FileAccess.WRITE)
	fa.store_string(JSON.stringify(tutto, " "))
	fa.close()
	Carte.ricarica()
	db = Carte.db()
	stato.text = "Carta salvata: le prossime partite usano questa versione."


func _copia() -> void:
	var p := "user://carte.json" if FileAccess.file_exists("user://carte.json") else "res://data/carte.json"
	DisplayServer.clipboard_set(FileAccess.get_file_as_string(p))
	stato.text = "JSON di tutte le carte copiato negli appunti (da incollare in data/carte.json)."


func _ripristina() -> void:
	if FileAccess.file_exists("user://carte.json"):
		DirAccess.remove_absolute("user://carte.json")
	_carica()
	stato.text = "Carte originali ripristinate."
