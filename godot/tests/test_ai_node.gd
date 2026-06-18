## Test headless: motore comportamentale IA solitaria (AI.plan_move).
## - Offensivo: sceglie una posizione/facing da cui PUÒ colpire il giocatore.
## - Difensivo: preferisce una cella NON minacciata dall'attacco del giocatore.
extends Node

func _mk(ch: String) -> GameState.Fighter:
	var f := GameState.Fighter.new()
	f.character = ch; f.stance = Domain.Stance.NEUTRAL; f.cell = Vector2i(0, 0); f.facing = 0
	f.wound_limit = 8; f.hand_limit = 5
	return f

func _ready() -> void:
	var ok := true

	# ── Offensivo: con passo+rotazione deve trovare una posizione da cui attaccare ──
	var s := GameState.new()
	var player := _mk("Warrior"); player.cell = Vector2i(0, 0); player.facing = 0
	var ai := _mk("Ronin"); ai.cell = HexGrid.DIRS[0] * 2   # due esagoni davanti al giocatore
	ai.is_ai = true; ai.ai_stance = "offensive"; ai.ai_preferred_range = 1
	s.fighters = [player, ai]
	# Carta IA sintetica: passo in qualsiasi direzione + rotazione, attacco frontale a dist1.
	var geom := {
		"type": "attack",
		"move": {"opts": [{"ordered": false, "atoms": [
			{"t": "step", "dir": -1, "n": 1, "opt": true},
			{"t": "rot", "n": 3, "opt": true}]}]},
		"attack": {"cells": [{"d": 0, "k": 1, "w": 1}]},
	}
	var plan := AI.plan_move(s, ai, geom)
	var hits: bool = Duel.attack_v2_cells(plan["cell"], plan["facing"], geom, 1).has(player.cell)
	if not hits:
		print("FAIL: l'IA offensiva non ha trovato una posizione per attaccare"); ok = false
	else:
		print("OK: IA offensiva → si posiziona/orienta per colpire il giocatore")

	# ── Difensivo: la cella attuale è minacciata; deve spostarsi al sicuro ──
	var s2 := GameState.new()
	var p2 := _mk("Warrior"); p2.cell = Vector2i(0, 0); p2.facing = 0; p2.planned = 64   # Testata: colpisce il fronte (DIRS[0])
	var ai2 := _mk("Ronin"); ai2.cell = HexGrid.DIRS[0]   # proprio davanti al giocatore = minacciato
	ai2.is_ai = true; ai2.ai_stance = "defensive"; ai2.ai_preferred_range = 1
	s2.fighters = [p2, ai2]
	var geom2 := {"type": "meditation",
		"move": {"opts": [{"ordered": false, "atoms": [{"t": "step", "dir": -1, "n": 1, "opt": true}]}]}}
	var threat := Duel.attack_v2_cells(p2.cell, p2.facing, CardDB.geometry(64), 1)
	var plan2 := AI.plan_move(s2, ai2, geom2)
	if threat.has(plan2["cell"]):
		print("FAIL: l'IA difensiva è rimasta in una cella minacciata"); ok = false
	else:
		print("OK: IA difensiva → si sposta fuori dalla minaccia del giocatore")

	print("RISULTATO: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
