## Test del motore: più varianti d'attacco gated da kamae diverse.
## L'attaccante usa la variante che combacia con la sua kamae (stance).
extends Node

var _failures := 0
const SIM := 999990

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok: ", msg)
	else:
		_failures += 1
		print("  FAIL: ", msg)


func _wounds(geom: Dictionary, stance_slug: String, foe_cell: Vector2i) -> int:
	var gs := GameState.new()
	var a := GameState.Fighter.new()
	a.character = "Warrior"; a.cell = Vector2i.ZERO; a.facing = 0
	a.wound_limit = 6; a.hand_limit = 5; a.focus = 5
	a.stance = Domain.STANCE_FROM_SLUG.get(stance_slug, Domain.Stance.NEUTRAL)
	CardDB.by_id[SIM] = {"id": SIM, "type": "attack", "char": "Warrior"}
	CardDB.geom[SIM] = geom
	a.planned = SIM
	var b := GameState.Fighter.new()
	b.character = "Ronin"; b.cell = foe_cell; b.facing = 3
	b.wound_limit = 6; b.hand_limit = 5; b.planned = -1
	gs.fighters.append(a); gs.fighters.append(b)
	var duel := Duel.new(gs)
	duel._resolve_chosen_speeds({})
	duel._resolve_card(0, {}, [])
	CardDB.by_id.erase(SIM)
	CardDB.geom.erase(SIM)
	return b.wounds.size()


func _ready() -> void:
	# Variante "aggression": 2 ferite a (1,0). Variante "balance": 1 ferita a (1,-1).
	var geom := {"type": "attack", "attacks": [
		{"cells": [{"q": 1, "r": 0, "w": 2}], "kamae": "aggression"},
		{"cells": [{"q": 1, "r": -1, "w": 1}], "kamae": "balance"},
	]}
	_check(_wounds(geom, "aggression", Vector2i(1, 0)) == 2, "in Aggressività colpisce la variante a (1,0) per 2")
	_check(_wounds(geom, "balance", Vector2i(1, 0)) == 0, "in Equilibrio la cella (1,0) NON è attiva → mancato")
	_check(_wounds(geom, "balance", Vector2i(1, -1)) == 1, "in Equilibrio colpisce la variante a (1,-1) per 1")
	_check(_wounds(geom, "determination", Vector2i(1, 0)) == 0, "kamae senza variante → nessun attacco attivo")

	# Variante senza gate (ungated) come ripiego per ogni kamae.
	var geom2 := {"type": "attack", "attacks": [
		{"cells": [{"q": 1, "r": 0, "w": 1}]},                       # ungated
		{"cells": [{"q": 1, "r": 0, "w": 3}], "kamae": "aggression"},
	]}
	_check(_wounds(geom2, "balance", Vector2i(1, 0)) == 1, "senza match si usa la variante ungated (1 ferita)")
	_check(_wounds(geom2, "aggression", Vector2i(1, 0)) == 3, "con match la variante gated vince sull'ungated (3 ferite)")

	# Retro-compatibilità: il vecchio `attack` singolo funziona ancora.
	var old := {"type": "attack", "attack": {"cells": [{"q": 1, "r": 0, "w": 2}]}}
	_check(_wounds(old, "neutral", Vector2i(1, 0)) == 2, "schema classico {attack} invariato")

	if _failures == 0:
		print("ATTACK VARIANTS DONE ok")
		get_tree().quit(0)
	else:
		print("ATTACK VARIANTS DONE failures=", _failures)
		get_tree().quit(1)
