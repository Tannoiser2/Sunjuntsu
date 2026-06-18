## HUD di gioco — Senjutsu
##
## Overlay 2D sopra l'arena 3D: mostra la mano del giocatore (schede generate dai
## dati del mazzo) e lo stato del duello. La logica vive in engine/Duel.gd;
## l'arena guida questo HUD.
extends CanvasLayer

signal card_played(card_data: Dictionary)
signal card_selected(card_data: Dictionary)

@onready var hand: Control = $Hand
@onready var info: Label = $Top/Info
@onready var hint: Label = $Bottom/Hint


func _ready() -> void:
	hand.card_played.connect(func(d):
		var label: String = d.get("name", d.get("file", "?"))
		if d.has("initiative"):
			label += " (ini %s)" % str(d.get("initiative"))
		info.text = "Carta giocata: %s" % label
		card_played.emit(d))
	hand.card_selected.connect(func(d): card_selected.emit(d))


## Mostra in mano le carte indicate (array di dizionari carta).
func show_hand(entries: Array) -> void:
	hand.set_hand(entries)


func set_info(text: String) -> void:
	info.text = text


func set_hint(text: String) -> void:
	hint.text = text
