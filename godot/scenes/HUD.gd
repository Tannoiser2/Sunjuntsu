## HUD di gioco — Senjutsu
##
## Overlay 2D sopra l'arena 3D: mostra la mano del giocatore (schede generate dai
## dati del mazzo) e lo stato del duello. La logica vive in engine/Duel.gd;
## l'arena guida questo HUD.
extends CanvasLayer

signal card_played(card_data: Dictionary)
signal card_selected(card_data: Dictionary)
signal kamae_chosen(slug: String)

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
	_build_kamae_chooser()
	_build_kamae_tree()
	_build_played_slot()


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
		var b := Button.new()
		b.custom_minimum_size = Vector2(110, 40)
		b.pressed.connect(func(): kamae_chosen.emit(slug))
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


func set_info(text: String) -> void:
	info.text = text


func set_hint(text: String) -> void:
	hint.text = text
