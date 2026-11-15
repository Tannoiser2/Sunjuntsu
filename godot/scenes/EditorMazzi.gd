extends Control
## Editor dei mazzi: a sinistra le carte che il personaggio può usare (firma + base), a destra il
## mazzo con i conteggi e le regole di costruzione. Il mazzo salvato si può usare in partita al posto
## di quello base.

const ORDINE := ["warrior", "ronin", "student", "master", "assassin", "monk", "yasuke", "yojimbo",
	"wakou", "onna", "sailor", "ashigaru", "ninja"]
const FILTRI_TIPO := [["", "Tutti i tipi"], ["attack", "Attacco"], ["defence", "Difesa"], ["meditation", "Meditazione"]]
const FILTRI_RANGO := [["", "Tutti i ranghi"], ["Wood", "Legno"], ["Steel", "Acciaio"], ["Gold", "Oro"], ["Jade", "Giada"]]
const FILTRI_FONTE := [["", "Firma e base"], ["firma", "Solo firma"], ["base", "Solo base"]]
const CARTA := Vector2(118, 165)

var k := "warrior"
var mazzo: Dictionary = {}       ## {"deck": {id: n}, "armi": [id], "dim": 30, "attivo": bool}
var modificato := false
var griglia: GridContainer
var lista: VBoxContainer
var lbl_conti: Label
var lbl_errori: Label
var box_armi: HFlowContainer
var scelta_pers: OptionButton
var scelta_dim: OptionButton
var f_tipo: OptionButton
var f_rango: OptionButton
var f_fonte: OptionButton
var usa: Button
var tex_cache: Dictionary = {}


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
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	m.add_child(v)
	# barra in alto
	var testa := HFlowContainer.new()
	testa.add_theme_constant_override("h_separation", 8)
	testa.add_theme_constant_override("v_separation", 6)
	v.add_child(testa)
	testa.add_child(Tema.etichetta("Editor dei mazzi", 26, Tema.VERMIGLIO, true))
	scelta_pers = OptionButton.new()
	scelta_pers.custom_minimum_size = Vector2(200, 46)
	for c in ORDINE:
		scelta_pers.add_item(Carte.db().characters[c].name)
	scelta_pers.item_selected.connect(func(i): _cambia_pers(ORDINE[i]))
	testa.add_child(scelta_pers)
	scelta_dim = OptionButton.new()
	scelta_dim.custom_minimum_size = Vector2(170, 46)
	scelta_dim.add_item("30 carte")
	scelta_dim.add_item("40 carte (torneo)")
	scelta_dim.item_selected.connect(func(i):
		mazzo["dim"] = 30 if i == 0 else 40
		_tocca())
	testa.add_child(scelta_dim)
	for d in [["Mazzo base", _riparti], ["Svuota", _svuota_mazzo], ["Salva", _salva], ["Menu", _esci]]:
		var b := Tema.bottone(d[0], 110)
		b.pressed.connect(d[1])
		testa.add_child(b)
	# armi
	box_armi = HFlowContainer.new()
	box_armi.add_theme_constant_override("h_separation", 6)
	box_armi.add_theme_constant_override("v_separation", 6)
	v.add_child(box_armi)
	# corpo
	var h := HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_theme_constant_override("separation", 10)
	v.add_child(h)
	var sx := VBoxContainer.new()
	sx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sx.add_theme_constant_override("separation", 6)
	h.add_child(sx)
	var filtri := HFlowContainer.new()
	filtri.add_theme_constant_override("h_separation", 6)
	sx.add_child(filtri)
	f_fonte = _filtro(filtri, FILTRI_FONTE)
	f_tipo = _filtro(filtri, FILTRI_TIPO)
	f_rango = _filtro(filtri, FILTRI_RANGO)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sx.add_child(sc)
	griglia = GridContainer.new()
	griglia.add_theme_constant_override("h_separation", 8)
	griglia.add_theme_constant_override("v_separation", 8)
	sc.add_child(griglia)
	# destra: il mazzo
	var dx := PanelContainer.new()
	dx.custom_minimum_size = Vector2(290, 0)
	h.add_child(dx)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 6)
	dx.add_child(dv)
	lbl_conti = Tema.etichetta("", 19, Tema.INCHIOSTRO)
	lbl_conti.custom_minimum_size = Vector2(266, 0)
	lbl_conti.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(lbl_conti)
	var sc2 := ScrollContainer.new()
	sc2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc2.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dv.add_child(sc2)
	lista = VBoxContainer.new()
	lista.custom_minimum_size = Vector2(266, 0)
	lista.add_theme_constant_override("separation", 2)
	sc2.add_child(lista)
	lbl_errori = Tema.etichetta("", 16, Tema.VERMIGLIO)
	lbl_errori.custom_minimum_size = Vector2(266, 0)
	lbl_errori.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(lbl_errori)
	usa = Tema.bottone("", 266)
	usa.toggle_mode = true
	usa.toggled.connect(func(on):
		mazzo["attivo"] = on
		modificato = true
		_aggiorna_conti())
	dv.add_child(usa)
	get_viewport().size_changed.connect(_colonne)
	var iniz: String = Sessione.setup.get("io", "warrior")
	scelta_pers.select(ORDINE.find(iniz))
	_cambia_pers(iniz)


func _filtro(dove: Control, voci: Array) -> OptionButton:
	var o := OptionButton.new()
	o.custom_minimum_size = Vector2(170, 44)
	for x in voci:
		o.add_item(x[1])
	o.item_selected.connect(func(_i): _riempi_griglia())
	dove.add_child(o)
	return o


func _colonne() -> void:
	var w: float = get_viewport().get_visible_rect().size.x - 20.0 - 300.0 - 20.0
	griglia.columns = maxi(2, int((w + 8.0) / (CARTA.x + 8.0)))


func _cambia_pers(nuovo: String) -> void:
	k = nuovo
	var salvato: Dictionary = Mazzi.carica().get(k, {})
	mazzo = salvato.duplicate(true) if not salvato.is_empty() else Mazzi.base(k)
	if not mazzo.has("attivo"):
		mazzo["attivo"] = false
	scelta_dim.select(0 if int(mazzo.get("dim", 30)) == 30 else 1)
	usa.set_pressed_no_signal(mazzo.attivo)
	modificato = false
	_colonne()
	_armi()
	_riempi_griglia()
	_aggiorna_conti()


func _armi() -> void:
	for c in box_armi.get_children():
		c.queue_free()
	var cd: Dictionary = Carte.db().characters[k]
	var n: int = int(cd.get("n_armi", 1))
	box_armi.add_child(Tema.etichetta("Arma (%s): " % ("scegline %d" % n if n > 1 else "una"), 19))
	var disp := Mazzi.armi(k)
	for id in disp:
		var b := Button.new()
		b.toggle_mode = true
		b.text = "%s (%s)" % [Carte.nome(id), Carte.carta(id).weapon]
		b.custom_minimum_size = Vector2(150, 42)
		b.set_pressed_no_signal(mazzo.armi.has(id))
		b.toggled.connect(_scegli_arma.bind(id))
		box_armi.add_child(b)
	var mancano: Array = []
	for a in cd.get("armi", []):
		var c := false
		for id in disp:
			if str(Carte.carta(id).weapon) == a:
				c = true
		if not c:
			mancano.append(a)
	if not mancano.is_empty():
		var l := Tema.etichetta("Senza carta nel gioco: %s" % ", ".join(mancano), 16)
		box_armi.add_child(l)


func _scegli_arma(on: bool, id: int) -> void:
	var n: int = int(Carte.db().characters[k].get("n_armi", 1))
	if on:
		if not mazzo.armi.has(id):
			mazzo.armi.append(id)
		while mazzo.armi.size() > n:
			mazzo.armi.pop_front()
	else:
		mazzo.armi.erase(id)
	_armi()
	_tocca()


func _riempi_griglia() -> void:
	for c in griglia.get_children():
		c.queue_free()
	var sig := Mazzi.firma(k)
	var tipo: String = FILTRI_TIPO[f_tipo.selected][0]
	var rango: String = FILTRI_RANGO[f_rango.selected][0]
	var fonte: String = FILTRI_FONTE[f_fonte.selected][0]
	for id in Mazzi.disponibili(k):
		var c := Carte.carta(id)
		if tipo != "" and c.type != tipo:
			continue
		if rango != "" and c.rank != rango:
			continue
		var di_firma: bool = str(c.pers) == sig
		if (fonte == "firma" and not di_firma) or (fonte == "base" and di_firma):
			continue
		griglia.add_child(_tessera(id))


func _tessera(id: int) -> Control:
	var c := Carte.carta(id)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	var t := TextureButton.new()
	t.ignore_texture_size = true
	t.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = CARTA
	t.texture_normal = _tex("res://assets/cards/" + c.img)
	t.pressed.connect(_ingrandisci.bind(id))
	v.add_child(t)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 2)
	v.add_child(h)
	var meno := Button.new()
	meno.text = "-"
	meno.custom_minimum_size = Vector2(36, 34)
	meno.pressed.connect(_cambia.bind(id, -1))
	h.add_child(meno)
	var q: int = int(mazzo.deck.get(str(id), 0))
	var l := Tema.etichetta("%d/%d" % [q, Mazzi.COPIE[c.rank]], 18, Tema.VERMIGLIO if q > 0 else Tema.INCHIOSTRO, q > 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(42, 0)
	h.add_child(l)
	var piu := Button.new()
	piu.text = "+"
	piu.custom_minimum_size = Vector2(36, 34)
	piu.disabled = q >= int(Mazzi.COPIE[c.rank])
	piu.pressed.connect(_cambia.bind(id, 1))
	h.add_child(piu)
	if q > 0:
		t.modulate = Color(1, 1, 1)
	else:
		t.modulate = Color(0.82, 0.82, 0.82)
	return v


func _cambia(id: int, d: int) -> void:
	var c := Carte.carta(id)
	var q: int = clampi(int(mazzo.deck.get(str(id), 0)) + d, 0, int(Mazzi.COPIE[c.rank]))
	if q == 0:
		mazzo.deck.erase(str(id))
	else:
		mazzo.deck[str(id)] = q
	_tocca()
	_riempi_griglia()


func _tocca() -> void:
	modificato = true
	_aggiorna_conti()


func _aggiorna_conti() -> void:
	var n := Mazzi.conta(mazzo.deck)
	var per: Dictionary = {"Wood": 0, "Steel": 0, "Gold": 0, "Jade": 0}
	var tipi := {"attack": 0, "defence": 0, "meditation": 0}
	for id in mazzo.deck:
		var c := Carte.carta(int(id))
		per[c.rank] += int(mazzo.deck[id])
		tipi[c.type] = int(tipi.get(c.type, 0)) + int(mazzo.deck[id])
	lbl_conti.text = "%s: %d/%d carte\nLegno %d · Acciaio %d · Oro %d/%d · Giada %d/%d\nAttacchi %d · Difese %d · Meditazioni %d" % [
		Carte.db().characters[k].name, n, int(mazzo.get("dim", 30)), per.Wood, per.Steel, per.Gold, Mazzi.MAX_ORO,
		per.Jade, Mazzi.MAX_GIADA, tipi.attack, tipi.defence, tipi.meditation]
	for c in lista.get_children():
		c.queue_free()
	var ids: Array = []
	for id in mazzo.deck:
		ids.append(int(id))
	ids.sort_custom(func(a, b): return Carte.carta(a).name < Carte.carta(b).name)
	for id in ids:
		var b := Button.new()
		b.text = "%dx %s" % [int(mazzo.deck[str(id)]), Carte.nome(id)]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(260, 34)
		b.add_theme_font_size_override("font_size", 17)
		b.tooltip_text = "Tocca per togliere una copia"
		b.pressed.connect(func():
			_cambia(id, -1))
		lista.add_child(b)
	usa.text = "In partita: mazzo personale" if mazzo.get("attivo", false) else "In partita: mazzo base"
	var err := Mazzi.errori(k, mazzo)
	lbl_errori.text = "Mazzo valido." if err.is_empty() else "\n".join(err)
	lbl_errori.add_theme_color_override("font_color", Color("2e6b2e") if err.is_empty() else Tema.VERMIGLIO)
	if modificato:
		lbl_errori.text += "\nModifiche non salvate."


func _riparti() -> void:
	var att: bool = mazzo.get("attivo", false)
	mazzo = Mazzi.base(k)
	mazzo["attivo"] = att
	scelta_dim.select(0)
	_armi()
	_riempi_griglia()
	_tocca()


func _svuota_mazzo() -> void:
	mazzo.deck = {}
	_riempi_griglia()
	_tocca()


func _salva() -> void:
	var tutti := Mazzi.carica()
	var err := Mazzi.errori(k, mazzo)
	if not err.is_empty() and mazzo.get("attivo", false):
		# un mazzo non valido si può salvare ma non usare
		mazzo["attivo"] = false
		usa.set_pressed_no_signal(false)
	tutti[k] = mazzo.duplicate(true)
	Mazzi.salva(tutti)
	modificato = false
	_aggiorna_conti()
	lbl_errori.text += "\nSalvato." + ("" if err.is_empty() else " Il mazzo non è valido: in partita si usa quello base.")


func _esci() -> void:
	get_tree().change_scene_to_file("res://scenes/Menu.tscn")


func _ingrandisci(id: int) -> void:
	var velo := ColorRect.new()
	velo.color = Color(0, 0, 0, 0.6)
	velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(velo)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	velo.add_child(cc)
	var pan := PanelContainer.new()
	cc.add_child(pan)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	pan.add_child(h)
	var t := TextureRect.new()
	t.texture = _tex("res://assets/cards/" + Carte.carta(id).img)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var alt: float = minf(560.0, get_viewport().get_visible_rect().size.y - 80.0)
	t.custom_minimum_size = Vector2(alt * 0.72, alt)
	h.add_child(t)
	var dv := VBoxContainer.new()
	dv.custom_minimum_size = Vector2(320, 0)
	h.add_child(dv)
	var c := Carte.carta(id)
	var nome := Tema.etichetta(c.name, 22, Tema.VERMIGLIO, true)
	nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nome.custom_minimum_size = Vector2(320, 0)
	dv.add_child(nome)
	dv.add_child(Tema.etichetta("%s · %s · %s" % [Carte.TIPI.get(c.type, c.type), Mazzi.RANGHI[c.rank],
		"firma" if str(c.pers) == Mazzi.firma(k) else "base"], 18))
	var txt := RichTextLabel.new()
	txt.bbcode_enabled = true
	txt.custom_minimum_size = Vector2(320, 260)
	txt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	txt.text = Carte.testo(c)
	dv.add_child(txt)
	var bb := HBoxContainer.new()
	bb.add_theme_constant_override("separation", 6)
	dv.add_child(bb)
	for d in [["Aggiungi", 1], ["Togli", -1]]:
		var b := Tema.bottone(d[0], 110)
		b.pressed.connect(func():
			_cambia(id, d[1])
			velo.queue_free())
		bb.add_child(b)
	var ch := Tema.bottone("Chiudi", 100)
	ch.pressed.connect(velo.queue_free)
	bb.add_child(ch)


func _tex(p: String) -> Texture2D:
	if not tex_cache.has(p):
		tex_cache[p] = load(p)
	return tex_cache[p]
