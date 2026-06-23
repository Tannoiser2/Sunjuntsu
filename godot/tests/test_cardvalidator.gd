## Test headless di CardValidator (Fase 3): regole error/warning.
extends Node

var _failures: int = 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok: ", msg)
	else:
		_failures += 1
		push_error("FAIL: " + msg)
		print("  FAIL: ", msg)


func _has(issues: Array, code: String) -> bool:
	for it in issues:
		if it.get("code") == code:
			return true
	return false


func _levels(issues: Array, code: String) -> String:
	for it in issues:
		if it.get("code") == code:
			return it.get("level")
	return ""


func _ready() -> void:
	var kw := {"Attack": true, "Defence": true, "Meditation": true, "Core": true}

	# Carta valida e completa: nessun problema.
	var ok_card := {"rank": "Steel", "type": "attack", "keywords": ["Attack"]}
	var ok_geom := {"type": "attack", "attack": {"cells": [{"d": 0, "k": 1, "w": 1}]}}
	var r0 := CardValidator.validate(ok_card, ok_geom, "warrior/x.webp", {"known_keywords": kw})
	_check(r0.is_empty(), "carta valida e completa: nessun problema")

	# Rank non valido -> errore.
	var r1 := CardValidator.validate({"rank": "Bronzo", "type": "attack", "keywords": ["Attack"]}, {}, "x", {"known_keywords": kw})
	_check(_has(r1, "rank") and _levels(r1, "rank") == "error", "rank non valido -> error")

	# Type incoerente coi keywords -> warning.
	var r2 := CardValidator.validate({"rank": "-", "type": "defence", "keywords": ["Attack"]}, {}, "x", {"known_keywords": kw})
	_check(_has(r2, "type") and _levels(r2, "type") == "warning", "type incoerente -> warning")

	# Keyword sconosciuta -> warning.
	var r3 := CardValidator.validate({"rank": "-", "type": "attack", "keywords": ["Attack", "Pippo"]}, {}, "x", {"known_keywords": kw})
	_check(_has(r3, "keyword"), "keyword sconosciuta -> warning")

	# Immagine mancante -> warning.
	var r4 := CardValidator.validate(ok_card, ok_geom, "", {"known_keywords": kw})
	_check(_has(r4, "image"), "immagine mancante -> warning")

	# Attacco con geometria avviata ma senza celle -> warning.
	var r5 := CardValidator.validate(ok_card, {"type": "attack", "counter": [8]}, "x", {"known_keywords": kw})
	_check(_has(r5, "no_attack"), "attacco con contenuto ma senza celle -> warning")

	# Attacco SENZA geometria (solo type) -> nessun warning no_attack (è "senza geometria").
	var r6 := CardValidator.validate(ok_card, {"type": "attack"}, "x", {"known_keywords": kw})
	_check(not _has(r6, "no_attack"), "attacco senza geometria: nessun falso warning")

	# kamae_req fuori vocabolario -> errore.
	var r7 := CardValidator.validate(ok_card, {"type": "attack", "kamae_req": "rabbia", "attack": {"cells": [{"d": 0, "k": 1, "w": 1}]}}, "x", {"known_keywords": kw})
	_check(_has(r7, "kamae_req") and _levels(r7, "kamae_req") == "error", "kamae_req non valido -> error")

	# Effetto: verbo sconosciuto -> warning, kamae non valido -> error.
	var geff := {"type": "attack", "attack": {"cells": [{"d": 0, "k": 1, "w": 1}]},
		"effects": [{"do": "teleport", "kamae": "furia"}]}
	var r8 := CardValidator.validate(ok_card, geff, "x", {"known_keywords": kw})
	_check(_has(r8, "effect"), "verbo effetto sconosciuto -> warning")
	_check(_has(r8, "effect_kamae") and _levels(r8, "effect_kamae") == "error", "kamae effetto non valido -> error")

	# switch_kamae verso "neutral" e "any": NON sono errori (4 stance reali; "any"
	# = qualsiasi, risolto da Duel.gd). Regressione: prima venivano marcati a torto.
	var gneu := {"type": "defence", "defence": {"cells": [{"d": 0, "k": 1, "v": 1}]},
		"effects": [{"do": "switch_kamae", "to": "neutral"}]}
	_check(not _has(CardValidator.validate(ok_card, gneu, "x", {"known_keywords": kw}), "effect_kamae"),
		"switch_kamae to:neutral -> nessun errore")
	var gany := {"type": "defence", "defence": {"cells": [{"d": 0, "k": 1, "v": 1}]},
		"effects": [{"do": "switch_kamae", "to": "any"}]}
	_check(not _has(CardValidator.validate(ok_card, gany, "x", {"known_keywords": kw}), "effect_kamae"),
		"switch_kamae to:any -> nessun errore")
	# Ma un 'to' davvero fuori vocabolario resta un errore.
	var gbad := {"type": "defence", "defence": {"cells": [{"d": 0, "k": 1, "v": 1}]},
		"effects": [{"do": "switch_kamae", "to": "furia"}]}
	_check(_has(CardValidator.validate(ok_card, gbad, "x", {"known_keywords": kw}), "effect_kamae"),
		"switch_kamae to:furia -> error")

	# Id duplicato -> errore.
	var r9 := CardValidator.validate(ok_card, ok_geom, "x", {"known_keywords": kw, "duplicate": true})
	_check(_has(r9, "dup_id") and _levels(r9, "dup_id") == "error", "id duplicato -> error")

	# Integrazione con CardDB: una carta reale trascritta non deve dare errori bloccanti.
	var real := CardValidator.validate_id(55)
	var has_error := false
	for it in real:
		if it.get("level") == "error":
			has_error = true
	_check(not has_error, "carta reale #55: nessun errore bloccante")

	if _failures == 0:
		print("CARDVALIDATOR DONE ok")
		get_tree().quit(0)
	else:
		print("CARDVALIDATOR DONE failures=", _failures)
		get_tree().quit(1)
