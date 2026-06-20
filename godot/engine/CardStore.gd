## Persistenza dell'editor di carte — Senjutsu
##
## Layer di SCRITTURA per l'editor (la LETTURA a runtime resta in CardDB).
## Carica/serializza i JSON dati delle carte e li salva in modo ATOMICO con
## backup `.bak`, così un salvataggio interrotto non corrompe i dati.
##
## Sorgente di verità anagrafica (decisione §4.1b della roadmap): l'editor NON
## riscrive `card_pool.json` (generato dall'Excel) ma un file OVERLAY separato
## `card_pool_overrides.json`, che CardDB fonde sopra il pool al caricamento.
##
## Geometria/immagini hanno invece il proprio file dedicato e vengono riscritti
## per intero (sono già hand-authored).
##
## Helper puro/headless-testabile: nessuna dipendenza dalla UI.
class_name CardStore
extends RefCounted

const POOL_PATH := "res://data/cards/card_pool.json"
const POOL_OVERRIDES_PATH := "res://data/cards/card_pool_overrides.json"
const GEOMETRY_PATH := "res://data/cards/geometry.json"
const IMAGES_PATH := "res://data/cards/card_images.json"

## Override anagrafici in memoria: id (String) -> { campo: valore }.
var overrides: Dictionary = {}

## Pool ORIGINALE (Excel) indicizzato per id, senza overlay. Caricato pigro:
## serve a calcolare l'override minimo (delta) e a ripristinare una carta.
var _pristine: Dictionary = {}


# ─── I/O di basso livello ────────────────────────────────────────────────────

## Legge e fa il parse di un JSON. Restituisce `null` se assente o non valido.
static func read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


## Salva `data` come JSON in modo atomico:
##  1. fa il backup dell'eventuale file esistente in `<path>.bak`,
##  2. scrive in `<path>.tmp`,
##  3. rinomina `.tmp` -> `path` (sostituzione atomica).
## `indent` = stringa di indentazione; `sort_keys` ordina le chiavi (diff stabili).
## Restituisce `{ ok: bool, error: String, backup: String }`.
static func save_json(path: String, data, indent := "  ", sort_keys := false) -> Dictionary:
	var text := JSON.stringify(data, indent, sort_keys) + "\n"
	var backup := ""

	# 1. backup del file esistente
	if FileAccess.file_exists(path):
		backup = path + ".bak"
		var src := FileAccess.get_file_as_string(path)
		var bf := FileAccess.open(backup, FileAccess.WRITE)
		if bf == null:
			return {"ok": false, "error": "backup non scrivibile (%d)" % FileAccess.get_open_error(), "backup": ""}
		bf.store_string(src)
		bf.close()

	# 2. scrittura temporanea
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "error": "tmp non scrivibile (%d)" % FileAccess.get_open_error(), "backup": backup}
	f.store_string(text)
	f.close()

	# 3. rename atomico tmp -> path
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		return {"ok": false, "error": "rename fallita (%d)" % err, "backup": backup}
	return {"ok": true, "error": "", "backup": backup}


# ─── Overlay anagrafica (card_pool_overrides.json) ───────────────────────────

## Carica gli override dal disco in `overrides`. No-op pulito se il file manca.
func load_overrides() -> void:
	overrides = {}
	var parsed = read_json(POOL_OVERRIDES_PATH)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var by = parsed.get("by_id", {})
	if typeof(by) == TYPE_DICTIONARY:
		for k in by.keys():
			if typeof(by[k]) == TYPE_DICTIONARY:
				overrides[str(k)] = (by[k] as Dictionary).duplicate(true)


## Imposta/aggiorna l'override di una carta (solo i campi forniti).
## Passare un dict vuoto rimuove l'override (vedi `clear_override`).
func set_override(id: int, fields: Dictionary) -> void:
	if fields.is_empty():
		clear_override(id)
		return
	overrides[str(id)] = fields.duplicate(true)


## Rimuove l'override di una carta (torna al valore generato dall'Excel).
func clear_override(id: int) -> void:
	overrides.erase(str(id))


## Override di una carta come dict (vuoto se assente).
func get_override(id: int) -> Dictionary:
	return overrides.get(str(id), {})


# ─── Pool pristine, delta e allocazione id ───────────────────────────────────

func _ensure_pristine() -> void:
	if not _pristine.is_empty():
		return
	var parsed = read_json(POOL_PATH)
	if typeof(parsed) == TYPE_DICTIONARY:
		for c in parsed.get("cards", []):
			_pristine[int(c.get("id", -1))] = c


## True se la carta esiste nel pool generato dall'Excel (non è una carta-utente).
func has_pristine(id: int) -> bool:
	_ensure_pristine()
	return _pristine.has(id)


## Carta originale (Excel) per id, senza overlay applicato; {} se id-utente.
func pristine_card(id: int) -> Dictionary:
	_ensure_pristine()
	return _pristine.get(id, {})


## Override minimo da salvare per una carta:
##  - carta dell'Excel: SOLO i campi che differiscono dall'originale (così future
##    modifiche dell'Excel ai campi non toccati continuano a passare);
##  - carta nuova (id-utente, non nel pool): il record completo.
## Un dict vuoto significa "nessuna differenza" → l'override va rimosso.
func compute_override(id: int, edited: Dictionary) -> Dictionary:
	_ensure_pristine()
	if not _pristine.has(id):
		return edited.duplicate(true)
	var base: Dictionary = _pristine[id]
	var diff := {}
	for k in edited.keys():
		if base.get(k, null) != edited[k]:
			diff[k] = edited[k]
	return diff


## Primo id libero >= floor_id (default 10000, intervallo riservato alle carte
## create dall'editor: non collide col pool Excel, con le carte di stato (id
## negativi) né coi mazzi SOLO).
func next_free_id(used_ids: Array, floor_id := 10000) -> int:
	var used := {}
	for u in used_ids:
		used[int(u)] = true
	var id := floor_id
	while used.has(id):
		id += 1
	return id


## Tipo della carta DEDOTTO dai keywords (regola §3.1): priorità
## attack > defence > meditation > core > altrimenti other. I keyword combinati
## tipo "Attack/Defence" valgono per entrambe le parti.
static func derive_type(keywords) -> String:
	var s := {}
	if keywords is Array:
		for k in keywords:
			for part in str(k).split("/"):
				s[part.strip_edges().to_lower()] = true
	if s.has("attack"):
		return "attack"
	if s.has("defence"):
		return "defence"
	if s.has("meditation"):
		return "meditation"
	if s.has("core"):
		return "core"
	return "other"


## Record di default per una nuova carta (id-utente).
static func new_card_template(id: int, character: String) -> Dictionary:
	return {
		"id": id, "name": "Nuova Carta", "char": character,
		"amount": 1, "rank": "Wood", "initiative": "-",
		"focus": 0, "keywords": [], "type": "other",
	}


## Salva l'overlay anagrafica su disco (chiavi ordinate, diff git stabili).
func save_overrides() -> Dictionary:
	var payload := {
		"note": "Override anagrafici scritti dall'editor di carte, fusi sopra card_pool.json da CardDB. NON generato dall'Excel.",
		"by_id": overrides,
	}
	return save_json(POOL_OVERRIDES_PATH, payload, "  ", true)


# ─── Geometria / immagini ────────────────────────────────────────────────────

## Riscrive l'intero geometry.json. `cards_by_id` ha chiavi String=id.
## NB: l'indentazione 1-spazio replica lo stile esistente per ridurre il churn.
func save_geometry(cards_by_id: Dictionary, characters: Dictionary, note := "") -> Dictionary:
	var existing = read_json(GEOMETRY_PATH)
	if note == "" and typeof(existing) == TYPE_DICTIONARY:
		note = existing.get("note", "")
	var payload := {"note": note, "cards": cards_by_id, "characters": characters}
	return save_json(GEOMETRY_PATH, payload, " ", false)


## Riscrive card_images.json. `by_id` ha chiavi String=id -> path relativo.
func save_images(by_id: Dictionary, note := "") -> Dictionary:
	var existing = read_json(IMAGES_PATH)
	if note == "" and typeof(existing) == TYPE_DICTIONARY:
		note = existing.get("note", "")
	var payload := {"note": note, "by_id": by_id}
	return save_json(IMAGES_PATH, payload, "  ", false)
