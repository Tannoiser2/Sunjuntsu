## Catalogo carte — Senjutsu
##
## Autoload singleton. Carica l'intero pool carte da
## res://data/cards/card_pool.json (generato dall'Excel ufficiale di
## deckbuilding) e lo indicizza per personaggio e per id.
##
## Formato dei campi: vedi data/cards/SCHEMA.md
extends Node

const POOL_PATH := "res://data/cards/card_pool.json"

var cards: Array = []                 ## tutte le carte (Array[Dictionary])
var by_id: Dictionary = {}            ## id (int) -> carta
var by_char: Dictionary = {}          ## personaggio (String) -> Array[carta]
var characters: Array = []            ## elenco personaggi


func _ready() -> void:
	_load_pool()
	print("[CardDB] %d carte, %d personaggi" % [cards.size(), characters.size()])


func _load_pool() -> void:
	if not FileAccess.file_exists(POOL_PATH):
		push_warning("[CardDB] pool mancante: " + POOL_PATH)
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(POOL_PATH))
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("cards"):
		push_warning("[CardDB] card_pool.json non valido")
		return
	cards = parsed["cards"]
	characters = parsed.get("characters", [])
	for c in cards:
		by_id[int(c.get("id", -1))] = c
		var ch: String = c.get("char", "?")
		if not by_char.has(ch):
			by_char[ch] = []
		by_char[ch].append(c)


## Carte di un personaggio (es. "Ronin", "Warrior").
func deck_for(character: String) -> Array:
	return by_char.get(character, [])


## Carta per id univoco (int).
func card(id: int) -> Dictionary:
	return by_id.get(id, {})


## True se la carta è di tipo attacco/difesa/meditazione.
func is_type(c: Dictionary, t: String) -> bool:
	return c.get("type", "") == t
