extends Control
## Menu principale: combattenti a sinistra, modalità a destra (sta in 1024x768).

var scelte: Dictionary = {}
var scelta_avv: OptionButton
var scelta_mazzo: OptionButton
var scelta_terreno: OptionButton
const TERRENI := [["nessuno", "Terreno: nessuno"], ["casuale", "Terreno: a caso"], ["a_turno", "Terreno: piazzato a turno"]]
const ORDINE := ["warrior", "ronin", "student", "master", "assassin", "monk", "yasuke", "yojimbo",
	"wakou", "onna", "sailor", "ashigaru", "ninja"]


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
	pan.add_theme_stylebox_override("panel", Tema.riquadro(Tema.CARTA, Tema.INCHIOSTRO, 3, 10, 22, 16))
	centro.add_child(pan)
	var h0 := HBoxContainer.new()
	h0.add_theme_constant_override("separation", 22)
	pan.add_child(h0)
	# colonna sinistra: combattenti
	var sx := VBoxContainer.new()
	sx.add_theme_constant_override("separation", 8)
	h0.add_child(sx)
	var l := Tema.etichetta("Scegli il tuo combattente (toccalo per la sua scheda)", 20, Tema.INCHIOSTRO, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sx.add_child(l)
	var gr := GridContainer.new()
	gr.columns = 5
	gr.add_theme_constant_override("h_separation", 8)
	gr.add_theme_constant_override("v_separation", 8)
	sx.add_child(gr)
	var db := Carte.db()
	for k in ORDINE:
		var cd: Dictionary = db.characters[k]
		var b := TextureButton.new()
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.custom_minimum_size = Vector2(156, 217)
		b.texture_normal = load("res://assets/cards/" + cd.char_img)
		b.pressed.connect(_tocca.bind(k))
		var bordo := Panel.new()
		bordo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bordo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(bordo)
		scelte[k] = bordo
		gr.add_child(b)
	# colonna destra: titolo, avversario, modalità
	var dx := VBoxContainer.new()
	dx.custom_minimum_size = Vector2(340, 0)
	dx.alignment = BoxContainer.ALIGNMENT_CENTER
	dx.add_theme_constant_override("separation", 10)
	h0.add_child(dx)
	var t := Tema.etichetta("SENJUTSU", 54, Tema.VERMIGLIO, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dx.add_child(t)
	var st := Tema.etichetta("Battaglia per il Giappone", 17, Tema.INCHIOSTRO, true)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dx.add_child(st)
	var la := Tema.etichetta("Avversario", 20)
	la.custom_minimum_size = Vector2(320, 0)
	dx.add_child(la)
	scelta_avv = OptionButton.new()
	scelta_avv.custom_minimum_size = Vector2(320, 50)
	for k in ORDINE:
		scelta_avv.add_item(db.characters[k].name)
	scelta_avv.item_selected.connect(func(i): _scegli_avv(ORDINE[i]))
	dx.add_child(scelta_avv)
	scelta_mazzo = OptionButton.new()
	scelta_mazzo.custom_minimum_size = Vector2(320, 46)
	scelta_mazzo.add_item("Mazzo base")
	scelta_mazzo.add_item("Mazzo personale")
	scelta_mazzo.item_selected.connect(_usa_mazzo)
	dx.add_child(scelta_mazzo)
	scelta_terreno = OptionButton.new()
	scelta_terreno.custom_minimum_size = Vector2(320, 46)
	for tv in TERRENI:
		scelta_terreno.add_item(tv[1])
	var tsel := 0
	for i in TERRENI.size():
		if TERRENI[i][0] == Sessione.setup.get("terreno", "nessuno"):
			tsel = i
	scelta_terreno.select(tsel)
	scelta_terreno.item_selected.connect(func(i): Sessione.setup["terreno"] = TERRENI[i][0])
	dx.add_child(scelta_terreno)
	var scelta_cam := OptionButton.new()
	scelta_cam.custom_minimum_size = Vector2(320, 46)
	scelta_cam.add_item("Telecamera: fissa")
	scelta_cam.add_item("Telecamera: segue l'azione")
	scelta_cam.select(1 if Sessione.setup.get("segui", false) else 0)
	scelta_cam.item_selected.connect(func(i): Sessione.setup["segui"] = i == 1)
	dx.add_child(scelta_cam)
	for d in [["Solitario (carte Solo)", _gioca.bind("solo", false)], ["Solitario Incubo", _gioca.bind("solo", true)],
			["Duello contro l'IA", _gioca.bind("duello", false)],
			["Duello online", func(): get_tree().change_scene_to_file("res://scenes/Online.tscn")],
			["Gioca con gli smartphone", _smartphone],
			["Campagna: la Via del Ronin", func(): get_tree().change_scene_to_file("res://scenes/CampagnaMenu.tscn")]]:
		var bt := Tema.bottone(d[0], 320)
		bt.pressed.connect(d[1])
		dx.add_child(bt)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	dx.add_child(hb)
	var b_carte := Tema.bottone("Carte", 156)
	b_carte.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Editor.tscn"))
	hb.add_child(b_carte)
	var b_mazzi := Tema.bottone("Editor mazzi", 156)
	b_mazzi.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/EditorMazzi.tscn"))
	hb.add_child(b_mazzi)
	var ver := Tema.etichetta("Versione %s" % ProjectSettings.get_setting("application/config/version"), 15)
	ver.custom_minimum_size = Vector2(320, 0)
	dx.add_child(ver)
	_scegli(Sessione.setup.get("io", "warrior"))


func _smartphone() -> void:
	var velo := ColorRect.new()
	velo.color = Color(0, 0, 0, 0.55)
	velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(velo)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	velo.add_child(cc)
	var pan := PanelContainer.new()
	cc.add_child(pan)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	pan.add_child(v)
	var t := Tema.etichetta("Gioca con gli smartphone", 26, Tema.VERMIGLIO, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var l := Tema.etichetta("Lo schermo mostra il tavoliere; ogni giocatore ha le sue carte e fa le sue scelte sul telefono, inquadrando un QR code.", 18)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(440, 0)
	v.add_child(l)
	for d in [["Un giocatore contro l'avversario Solo", true], ["Due giocatori, un telefono ciascuno", false]]:
		var b := Tema.bottone(d[0], 440)
		b.pressed.connect(func():
			Sessione.setup["modo"] = "telefoni"
			Sessione.setup["tel_solo"] = d[1]
			Sessione.setup["incubo"] = false
			if d[1] and not Carte.db().solo.has(Sessione.setup.avv):
				Sessione.setup["avv"] = "ronin" if Sessione.setup.io != "ronin" else "warrior"
			get_tree().change_scene_to_file("res://scenes/Partita.tscn"))
		v.add_child(b)
	var ch := Tema.bottone("Annulla", 140)
	ch.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ch.pressed.connect(velo.queue_free)
	v.add_child(ch)


func _scegli_avv(k: String) -> void:
	if k == Sessione.setup.get("io", "warrior"):
		k = "ronin" if k != "ronin" else "warrior"
	Sessione.setup["avv"] = k
	scelta_avv.select(ORDINE.find(k))


func _gioca(modo: String, incubo: bool) -> void:
	if modo == "solo" and not Carte.db().solo.has(Sessione.setup.avv):
		Sessione.setup["avv"] = "ronin" if Sessione.setup.io != "ronin" else "warrior"
	Sessione.setup["modo"] = modo
	Sessione.setup["incubo"] = incubo
	get_tree().change_scene_to_file("res://scenes/Partita.tscn")


func _tocca(k: String) -> void:
	_scegli(k)
	SchedaPersonaggio.apri(self, k)


func _scegli(k: String) -> void:
	Sessione.setup["io"] = k
	for c in scelte:
		var sb := Tema.riquadro(Color(0, 0, 0, 0), Tema.ORO if c == k else Color(0, 0, 0, 0), 5, 8)
		scelte[c].add_theme_stylebox_override("panel", sb)
	_scegli_avv(Sessione.setup.get("avv", "ronin"))
	_aggiorna_mazzo()


func _aggiorna_mazzo() -> void:
	if scelta_mazzo == null:
		return
	var k: String = Sessione.setup.get("io", "warrior")
	var m: Dictionary = Mazzi.carica().get(k, {})
	var valido: bool = not m.is_empty() and Mazzi.errori(k, m).is_empty()
	scelta_mazzo.set_item_disabled(1, not valido)
	scelta_mazzo.select(1 if valido and m.get("attivo", false) else 0)


func _usa_mazzo(i: int) -> void:
	var k: String = Sessione.setup.get("io", "warrior")
	var tutti := Mazzi.carica()
	if tutti.has(k):
		tutti[k]["attivo"] = i == 1
		Mazzi.salva(tutti)
