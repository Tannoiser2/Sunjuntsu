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


func _ready() -> void:
	hand.card_played.connect(func(d):
		var label: String = d.get("name", d.get("file", "?"))
		if d.has("initiative"):
			label += " (ini %s)" % str(d.get("initiative"))
		info.text = "Carta giocata: %s" % label
		card_played.emit(d))
	hand.card_selected.connect(func(d): card_selected.emit(d))
	_build_kamae_chooser()


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
