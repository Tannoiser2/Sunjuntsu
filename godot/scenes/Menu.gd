extends Control
## Menu principale.

var scelte: Dictionary = {}
var scelta_avv: OptionButton
const ORDINE := ["warrior", "ronin", "student", "master", "assassin", "monk", "yasuke", "yojimbo"]


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
	pan.add_theme_stylebox_override("panel", Tema.riquadro(Tema.CARTA, Tema.INCHIOSTRO, 3, 10, 36, 26))
	centro.add_child(pan)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	pan.add_child(v)
	var t := Tema.etichetta("SENJUTSU", 76, Tema.VERMIGLIO, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var st := Tema.etichetta("Battaglia per il Giappone", 26, Tema.INCHIOSTRO, true)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(st)
	var l := Tema.etichetta("Scegli il tuo combattente", 22)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var h := HFlowContainer.new()
	h.alignment = FlowContainer.ALIGNMENT_CENTER
	h.custom_minimum_size = Vector2(760, 0)
	h.add_theme_constant_override("h_separation", 10)
	h.add_theme_constant_override("v_separation", 8)
	v.add_child(h)
	var db := Carte.db()
	for k in ORDINE:
		var cd: Dictionary = db.characters[k]
		var b := TextureButton.new()
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.custom_minimum_size = Vector2(118, 164)
		b.texture_normal = load("res://assets/cards/" + cd.char_img)
		b.pressed.connect(_scegli.bind(k))
		var bordo := Panel.new()
		bordo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bordo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(bordo)
		scelte[k] = bordo
		h.add_child(b)
	var ha := HBoxContainer.new()
	ha.alignment = BoxContainer.ALIGNMENT_CENTER
	ha.add_theme_constant_override("separation", 10)
	v.add_child(ha)
	var la := Tema.etichetta("Avversario", 20)
	la.custom_minimum_size = Vector2(100, 0)
	ha.add_child(la)
	scelta_avv = OptionButton.new()
	scelta_avv.custom_minimum_size = Vector2(240, 46)
	for k in ORDINE:
		scelta_avv.add_item(db.characters[k].name)
	scelta_avv.item_selected.connect(func(i): _scegli_avv(ORDINE[i]))
	ha.add_child(scelta_avv)
	var nota := Tema.etichetta("In Solitario l'avversario può essere Guerriero o Ronin.", 16)
	nota.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nota.custom_minimum_size = Vector2(420, 0)
	v.add_child(nota)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 12)
	v.add_child(hb)
	var b1 := Tema.bottone("Solitario (carte Solo)", 250)
	b1.pressed.connect(_gioca.bind("solo", false))
	hb.add_child(b1)
	var b3 := Tema.bottone("Solitario Incubo", 200)
	b3.pressed.connect(_gioca.bind("solo", true))
	hb.add_child(b3)
	var hb2 := HBoxContainer.new()
	hb2.alignment = BoxContainer.ALIGNMENT_CENTER
	hb2.add_theme_constant_override("separation", 12)
	v.add_child(hb2)
	var b5 := Tema.bottone("Duello online", 190)
	b5.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Online.tscn"))
	hb2.add_child(b5)
	var b4 := Tema.bottone("Duello contro l'IA", 220)
	b4.pressed.connect(_gioca.bind("duello", false))
	hb2.add_child(b4)
	var b2 := Tema.bottone("Carte ed editor", 190)
	b2.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Editor.tscn"))
	hb2.add_child(b2)
	var ver := Tema.etichetta("Versione %s — regole della 1a edizione, carte italiane" % ProjectSettings.get_setting("application/config/version"), 16)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(ver)
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
		var sb := Tema.riquadro(Color(0, 0, 0, 0), Tema.ORO if c == k else Color(0, 0, 0, 0), 6, 10)
		scelte[c].add_theme_stylebox_override("panel", sb)
	_scegli_avv(Sessione.setup.get("avv", "ronin"))
