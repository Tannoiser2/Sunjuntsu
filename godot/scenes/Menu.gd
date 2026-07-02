## Menu principale — Senjutsu
extends Control


func _ready() -> void:
	$VBox/SoloButton.pressed.connect(_on_solo)
	$VBox/VersusButton.pressed.connect(_on_versus)
	$VBox/OnlineButton.pressed.connect(_on_online)
	$VBox/EditorButton.pressed.connect(_on_editor)
	$VBox/QuitButton.pressed.connect(func(): get_tree().quit())

	var version: String = str(ProjectSettings.get_setting("application/config/version", "?"))
	$Version.text = "v%s" % version
	$Changes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$Changes.text = _latest_changes(version)


## Ricava le "Novità" dall'ultima voce del CHANGELOG.md (titolo + primi punti),
## così lo splash resta sempre allineato. Fallback se il file non è leggibile
## (es. build esportata in cui non è impacchettato).
func _latest_changes(version: String) -> String:
	# Il file vive dentro il progetto (res://CHANGELOG.md) così è leggibile sia
	# nell'editor sia nelle build esportate (incluso via include_filter "*.md").
	# Fallback: vecchia posizione alla root del repo, per sicurezza.
	var path := "res://CHANGELOG.md"
	if not FileAccess.file_exists(path):
		path = ProjectSettings.globalize_path("res://").path_join("../CHANGELOG.md")
	if not FileAccess.file_exists(path):
		return "Novità v%s — vedi CHANGELOG.md" % version
	var lines := FileAccess.get_file_as_string(path).split("\n")
	var out: Array = []
	var started := false
	var bullets := 0
	for raw in lines:
		var line := str(raw)
		if line.begins_with("## ["):
			if started:
				break
			started = true
			# "## [0.62.0] — 2026-06-21" → "Novità v0.62.0 — 2026-06-21"
			out.append("Novità v" + line.substr(4).replace("] —", " —").replace("]", "").strip_edges())
		elif started and line.begins_with("### "):
			out.append(_clean_md(line.substr(4)))
		elif started and line.strip_edges().begins_with("- ") and bullets < 3:
			out.append("• " + _trunc(_clean_md(line.strip_edges().substr(2)), 92))
			bullets += 1
	if out.is_empty():
		return "Novità v%s — vedi CHANGELOG.md" % version
	return "\n".join(out)


func _clean_md(s: String) -> String:
	return s.replace("**", "").replace("`", "").strip_edges()


func _trunc(s: String, n: int) -> String:
	return s if s.length() <= n else s.substr(0, n - 1).strip_edges() + "…"


func _on_solo() -> void:
	# Solo: giocatore (pedina 0) contro l'IA solitaria (pedina 1).
	_show_char_select("solo")


func _on_versus() -> void:
	# 1v1 locale (hot-seat): due giocatori umani sullo stesso dispositivo, con
	# TUTTA la logica del duello (programmazione coperta a turno, rivelazione,
	# risoluzione per iniziativa). Si passano il dispositivo tra le fasi.
	_show_char_select("versus")


# ─── Selezione dei combattenti (ritratti da assets/portraits) ─────────────────

var _select_layer: Control
var _select_title: Label
var _pending_mode := ""
var _picked: Array = []


## Overlay di selezione: prima il combattente del Giocatore 1, poi quello del
## Giocatore 2 (o dell'IA in modalità solo). Al termine imposta
## Domain.selected_chars e avvia l'Arena.
func _show_char_select(mode: String) -> void:
	_pending_mode = mode
	_picked = []
	if _select_layer != null:
		_select_layer.queue_free()
	_select_layer = Control.new()
	_select_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_select_layer)

	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.05, 0.05, 0.07, 0.9)
	_select_layer.add_child(scrim)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(920, 560)
	box.offset_left = -460; box.offset_right = 460
	box.offset_top = -280; box.offset_bottom = 280
	box.add_theme_constant_override("separation", 14)
	_select_layer.add_child(box)

	_select_title = Label.new()
	_select_title.add_theme_font_size_override("font_size", 26)
	_select_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_select_title)
	_update_select_title()

	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(grid)
	for ch in Domain.ROSTER:
		grid.add_child(_char_cell(str(ch)))

	var back := Button.new()
	back.text = "Indietro"
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func():
		_select_layer.queue_free()
		_select_layer = null)
	box.add_child(back)


## Cella del roster: ritratto (o iniziale, se il ritratto manca — es. Hachikō)
## + nome italiano, cliccabile.
func _char_cell(ch: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(122, 158)
	btn.pressed.connect(func(): _on_char_picked(ch))
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 4)
	btn.add_child(v)
	var tex := CardDB.portrait_for(ch)
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.custom_minimum_size = Vector2(110, 110)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(tr)
	else:
		var init := Label.new()
		init.text = str(Domain.CHAR_NAMES_IT.get(ch, ch)).substr(0, 1)
		init.add_theme_font_size_override("font_size", 64)
		init.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		init.custom_minimum_size = Vector2(110, 110)
		init.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(init)
	var name_lbl := Label.new()
	name_lbl.text = str(Domain.CHAR_NAMES_IT.get(ch, ch))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(name_lbl)
	return btn


func _update_select_title() -> void:
	if _picked.is_empty():
		_select_title.text = "Scegli il tuo combattente" if _pending_mode == "solo" 				else "Giocatore 1 — scegli il combattente"
	else:
		var p1 := str(Domain.CHAR_NAMES_IT.get(_picked[0], _picked[0]))
		_select_title.text = ("Scegli l'avversario (IA) — tu: %s" % p1) if _pending_mode == "solo" 				else "Giocatore 2 — scegli il combattente (G1: %s)" % p1


func _on_char_picked(ch: String) -> void:
	_picked.append(ch)
	if _picked.size() < 2:
		_update_select_title()
		return
	Domain.selected_chars = _picked.duplicate()
	Domain.game_mode = _pending_mode
	get_tree().change_scene_to_file("res://scenes/Arena.tscn")


func _on_editor() -> void:
	# Editor di carte (Fase 1: browser & inspector). Vedi docs/CARD_EDITOR_ROADMAP.md.
	get_tree().change_scene_to_file("res://scenes/CardEditor.tscn")


func _on_online() -> void:
	# Tavolo ONLINE companion: questo schermo mostra la board e il codice stanza;
	# i due giocatori si collegano col telefono (pagina phone/). Serve il relay
	# (server/server.js) in ascolto su Domain.ws_url.
	get_tree().change_scene_to_file("res://scenes/TableOnline.tscn")
