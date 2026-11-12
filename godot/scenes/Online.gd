extends Control
## Sala d'attesa del gioco online: si crea una stanza con un codice di 4 lettere
## oppure si entra in quella di un amico.

var rete: Rete
var nome: LineEdit
var cod: LineEdit
var stato: Label
var grande: Label
var b_crea: Button
var b_entra: Button
var b_inizia: Button
var codice := ""
var posto := -1
var attivo := true


func _ready() -> void:
	theme = Tema.tema()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sfondo := TextureRect.new()
	sfondo.texture = load("res://assets/maps/arena.webp")
	sfondo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sfondo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	sfondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sfondo.modulate = Color(0.45, 0.42, 0.4)
	add_child(sfondo)
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	var pan := PanelContainer.new()
	pan.add_theme_stylebox_override("panel", Tema.riquadro(Tema.CARTA, Tema.INCHIOSTRO, 3, 10, 32, 24))
	centro.add_child(pan)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(520, 0)
	v.add_theme_constant_override("separation", 14)
	pan.add_child(v)
	var t := Tema.etichetta("Duello online", 40, Tema.VERMIGLIO, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var pers: String = Carte.db().characters[Sessione.setup.get("io", "warrior")].name
	var l := Tema.etichetta("Chi crea la stanza gioca con %s, l'ospite con l'altro combattente." % pers, 19)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(500, 0)
	v.add_child(l)
	if Sessione.rete == null:
		Sessione.rete = Rete.new()
		get_tree().root.add_child.call_deferred(Sessione.rete)
	rete = Sessione.rete
	var salvati := rete.load_session()
	var h1 := HBoxContainer.new()
	h1.add_theme_constant_override("separation", 10)
	v.add_child(h1)
	h1.add_child(Tema.etichetta("Il tuo nome", 20))
	nome = LineEdit.new()
	nome.text = str(salvati.get("name", "Samurai"))
	nome.max_length = 20
	nome.custom_minimum_size = Vector2(260, 44)
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h1.add_child(nome)
	b_crea = Tema.bottone("Crea una stanza", 300)
	b_crea.pressed.connect(_crea)
	v.add_child(b_crea)
	var h2 := HBoxContainer.new()
	h2.add_theme_constant_override("separation", 10)
	v.add_child(h2)
	h2.add_child(Tema.etichetta("Codice", 20))
	cod = LineEdit.new()
	cod.text = str(salvati.get("room", ""))
	cod.max_length = 4
	cod.custom_minimum_size = Vector2(120, 44)
	h2.add_child(cod)
	b_entra = Tema.bottone("Entra nella stanza", 240)
	b_entra.pressed.connect(_entra)
	h2.add_child(b_entra)
	grande = Tema.etichetta("", 64, Tema.INCHIOSTRO, true)
	grande.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(grande)
	stato = Tema.etichetta("", 20, Tema.VERMIGLIO)
	stato.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stato.custom_minimum_size = Vector2(500, 30)
	stato.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(stato)
	b_inizia = Tema.bottone("Inizia il duello", 300)
	b_inizia.visible = false
	b_inizia.pressed.connect(_inizia)
	v.add_child(b_inizia)
	var bm := Tema.bottone("Torna al menu", 200)
	bm.pressed.connect(func():
		attivo = false
		get_tree().change_scene_to_file("res://scenes/Menu.tscn"))
	v.add_child(bm)


func _blocca(si: bool) -> void:
	b_crea.disabled = si
	b_entra.disabled = si


func _crea() -> void:
	_blocca(true)
	stato.text = "Creo la stanza…"
	rete._save({"name": nome.text})
	codice = await rete.create_room(nome.text, {"pers": Sessione.setup.get("io", "warrior")})
	if codice == "":
		stato.text = "Non riesco a creare la stanza. " + rete.last_error
		_blocca(false)
		return
	posto = 0
	rete.remember_room(codice, 0)
	grande.text = codice
	stato.text = "Dai questo codice al tuo avversario. In attesa che entri…"
	_attendi()


func _entra() -> void:
	_blocca(true)
	codice = cod.text.strip_edges().to_upper()
	stato.text = "Entro nella stanza %s…" % codice
	rete._save({"name": nome.text})
	posto = await rete.join_room(codice, nome.text, 2)
	if posto < 0:
		stato.text = ("La stanza è piena." if posto == -1 else "Stanza non trovata. ") + rete.last_error
		_blocca(false)
		return
	rete.remember_room(codice, posto)
	grande.text = codice
	stato.text = "Sei dentro. In attesa che parta il duello…"
	_attendi()


func _attendi() -> void:
	while attivo and is_inside_tree():
		var st: Dictionary = await rete.room(codice)
		if not attivo or not is_inside_tree():
			return
		if st.get("status", "") == "playing" and st.has("game"):
			_parti(JSON.parse_string(str(st.game)))
			return
		var posti: Dictionary = Rete._as_dict(st.get("seats", {}))
		if posto == 0:
			if posti.has("1"):
				stato.text = "%s è entrato: puoi iniziare." % str(posti["1"].get("name", "L'avversario"))
				b_inizia.visible = true
		elif posti.has("0"):
			stato.text = "Stanza di %s. In attesa che parta il duello…" % str(posti["0"].get("name", "?"))
		await get_tree().create_timer(1.5).timeout


func _inizia() -> void:
	b_inizia.disabled = true
	var mio: String = Sessione.setup.get("io", "warrior")
	var partita := {"seed": randi() % 1000000 + 1, "pers": [mio, "ronin" if mio == "warrior" else "warrior"]}
	if not await rete.start_room(codice, partita):
		stato.text = "Non riesco ad avviare. " + rete.last_error
		b_inizia.disabled = false


func _parti(partita: Dictionary) -> void:
	attivo = false
	Sessione.setup["modo"] = "online"
	Sessione.setup["codice"] = codice
	Sessione.setup["posto"] = posto
	Sessione.setup["partita"] = partita
	get_tree().change_scene_to_file("res://scenes/Partita.tscn")
