## HUD di gioco — Senjutsu
##
## Overlay 2D sopra l'arena 3D: mostra la mano del giocatore (carte ritagliate
## dai PDF) e le informazioni di turno. Espone il segnale card_played.
extends CanvasLayer

signal card_played(card_data: Dictionary)

const MANIFEST := "res://assets/cards/cards_manifest.json"

@onready var hand: Control = $Hand
@onready var info: Label = $Top/Info
@onready var hint: Label = $Bottom/Hint


func _ready() -> void:
	hand.card_played.connect(func(d):
		info.text = "Carta giocata: %s" % d.get("file", "?")
		card_played.emit(d))


## Pesca una mano di `count` carte dal mazzo `deck` (es. "warrior").
func deal_hand(deck: String, count: int = 6) -> void:
	var entries := _manifest_for(deck)
	entries.shuffle()
	hand.set_hand(entries.slice(0, count), deck)
	info.text = "Mano: %s" % deck.capitalize()


func set_info(text: String) -> void:
	info.text = text


func _manifest_for(deck: String) -> Array:
	if not FileAccess.file_exists(MANIFEST):
		push_warning("[HUD] manifest mancante: " + MANIFEST)
		return []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if typeof(parsed) != TYPE_DICTIONARY:
		return []
	var out: Array = []
	for c in parsed.get("cards", []):
		if c.get("deck", "") == deck:
			out.append(c)
	return out
