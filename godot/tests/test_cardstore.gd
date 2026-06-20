## Test headless di CardStore: scrittura atomica + .bak, ordinamento chiavi,
## round-trip e logica overlay anagrafica. Non tocca i dati reali del repo
## (usa file temporanei sotto user://).
extends Node

var _failures: int = 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok: ", msg)
	else:
		_failures += 1
		push_error("FAIL: " + msg)
		print("  FAIL: ", msg)


func _ready() -> void:
	_test_save_roundtrip()
	_test_atomic_backup()
	_test_sorted_keys()
	_test_overlay_inmem()

	if _failures == 0:
		print("CARDSTORE DONE ok")
		get_tree().quit(0)
	else:
		print("CARDSTORE DONE failures=", _failures)
		get_tree().quit(1)


func _test_save_roundtrip() -> void:
	print("[save_roundtrip]")
	var path := "user://_test_store_roundtrip.json"
	var data := {"b": 2, "a": 1, "nested": {"y": [1, 2, 3], "x": "ok"}}
	var res := CardStore.save_json(path, data)
	_check(res.get("ok", false), "save_json riuscito")
	_check(FileAccess.file_exists(path), "file creato")
	var back = CardStore.read_json(path)
	_check(typeof(back) == TYPE_DICTIONARY, "rilettura è dict")
	_check(back.get("a", -1) == 1 and back.get("b", -1) == 2, "valori top-level conservati")
	_check(back.get("nested", {}).get("x", "") == "ok", "valori annidati conservati")
	DirAccess.remove_absolute(path)


func _test_atomic_backup() -> void:
	print("[atomic_backup]")
	var path := "user://_test_store_bak.json"
	# primo salvataggio: nessun .bak (file inesistente)
	var r1 := CardStore.save_json(path, {"v": 1})
	_check(r1.get("backup", "x") == "", "primo salvataggio senza backup")
	_check(not FileAccess.file_exists(path + ".bak"), ".bak assente al primo salvataggio")
	# secondo salvataggio: il vecchio contenuto finisce in .bak
	var r2 := CardStore.save_json(path, {"v": 2})
	_check(r2.get("backup", "") == path + ".bak", "secondo salvataggio crea backup")
	_check(FileAccess.file_exists(path + ".bak"), ".bak presente")
	var bak = CardStore.read_json(path + ".bak")
	_check(typeof(bak) == TYPE_DICTIONARY and bak.get("v", -1) == 1, ".bak contiene la versione precedente")
	var cur = CardStore.read_json(path)
	_check(cur.get("v", -1) == 2, "file corrente è la nuova versione")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + ".bak")


func _test_sorted_keys() -> void:
	print("[sorted_keys]")
	var path := "user://_test_store_sorted.json"
	CardStore.save_json(path, {"zebra": 1, "alpha": 2, "mid": 3}, "  ", true)
	var text := FileAccess.get_file_as_string(path)
	var ia := text.find("\"alpha\"")
	var im := text.find("\"mid\"")
	var iz := text.find("\"zebra\"")
	_check(ia != -1 and im != -1 and iz != -1, "tutte le chiavi presenti")
	_check(ia < im and im < iz, "chiavi ordinate alfabeticamente con sort_keys")
	DirAccess.remove_absolute(path)


func _test_overlay_inmem() -> void:
	print("[overlay_inmem]")
	var store := CardStore.new()
	store.load_overrides()   # file reale assente -> overrides vuoti
	_check(store.overrides.is_empty(), "overrides vuoti senza file")
	store.set_override(143, {"focus": 2, "name": "Cross Kick (edit)"})
	_check(store.get_override(143).get("focus", -1) == 2, "set_override registra i campi")
	_check(store.get_override(999).is_empty(), "carta senza override -> dict vuoto")
	store.set_override(143, {})   # dict vuoto = rimozione
	_check(store.get_override(143).is_empty(), "override vuoto rimuove la voce")
	store.set_override(143, {"focus": 1})
	store.clear_override(143)
	_check(store.get_override(143).is_empty(), "clear_override rimuove la voce")
