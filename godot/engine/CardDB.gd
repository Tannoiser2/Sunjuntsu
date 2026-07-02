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
	_merge_images(read_json_or_null(path))
	_merge_images(_overlay(path))


func _merge_images(parsed) -> void:
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for k in parsed.get("by_id", {}).keys():
		images[int(k)] = parsed["by_id"][k]


## Percorso dell'immagine reale della carta (relativo a assets/cards/), o "".
func image_for(id: int) -> String:
	if Status.is_status(id):
		return Status.image_for(id)
	return images.get(id, "")


## Aggiorna in memoria l'immagine associata a una carta (usata dall'editor dopo
## il salvataggio, così anteprima/indicatori si aggiornano senza riavvio).
func set_image(id: int, rel_path: String) -> void:
	if rel_path == "":
		images.erase(id)
	else:
		images[id] = rel_path


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


## Overlay user:// scritto dall'editor nelle build esportate (dove res:// è di
## sola lettura — vedi CardStore.writable_path). In editor restituisce `null`:
## lì la fonte di verità è res://. `null` anche se l'overlay è assente/illeggibile.
static func _overlay(res_path: String) -> Variant:
	if OS.has_feature("editor"):
		return null
	var p := "user://" + res_path.get_file()
	if not FileAccess.file_exists(p):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(p))


func _load_geometry() -> void:
	_merge_geometry(read_json_or_null(GEOMETRY_PATH))
	_merge_geometry(_overlay(GEOMETRY_PATH))


func _merge_geometry(parsed) -> void:
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for k in parsed.get("cards", {}).keys():
		geom[int(k)] = parsed["cards"][k]
	var ch = parsed.get("characters", {})
	if typeof(ch) == TYPE_DICTIONARY and not ch.is_empty():
		char_stats = ch


## Parse di un file JSON res://, o `null` se assente/illeggibile.
static func read_json_or_null(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


## Geometria/effetti trascritti per una carta (vuoto se non ancora trascritta).
func geometry(id: int) -> Dictionary:
	return geom.get(id, {})


## Aggiorna in memoria la geometria di una carta (usata dall'editor visuale dopo
## il salvataggio, così list/anteprima si aggiornano senza riavvio).
func set_geometry(id: int, g: Dictionary) -> void:
	if g.is_empty():
		geom.erase(id)
	else:
		geom[id] = g


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
## Slug del mazzo/asset per un personaggio (chiavi di data/decks/index.json e
## assets/portraits): quasi sempre il nome minuscolo, con le eccezioni storiche.
func deck_slug_for(character: String) -> String:
	match character:
		"Onna-Bugeisha":
			return "onna_bugeisha"
		"Hachiko":
			return "hachik"
		_:
			return character.to_lower()


## Ritratto del personaggio (assets/portraits/<slug>.webp), null se assente
## (es. Hachikō: nessun ritratto nei materiali — la UI mostra l'iniziale).
func portrait_for(character: String) -> Texture2D:
	var path := "res://assets/portraits/%s.webp" % deck_slug_for(character)
	if ResourceLoader.exists(path):
		return load(path)
	return null


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
			return [901, 902, 903, 904, 905]
		"warrior":
			return [911, 912, 913, 914, 915, 993]
		"yasuke":
			return [916, 917, 918, 919, 920]
		"wakou":
			return [921, 922, 923, 924, 981]
		"sailor":
			return [925, 926, 927, 928, 984]
		"assassin":
			return [929, 930, 931, 932, 987]
		"hachiko":
			return [933, 934, 935, 936, 937]
		"kojiro":
			return [938, 939, 940, 941, 942]
		"master":
			return [943, 944, 945, 946, 947]
		"monk":
			return [948, 949, 950, 951, 952, 953]
		"ninja":
			return [954, 955, 956, 957, 990]
		"onna_bugeisha":
			return [958, 959, 960, 961, 962]
		"yojimbo":
			return [963, 964, 965]
		"student":
			return [966, 967, 968, 969, 970]
		"musashi":
			return [971, 972, 973, 974, 975]
		"ashigaru":
			return [976, 977, 978, 979]
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
	_apply_overrides_from(read_json_or_null(POOL_OVERRIDES_PATH))
	_apply_overrides_from(_overlay(POOL_OVERRIDES_PATH))


func _apply_overrides_from(parsed) -> void:
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var by = parsed.get("by_id", {})
	if typeof(by) != TYPE_DICTIONARY:
		return
	for k in by.keys():
		if typeof(by[k]) == TYPE_DICTIONARY:
			apply_override(int(k), by[k])


## Applica un override anagrafico IN MEMORIA. Usato sia al caricamento sia
## dall'editor dopo un salvataggio, così la vista runtime resta coerente senza
## riavviare. Se la carta esiste, fonde i campi (spostando il bucket per
## personaggio se cambia `char`); se l'id è nuovo (carta creata dall'editor,
## id-utente >= 10000) la AGGIUNGE al catalogo.
func apply_override(id: int, fields: Dictionary) -> void:
	if by_id.has(id):
		var card: Dictionary = by_id[id]
		var old_char: String = str(card.get("char", "?"))
		for f in fields.keys():
			card[f] = fields[f]
		var new_char: String = str(card.get("char", "?"))
		if new_char != old_char:
			if by_char.has(old_char):
				by_char[old_char].erase(card)
			if not by_char.has(new_char):
				by_char[new_char] = []
			by_char[new_char].append(card)
		return
	# Carta nuova: record completo aggiunto al catalogo.
	var card := fields.duplicate(true)
	card["id"] = id
	var ch: String = str(card.get("char", "?"))
	cards.append(card)
	by_id[id] = card
	if not by_char.has(ch):
		by_char[ch] = []
	by_char[ch].append(card)
	if not characters.has(ch):
		characters.append(ch)


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
