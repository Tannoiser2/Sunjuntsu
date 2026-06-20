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
var _form: VBoxContainer         ## colonna "carta simulata" (gemello editabile)
var _status: Label
var _orig_preview: Control       ## colonna "carta originale" (immagine reale)
var _orig_indicators: Label
var _palette_holder: Control     ## colonna destra: palette trascinabili
var _btn_new: Button
var _btn_dup: Button
var _btn_save: Button
var _btn_cancel: Button
var _btn_remove: Button
var _btn_undo: Button
var _btn_redo: Button

# Stato di editing.
var _store: CardStore
var _w: Dictionary = {}          ## campo -> widget editabile
var _w_type: Label               ## etichetta `type` derivata (read-only)
var _geom_editor: GeometryEditor ## editor visuale geometria (Fase 4)
var _issues_box: VBoxContainer   ## pannello avvisi di validazione (Fase 3)
var _img_path_label: Label       ## path immagine corrente (Fase 6)
var _current_id: int = -1
var _pending_new: bool = false   ## carta creata/duplicata non ancora salvata

# Undo/redo (Fase 6): cronologia dello stato di editing (anagrafica + geometria)
# della carta corrente. Modello working-state, coerente col salvataggio esplicito.
var _history: Array = []
var _hist_idx: int = 0
var _suspend_record: bool = false   ## true durante (ri)costruzione del form


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
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	root.offset_left = 10; root.offset_top = 8
	root.offset_right = -10; root.offset_bottom = -8
	add_child(root)

	root.add_child(_build_topbar())

	var main := HBoxContainer.new()
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 10)
	root.add_child(main)
	main.add_child(_build_list_panel())     # lista stretta a sinistra
	main.add_child(_build_center())          # originale ↔ simulata
	main.add_child(_build_palette_panel())   # palette a destra

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 12)
	_status.add_theme_color_override("font_color", Color(0.7, 0.78, 0.9))
	root.add_child(_status)


## Riga in alto: azioni (a sinistra) + filtri (a destra).
func _build_topbar() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	_btn_new = _toolbar_button(bar, "Nuova", _on_new)
	_btn_dup = _toolbar_button(bar, "Duplica", _on_duplicate)
	_btn_save = _toolbar_button(bar, "Salva", _on_save)
	_btn_cancel = _toolbar_button(bar, "Annulla", _on_cancel)
	_btn_remove = _toolbar_button(bar, "Rim. ovr", _on_remove_override)
	_btn_remove.tooltip_text = "Rimuovi override"
	_btn_undo = _toolbar_button(bar, "Undo", _undo)
	_btn_redo = _toolbar_button(bar, "Redo", _redo)

	bar.add_child(VSeparator.new())

	_search = LineEdit.new()
	_search.placeholder_text = "Cerca…"
	_search.clear_button_enabled = true
	_search.custom_minimum_size = Vector2(120, 0)
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(func(_t): _refresh_list())
	bar.add_child(_search)
	_char_opt = _filter_option()
	_type_opt = _filter_option()
	_rank_opt = _filter_option()
	bar.add_child(_char_opt)
	bar.add_child(_type_opt)
	bar.add_child(_rank_opt)

	var back := Button.new()
	back.text = "Menu"
	back.add_theme_font_size_override("font_size", 12)
	back.pressed.connect(_on_back)
	bar.add_child(back)
	return bar


func _filter_option() -> OptionButton:
	var o := OptionButton.new()
	o.clip_text = true
	o.custom_minimum_size = Vector2(96, 0)
	o.add_theme_font_size_override("font_size", 12)
	o.item_selected.connect(func(_i): _refresh_list())
	return o


## Colonna sinistra stretta: solo l'elenco delle carte.
func _build_list_panel() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(110, 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_stretch_ratio = 1.2
	col.add_theme_constant_override("separation", 6)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(_on_item_selected)
	col.add_child(_list)
	_count = Label.new()
	_count.add_theme_font_size_override("font_size", 11)
	_count.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_count)
	return col


## Centro: carta ORIGINALE (immagine reale) ↔ carta SIMULATA (gemello editabile).
func _build_center() -> Control:
	var center := HBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_stretch_ratio = 6.5
	center.add_theme_constant_override("separation", 10)

	# Colonna ORIGINALE.
	var orig := VBoxContainer.new()
	orig.custom_minimum_size = Vector2(150, 0)
	orig.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	orig.size_flags_stretch_ratio = 1.3
	orig.add_theme_constant_override("separation", 4)
	var ol := Label.new()
	ol.text = "Carta originale"
	ol.add_theme_font_size_override("font_size", 14)
	ol.add_theme_color_override("font_color", Color(0.7, 0.78, 0.9))
	orig.add_child(ol)
	_orig_preview = CenterContainer.new()
	_orig_preview.custom_minimum_size = Vector2(156, 216)
	orig.add_child(_orig_preview)
	_img_path_label = Label.new()
	_img_path_label.text = "(nessuna)"
	_img_path_label.add_theme_font_size_override("font_size", 10)
	_img_path_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_img_path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	orig.add_child(_img_path_label)
	var imgbtns := HBoxContainer.new()
	imgbtns.add_theme_constant_override("separation", 4)
	for spec in [["Cambia", _open_image_picker], ["Importa", _open_image_import],
			["Togli", func(): _set_image("")]]:
		var b := Button.new()
		b.text = spec[0]
		b.add_theme_font_size_override("font_size", 11)
		b.pressed.connect(spec[1])
		imgbtns.add_child(b)
	orig.add_child(imgbtns)
	_orig_indicators = Label.new()
	_orig_indicators.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_orig_indicators.add_theme_font_size_override("font_size", 11)
	orig.add_child(_orig_indicators)
	center.add_child(orig)

	# Colonna SIMULATA (gemello) — larghezza FISSA: i contenuti larghi scorrono
	# dentro la colonna invece di espanderla e spingere la palette fuori schermo.
	var simcol := VBoxContainer.new()
	simcol.custom_minimum_size = Vector2(250, 0)
	simcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	simcol.size_flags_stretch_ratio = 3.2
	simcol.add_theme_constant_override("separation", 4)
	var sl := Label.new()
	sl.text = "Carta simulata"
	sl.add_theme_font_size_override("font_size", 14)
	sl.add_theme_color_override("font_color", Color(0.7, 0.78, 0.9))
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	simcol.add_child(sl)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED  # niente scroll orizzontale
	_form = VBoxContainer.new()
	_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form.add_theme_constant_override("separation", 4)
	scroll.add_child(_form)
	simcol.add_child(scroll)
	center.add_child(simcol)
	return center


func _toolbar_button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 12)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


## Colonna destra: contenitore della palette (riempito per carta in _build_form).
func _build_palette_panel() -> Control:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(140, 0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = 1.4
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_palette_holder = VBoxContainer.new()
	_palette_holder.add_theme_constant_override("separation", 6)
	scroll.add_child(_palette_holder)
	return scroll


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
			flags += " ~g"
		if CardDB.image_for(id) == "":
			flags += " ~i"
		if id >= 10000:
			flags += " *"   # carta creata dall'editor
		var idx := _list.add_item("#%d  %s%s" % [id, str(c.get("name", "?")), flags])
		_list.set_item_metadata(idx, id)
		shown += 1

	_count.text = "%d / %d carte   ~g no geometria · ~i no immagine · * carta-utente" % [shown, ids.size()]
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
	_reset_history()
	if is_new:
		_status.text = "Carta #%d non salvata — compila e premi Salva" % id
	elif not _store.get_override(id).is_empty():
		_status.text = "Override attivo per #%d" % id
	else:
		_status.text = "Carta #%d (dall'Excel)" % id


func _build_form(id: int, c: Dictionary, geom_data = null) -> void:
	_suspend_record = true
	for ch in _form.get_children():
		ch.queue_free()
	_w = {}

	var head := Label.new()
	head.text = "#%d%s" % [id, "  * carta-utente" if id >= 10000 else ""]
	head.add_theme_font_size_override("font_size", 18)
	_form.add_child(head)

	_issues_box = VBoxContainer.new()
	_issues_box.add_theme_constant_override("separation", 1)
	_form.add_child(_issues_box)

	_add_section("Anagrafica")
	_w["name"] = _add_edit_text("nome", str(c.get("name", "")))
	_w["char"] = _add_edit_option("personaggio", _char_list(), str(c.get("char", "Warrior")))
	_w["amount"] = _add_edit_spin("amount", 1, 6, int(c.get("amount", 1)))
	_w["rank"] = _add_edit_option("rank", ["Wood", "Steel", "Gold", "Jade", "-"], str(c.get("rank", "-")))
	_w["initiative"] = _add_edit_text("initiative", str(c.get("initiative", "-")))
	_w["focus"] = _add_edit_spin("focus", 0, 9, int(c.get("focus", 0)))
	_build_keywords_field(c.get("keywords", []))
	# Registrazione undo/redo + validazione su ogni modifica dell'anagrafica.
	_w["name"].text_changed.connect(func(_t): _on_edit())
	_w["char"].item_selected.connect(func(_i): _on_edit())
	_w["amount"].value_changed.connect(func(_v): _on_edit())
	_w["rank"].item_selected.connect(func(_i): _on_edit())
	_w["initiative"].text_changed.connect(func(_t): _on_edit())
	_w["focus"].value_changed.connect(func(_v): _on_edit())

	# Geometria/effetti — editor visuale drag & drop (Fase 4).
	_add_section("Geometria / effetti")
	_geom_editor = GeometryEditor.new()
	_geom_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form.add_child(_geom_editor)
	var geom_src: Dictionary = geom_data if geom_data != null else CardDB.geometry(id)
	_geom_editor.load_geometry(str(c.get("type", "attack")), geom_src)
	_geom_editor.changed.connect(func(): _on_edit())
	var geobtns := HBoxContainer.new()
	var save_geo := Button.new()
	save_geo.text = "Salva geometria"
	save_geo.pressed.connect(_on_save_geometry)
	geobtns.add_child(save_geo)
	var sim := Button.new()
	sim.text = "Simula carta"
	sim.tooltip_text = "Risolve il gemello contro un avversario fittizio e mostra l'esito"
	sim.pressed.connect(_on_simulate)
	geobtns.add_child(sim)
	_form.add_child(geobtns)

	# Palette trascinabile nella colonna destra (legata a questo GeometryEditor).
	for ch in _palette_holder.get_children():
		ch.queue_free()
	_palette_holder.add_child(_geom_editor.build_palette())

	_suspend_record = false


func _build_keywords_field(kws) -> void:
	var le := LineEdit.new()
	le.text = ", ".join(_as_strings(kws))
	le.text_changed.connect(func(_t): _recalc_type(); _record())
	_w["keywords"] = le
	_edit_row("keywords", le)

	var add := OptionButton.new()
	add.add_item("+ keyword")
	for kw in KNOWN_KEYWORDS:
		add.add_item(kw)
	add.item_selected.connect(_on_add_keyword.bind(add))
	_edit_row("", add)

	_w_type = Label.new()
	_edit_row("type", _w_type)
	_recalc_type()


func _on_add_keyword(idx: int, opt: OptionButton) -> void:
	if idx > 0:
		var kw := opt.get_item_text(idx)
		var cur := _parse_keywords()
		if not cur.has(kw):
			cur.append(kw)
			_w["keywords"].text = ", ".join(cur)
			_recalc_type()
			_record()
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
		_status.text = "Errore salvataggio: %s" % str(res.get("error", ""))
		return
	CardDB.apply_override(_current_id, fields)
	var saved_id := _current_id
	_pending_new = false
	_refresh_list()
	_select_in_list(saved_id)
	_load_card(saved_id, false)
	if ov.is_empty():
		_status.text = "Salvato #%d (override rimosso: identica all'Excel)" % saved_id
	else:
		_status.text = "Salvato #%d (%d campi nell'overlay)" % [saved_id, ov.size()]


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
	_status.text = "Duplicata da #%d -> nuova #%d (non salvata)" % [src_id, id]


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
		_status.text = "Errore: %s" % str(res.get("error", ""))
		return
	# Ripristina in memoria i valori originali dell'Excel.
	CardDB.apply_override(_current_id, _store.pristine_card(_current_id))
	var id := _current_id
	_refresh_list()
	_select_in_list(id)
	_load_card(id, false)
	_status.text = "Override rimosso #%d (tornato all'Excel)" % id


func _on_save_geometry() -> void:
	if _current_id < 0 or _geom_editor == null:
		return
	var g := _geom_editor.to_geometry()
	var res := _store.save_card_geometry(_current_id, g)
	if not res.get("ok", false):
		_status.text = "Errore geometria: %s" % str(res.get("error", ""))
		return
	CardDB.set_geometry(_current_id, g)
	var id := _current_id
	_refresh_list()
	_select_in_list(id)
	var na: int = g.get("attack", {}).get("cells", []).size()
	var nd: int = g.get("defence", {}).get("cells", []).size()
	_status.text = "Geometria #%d salvata (%d celle att., %d dif.)" % [id, na, nd]
	_run_validation()


## ─── Tester "Simula carta" (Fase 5) ─────────────────────────────────────────

func _on_simulate() -> void:
	if _current_id < 0 or _geom_editor == null:
		return
	var card: Dictionary = _collect_fields() if _w.has("name") else CardDB.card(_current_id)
	var geom := _geom_editor.to_geometry()
	_show_sim_result(CardSimulator.simulate(card, geom))


func _show_sim_result(r: Dictionary) -> void:
	var pop := PopupPanel.new()
	add_child(pop)
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(480, 380)
	vb.add_theme_constant_override("separation", 6)

	var head := Label.new()
	head.add_theme_font_size_override("font_size", 16)
	if r.get("hit", false):
		var tags = r.get("target_tags", [])
		var suffix := ""
		if tags is Array and not tags.is_empty():
			suffix = " (%s)" % ", ".join(tags.map(func(x): return str(x)))
		head.text = "COLPITO — %d ferita/e%s" % [int(r.get("target_wounds", 0)), suffix]
		head.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
	else:
		head.text = "Mancato (fuori arco / parato / carta non offensiva)"
		head.add_theme_color_override("font_color", Color(0.9, 0.7, 0.4))
	vb.add_child(head)

	var sub := Label.new()
	sub.text = "Attaccante: cella %s · facing %d · focus %d   |   bersaglio in %s" % [
		str(r.get("attacker_cell")), int(r.get("attacker_facing", 0)),
		int(r.get("attacker_focus", 0)), str(r.get("target_cell"))]
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color(0.6, 0.66, 0.74))
	vb.add_child(sub)

	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var logbox := VBoxContainer.new()
	logbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ll := Label.new()
	ll.text = "Log di risoluzione:"
	ll.add_theme_color_override("font_color", Color(0.7, 0.78, 0.9))
	logbox.add_child(ll)
	for line in r.get("log", []):
		var l := Label.new()
		l.text = "- " + str(line)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		logbox.add_child(l)
	sc.add_child(logbox)
	vb.add_child(sc)

	var close := Button.new()
	close.text = "Chiudi"
	close.pressed.connect(pop.queue_free)
	vb.add_child(close)
	pop.add_child(vb)
	pop.popup_centered(Vector2i(520, 440))


## ─── Undo / Redo (Fase 6) ───────────────────────────────────────────────────

func _on_edit() -> void:
	_run_validation()
	_record()


func _snapshot() -> Dictionary:
	return {
		"ana": _collect_fields() if _w.has("name") else {},
		"geo": _geom_editor.to_geometry() if _geom_editor != null else {},
	}


func _record() -> void:
	if _suspend_record or _current_id < 0:
		return
	var snap := _snapshot()
	if not _history.is_empty() \
			and _history[_hist_idx].get("ana") == snap["ana"] \
			and _history[_hist_idx].get("geo") == snap["geo"]:
		return   # nessun cambiamento effettivo
	_history.resize(_hist_idx + 1)   # tronca il "redo" oltre il punto corrente
	_history.append(snap)
	_hist_idx = _history.size() - 1
	_update_undo_buttons()


func _reset_history() -> void:
	_history = [_snapshot()]
	_hist_idx = 0
	_update_undo_buttons()


func _undo() -> void:
	if _hist_idx <= 0:
		return
	_hist_idx -= 1
	_restore(_history[_hist_idx])
	_status.text = "Undo (%d/%d)" % [_hist_idx + 1, _history.size()]


func _redo() -> void:
	if _hist_idx >= _history.size() - 1:
		return
	_hist_idx += 1
	_restore(_history[_hist_idx])
	_status.text = "Redo (%d/%d)" % [_hist_idx + 1, _history.size()]


func _restore(snap: Dictionary) -> void:
	var ana: Dictionary = snap.get("ana", {})
	var geo: Dictionary = snap.get("geo", {})
	_build_form(_current_id, ana if not ana.is_empty() else CardDB.card(_current_id), geo)
	var img := "" if _pending_new else CardDB.image_for(_current_id)
	_update_preview(ana, img)
	_update_indicators(CardDB.geometry(_current_id), img)
	_run_validation()
	_update_undo_buttons()


func _update_undo_buttons() -> void:
	if _btn_undo != null:
		_btn_undo.disabled = _hist_idx <= 0
	if _btn_redo != null:
		_btn_redo.disabled = _hist_idx >= _history.size() - 1


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.ctrl_pressed and event.keycode == KEY_Z:
		_redo() if event.shift_pressed else _undo()
		accept_event()
	elif event.ctrl_pressed and event.keycode == KEY_Y:
		_redo()
		accept_event()


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
		ok.text = "Nessun problema"
		ok.add_theme_font_size_override("font_size", 12)
		ok.add_theme_color_override("font_color", Color(0.45, 0.75, 0.5))
		_issues_box.add_child(ok)
		return
	for it in issues:
		var err: bool = it.get("level", "") == "error"
		var l := Label.new()
		l.text = "%s %s" % ["[!]" if err else "[~]", str(it.get("msg", ""))]
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


## ─── Immagini (Fase 6) ──────────────────────────────────────────────────────

func _current_char() -> String:
	if _w.has("char"):
		return _selected_text(_w["char"])
	return str(CardDB.card(_current_id).get("char", ""))


## Associa/azzera l'immagine della carta corrente e aggiorna tutto in vivo.
func _set_image(rel: String) -> void:
	if _current_id < 0:
		return
	var res := _store.save_image_for(_current_id, rel)
	if not res.get("ok", false):
		_status.text = "✗ Errore immagine: %s" % str(res.get("error", ""))
		return
	CardDB.set_image(_current_id, rel)
	if _img_path_label != null:
		_img_path_label.text = rel if rel != "" else "(nessuna)"
	var card: Dictionary = _collect_fields() if _w.has("name") else CardDB.card(_current_id)
	_update_preview(card, rel)
	_update_indicators(CardDB.geometry(_current_id), rel)
	_refresh_list()
	_select_in_list(_current_id)
	_run_validation()
	_status.text = "Immagine #%d %s" % [_current_id, "rimossa" if rel == "" else rel]


## Picker delle immagini già presenti in assets/cards (cartella del personaggio
## in cima), come griglia di miniature.
func _open_image_picker() -> void:
	if _current_id < 0:
		return
	var pop := PopupPanel.new()
	add_child(pop)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(540, 480)
	var grid := GridContainer.new()
	grid.columns = 4
	var slug := CardStore.char_slug(_current_char())
	var imgs := CardStore.list_card_images()
	imgs.sort_custom(func(a, b):
		var pa: bool = a.begins_with(slug + "/")
		var pb: bool = b.begins_with(slug + "/")
		if pa != pb:
			return pa
		return a < b)
	for rel in imgs:
		var b := Button.new()
		b.custom_minimum_size = Vector2(120, 165)
		b.icon = CardView._load_texture("res://assets/cards/" + rel)
		b.expand_icon = true
		b.tooltip_text = rel
		b.pressed.connect(func():
			pop.queue_free()
			_set_image(rel))
		grid.add_child(b)
	scroll.add_child(grid)
	pop.add_child(scroll)
	pop.popup_centered(Vector2i(580, 540))


## Importa un file immagine dal disco e apre il dialog di ritaglio.
func _open_image_import() -> void:
	if _current_id < 0:
		return
	var fd := FileDialog.new()
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.filters = ["*.png, *.jpg, *.jpeg, *.webp ; Immagini"]
	add_child(fd)
	fd.file_selected.connect(func(path: String):
		fd.queue_free()
		var img := Image.new()
		if img.load(path) != OK:
			_status.text = "✗ Impossibile caricare: %s" % path
			return
		_open_crop_dialog(img))
	fd.canceled.connect(fd.queue_free)
	fd.popup_centered(Vector2i(760, 520))


func _open_crop_dialog(img: Image) -> void:
	var dlg := ImageCropDialog.new()
	add_child(dlg)
	dlg.setup(img)
	dlg.cropped.connect(func(region: Rect2i):
		var slug := CardStore.char_slug(_current_char())
		if slug == "":
			slug = "carta"
		var dest := CardStore.next_image_name(slug)
		var res := CardStore.crop_and_save_webp(img, region, dest)
		if not res.get("ok", false):
			_status.text = "✗ Ritaglio: %s" % str(res.get("error", ""))
			return
		_set_image(dest))
	dlg.popup_centered()


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
	for ch in _orig_preview.get_children():
		ch.queue_free()
	for ch in _palette_holder.get_children():
		ch.queue_free()
	_orig_indicators.text = ""
	_img_path_label.text = "(nessuna)"
	_w = {}
	_geom_editor = null
	_history = []
	_hist_idx = 0
	_update_undo_buttons()


# ─── Carta originale (colonna sinistra del centro) & indicatori ──────────────

## Mostra l'immagine REALE della carta (grande) per il confronto col gemello.
## Se non c'è immagine, un segnaposto. Aggiorna anche il path.
func _update_preview(c: Dictionary, img: String) -> void:
	for ch in _orig_preview.get_children():
		ch.queue_free()
	_img_path_label.text = img if img != "" else "(nessuna)"
	if img != "":
		var tr := TextureRect.new()
		tr.texture = CardView._load_texture("res://assets/cards/" + img)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(156, 216)
		_orig_preview.add_child(tr)
	else:
		var ph := Label.new()
		ph.text = "(nessuna immagine originale)\nusa «Cambia…» o «Importa»"
		ph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ph.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
		_orig_preview.add_child(ph)


func _update_indicators(g: Dictionary, img: String) -> void:
	var lines: Array = []
	lines.append("✓ Geometria presente" if not g.is_empty() else "⚠ Senza geometria")
	lines.append("✓ Immagine presente" if img != "" else "⚠ Senza immagine")
	_orig_indicators.text = "  ·  ".join(lines)


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
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(0.7, 0.78, 0.9))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(120, 0)
	_form.add_child(l)


func _edit_row(key: String, widget: Control) -> void:
	var hb := HBoxContainer.new()
	var k := Label.new()
	k.text = key
	k.custom_minimum_size = Vector2(78, 0)
	k.add_theme_font_size_override("font_size", 11)
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
	opt.clip_text = true
	opt.custom_minimum_size = Vector2(80, 0)
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
