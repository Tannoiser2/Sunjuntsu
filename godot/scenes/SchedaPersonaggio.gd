class_name SchedaPersonaggio
extends RefCounted
## Riquadro con carta del personaggio, albero Kamae, regole speciali e consigli di gioco.
## Si apre toccando il personaggio nel menu o il ritratto in partita.


static func apri(genitore: Control, k: String, extra: Button = null) -> Control:
	var cd: Dictionary = Carte.db().characters[k]
	var vp: Vector2 = genitore.get_viewport_rect().size
	var velo := ColorRect.new()
	velo.color = Color(0, 0, 0, 0.55)
	velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	velo.mouse_filter = Control.MOUSE_FILTER_STOP
	genitore.add_child(velo)
	velo.gui_input.connect(func(e):
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			velo.queue_free())
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	velo.add_child(centro)
	var pan := PanelContainer.new()
	pan.add_theme_stylebox_override("panel", Tema.riquadro(Tema.CARTA, Tema.INCHIOSTRO, 3, 10, 18, 14))
	centro.add_child(pan)
	var largo: float = clampf(vp.x - 60.0, 600.0, 940.0)
	var alto: float = clampf(vp.y - 60.0, 420.0, 640.0)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	h.custom_minimum_size = Vector2(largo - 36.0, alto - 28.0)
	pan.add_child(h)
	# carte: personaggio e Kamae
	var img_h: float = (alto - 40.0) / 2.0
	var colc := VBoxContainer.new()
	colc.add_theme_constant_override("separation", 8)
	h.add_child(colc)
	for p in [cd.char_img, cd.kamae_img]:
		var t := TextureRect.new()
		t.texture = load("res://assets/cards/" + p)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.custom_minimum_size = Vector2(img_h * 0.72, img_h)
		colc.add_child(t)
	# testo
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	h.add_child(v)
	var nome := Tema.etichetta(cd.name, 30, Tema.VERMIGLIO, true)
	nome.custom_minimum_size = Vector2(300, 0)
	v.add_child(nome)
	var tit := Tema.etichetta("%s  ·  mano %d  ·  ferite %d  ·  vantaggio %d" % [cd.title, int(cd.hand), int(cd.wounds), int(cd.advantage)], 17)
	tit.custom_minimum_size = Vector2(300, 0)
	tit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(tit)
	var testo := RichTextLabel.new()
	testo.bbcode_enabled = true
	testo.custom_minimum_size = Vector2(300, 200)
	testo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	testo.add_theme_font_size_override("normal_font_size", 18)
	testo.add_theme_font_size_override("bold_font_size", 19)
	testo.add_theme_color_override("default_color", Tema.INCHIOSTRO)
	var t2 := "[b]Abilità e regole speciali[/b]\n"
	for a in cd.get("abilita", []):
		t2 += "- %s\n" % a
	t2 += "\n[b]Come giocarlo[/b]\n%s" % cd.get("strategia", "")
	testo.text = t2
	v.add_child(testo)
	var bb := HBoxContainer.new()
	bb.alignment = BoxContainer.ALIGNMENT_END
	bb.add_theme_constant_override("separation", 8)
	v.add_child(bb)
	if extra != null:
		extra.pressed.connect(velo.queue_free)
		bb.add_child(extra)
	var chiudi := Tema.bottone("Chiudi", 120)
	chiudi.pressed.connect(velo.queue_free)
	bb.add_child(chiudi)
	return velo
