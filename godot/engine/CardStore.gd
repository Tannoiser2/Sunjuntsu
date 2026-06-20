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
