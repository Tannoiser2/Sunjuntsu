## Editor di carte — Senjutsu
##
## Scena standalone (decisione §4.2), raggiungibile dal Menu e testabile headless.
##  - Fase 1: browser con filtri + inspector con anteprima (CardView).
##  - Fase 2: editing dell'ANAGRAFICA con widget tipizzati, ricalcolo automatico
##    di `type` dai keywords, creazione/duplica carta e salvataggio via overlay
##    (engine/CardStore.gd → card_pool_overrides.json), senza toccare l'Excel.
##
## Geometria/effetti e immagine restano in sola lettura (Fasi 4/6).
## Vedi docs/CARD_EDITOR_ROADMAP.md.
extends Control

const CardView := preload("res://scenes/CardView.gd")

## Keyword note per l'autocomplete (vocabolario §3.3 + dati reali).
const KNOWN_KEYWORDS := [
	"Attack", "Defence", "Attack/Defence", "Meditation", "Core",
	"Instant", "Instant Replacement", "Instant Additional",
	"Prepared", "Bushido", "Weapon", "Solo",
	"Range1", "Range2", "Range3", "Range4", "Range5", "Range6",
]

## Valori dei filtri a tendina, paralleli agli indici degli OptionButton.
var _char_values: Array = []
var _type_values: Array = []
var _rank_values: Array = []

# Widget del browser.
var _search: LineEdit
var _char_opt: OptionButton
var _type_opt: OptionButton
var _rank_opt: OptionButton
var _list: ItemList
var _count: Label

# Pannello di dettaglio / editing.
var _form: VBoxContainer
var _status: Label
var _preview_holder: Control
var _indicators: Label
var _btn_new: Button
var _btn_dup: Button
var _btn_save: Button
var _btn_cancel: Button
var _btn_remove: Button

# Stato di editing.
var _store: CardStore
var _w: Dictionary = {}          ## campo -> widget editabile
var _w_type: Label               ## etichetta `type` derivata (read-only)
var _geom_editor: GeometryEditor ## editor visuale geometria (Fase 4)
var _issues_box: VBoxContainer   ## pannello avvisi di validazione (Fase 3)
var _current_id: int = -1
var _pending_new: bool = false   ## carta creata/duplicata non ancora salvata


func _ready() -> void:
	_store = CardStore.new()
	_store.load_overrides()
	_build_ui()
	_populate_filters()
	_refresh_list()
	_clear_form_to_hint()
	_update_toolbar()


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
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)

	var tb := HBoxContainer.new()
	tb.add_theme_constant_override("separation", 6)
	_btn_new = _toolbar_button(tb, "Nuova", _on_new)
	_btn_dup = _toolbar_button(tb, "Duplica", _on_duplicate)
	_btn_save = _toolbar_button(tb, "Salva", _on_save)
	_btn_cancel = _toolbar_button(tb, "Annulla", _on_cancel)
	_btn_remove = _toolbar_button(tb, "Rimuovi override", _on_remove_override)
	col.add_child(tb)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 12)
	_status.add_theme_color_override("font_color", Color(0.7, 0.78, 0.9))
	col.add_child(_status)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_form = VBoxContainer.new()
	_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form.add_theme_constant_override("separation", 4)
	scroll.add_child(_form)
	col.add_child(scroll)
	return col


func _toolbar_button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


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
	_char_opt.clear()
	_char_values = [""]
	_char_opt.add_item("Tutti i personaggi")
	for c in _char_list():
		_char_opt.add_item(str(c))
		_char_values.append(str(c))

	_type_opt.clear()
	_type_values = [""]
	_type_opt.add_item("Tutti i tipi")
	for pair in [["attack", "Attacco"], ["defence", "Difesa"],
			["meditation", "Meditazione"], ["core", "Base"], ["other", "Altro"]]:
		_type_opt.add_item(pair[1])
		_type_values.append(pair[0])

	_rank_opt.clear()
	_rank_values = [""]
	_rank_opt.add_item("Tutti i rank")
	for pair in [["Wood", "Legno"], ["Steel", "Acciaio"], ["Gold", "Oro"],
			["Jade", "Giada"], ["-", "— (Base)"]]:
		_rank_opt.add_item(pair[1])
		_rank_values.append(pair[0])


func _char_list() -> Array:
	var a: Array = CardDB.by_char.keys()
	a.sort()
	return a


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
		var flags := ""
		if CardDB.geometry(id).is_empty():
			flags += " ◇"
		if CardDB.image_for(id) == "":
			flags += " ✕"
		if id >= 10000:
			flags += " ★"   # carta creata dall'editor
		var idx := _list.add_item("#%d  %s%s" % [id, str(c.get("name", "?")), flags])
		_list.set_item_metadata(idx, id)
		shown += 1

	_count.text = "%d / %d carte  ·  ◇ no geometria  ✕ no immagine  ★ carta-utente" % [shown, ids.size()]
	_select_in_list(_current_id)


func _select_in_list(id: int) -> void:
	if id < 0:
		return
	for i in _list.item_count:
		if int(_list.get_item_metadata(i)) == id:
			_list.select(i)
			return


func _on_item_selected(idx: int) -> void:
	_load_card(int(_list.get_item_metadata(idx)), false)


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/Menu.tscn")


# ─── Caricamento carta nel form ──────────────────────────────────────────────

func _load_card(id: int, is_new: bool, fields: Dictionary = {}) -> void:
	_current_id = id
	_pending_new = is_new
	var c: Dictionary = fields if not fields.is_empty() else CardDB.card(id)
	_build_form(id, c)
	var img := "" if is_new else CardDB.image_for(id)
	_update_preview(c, img)
	_update_indicators(CardDB.geometry(id), img)
	_update_toolbar()
	_run_validation()
	if is_new:
		_status.text = "Carta #%d non salvata — compila e premi Salva" % id
	elif not _store.get_override(id).is_empty():
		_status.text = "Override attivo per #%d" % id
	else:
		_status.text = "Carta #%d (dall'Excel)" % id


func _build_form(id: int, c: Dictionary) -> void:
	for ch in _form.get_children():
		ch.queue_free()
	_w = {}

	var head := Label.new()
	head.text = "#%d%s" % [id, "  ★ carta-utente" if id >= 10000 else ""]
	head.add_theme_font_size_override("font_size", 18)
	_form.add_child(head)

	_issues_box = VBoxContainer.new()
	_issues_box.add_theme_constant_override("separation", 1)
	_form.add_child(_issues_box)

	_add_section("Anagrafica  (editabile)")
	_w["name"] = _add_edit_text("nome", str(c.get("name", "")))
	_w["char"] = _add_edit_option("personaggio", _char_list(), str(c.get("char", "Warrior")))
	_w["amount"] = _add_edit_spin("amount", 1, 6, int(c.get("amount", 1)))
	_w["rank"] = _add_edit_option("rank", ["Wood", "Steel", "Gold", "Jade", "-"], str(c.get("rank", "-")))
	_w["initiative"] = _add_edit_text("initiative", str(c.get("initiative", "-")))
	_w["focus"] = _add_edit_spin("focus", 0, 9, int(c.get("focus", 0)))
	_build_keywords_field(c.get("keywords", []))

	# Geometria/effetti — editor visuale drag & drop (Fase 4).
	_add_section("Geometria / effetti  (visuale — trascina le icone)")
	_geom_editor = GeometryEditor.new()
	_geom_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form.add_child(_geom_editor)
	_geom_editor.load_geometry(str(c.get("type", "attack")), CardDB.geometry(id))
	_geom_editor.changed.connect(func(): _run_validation())
	var save_geo := Button.new()
	save_geo.text = "Salva geometria"
	save_geo.pressed.connect(_on_save_geometry)
	_form.add_child(save_geo)

	# Immagine — sola lettura.
	_add_section("Immagine  (sola lettura)")
	var img := "" if _pending_new else CardDB.image_for(id)
	_add_readonly_field("path", img if img != "" else "(nessuna)")


func _build_keywords_field(kws) -> void:
	var le := LineEdit.new()
	le.text = ", ".join(_as_strings(kws))
	le.text_changed.connect(func(_t): _recalc_type())
	_w["keywords"] = le
	_edit_row("keywords", le)

	var add := OptionButton.new()
	add.add_item("＋ aggiungi keyword nota")
	for kw in KNOWN_KEYWORDS:
		add.add_item(kw)
	add.item_selected.connect(_on_add_keyword.bind(add))
	_edit_row("", add)

	_w_type = Label.new()
	_edit_row("type (auto)", _w_type)
	_recalc_type()


func _on_add_keyword(idx: int, opt: OptionButton) -> void:
	if idx > 0:
		var kw := opt.get_item_text(idx)
		var cur := _parse_keywords()
		if not cur.has(kw):
			cur.append(kw)
			_w["keywords"].text = ", ".join(cur)
			_recalc_type()
	opt.selected = 0


func _parse_keywords() -> Array:
	var out: Array = []
	var le: LineEdit = _w["keywords"]
	for tok in le.text.split(","):
		var t := tok.strip_edges()
		if t != "":
			out.append(t)
	return out


func _recalc_type() -> void:
	if _w_type == null:
		return
	var t := CardStore.derive_type(_parse_keywords())
	var e := Domain.parse_card_type(t)
	_w_type.text = "%s  (%s)" % [Domain.CARD_TYPE_LABELS.get(e, "?"), t]
	_run_validation()


func _collect_fields() -> Dictionary:
	var kws := _parse_keywords()
	return {
		"id": _current_id,
		"name": _w["name"].text.strip_edges(),
		"char": _selected_text(_w["char"]),
		"amount": int(_w["amount"].value),
		"rank": _selected_text(_w["rank"]),
		"initiative": _w["initiative"].text.strip_edges(),
		"focus": int(_w["focus"].value),
		"keywords": kws,
		"type": CardStore.derive_type(kws),
	}


# ─── Azioni: salva / nuova / duplica / annulla / rimuovi override ─────────────

func _on_save() -> void:
	if _current_id < 0:
		return
	var fields := _collect_fields()
	var ov := _store.compute_override(_current_id, fields)
	_store.set_override(_current_id, ov)
	var res := _store.save_overrides()
	if not res.get("ok", false):
		_status.text = "✗ Errore salvataggio: %s" % str(res.get("error", ""))
		return
	CardDB.apply_override(_current_id, fields)
	var saved_id := _current_id
	_pending_new = false
	_refresh_list()
	_select_in_list(saved_id)
	_load_card(saved_id, false)
	if ov.is_empty():
		_status.text = "✓ Salvato #%d (nessuna differenza dall'Excel: override rimosso)" % saved_id
	else:
		_status.text = "✓ Salvato #%d (%d campi nell'overlay)" % [saved_id, ov.size()]


func _on_new() -> void:
	var id := _store.next_free_id(CardDB.by_id.keys())
	_load_card(id, true, CardStore.new_card_template(id, _default_char()))


func _on_duplicate() -> void:
	if _current_id < 0 or _pending_new:
		return
	var src := CardDB.card(_current_id)
	if src.is_empty():
		return
	var src_id := _current_id
	var id := _store.next_free_id(CardDB.by_id.keys())
	var fields := src.duplicate(true)
	fields["id"] = id
	fields["name"] = str(src.get("name", "")) + " (copia)"
	fields.erase("file")
	_load_card(id, true, fields)
	_status.text = "Duplicata da #%d → nuova #%d (non salvata)" % [src_id, id]


func _on_cancel() -> void:
	if _pending_new:
		_pending_new = false
		_current_id = -1
		_clear_form_to_hint()
		_update_toolbar()
		_status.text = "Creazione annullata"
	elif _current_id >= 0:
		_load_card(_current_id, false)
		_status.text = "Modifiche annullate"


func _on_remove_override() -> void:
	if _pending_new or _current_id < 0 or not _store.has_pristine(_current_id):
		return
	if _store.get_override(_current_id).is_empty():
		_status.text = "Nessun override da rimuovere"
		return
	_store.clear_override(_current_id)
	var res := _store.save_overrides()
	if not res.get("ok", false):
		_status.text = "✗ Errore: %s" % str(res.get("error", ""))
		return
	# Ripristina in memoria i valori originali dell'Excel.
	CardDB.apply_override(_current_id, _store.pristine_card(_current_id))
	var id := _current_id
	_refresh_list()
	_select_in_list(id)
	_load_card(id, false)
	_status.text = "✓ Override rimosso #%d (tornato all'Excel)" % id


func _on_save_geometry() -> void:
	if _current_id < 0 or _geom_editor == null:
		return
	var g := _geom_editor.to_geometry()
	var res := _store.save_card_geometry(_current_id, g)
	if not res.get("ok", false):
		_status.text = "✗ Errore geometria: %s" % str(res.get("error", ""))
		return
	CardDB.set_geometry(_current_id, g)
	var id := _current_id
	_refresh_list()
	_select_in_list(id)
	var na: int = g.get("attack", {}).get("cells", []).size()
	var nd: int = g.get("defence", {}).get("cells", []).size()
	_status.text = "✓ Geometria #%d salvata (%d celle att., %d dif.)" % [id, na, nd]
	_run_validation()


## Validazione live (Fase 3): valuta lo stato CORRENTE del form + geometria e
## mostra gli avvisi inline (⛔ errori bloccanti, ⚠ warning non bloccanti).
func _run_validation() -> void:
	if _issues_box == null or _current_id < 0:
		return
	for ch in _issues_box.get_children():
		ch.queue_free()
	var card: Dictionary = _collect_fields() if _w.has("name") else CardDB.card(_current_id)
	var geom: Dictionary = _geom_editor.to_geometry() if _geom_editor != null else CardDB.geometry(_current_id)
	var img := "" if _pending_new else CardDB.image_for(_current_id)
	var issues := CardValidator.validate(card, geom, img, {
		"known_keywords": CardValidator.known_keywords_set(),
		"duplicate": _count_id(_current_id) > 1,
	})
	if issues.is_empty():
		var ok := Label.new()
		ok.text = "✓ Nessun problema"
		ok.add_theme_font_size_override("font_size", 12)
		ok.add_theme_color_override("font_color", Color(0.45, 0.75, 0.5))
		_issues_box.add_child(ok)
		return
	for it in issues:
		var err: bool = it.get("level", "") == "error"
		var l := Label.new()
		l.text = "%s %s" % ["⛔" if err else "⚠", str(it.get("msg", ""))]
		l.add_theme_font_size_override("font_size", 12)
		l.add_theme_color_override("font_color", Color(0.9, 0.42, 0.42) if err else Color(0.92, 0.76, 0.4))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_issues_box.add_child(l)


func _count_id(id: int) -> int:
	var n := 0
	for c in CardDB.cards:
		if int(c.get("id", -999999)) == id:
			n += 1
	return n


func _default_char() -> String:
	var list := _char_list()
	return str(list[0]) if not list.is_empty() else "Warrior"


func _update_toolbar() -> void:
	var loaded := _current_id >= 0
	_btn_save.disabled = not loaded
	_btn_cancel.disabled = not loaded
	_btn_dup.disabled = not loaded or _pending_new
	var has_override := loaded and not _pending_new and _store.has_pristine(_current_id) \
			and not _store.get_override(_current_id).is_empty()
	_btn_remove.disabled = not has_override


func _clear_form_to_hint() -> void:
	for ch in _form.get_children():
		ch.queue_free()
	var hint := Label.new()
	hint.text = "Seleziona una carta, oppure premi «Nuova»."
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_form.add_child(hint)
	for ch in _preview_holder.get_children():
		ch.queue_free()
	_indicators.text = ""


# ─── Anteprima & indicatori ──────────────────────────────────────────────────

func _update_preview(c: Dictionary, img: String) -> void:
	for ch in _preview_holder.get_children():
		ch.queue_free()
	var cv := CardView.new()
	_preview_holder.add_child(cv)
	if img != "":
		var entry := c.duplicate(true)
		entry["file"] = img
		cv.setup(entry)
	else:
		cv.setup(c)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _update_indicators(g: Dictionary, img: String) -> void:
	var lines: Array = []
	lines.append("✓ Geometria presente" if not g.is_empty() else "⚠ Senza geometria")
	lines.append("✓ Immagine presente" if img != "" else "⚠ Senza immagine")
	_indicators.text = "\n".join(lines)


func _geometry_summary(g: Dictionary) -> String:
	var lines: Array = []
	lines.append("tipo: %s" % str(g.get("type", "?")))
	if g.has("kamae_req"):
		lines.append("kamae richiesto: %s" % str(g["kamae_req"]))
	if g.has("move"):
		var parts: Array = []
		for opt in g.get("move", {}).get("opts", []):
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
		var es: Array = []
		for e in g.get("effects", []):
			es.append(str(e.get("do", "?")))
		lines.append("effetti (%d): %s" % [g.get("effects", []).size(), ", ".join(es)])
	if g.has("note") and str(g.get("note", "")) != "":
		lines.append("nota: %s" % str(g.get("note")))
	return "\n".join(lines)


# ─── Helper di layout ────────────────────────────────────────────────────────

func _add_section(text: String) -> void:
	_form.add_child(HSeparator.new())
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color(0.7, 0.78, 0.9))
	_form.add_child(l)


func _edit_row(key: String, widget: Control) -> void:
	var hb := HBoxContainer.new()
	var k := Label.new()
	k.text = key
	k.custom_minimum_size = Vector2(110, 0)
	k.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	hb.add_child(k)
	widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(widget)
	_form.add_child(hb)


func _add_edit_text(key: String, val: String) -> LineEdit:
	var le := LineEdit.new()
	le.text = val
	_edit_row(key, le)
	return le


func _add_edit_spin(key: String, mn: int, mx: int, val: int) -> SpinBox:
	var sb := SpinBox.new()
	sb.min_value = mn
	sb.max_value = mx
	sb.step = 1
	sb.value = clampi(val, mn, mx)
	_edit_row(key, sb)
	return sb


func _add_edit_option(key: String, values: Array, current: String) -> OptionButton:
	var opt := OptionButton.new()
	var found := -1
	for i in values.size():
		opt.add_item(str(values[i]))
		if str(values[i]) == current:
			found = i
	if found == -1 and current != "":
		opt.add_item(current)
		found = opt.item_count - 1
	opt.selected = maxi(found, 0)
	_edit_row(key, opt)
	return opt


func _selected_text(opt: OptionButton) -> String:
	return opt.get_item_text(opt.selected) if opt.selected >= 0 else ""


func _add_readonly_field(key: String, value: String) -> void:
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
	_form.add_child(hb)


func _add_multiline(key: String, value: String) -> void:
	var k := Label.new()
	k.text = key
	k.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_form.add_child(k)
	var te := TextEdit.new()
	te.text = value
	te.editable = false
	te.scroll_fit_content_height = true
	te.custom_minimum_size = Vector2(0, 60)
	te.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form.add_child(te)


func _as_strings(arr) -> Array:
	var out: Array = []
	if arr is Array:
		for x in arr:
			out.append(str(x))
	return out
