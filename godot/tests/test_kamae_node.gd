## Test headless: albero Kamae — traversal, focus dai rami rosa, IA, switch "any".
extends Node

func _mk(ch: String) -> GameState.Fighter:
	var f := GameState.Fighter.new()
	f.character = ch; f.stance = Domain.Stance.NEUTRAL
	f.cell = Vector2i(0,0); f.facing = 0
	f.wound_limit = 5; f.hand_limit = 5
	return f

func _ready() -> void:
	var ok := true
	var tree := CardDB.kamae_tree_for("warrior")

	# Da NEUTRAL, 1 passo: raggiungi determination e aggression (rami non rosa → 0 focus).
	var t1 := Kamae.change_targets(tree, "neutral", 1)
	if not (t1.has("determination") and t1.has("aggression")):
		print("FAIL: n=1 non raggiunge determination/aggression: %s" % str(t1)); ok = false
	elif t1.has("balance"):
		print("FAIL: balance raggiungibile in 1 passo (non dovrebbe): %s" % str(t1)); ok = false
	else:
		print("OK: n=1 → %s" % str(t1))

	# A 3 passi balance è raggiungibile attraversando rami ROSA → focus ≥ 1.
	var t3 := Kamae.change_targets(tree, "neutral", 3)
	if not t3.has("balance"):
		print("FAIL: n=3 non raggiunge balance: %s" % str(t3)); ok = false
	elif int(t3["balance"]) < 1:
		print("FAIL: balance senza focus dai rami rosa (focus=%d)" % int(t3["balance"])); ok = false
	else:
		print("OK: n=3 → balance con focus %d (rami rosa)" % int(t3["balance"]))

	# IA: change_kamae applicato dal motore (preferisce aggression).
	var s := GameState.new()
	var ai := _mk("Warrior"); ai.is_ai = true
	s.fighters = [ai, _mk("Ronin")]
	var duel := Duel.new(s)
	var geomA := {"effects": [{"do": "change_kamae", "n": 1, "when": "always"}]}
	duel._apply_effects(0, -1, geomA, "always", [])
	if Domain.STANCE_SLUG[ai.stance] != "aggression":
		print("FAIL: IA change_kamae non ha spostato in aggression (%s)" % Domain.STANCE_SLUG[ai.stance]); ok = false
	else:
		print("OK: IA change_kamae → aggression")

	# switch_kamae "any" → aggression (≠ neutral).
	var p := _mk("Warrior")
	var s2 := GameState.new(); s2.fighters = [p, _mk("Ronin")]
	var duel2 := Duel.new(s2)
	var geomS := {"effects": [{"do": "switch_kamae", "to": "any", "when": "always"}]}
	duel2._apply_effects(0, -1, geomS, "always", [])
	if Domain.STANCE_SLUG[p.stance] == "neutral":
		print("FAIL: switch_kamae 'any' non ha cambiato posizione"); ok = false
	else:
		print("OK: switch_kamae 'any' → %s" % Domain.STANCE_SLUG[p.stance])

	# Focus cap a 3.
	var ff := _mk("Warrior")
	ff.gain_focus(5)
	if ff.focus != 3:
		print("FAIL: cap focus non a 3 (=%d)" % ff.focus); ok = false
	else:
		print("OK: focus cappato a 3")

	print("RISULTATO: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
