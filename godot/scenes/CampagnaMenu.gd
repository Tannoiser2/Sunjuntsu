extends Control
## Schermata della campagna «La Via del Ronin»: elenco degli scenari, racconto, obiettivo e regole.

var st: Dictionary
var sel := ""
var lista: VBoxContainer
var testo: RichTextLabel
var b_gioca: Button
var strada := "rosso"
var scelta_strada: HBoxContainer
var b_rossa: Button
var b_blu: Button


func _ready() -> void:
	theme = Tema.tema()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	st = Campagna.carica()
	# ritorno da uno scenario vinto
	var vinto: String = Sessione.setup.get("vinto", "")
	var da_scegliere := ""
	if vinto != "":
		Sessione.setup.erase("vinto")
		if not st.fatti.has(vinto):
			st.fatti.append(vinto)
			# le carte aggiunte nella preparazione dello scenario restano nel mazzo
			if Sessione.setup.get("mazzo_dopo", null) is Dictionary:
				st.mazzo = Sessione.setup.mazzo_dopo.duplicate()
			if Campagna.scenario(vinto).has("dopo"):
				da_scegliere = vinto
		Campagna.salva(st)
	Sessione.setup.erase("mazzo_dopo")
	var sf := ColorRect.new()
	sf.color = Tema.CARTA_SCURA
	sf.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sf)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for l in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + l, 16)
	add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	m.add_child(v)
	var tit := Tema.etichetta("La Via del Ronin — campagna in solitario", 30, Tema.VERMIGLIO, true)
	tit.custom_minimum_size = Vector2(400, 0)
	tit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(tit)
	var h := HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_theme_constant_override("separation", 16)
	v.add_child(h)
	lista = VBoxContainer.new()
	lista.custom_minimum_size = Vector2(300, 0)
	lista.add_theme_constant_override("separation", 8)
	h.add_child(lista)
	var pan := PanelContainer.new()
	pan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pan.add_theme_stylebox_override("panel", Tema.riquadro(Tema.CARTA, Tema.INCHIOSTRO, 2, 8, 16, 12))
	h.add_child(pan)
	testo = RichTextLabel.new()
	testo.bbcode_enabled = true
	testo.custom_minimum_size = Vector2(320, 200)
	testo.add_theme_font_size_override("normal_font_size", 19)
	testo.add_theme_font_size_override("bold_font_size", 20)
	testo.add_theme_color_override("default_color", Tema.INCHIOSTRO)
	var vt := VBoxContainer.new()
	vt.add_theme_constant_override("separation", 8)
	pan.add_child(vt)
	scelta_strada = HBoxContainer.new()
	scelta_strada.add_theme_constant_override("separation", 10)
	vt.add_child(scelta_strada)
	b_rossa = Tema.bottone("Via rossa", 160)
	b_rossa.toggle_mode = true
	b_rossa.pressed.connect(func(): strada = "rosso"; _mostra(sel))
	scelta_strada.add_child(b_rossa)
	b_blu = Tema.bottone("Via blu", 160)
	b_blu.toggle_mode = true
	b_blu.pressed.connect(func(): strada = "blu"; _mostra(sel))
	scelta_strada.add_child(b_blu)
	testo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vt.add_child(testo)
	var bb := HFlowContainer.new()
	bb.add_theme_constant_override("h_separation", 10)
	v.add_child(bb)
	b_gioca = Tema.bottone("Gioca lo scenario", 220)
	b_gioca.pressed.connect(_gioca)
	bb.add_child(b_gioca)
	var b_storia := Tema.bottone("Racconto", 150)
	b_storia.pressed.connect(func(): _fumetto(Campagna.scenario(sel).get("fumetto", []), Callable()))
	bb.add_child(b_storia)
	var b_nuova := Tema.bottone("Ricomincia la campagna", 260)
	b_nuova.pressed.connect(func():
		st = Campagna.nuova()
		Campagna.salva(st)
		_elenco())
	bb.add_child(b_nuova)
	var b_menu := Tema.bottone("Menu", 120)
	b_menu.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Menu.tscn"))
	bb.add_child(b_menu)
	_elenco()
	if da_scegliere != "":
		_scelta_dopo(da_scegliere)
	elif vinto != "" and Campagna.scenario(vinto).has("finale"):
		_fumetto([Campagna.scenario(vinto).finale], Callable())


func _elenco() -> void:
	for c in lista.get_children():
		c.queue_free()
	var prossimo := Campagna.prossimo(st)
	var n := 0
	for sc in Campagna.dati().scenari:
		n += 1
		var stato := "vinto" if st.fatti.has(sc.id) else ("in arrivo" if not sc.get("pronto", true) else ("da giocare" if sc.id == prossimo else "bloccato"))
		var b := Button.new()
		b.text = "%d. %s (%s)" % [n, sc.titolo, stato]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(300, 46)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(_mostra.bind(sc.id))
		lista.add_child(b)
	_mostra(prossimo if prossimo != "" else Campagna.dati().scenari[0].id)


func _mostra(id: String) -> void:
	if id != sel:
		var imp := Campagna.strada_imposta(id, st)
		strada = imp if imp != "" else "rosso"
	sel = id
	var base := Campagna.scenario(id)
	var imposta := Campagna.strada_imposta(id, st)
	if imposta != "":
		strada = imposta
	var sc := Campagna.con_strada(id, strada)
	scelta_strada.visible = base.has("strade") and imposta == ""
	b_rossa.button_pressed = strada == "rosso"
	b_blu.button_pressed = strada == "blu"
	var t := "[b]%s[/b]\n\n[i]%s[/i]\n\n[b]Obiettivo[/b]\n%s\n" % [sc.titolo, sc.intro, sc.obiettivo]
	if base.has("strade"):
		t += "\n[b]%s[/b]%s\n%s\n" % ["Via rossa" if strada == "rosso" else "Via blu",
			" (decisa dalla scelta fatta nello scenario precedente)" if imposta != "" else "", sc.testo_strada]
	if not sc.regole.is_empty():
		t += "\n[b]Regole dello scenario[/b]\n"
		for r in sc.regole:
			t += "- %s\n" % r
	if not sc.nemici.is_empty():
		t += "\n[b]Avversari[/b]\n"
		for nm in sc.nemici:
			var tipo: String = Carte.db().nemici[nm.tipo].name if Carte.db().nemici.has(nm.tipo) else Carte.db().characters[nm.tipo].name
			t += "- %s (%s): ferite %d, %s, avvicina da %s\n" % [nm.nome, tipo, int(nm.ferite),
				"offensivo" if nm.post == "off" else "difensivo", Carte.COMPORTAMENTI[int(nm.comp)].to_lower()]
	if base.has("dopo"):
		t += "\n[b]Dopo il duello[/b] sceglierai una di queste strade:\n"
		for d in base.dopo:
			t += "- %s\n" % d.testo
	t += "\n[b]Mazzo del Ronin[/b]: %d carte più Carta Speciale e Spazzata di Naginata." % Mazzi.conta(st.mazzo)
	testo.text = "[font_size=22]" + t + "[/font_size]"
	b_gioca.disabled = not st.fatti.has(id) and id != Campagna.prossimo(st)


## Tavole a fumetto del libro della campagna, da sfogliare prima di giocare.
func _fumetto(pagine: Array, poi: Callable) -> void:
	if pagine.is_empty():
		if poi.is_valid():
			poi.call()
		return
	var ov := Control.new()
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ov)
	var sf := ColorRect.new()
	sf.color = Color(0.05, 0.04, 0.04)
	sf.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.add_child(sf)
	var tr := TextureRect.new()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.offset_top = 8
	tr.offset_bottom = -70
	ov.add_child(tr)
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bar.offset_top = -62
	bar.offset_bottom = -8
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.add_theme_constant_override("separation", 12)
	ov.add_child(bar)
	var b_ind := Tema.bottone("Indietro", 130)
	var lbl := Tema.etichetta("", 20, Color.WHITE)
	lbl.custom_minimum_size = Vector2(90, 0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var b_av := Tema.bottone("Avanti", 130)
	var b_salta := Tema.bottone("Gioca" if poi.is_valid() else "Chiudi", 130)
	for x in [b_ind, lbl, b_av, b_salta]:
		bar.add_child(x)
	var stato := {"i": 0}
	var mostra := func():
		tr.texture = load("res://assets/fumetto/%s.webp" % pagine[stato.i])
		lbl.text = "%d / %d" % [stato.i + 1, pagine.size()]
		b_ind.disabled = stato.i == 0
		b_av.disabled = stato.i == pagine.size() - 1
	var chiudi := func():
		ov.queue_free()
		if poi.is_valid():
			poi.call()
	b_ind.pressed.connect(func(): stato.i = maxi(0, stato.i - 1); mostra.call())
	b_av.pressed.connect(func(): stato.i = mini(pagine.size() - 1, stato.i + 1); mostra.call())
	b_salta.pressed.connect(chiudi)
	# tocco sulla tavola: metà destra avanti, metà sinistra indietro; anche scorrimento col dito
	tr.mouse_filter = Control.MOUSE_FILTER_STOP
	var trascina := {"x": 0.0}
	tr.gui_input.connect(func(ev: InputEvent):
		if (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT) or ev is InputEventScreenTouch:
			if ev.pressed:
				trascina.x = ev.position.x
			else:
				var dx: float = ev.position.x - trascina.x
				var avanti: bool = dx < -40.0 or (absf(dx) <= 40.0 and ev.position.x > tr.size.x * 0.5)
				if avanti and stato.i < pagine.size() - 1:
					stato.i += 1
				elif not avanti and stato.i > 0:
					stato.i -= 1
				mostra.call())
	mostra.call()


## Scelta di fine scenario: cambia il mazzo del Ronin (e a volte la strada successiva).
func _scelta_dopo(id: String) -> void:
	var sc := Campagna.scenario(id)
	var ov := ColorRect.new()
	ov.color = Color(0, 0, 0, 0.7)
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ov)
	var pan := PanelContainer.new()
	pan.add_theme_stylebox_override("panel", Tema.riquadro(Tema.CARTA, Tema.INCHIOSTRO, 2, 8, 18, 14))
	pan.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pan.custom_minimum_size = Vector2(minf(720.0, get_viewport_rect().size.x - 40.0), 0)
	pan.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pan.grow_vertical = Control.GROW_DIRECTION_BOTH
	ov.add_child(pan)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	pan.add_child(v)
	var tit := Tema.etichetta("%s: scenario vinto. Che cosa fa il Ronin?" % sc.titolo, 24, Tema.VERMIGLIO, true)
	tit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tit.custom_minimum_size = Vector2(400, 0)
	tit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(tit)
	for d in sc.dopo:
		var b := Button.new()
		b.text = d.testo
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(400, 70)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 19)
		b.pressed.connect(func():
			ov.queue_free()
			if d.get("copia_acciaio", false):
				_scegli_acciaio(id, d)
			else:
				Campagna.applica_dopo(st, id, d)
				Campagna.salva(st)
				_elenco())
		v.add_child(b)


func _scegli_acciaio(id: String, d: Dictionary) -> void:
	Campagna.applica_dopo(st, id, d)
	var carte := Campagna.acciaio_singole(st.mazzo)
	if carte.is_empty():
		Campagna.salva(st)
		_elenco()
		return
	var ov := ColorRect.new()
	ov.color = Color(0, 0, 0, 0.7)
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ov)
	var pan := PanelContainer.new()
	pan.add_theme_stylebox_override("panel", Tema.riquadro(Tema.CARTA, Tema.INCHIOSTRO, 2, 8, 18, 14))
	pan.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pan.custom_minimum_size = Vector2(minf(720.0, get_viewport_rect().size.x - 40.0), 0)
	pan.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pan.grow_vertical = Control.GROW_DIRECTION_BOTH
	ov.add_child(pan)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	pan.add_child(v)
	var tit := Tema.etichetta("Quale carta d'Acciaio raddoppi?", 24, Tema.VERMIGLIO, true)
	tit.custom_minimum_size = Vector2(400, 0)
	v.add_child(tit)
	var fl := HFlowContainer.new()
	fl.add_theme_constant_override("h_separation", 10)
	fl.add_theme_constant_override("v_separation", 10)
	v.add_child(fl)
	for c in carte:
		var b := Tema.bottone(Carte.nome(c), 280)
		b.pressed.connect(func():
			st.mazzo[str(c)] = int(st.mazzo.get(str(c), 0)) + 1
			Campagna.salva(st)
			ov.queue_free()
			_elenco())
		fl.add_child(b)


func _gioca() -> void:
	_fumetto(Campagna.scenario(sel).get("fumetto", []), _avvia)


func _avvia() -> void:
	var sc := Campagna.scenario(sel)
	Sessione.setup["strada"] = strada
	Sessione.setup["modo"] = "campagna"
	Sessione.setup["scenario"] = sel
	Sessione.setup["mappa"] = sc.get("mappa", "villaggio")
	Sessione.setup["io"] = "ronin"
	get_tree().change_scene_to_file("res://scenes/Partita.tscn")
