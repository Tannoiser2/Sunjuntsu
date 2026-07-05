## Test headless: cablaggio del mazzo IA solitario (CardDB.solo_deck_for).
## Verifica che ogni personaggio costruisca un mazzo valido = carte di Classe +
## carte generiche pescate dai mazzi di selezione (CardDB.GENERIC_DECKS) secondo
## AI_DECK_COMPOSITION. Usa solo i dati (nessun rendering).
extends Node

var _fail: int = 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok: ", msg)
	else:
		_fail += 1
		push_error("FAIL: " + msg)
		print("  FAIL: ", msg)


## Quante carte generiche prevede la composizione (pescate fisse + 1 "additional").
func _expected_generic_count(comp) -> int:
	if comp == null:
		return 0
	var n: int = 0
	for k in ["I", "II", "III", "IV", "V", "VI", "VII"]:
		n += int(comp.get(k, 0))
	if not (comp.get("extra", []) as Array).is_empty():
		n += 1
	return n


func _ready() -> void:
	for slug in CardDB.AI_DECK_COMPOSITION.keys():
		var deck: Array = CardDB.solo_deck_for(slug)
		_check(not deck.is_empty(), "%s: mazzo non vuoto (%d carte)" % [slug, deck.size()])

		# Ogni id del mazzo esiste nel pool.
		var ids_ok: bool = true
		for cid in deck:
			if not CardDB.by_id.has(int(cid)):
				ids_ok = false
				print("    id non nel pool: ", cid)
		_check(ids_ok, "%s: tutti gli id risolvono nel pool" % slug)

		# Dimensione attesa = carte di Classe + generiche previste.
		var comp = CardDB.AI_DECK_COMPOSITION.get(slug, null)
		var class_n: int = CardDB._solo_class_cards(slug).size()
		var exp: int = class_n + _expected_generic_count(comp)
		_check(deck.size() == exp,
			"%s: dimensione %d == attesa %d (classe %d + generiche %d)"
			% [slug, deck.size(), exp, class_n, exp - class_n])

	# Ogni carta dei mazzi generici ha geometria trascritta.
	var geom_ok: bool = true
	for key in CardDB.GENERIC_DECKS.keys():
		for cid in CardDB.GENERIC_DECKS[key]:
			if CardDB.geometry(int(cid)).is_empty():
				geom_ok = false
				print("    generica senza geometria: ", cid)
	_check(geom_ok, "tutte le carte in GENERIC_DECKS hanno geometria")

	# Più costruzioni consecutive restano valide (l'estrazione è casuale).
	var stable: bool = true
	for _i in range(20):
		var d: Array = CardDB.solo_deck_for("ronin")
		if d.is_empty():
			stable = false
	_check(stable, "ronin: 20 costruzioni consecutive sempre valide")

	print("SOLO_DECKS DONE; fallimenti=", _fail)
	get_tree().quit(_fail)
