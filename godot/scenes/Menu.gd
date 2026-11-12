extends Control
## Menu principale: combattenti a sinistra, modalità a destra (sta in 1024x768).

var scelte: Dictionary = {}
var scelta_avv: OptionButton
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
	var l := Tema.etichetta("Scegli il tuo combattente", 22, Tema.INCHIOSTRO, true)
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
		b.pressed.connect(_scegli.bind(k))
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
	for d in [["Solitario (carte Solo)", _gioca.bind("solo", false)], ["Solitario Incubo", _gioca.bind("solo", true)],
			["Duello contro l'IA", _gioca.bind("duello", false)],
			["Duello online", func(): get_tree().change_scene_to_file("res://scenes/Online.tscn")],
			["Carte ed editor", func(): get_tree().change_scene_to_file("res://scenes/Editor.tscn")]]:
		var bt := Tema.bottone(d[0], 320)
		bt.pressed.connect(d[1])
		dx.add_child(bt)
	var nota := Tema.etichetta("In Solitario il Ninja non è disponibile come avversario; l'Ashigaru combatte insieme a Hachiko.", 15)
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nota.custom_minimum_size = Vector2(320, 0)
	dx.add_child(nota)
	var ver := Tema.etichetta("Versione %s" % ProjectSettings.get_setting("application/config/version"), 15)
	ver.custom_minimum_size = Vector2(320, 0)
	dx.add_child(ver)
	_scegli(Sessione.setup.get("io", "warrior"))


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


func _scegli(k: String) -> void:
	Sessione.setup["io"] = k
	for c in scelte:
		var sb := Tema.riquadro(Color(0, 0, 0, 0), Tema.ORO if c == k else Color(0, 0, 0, 0), 5, 8)
		scelte[c].add_theme_stylebox_override("panel", sb)
	_scegli_avv(Sessione.setup.get("avv", "ronin"))
