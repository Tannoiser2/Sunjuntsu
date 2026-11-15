extends Control
## Schermata della campagna «La Via del Ronin»: elenco degli scenari, racconto, obiettivo e regole.

var st: Dictionary
var sel := ""
var lista: VBoxContainer
var testo: RichTextLabel
var b_gioca: Button


func _ready() -> void:
	theme = Tema.tema()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	st = Campagna.carica()
	# ritorno da uno scenario vinto
	var vinto: String = Sessione.setup.get("vinto", "")
	if vinto != "":
		Sessione.setup.erase("vinto")
		if not st.fatti.has(vinto):
			st.fatti.append(vinto)
		Campagna.salva(st)
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
	pan.add_child(testo)
	var bb := HFlowContainer.new()
	bb.add_theme_constant_override("h_separation", 10)
	v.add_child(bb)
	b_gioca = Tema.bottone("Gioca lo scenario", 220)
	b_gioca.pressed.connect(_gioca)
	bb.add_child(b_gioca)
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
	sel = id
	var sc := Campagna.scenario(id)
	var t := "[b]%s[/b]\n\n[i]%s[/i]\n\n[b]Obiettivo[/b]\n%s\n" % [sc.titolo, sc.intro, sc.obiettivo]
	if not sc.regole.is_empty():
		t += "\n[b]Regole dello scenario[/b]\n"
		for r in sc.regole:
			t += "- %s\n" % r
	if not sc.nemici.is_empty():
		t += "\n[b]Avversari[/b]\n"
		for nm in sc.nemici:
			t += "- %s (%s): ferite %d, %s, avvicina da %s\n" % [nm.nome, Carte.db().nemici[nm.tipo].name, int(nm.ferite),
				"offensivo" if nm.post == "off" else "difensivo", Carte.COMPORTAMENTI[int(nm.comp)].to_lower()]
	t += "\n[b]Mazzo del Ronin[/b]: %d carte più Carta Speciale e Spazzata di Naginata." % Mazzi.conta(st.mazzo)
	var pronto: bool = sc.get("pronto", true)
	if not pronto:
		t += "\n\n[b]Questo scenario arriverà nel prossimo aggiornamento.[/b]"
	testo.text = "[font_size=22]" + t + "[/font_size]"
	b_gioca.disabled = not pronto or (not st.fatti.has(id) and id != Campagna.prossimo(st))


func _gioca() -> void:
	var sc := Campagna.scenario(sel)
	Sessione.setup["modo"] = "campagna"
	Sessione.setup["scenario"] = sel
	Sessione.setup["mappa"] = sc.get("mappa", "villaggio")
	Sessione.setup["io"] = "ronin"
	get_tree().change_scene_to_file("res://scenes/Partita.tscn")
