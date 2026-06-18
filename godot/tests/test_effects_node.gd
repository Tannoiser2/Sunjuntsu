## Test headless: nuovi verbi effetto (spend_focus, foe_lose_focus, foe_discard,
## reduce_damage, reset_deck) + presenza dei gruppi OPPURE (alt) sulle carte
## ri-trascritte.
extends Node

func _mk(ch: String) -> GameState.Fighter:
	var f := GameState.Fighter.new()
	f.character = ch; f.stance = Domain.Stance.NEUTRAL; f.cell = Vector2i(0, 0)
	f.wound_limit = 8; f.hand_limit = 9
	return f

func _ready() -> void:
	var ok := true
	var s := GameState.new()
	var f := _mk("Ronin"); var foe := _mk("Warrior")
	s.fighters = [f, foe]
	var duel := Duel.new(s)

	# spend_focus (tutto)
	f.focus = 3
	duel._apply_effects(0, 1, {"effects": [{"do": "spend_focus", "all": true}]}, "always", [])
	if f.focus != 0:
		print("FAIL: spend_focus all → focus %d (atteso 0)" % f.focus); ok = false
	else: print("OK: spend_focus all azzera i focus")

	# foe_lose_focus
	foe.focus = 3
	duel._apply_effects(0, 1, {"effects": [{"do": "foe_lose_focus", "n": 2}]}, "always", [])
	if foe.focus != 1:
		print("FAIL: foe_lose_focus 2 → %d (atteso 1)" % foe.focus); ok = false
	else: print("OK: foe_lose_focus toglie focus all'avversario")

	# foe_discard
	foe.hand = [10, 11, 12]
	duel._apply_effects(0, 1, {"effects": [{"do": "foe_discard", "n": 2}]}, "always", [])
	if foe.hand.size() != 1:
		print("FAIL: foe_discard 2 → mano %d (atteso 1)" % foe.hand.size()); ok = false
	else: print("OK: foe_discard scarta dalla mano avversaria")

	# reduce_damage (persistente) + applicazione in attacco
	duel._apply_effects(1, 0, {"effects": [{"do": "reduce_damage", "n": 1}]}, "always", [])
	if foe.damage_reduction != 1:
		print("FAIL: reduce_damage → %d (atteso 1)" % foe.damage_reduction); ok = false
	else: print("OK: reduce_damage imposta la riduzione persistente")

	# reset_deck: sposta nel mazzo le carte NON-meditazione di mano/scarti
	var f2 := _mk("Warrior")
	# 64=Testata (attacco non-core), 116=Mente Rapida (meditazione), 60=attacco non-core
	f2.hand = [64, 116]; f2.discard = [60]; f2.draw_pile = []
	var s2 := GameState.new(); s2.fighters = [f2, _mk("Ronin")]
	var duel2 := Duel.new(s2)
	duel2._apply_effects(0, 1, {"effects": [{"do": "reset_deck"}]}, "always", [])
	if not f2.hand.has(116):
		print("FAIL: reset_deck non doveva spostare la meditazione"); ok = false
	elif f2.draw_pile.size() != 2:
		print("FAIL: reset_deck → mazzo %d (atteso 2 non-meditazione)" % f2.draw_pile.size()); ok = false
	else: print("OK: reset_deck rimescola solo le non-meditazione")

	# OPPURE: una carta ri-trascritta con alternative espone option_keys
	var s3 := GameState.new()
	var f3 := _mk("Warrior"); f3.planned = 59   # Concentrazione Ritrovata: ha un OPPURE di movimento? verifichiamo #102
	f3.stance = Domain.Stance.NEUTRAL
	s3.fighters = [f3, _mk("Ronin")]
	var duel3 := Duel.new(s3)
	var has_alt := false
	for cid in [59, 102, 125, 34, 16]:
		if not CardDB.geometry(cid).get("effects", []).is_empty():
			for e in CardDB.geometry(cid).get("effects", []):
				if e.has("alt"): has_alt = true
	if not has_alt:
		print("FAIL: nessuna carta ri-trascritta espone gruppi OPPURE (alt)"); ok = false
	else: print("OK: i gruppi OPPURE (alt) sono presenti nelle carte ri-trascritte")

	# cancel_movement: imposta il flag sull'avversario
	foe.movement_cancelled = false
	duel._apply_effects(0, 1, {"effects": [{"do": "cancel_movement"}]}, "always", [])
	if not foe.movement_cancelled:
		print("FAIL: cancel_movement non ha impostato il flag"); ok = false
	else: print("OK: cancel_movement annulla il movimento avversario")

	# cancel_abilities: azzera la riduzione danno persistente dell'avversario
	foe.damage_reduction = 2
	duel._apply_effects(0, 1, {"effects": [{"do": "cancel_abilities"}]}, "always", [])
	if foe.damage_reduction != 0:
		print("FAIL: cancel_abilities non ha azzerato la riduzione danno (%d)" % foe.damage_reduction); ok = false
	else: print("OK: cancel_abilities annulla gli effetti persistenti")

	# block_initiative: allarga l'intervallo d'iniziativa del blocco (±1)
	var sb := GameState.new()
	var att := _mk("Warrior"); att.cell = Vector2i(0, 0); att.facing = 0; att.planned = 119
	var dfn := _mk("Ronin"); dfn.cell = HexGrid.DIRS[0]; dfn.planned = 31
	dfn.facing = AI.facing_toward(dfn.cell, Vector2i(0, 0))
	sb.fighters = [att, dfn]
	var d := Duel.new(sb)
	d._block_ready = {1: 5}
	var blocked_no: bool = d._attack_blocked(0, 1, 6, CardDB.geometry(119))   # vel6 vs blocco5: no
	dfn.block_initiative_bonus = 1
	var blocked_yes: bool = d._attack_blocked(0, 1, 6, CardDB.geometry(119))  # con +1: sì
	if blocked_no or not blocked_yes:
		print("FAIL: block_initiative (no=%s sì=%s)" % [blocked_no, blocked_yes]); ok = false
	else: print("OK: block_initiative allarga l'intervallo del blocco (vel6 bloccata con +1)")

	print("RISULTATO: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
