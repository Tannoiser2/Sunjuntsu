## HUD di gioco — Senjutsu
##
## Overlay 2D sopra l'arena 3D: mostra la mano del giocatore (schede generate dai
## dati del mazzo) e lo stato del duello. La logica vive in engine/Duel.gd;
## l'arena guida questo HUD.
extends CanvasLayer

signal card_played(card_data: Dictionary)
signal card_selected(card_data: Dictionary)
signal card_hovered(card_data: Dictionary, entered: bool)
signal kamae_chosen(slug: String)
signal confirm_pressed()
signal option_chosen(alt: String)

@onready var hand: Control = $Hand
@onready var info: Label = $Top/Info
@onready var hint: Label = $Bottom/Hint

const _STANCE_LABEL := {
	"aggression": "Aggr.", "balance": "Equil.", "determination": "Determ.", "neutral": "Neutra",
}
var _kamae_box: HBoxContainer
var _kamae_btns: Dictionary = {}


var _tree_panel: Control
var _tree_rect: TextureRect
var _tree_marker: Panel
var _tree_nodes: Dictionary = {}

var _played_panel: Control
var _played_rect: TextureRect
var _played_label: Label


func _ready() -> void:
	hand.card_played.connect(func(d):
		var label: String = d.get("name", d.get("file", "?"))
		if d.has("initiative"):
			label += " (ini %s)" % str(d.get("initiative"))
		info.text = "Carta giocata: %s" % label
		card_played.emit(d))
	hand.card_selected.connect(func(d): card_selected.emit(d))
	hand.card_hovered.connect(func(d, e): card_hovered.emit(d, e))
	_build_kamae_chooser()
	_build_kamae_tree()
	_build_played_slot()
	_build_confirm_button()
	_build_option_chooser()
	_build_status_strip()


## Riquadro "carta giocata": mostra la carta programmata finché non è scartata a
## fine turno (sotto l'albero Kamae).
func _build_played_slot() -> void:
	_played_panel = Control.new()
	_played_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_played_panel.position = Vector2(12, 300)
	_played_panel.custom_minimum_size = Vector2(110, 160)
	_played_panel.size = Vector2(110, 160)
	_played_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_played_panel)
	_played_label = Label.new()
	_played_label.text = "Giocata"
	_played_label.position = Vector2(0, -20)
	_played_panel.add_child(_played_label)
	_played_rect = TextureRect.new()
	_played_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_played_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_played_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_played_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_played_panel.add_child(_played_rect)
	_played_panel.visible = false


## Mostra la carta giocata (immagine o, in mancanza, testo).
func show_played_card(file: String, name: String) -> void:
	_played_label.text = "Giocata: " + name
	var tex := _load_tex("res://assets/cards/" + file) if file != "" else null
	_played_rect.texture = tex
	_played_panel.visible = true


func hide_played_card() -> void:
	_played_panel.visible = false


var _confirm_btn: Button


## Pulsante "Conferma azione" mostrato durante la TUA risoluzione: rende esplicita
## la chiusura del turno (equivale a INVIO / click sul bersaglio rosso).
var _opt_box: HBoxContainer
var _opt_btns: Dictionary = {}


## Selettore "OPPURE": una riga di pulsanti, uno per alternativa, mostrato durante
## la TUA risoluzione quando la carta ha opzioni mutuamente esclusive.
func _build_option_chooser() -> void:
	var wrap := VBoxContainer.new()
	wrap.set_anchors_preset(Control.PRESET_CENTER_TOP)
	wrap.anchor_left = 0.5; wrap.anchor_right = 0.5
	wrap.offset_left = -320; wrap.offset_right = 320; wrap.offset_top = 120
	add_child(wrap)
	var lbl := Label.new()
	lbl.text = "Scegli un'opzione (OPPURE):"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wrap.add_child(lbl)
	_opt_box = HBoxContainer.new()
	_opt_box.alignment = BoxContainer.ALIGNMENT_CENTER
	wrap.add_child(_opt_box)
	wrap.visible = false
	_opt_box.set_meta("wrap", wrap)


## options: Array di {alt:String, label:String}. Vuoto = nascondi.
func show_options(options: Array) -> void:
	for c in _opt_box.get_children():
		c.queue_free()
	_opt_btns.clear()
	var wrap: Control = _opt_box.get_meta("wrap")
	if options.is_empty():
		wrap.visible = false
		return
	for opt in options:
		var a := String(opt.get("alt", ""))
		var b := Button.new()
		b.custom_minimum_size = Vector2(190, 46)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.text = String(opt.get("label", a))
		b.pressed.connect(func(): option_chosen.emit(a))
		_opt_box.add_child(b)
		_opt_btns[a] = b
	wrap.visible = true


func mark_option(alt: String) -> void:
	for a in _opt_btns:
		var b: Button = _opt_btns[a]
		b.modulate = Color(1.3, 1.2, 0.5) if a == alt else Color.WHITE


func hide_options() -> void:
	(_opt_box.get_meta("wrap") as Control).visible = false


func _build_confirm_button() -> void:
	_confirm_btn = Button.new()
	_confirm_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_confirm_btn.anchor_left = 1.0
	_confirm_btn.anchor_top = 1.0
	_confirm_btn.anchor_right = 1.0
	_confirm_btn.anchor_bottom = 1.0
	_confirm_btn.offset_left = -210
	_confirm_btn.offset_top = -130
	_confirm_btn.offset_right = -20
	_confirm_btn.offset_bottom = -70
	_confirm_btn.text = "Conferma ▶ (INVIO)"
	_confirm_btn.add_theme_font_size_override("font_size", 20)
	_confirm_btn.pressed.connect(func(): confirm_pressed.emit())
	add_child(_confirm_btn)
	_confirm_btn.visible = false


func show_confirm(label: String = "Conferma ▶ (INVIO)") -> void:
	_confirm_btn.text = label
	_confirm_btn.visible = true


func hide_confirm() -> void:
	_confirm_btn.visible = false


func _build_kamae_tree() -> void:
	_tree_panel = Control.new()
	_tree_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_tree_panel.position = Vector2(12, 70)
	_tree_panel.custom_minimum_size = Vector2(150, 209)
	_tree_panel.size = Vector2(150, 209)
	_tree_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tree_panel)
	var lbl := Label.new()
	lbl.text = "Kamae"
	lbl.position = Vector2(0, -20)
	_tree_panel.add_child(lbl)
	_tree_rect = TextureRect.new()
	_tree_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tree_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tree_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_tree_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tree_panel.add_child(_tree_rect)
	_tree_marker = Panel.new()
	_tree_marker.size = Vector2(30, 30)
	_tree_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 0.85, 0.2, 0.25)
	sb.set_border_width_all(4)
	sb.border_color = Color(1, 0.85, 0.1)
	sb.set_corner_radius_all(15)
	_tree_marker.add_theme_stylebox_override("panel", sb)
	_tree_panel.add_child(_tree_marker)
	_tree_panel.visible = false


## Imposta l'albero Kamae del personaggio (immagine + posizioni nodi normalizzate).
func setup_kamae_tree(image_path: String, nodes: Dictionary) -> void:
	_tree_nodes = nodes
	var tex := _load_tex("res://assets/cards/" + image_path)
	if tex != null:
		_tree_rect.texture = tex
		_tree_panel.visible = true


## Sposta il segnalino sulla posizione Kamae corrente.
func set_kamae_marker(slug: String) -> void:
	if not _tree_nodes.has(slug):
		return
	var n: Array = _tree_nodes[slug]
	var pos := Vector2(float(n[0]) * _tree_panel.size.x, float(n[1]) * _tree_panel.size.y)
	_tree_marker.position = pos - _tree_marker.size * 0.5


static func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	var img := Image.new()
	if img.load(path) == OK:
		return ImageTexture.create_from_image(img)
	return null


func _build_kamae_chooser() -> void:
	var wrap := VBoxContainer.new()
	wrap.set_anchors_preset(Control.PRESET_CENTER_TOP)
	wrap.anchor_left = 0.5
	wrap.anchor_right = 0.5
	wrap.offset_left = -240
	wrap.offset_right = 240
	wrap.offset_top = 44
	add_child(wrap)
	var lbl := Label.new()
	lbl.text = "Cambia Kamae — scegli la posizione:"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wrap.add_child(lbl)
	_kamae_box = HBoxContainer.new()
	_kamae_box.alignment = BoxContainer.ALIGNMENT_CENTER
	wrap.add_child(_kamae_box)
	for slug in ["aggression", "balance", "determination", "neutral"]:
		var sl: String = slug   # cattura per-iterazione: senza, tutti i bottoni emetterebbero l'ultimo slug
		var b := Button.new()
		b.custom_minimum_size = Vector2(110, 40)
		b.pressed.connect(func(): kamae_chosen.emit(sl))
		_kamae_box.add_child(b)
		_kamae_btns[slug] = b
	wrap.visible = false
	_kamae_box.set_meta("wrap", wrap)


## Mostra il selettore Kamae: `current` evidenziato, raggiungibili abilitati
## (reachable: slug -> focus guadagnato). Vuoto = nascondi.
func show_kamae(current: String, reachable: Dictionary) -> void:
	var wrap: Control = _kamae_box.get_meta("wrap")
	if reachable.is_empty():
		wrap.visible = false
		return
	wrap.visible = true
	for slug in _kamae_btns:
		var b: Button = _kamae_btns[slug]
		var name: String = _STANCE_LABEL[slug]
		if slug == current:
			b.text = "● " + name
			b.disabled = true
		elif reachable.has(slug):
			var f: int = int(reachable[slug])
			b.text = name + (" +%d◈" % f if f > 0 else "")
			b.disabled = false
		else:
			b.text = name
			b.disabled = true


func hide_kamae() -> void:
	(_kamae_box.get_meta("wrap") as Control).visible = false


## Mostra in mano le carte indicate (array di dizionari carta).
func show_hand(entries: Array) -> void:
	hand.set_hand(entries)


## ── Carte di STATO (ferite/stordimento/azzoppamenti/veleni) ──────────────────
## Striscia verticale sul lato destro: mostra come CARTE (con la loro arte reale)
## le ferite e gli altri stati attivi del combattente di turno.
var _status_panel: VBoxContainer
var _status_title: Label


func _build_status_strip() -> void:
	_status_panel = VBoxContainer.new()
	_status_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_status_panel.anchor_left = 1.0
	_status_panel.anchor_right = 1.0
	_status_panel.offset_left = -118
	_status_panel.offset_right = -6
	_status_panel.offset_top = 46
	_status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_status_panel)
	_status_title = Label.new()
	_status_title.text = "Ferite / stati"
	_status_title.add_theme_font_size_override("font_size", 12)
	_status_panel.add_child(_status_title)
	_status_panel.visible = false


## entries: Array di {file:String, name:String, count:int}. Vuoto = nascondi.
func set_status_cards(entries: Array) -> void:
	# Rimuove le miniature precedenti (tiene il titolo).
	for c in _status_panel.get_children():
		if c != _status_title:
			c.queue_free()
	if entries.is_empty():
		_status_panel.visible = false
		return
	_status_panel.visible = true
	for e in entries:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tr := TextureRect.new()
		tr.custom_minimum_size = Vector2(64, 88)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.tooltip_text = String(e.get("name", ""))
		var tex := _load_tex("res://assets/cards/" + String(e.get("file", "")))
		if tex != null:
			tr.texture = tex
		row.add_child(tr)
		var cnt := int(e.get("count", 1))
		if cnt > 1:
			var lbl := Label.new()
			lbl.text = "×%d" % cnt
			lbl.add_theme_font_size_override("font_size", 16)
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(lbl)
		_status_panel.add_child(row)


func set_info(text: String) -> void:
	info.text = text


func set_hint(text: String) -> void:
	hint.text = text
