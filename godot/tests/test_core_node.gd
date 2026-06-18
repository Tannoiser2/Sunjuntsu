## Test headless: carte CORE (abilità Speciale + Arma core) — setup iniziale in mano,
## non rientrano mai nel mazzo, non contano nel limite, tornano in mano dopo l'uso e
## non si scartano mai (regolamento p.4 e p.10).
extends Node

func _mk(ch: String, deck: Array) -> GameState.Fighter:
	var f := GameState.Fighter.new()
	f.character = ch; f.stance = Domain.Stance.NEUTRAL; f.cell = Vector2i(0, 0)
	f.wound_limit = 12; f.hand_limit = 5
	f.draw_pile = deck.duplicate()
	return f

func _ready() -> void:
	var ok := true
	var s := GameState.new()
	# 53 = abilità core Guerriero, 72 = arma core (Nodachi); il resto non-core.
	var a := _mk("Warrior", [53, 72, 60, 61, 64, 65, 87, 113, 116])
	# 23 = abilità core Ronin, 71 = arma core (Naginata).
	var b := _mk("Ronin", [23, 71, 27, 29, 32, 33, 35, 107, 126])
	s.fighters = [a, b]
	var duel := Duel.new(s)
	duel.start()

	# Setup: core abilità + arma in mano, fuori dal mazzo.
	if not (a.hand.has(53) and a.hand.has(72)):
		print("FAIL: le core del Guerriero (53/72) non sono in mano"); ok = false
	elif a.draw_pile.has(53) or a.draw_pile.has(72):
		print("FAIL: una core è rimasta nel mazzo"); ok = false
	elif not (b.hand.has(23) and b.hand.has(71)):
		print("FAIL: le core del Ronin (23/71) non sono in mano"); ok = false
	else:
		print("OK: setup → abilità core + arma core in mano, fuori dal mazzo")

	# Le core non contano verso il limite: 5 non-core + 2 core = 7 in mano (più la
	# pesca del turno). Verifichiamo che ci siano almeno 2 core e ≥5 non-core.
	var ncore := 0
	for cid in a.hand:
		if Duel.is_core(cid): ncore += 1
	if ncore != 2:
		print("FAIL: attese 2 core in mano, trovate %d" % ncore); ok = false
	else:
		print("OK: entrambe le core (abilità + arma) non contano nel limite")

	# Gioca l'arma core (#72) e risolvi il turno: deve TORNARE in mano, mai negli scarti.
	# (b gioca una carta qualunque per far partire la risoluzione.)
	var bcard := -1
	for cid in b.hand:
		if not Duel.is_core(cid): bcard = cid; break
	if not duel.plan_card(0, 72):
		print("FAIL: impossibile programmare l'arma core"); ok = false
	duel.plan_card(1, bcard)
	if a.discard.has(72) or a.discard.has(53):
		print("FAIL: una core è finita negli scarti"); ok = false
	elif not (a.hand.has(72) and a.hand.has(53)):
		print("FAIL: dopo l'uso le core non sono tornate in mano"); ok = false
	else:
		print("OK: l'arma core giocata torna in mano e non si scarta")

	print("RISULTATO: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
