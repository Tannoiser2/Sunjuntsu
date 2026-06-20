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
	_test_derive_type()
	_test_compute_override()
	_test_next_free_id()
	_test_apply_override_carddb()

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


func _test_derive_type() -> void:
	print("[derive_type]")
	_check(CardStore.derive_type(["Attack"]) == "attack", "Attack -> attack")
	_check(CardStore.derive_type(["Defence", "Attack"]) == "attack", "Defence+Attack -> attack (priorità)")
	_check(CardStore.derive_type(["Attack/Defence"]) == "attack", "Attack/Defence -> attack")
	_check(CardStore.derive_type(["Defence"]) == "defence", "Defence -> defence")
	_check(CardStore.derive_type(["Meditation"]) == "meditation", "Meditation -> meditation")
	_check(CardStore.derive_type(["Core"]) == "core", "Core -> core")
	_check(CardStore.derive_type(["Prepared"]) == "other", "keyword non tipante -> other")
	_check(CardStore.derive_type([]) == "other", "nessun keyword -> other")


func _test_compute_override() -> void:
	print("[compute_override]")
	var store := CardStore.new()
	# #143 Cross Kick esiste nel pool Excel.
	_check(store.has_pristine(143), "#143 presente nel pool pristine")
	var base := store.pristine_card(143)
	# Modifica di un solo campo -> override minimo con solo quel campo.
	var edited := base.duplicate(true)
	edited["focus"] = 99
	var ov := store.compute_override(143, edited)
	_check(ov.size() == 1 and ov.get("focus", -1) == 99, "delta = solo il campo cambiato (focus)")
	# Nessuna modifica -> override vuoto (revert).
	_check(store.compute_override(143, base.duplicate(true)).is_empty(), "nessuna differenza -> override vuoto")
	# Id-utente non nel pool -> record completo.
	var full := {"id": 10001, "name": "Nuova", "char": "Warrior", "type": "other"}
	var ov2 := store.compute_override(10001, full)
	_check(ov2.size() == full.size(), "carta nuova -> record completo nell'override")


func _test_next_free_id() -> void:
	print("[next_free_id]")
	var store := CardStore.new()
	_check(store.next_free_id([1, 2, 313]) == 10000, "nessun id-utente -> 10000")
	_check(store.next_free_id([10000, 10001, 5]) == 10002, "salta gli id-utente occupati")
	_check(store.next_free_id([10000, 10002]) == 10001, "riempe il buco tra gli id-utente")


func _test_apply_override_carddb() -> void:
	print("[apply_override_carddb]")
	# Carta nuova in memoria (id-utente fittizio, non scrive su disco).
	var nid := 99999
	_check(not CardDB.by_id.has(nid), "id 99999 inizialmente assente")
	CardDB.apply_override(nid, {"name": "Carta Test", "char": "__TestChar__", "type": "other"})
	_check(CardDB.by_id.has(nid), "apply_override aggiunge la carta nuova")
	_check(CardDB.by_char.get("__TestChar__", []).size() == 1, "carta nuova nel bucket del personaggio")
	# Modifica con spostamento di bucket per cambio char.
	CardDB.apply_override(nid, {"char": "__OtherChar__"})
	_check(not CardDB.by_id[nid].has("char") or CardDB.by_id[nid]["char"] == "__OtherChar__", "char aggiornato")
	_check(CardDB.by_char.get("__TestChar__", []).is_empty(), "bucket vecchio svuotato dopo cambio char")
	_check(CardDB.by_char.get("__OtherChar__", []).size() == 1, "carta spostata nel nuovo bucket")
