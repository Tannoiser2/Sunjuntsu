## Catalogo carte — Senjutsu
##
## Autoload singleton. Carica l'intero pool carte da
## res://data/cards/card_pool.json (generato dall'Excel ufficiale di
## deckbuilding) e lo indicizza per personaggio e per id.
##
## Formato dei campi: vedi data/cards/SCHEMA.md
extends Node

const POOL_PATH := "res://data/cards/card_pool.json"
const POOL_OVERRIDES_PATH := "res://data/cards/card_pool_overrides.json"
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
var kamae_trees: Dictionary = {}      ## slug personaggio -> albero kamae


func _ready() -> void:
	_load_pool()
	_load_overrides()
	_load_decks()
	_load_geometry()
	_load_images()
	_load_kamae_trees()
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
	if Status.is_status(id):
		return Status.image_for(id)
	return images.get(id, "")


func _load_kamae_trees() -> void:
	var path := "res://data/cards/kamae_trees.json"
	if not FileAccess.file_exists(path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) == TYPE_DICTIONARY:
		kamae_trees = parsed.get("trees", {})


## Albero Kamae del personaggio (slug, es. "warrior"), o {} se assente.
func kamae_tree_for(slug: String) -> Dictionary:
	return kamae_trees.get(slug, {})


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


## Mazzo dell'AVVERSARIO solitario (sottoinsieme curato secondo solo_AI_tables_v1.xlsx),
## costruito riusando la geometria già trascritta del personaggio. L'IA rivela la cima
## ogni turno; niente focus/mano. The Terror (#28) cambia l'atteggiamento dell'IA.
func solo_deck_for(slug: String) -> Array:
	match slug:
		"ronin":
			# Mazzo SOLO dedicato dell'avversario Ronin (carte "SOLO" con la meccanica
			# CHANGE AI BEHAVIOUR / RESET DECK): Charge, Steel Block, Reverse Carved Fang,
			# Feral Sweep, The Terror (incubo).
			return [901, 902, 903, 904, 905]
		"warrior":
			# Mazzo SOLO dedicato dell'avversario Guerriero.
			return [911, 912, 913, 914, 915]
	return draw_pile_for(slug)


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


## Override anagrafici dell'editor di carte (decisione §4.1b della roadmap):
## un file separato `card_pool_overrides.json` con `by_id[<id>] = {campi…}`
## viene fuso SOPRA il pool generato dall'Excel, senza toccare card_pool.json.
## No-op se il file non esiste. I dict in `by_id` e `cards` sono gli stessi
## oggetti: fondere qui aggiorna entrambe le viste.
func _load_overrides() -> void:
	if not FileAccess.file_exists(POOL_OVERRIDES_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(POOL_OVERRIDES_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var by: Dictionary = parsed.get("by_id", {})
	for k in by.keys():
		var id := int(k)
		if not by_id.has(id):
			continue   # gli override valgono solo per carte esistenti nel pool
		var fields = by[k]
		if typeof(fields) != TYPE_DICTIONARY:
			continue
		var card: Dictionary = by_id[id]
		for f in fields.keys():
			card[f] = fields[f]


## Carte di un personaggio (es. "Ronin", "Warrior").
func deck_for(character: String) -> Array:
	return by_char.get(character, [])


## Carta per id univoco (int). Gli id NEGATIVI sono carte di STATO
## (ferite/stordimento/azzoppamenti/veleni), vedi engine/Status.gd.
func card(id: int) -> Dictionary:
	if Status.is_status(id):
		return Status.card(id)
	return by_id.get(id, {})


## True se la carta è di tipo attacco/difesa/meditazione.
func is_type(c: Dictionary, t: String) -> bool:
	return c.get("type", "") == t


## Tipo "istantaneo" della carta dalle keyword (regolamento 1.5 p.13):
##   "replacement" = Istantanea di Sostituzione (sostituisce la carta rivelata)
##   "additional"  = Istantanea Aggiuntiva (giocata in più dopo aver risolto)
##   "instant"     = Istantanea generica
##   ""            = carta normale
func instant_kind(id: int) -> String:
	var kws: Array = card(id).get("keywords", [])
	if "Instant Replacement" in kws:
		return "replacement"
	if "Instant Additional" in kws:
		return "additional"
	if "Instant" in kws:
		return "instant"
	return ""
