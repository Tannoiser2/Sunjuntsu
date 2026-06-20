## Test headless di CardSimulator (Fase 5): risoluzione di una carta nel motore.
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
	# Attacco fronte adiacente da 2 ferite: deve colpire e infliggere 2 ferite.
	var atk := {"char": "Warrior", "type": "attack"}
	var geom := {"type": "attack", "attack": {"cells": [{"d": 0, "k": 1, "w": 2}]}}
	var r := CardSimulator.simulate(atk, geom)
	_check(r.get("hit", false), "attacco a segno (hit)")
	_check(r.get("target_wounds", 0) == 2, "2 ferite inflitte (%d)" % r.get("target_wounds", -1))
	_check(not (r.get("log", []) as Array).is_empty(), "log di risoluzione non vuoto")

	# Esecuzione: il bersaglio cade (ferite = wound_limit).
	var ge := {"type": "attack", "attack": {"cells": [{"d": 0, "k": 1, "w": "exec"}]}}
	var re := CardSimulator.simulate(atk, ge)
	_check(re.get("target_wounds", 0) >= 6, "esecuzione satura le ferite (%d)" % re.get("target_wounds", -1))

	# Carta senza attacco (meditazione): nessuna ferita, nessun crash.
	var rm := CardSimulator.simulate({"char": "Warrior", "type": "meditation"}, {"type": "meditation"})
	_check(not rm.get("hit", true), "meditazione: nessuna ferita")

	# Lo stato di CardDB è ripristinato (id temporaneo rimosso).
	_check(not CardDB.by_id.has(CardSimulator.SIM_ID), "id temporaneo rimosso da by_id")
	_check(not CardDB.geom.has(CardSimulator.SIM_ID), "id temporaneo rimosso da geom")

	# Round-trip su una carta reale trascritta (#55): non deve dare errori.
	var c55 := CardDB.card(55)
	var g55 := CardDB.geometry(55)
	var r55 := CardSimulator.simulate(c55, g55)
	_check(r55.has("log"), "simulazione carta reale #55 produce un esito")

	if _failures == 0:
		print("SIMULATOR DONE ok")
		get_tree().quit(0)
	else:
		print("SIMULATOR DONE failures=", _failures)
		get_tree().quit(1)
