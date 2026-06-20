## Editor di carte — Senjutsu (Fase 1: browser & inspector, SOLA LETTURA)
##
## Scena standalone (decisione §4.2 della roadmap), raggiungibile dal Menu e
## testabile headless. Mostra l'elenco delle carte con filtri (personaggio,
## tipo, rank, testo libero sul nome), un pannello di dettaglio con TUTTI i
## campi (anagrafica + geometria + immagine) e un'anteprima riusando CardView.
##
## Lettura via CardDB (già carica e indicizza tutto). La scrittura arriverà in
## Fase 2 tramite engine/CardStore.gd. Vedi docs/CARD_EDITOR_ROADMAP.md.
extends Control

const CardView := preload("res://scenes/CardView.gd")

## Valori dei filtri a tendina, paralleli agli indici degli OptionButton.
var _char_values: Array = []
var _type_values: Array = []
var _rank_values: Array = []

# Riferimenti ai widget costruiti in codice.
var _search: LineEdit
var _char_opt: OptionButton
var _type_opt: OptionButton
var _rank_opt: OptionButton
var _list: ItemList
var _count: Label
var _detail: VBoxContainer
var _preview_holder: Control
var _indicators: Label

var _selected_id: int = -1


func _ready() -> void:
	_build_ui()
	_populate_filters()
	_refresh_list()


# ─── Costruzione UI ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
	root.offset_left = 12; root.offset_top = 12
	root.offset_right = -12; root.offset_bottom = -12
	add_child(root)

	root.add_child(_build_left_panel())
	root.add_child(_build_detail_panel())
	root.add_child(_build_right_panel())


func _build_left_panel() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(340, 0)
	col.add_theme_constant_override("separation", 8)

	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = "Editor Carte"
	title.add_theme_font_size_override("font_size", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var back := Button.new()
	back.text = "← Menu"
	back.pressed.connect(_on_back)
	header.add_child(back)
	col.add_child(header)

	_search = LineEdit.new()
	_search.placeholder_text = "Cerca per nome…"
	_search.clear_button_enabled = true
	_search.text_changed.connect(func(_t): _refresh_list())
	col.add_child(_search)

	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 6)
	_char_opt = OptionButton.new()
	_char_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_char_opt.item_selected.connect(func(_i): _refresh_list())
	filters.add_child(_char_opt)
	_type_opt = OptionButton.new()
	_type_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_type_opt.item_selected.connect(func(_i): _refresh_list())
	filters.add_child(_type_opt)
	_rank_opt = OptionButton.new()
	_rank_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rank_opt.item_selected.connect(func(_i): _refresh_list())
	filters.add_child(_rank_opt)
	col.add_child(filters)

	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(_on_item_selected)
	col.add_child(_list)

	_count = Label.new()
	_count.add_theme_font_size_override("font_size", 12)
	col.add_child(_count)

	return col


func _build_detail_panel() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 4)
	scroll.add_child(_detail)
	var hint := Label.new()
	hint.text = "Seleziona una carta dall'elenco."
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_detail.add_child(hint)
	return scroll


func _build_right_panel() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(300, 0)
	col.add_theme_constant_override("separation", 8)

	var lbl := Label.new()
	lbl.text = "Anteprima"
	lbl.add_theme_font_size_override("font_size", 16)
	col.add_child(lbl)

	_preview_holder = CenterContainer.new()
	_preview_holder.custom_minimum_size = Vector2(0, 230)
	col.add_child(_preview_holder)

	_indicators = Label.new()
	_indicators.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_indicators.add_theme_font_size_override("font_size", 13)
	col.add_child(_indicators)

	return col


# ─── Filtri ed elenco ────────────────────────────────────────────────────────

func _populate_filters() -> void:
	# Personaggi: "Tutti" + distinti ordinati.
	_char_opt.clear()
	_char_values = [""]
	_char_opt.add_item("Tutti i personaggi")
	var chars: Array = CardDB.by_char.keys()
	chars.sort()
	for c in chars:
		_char_opt.add_item(str(c))
		_char_values.append(str(c))

	# Tipo: "Tutti" + vocabolario controllato.
	_type_opt.clear()
	_type_values = [""]
	_type_opt.add_item("Tutti i tipi")
	for pair in [["attack", "Attacco"], ["defence", "Difesa"],
			["meditation", "Meditazione"], ["core", "Base"], ["other", "Altro"]]:
		_type_opt.add_item(pair[1])
		_type_values.append(pair[0])

	# Rank: "Tutti" + i quattro rami + Core.
	_rank_opt.clear()
	_rank_values = [""]
	_rank_opt.add_item("Tutti i rank")
	for pair in [["Wood", "Legno"], ["Steel", "Acciaio"], ["Gold", "Oro"],
			["Jade", "Giada"], ["-", "— (Base)"]]:
		_rank_opt.add_item(pair[1])
		_rank_values.append(pair[0])


func _refresh_list() -> void:
	var want_char: String = _char_values[_char_opt.selected] if _char_opt.selected >= 0 else ""
	var want_type: String = _type_values[_type_opt.selected] if _type_opt.selected >= 0 else ""
	var want_rank: String = _rank_values[_rank_opt.selected] if _rank_opt.selected >= 0 else ""
	var needle: String = _search.text.strip_edges().to_lower()

	var ids: Array = CardDB.by_id.keys()
	ids.sort()

	_list.clear()
	var shown := 0
	for id in ids:
		var c: Dictionary = CardDB.by_id[id]
		if want_char != "" and str(c.get("char", "")) != want_char:
			continue
		if want_type != "" and str(c.get("type", "")) != want_type:
			continue
		if want_rank != "" and str(c.get("rank", "")) != want_rank:
			continue
		if needle != "" and not str(c.get("name", "")).to_lower().contains(needle):
			continue
		var has_geom := not CardDB.geometry(id).is_empty()
		var has_img := CardDB.image_for(id) != ""
		var flags := ""
		if not has_geom:
			flags += " ◇"   # senza geometria
		if not has_img:
			flags += " ✕"   # senza immagine
		var idx := _list.add_item("#%d  %s%s" % [id, str(c.get("name", "?")), flags])
		_list.set_item_metadata(idx, id)
		shown += 1

	_count.text = "%d / %d carte  ·  ◇ senza geometria  ✕ senza immagine" % [shown, ids.size()]

	# Mantieni selezione se ancora visibile.
	if _selected_id != -1:
		for i in _list.item_count:
			if int(_list.get_item_metadata(i)) == _selected_id:
				_list.select(i)
				return


func _on_item_selected(idx: int) -> void:
	_selected_id = int(_list.get_item_metadata(idx))
	_show_card(_selected_id)


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/Menu.tscn")


# ─── Pannello di dettaglio ───────────────────────────────────────────────────

func _show_card(id: int) -> void:
	for ch in _detail.get_children():
		ch.queue_free()
	var c: Dictionary = CardDB.card(id)

	_add_heading(str(c.get("name", "?")))

	# Anagrafica (card_pool.json)
	_add_section("Anagrafica")
	_add_field("id", str(id) + "  (read-only)")
	_add_field("nome", str(c.get("name", "")))
	_add_field("personaggio", str(c.get("char", "")))
	_add_field("amount", str(c.get("amount", "")))
	var rank_str := str(c.get("rank", "-"))
	var rank := Domain.parse_rank(rank_str)
	_add_field_colored("rank", "%s (%s)" % [Domain.RANK_LABELS.get(rank, "—"), rank_str],
			Domain.RANK_COLORS.get(rank, Color.GRAY))
	_add_field("initiative", str(c.get("initiative", "-")))
	_add_field("focus", str(c.get("focus", 0)))
	_add_field("keywords", ", ".join(_as_strings(c.get("keywords", []))))
	var typ := Domain.parse_card_type(str(c.get("type", "")))
	_add_field("type", "%s (%s)" % [Domain.CARD_TYPE_LABELS.get(typ, "?"), str(c.get("type", ""))])

	# Geometria/effetti (geometry.json)
	var g: Dictionary = CardDB.geometry(id)
	_add_section("Geometria / effetti")
	if g.is_empty():
		var none := Label.new()
		none.text = "— Nessuna geometria trascritta per questa carta."
		none.add_theme_color_override("font_color", Color(0.85, 0.6, 0.3))
		_detail.add_child(none)
	else:
		_add_multiline("riassunto", _geometry_summary(g))
		_add_multiline("JSON", JSON.stringify(g, "  "))

	# Immagine (card_images.json)
	_add_section("Immagine")
	var img := CardDB.image_for(id)
	_add_field("path", img if img != "" else "(nessuna)")

	_update_preview(id, c, img)
	_update_indicators(g, img)


func _geometry_summary(g: Dictionary) -> String:
	var lines: Array = []
	lines.append("tipo: %s" % str(g.get("type", "?")))
	if g.has("kamae_req"):
		lines.append("kamae richiesto: %s" % str(g["kamae_req"]))
	if g.has("move"):
		var opts: Array = g.get("move", {}).get("opts", [])
		var parts: Array = []
		for opt in opts:
			var atoms: Array = []
			for a in opt.get("atoms", []):
				var s := "passo" if a.get("t", "") == "step" else "rotazione"
				if a.get("t", "") == "step":
					s += " dir%s" % str(a.get("dir", "?"))
				s += " x%s" % str(a.get("n", 1))
				if a.get("opt", false):
					s += " (opz.)"
				atoms.append(s)
			parts.append(" + ".join(atoms))
		lines.append("movimento: %s" % " OPPURE ".join(parts))
	if g.has("attack"):
		var cells: Array = g.get("attack", {}).get("cells", [])
		var cs: Array = []
		for cell in cells:
			cs.append("dir%s/anello%s→%s" % [str(cell.get("d", "?")), str(cell.get("k", "?")), str(cell.get("w", "?"))])
		lines.append("attacco (%d celle): %s" % [cells.size(), ", ".join(cs)])
	if g.has("defence"):
		var cells: Array = g.get("defence", {}).get("cells", [])
		var cs: Array = []
		for cell in cells:
			cs.append("dir%s/anello%s blocco%s" % [str(cell.get("d", "?")), str(cell.get("k", "?")), str(cell.get("v", "?"))])
		lines.append("difesa (%d celle): %s" % [cells.size(), ", ".join(cs)])
	if g.has("counter"):
		lines.append("contrattacco a iniziative: %s" % str(g.get("counter")))
	if g.has("effects"):
		var effs: Array = g.get("effects", [])
		var es: Array = []
		for e in effs:
			es.append(str(e.get("do", "?")))
		lines.append("effetti (%d): %s" % [effs.size(), ", ".join(es)])
	if g.has("note") and str(g.get("note", "")) != "":
		lines.append("nota: %s" % str(g.get("note")))
	return "\n".join(lines)


# ─── Anteprima & indicatori ──────────────────────────────────────────────────

func _update_preview(id: int, c: Dictionary, img: String) -> void:
	for ch in _preview_holder.get_children():
		ch.queue_free()
	var cv := CardView.new()
	_preview_holder.add_child(cv)
	# CardView mostra l'immagine reale se l'entry ha "file", altrimenti la
	# scheda data-driven dai campi anagrafici.
	if img != "":
		var entry := c.duplicate(true)
		entry["file"] = img
		cv.setup(entry)
	else:
		cv.setup(c)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _update_indicators(g: Dictionary, img: String) -> void:
	var lines: Array = []
	if g.is_empty():
		lines.append("⚠ Senza geometria")
	else:
		lines.append("✓ Geometria presente")
	if img == "":
		lines.append("⚠ Senza immagine")
	else:
		lines.append("✓ Immagine presente")
	_indicators.text = "\n".join(lines)


# ─── Helper di layout ────────────────────────────────────────────────────────

func _add_heading(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(l)


func _add_section(text: String) -> void:
	var sep := HSeparator.new()
	_detail.add_child(sep)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color(0.7, 0.78, 0.9))
	_detail.add_child(l)


func _add_field(key: String, value: String) -> void:
	var hb := HBoxContainer.new()
	var k := Label.new()
	k.text = key
	k.custom_minimum_size = Vector2(110, 0)
	k.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	hb.add_child(k)
	var v := Label.new()
	v.text = value
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hb.add_child(v)
	_detail.add_child(hb)


func _add_field_colored(key: String, value: String, color: Color) -> void:
	_add_field(key, value)
	var last: HBoxContainer = _detail.get_child(_detail.get_child_count() - 1)
	(last.get_child(1) as Label).add_theme_color_override("font_color", color)


func _add_multiline(key: String, value: String) -> void:
	var k := Label.new()
	k.text = key
	k.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_detail.add_child(k)
	var te := TextEdit.new()
	te.text = value
	te.editable = false
	te.scroll_fit_content_height = true
	te.custom_minimum_size = Vector2(0, 60)
	te.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_child(te)


func _as_strings(arr) -> Array:
	var out: Array = []
	if arr is Array:
		for x in arr:
			out.append(str(x))
	return out
