## Catalogo carte — Senjutsu
##
## Autoload singleton. Carica l'intero pool carte da
## res://data/cards/card_pool.json (generato dall'Excel ufficiale di
## deckbuilding) e lo indicizza per personaggio e per id.
##
## Formato dei campi: vedi data/cards/SCHEMA.md
extends Node

const POOL_PATH := "res://data/cards/card_pool.json"
const GEOMETRY_PATH := "res://data/cards/geometry.json"

const DECK_DIR := "res://data/decks/"

var cards: Array = []                 ## tutte le carte (Array[Dictionary])
var by_id: Dictionary = {}            ## id (int) -> carta
var by_char: Dictionary = {}          ## personaggio (String) -> Array[carta]
var characters: Array = []            ## elenco personaggi
var decks: Dictionary = {}            ## slug (String) -> Array[carta del mazzo]
var geom: Dictionary = {}             ## id (int) -> geometria/effetti (GEOMETRY_SCHEMA.md)
var char_stats: Dictionary = {}       ## personaggio (String) -> {wound_limit, hand_limit, weapons}
var images: Dictionary = {}           ## id (int) -> percorso relativo immagine carta


func _ready() -> void:
	_load_pool()
	_load_decks()
	_load_geometry()
	_load_images()
	print("[CardDB] %d carte, %d personaggi, %d mazzi, %d geometrie, %d immagini" % [
		cards.size(), characters.size(), decks.size(), geom.size(), images.size()])


func _load_images() -> void:
	var path := "res://data/cards/card_images.json"
	if not FileAccess.file_exists(path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for k in parsed.get("by_id", {}).keys():
		images[int(k)] = parsed["by_id"][k]


## Percorso dell'immagine reale della carta (relativo a assets/cards/), o "".
func image_for(id: int) -> String:
	return images.get(id, "")


func _load_geometry() -> void:
	if not FileAccess.file_exists(GEOMETRY_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(GEOMETRY_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for k in parsed.get("cards", {}).keys():
		geom[int(k)] = parsed["cards"][k]
	char_stats = parsed.get("characters", {})


## Geometria/effetti trascritti per una carta (vuoto se non ancora trascritta).
func geometry(id: int) -> Dictionary:
	return geom.get(id, {})


## Statistiche del personaggio (limite ferite/mano, armi) o {} se assente.
func character_stats(character: String) -> Dictionary:
	return char_stats.get(character, {})


func _load_decks() -> void:
	# Liste mazzo autorevoli (foglio Custom Decks). Chiave = slug, es. "warrior".
	var idx_path := DECK_DIR + "index.json"
	if not FileAccess.file_exists(idx_path):
		return
	var idx = JSON.parse_string(FileAccess.get_file_as_string(idx_path))
	if typeof(idx) != TYPE_DICTIONARY:
		return
	for entry in idx.get("decks", []):
		var slug: String = entry.get("slug", "")
		var path := DECK_DIR + slug + ".json"
		if FileAccess.file_exists(path):
			var d = JSON.parse_string(FileAccess.get_file_as_string(path))
			if typeof(d) == TYPE_DICTIONARY:
				decks[slug] = d.get("cards", [])


## Mazzo autorevole per slug (es. "warrior", "ronin"). Espande le copie (amount).
func draw_pile_for(slug: String) -> Array:
	var pile: Array = []
	for c in decks.get(slug, []):
		for _i in range(int(c.get("amount", 1))):
			pile.append(int(c.get("id", -1)))
	return pile


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
