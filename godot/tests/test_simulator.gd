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

	# explain(): spiega la carta in frasi italiane leggibili.
	var ex := CardSimulator.explain(
		{"char": "Warrior", "type": "attack", "initiative": "7", "focus": 1},
		{"type": "attack",
		 "move": {"opts": [{"atoms": [
			{"t": "step", "dir": 0, "n": 2, "opt": false},
			{"t": "rot", "n": 1, "opt": false, "kamae": "aggression"}]}]},
		 "attack": {"cells": [{"d": 0, "k": 1, "w": 1}]},
		 "effects": [{"do": "draw", "n": 2, "when": "on_hit"}]})
	var joined := "\n".join(ex.map(func(x): return str(x)))
	_check(ex.size() >= 4, "explain produce piu' frasi (%d)" % ex.size())
	_check("iniziativa 7" in joined, "explain cita l'iniziativa")
	_check("muoverti di 2 in avanti" in joined, "explain descrive il passo")
	_check("Aggressività" in joined, "explain cita il gate Kamae dell'atomo")
	_check("peschi 2 carta/e" in joined and "se l'attacco va a segno" in joined, "explain descrive l'effetto on_hit")

	# explain() su carta senza geometria: non crasha, dà almeno l'intestazione.
	var ex0 := CardSimulator.explain({"type": "meditation"}, {"type": "meditation"})
	_check(ex0.size() >= 1, "explain gestisce geometria assente")

	if _failures == 0:
		print("SIMULATOR DONE ok")
		get_tree().quit(0)
	else:
		print("SIMULATOR DONE failures=", _failures)
		get_tree().quit(1)
