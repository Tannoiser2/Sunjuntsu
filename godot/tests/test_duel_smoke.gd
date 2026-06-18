## Test deterministico: risoluzione carte schema v2 (celle attacco + effetti).
extends Node

func _mk(ch, stance) -> GameState.Fighter:
	var f = GameState.Fighter.new()
	f.character = ch; f.stance = stance
	f.cell = Vector2i(0, 0); f.facing = 0
	f.wound_limit = 5; f.hand_limit = 5
	return f

func _ready() -> void:
	var ok := true
	var log: Array = []

	# 1) Testata (#64): attacco fronte d0 k1, SE RIUSCITO azzoppa + 1 focus.
	var s := GameState.new()
	var a := _mk("Warrior", Domain.Stance.NEUTRAL)
	var b := _mk("Ronin", Domain.Stance.NEUTRAL)
	b.cell = HexGrid.DIRS[0]; b.facing = 3
	s.fighters.append(a); s.fighters.append(b)
	var duel := Duel.new(s)
	a.planned = 64; b.planned = -1
	duel._resolve_chosen_speeds({})
	duel._resolve_card(0, {}, log)
	if b.wounds.size() != 1: print("FAIL Testata ferite=", b.wounds.size()); ok = false
	if b.hobble != 1: print("FAIL Testata hobble=", b.hobble); ok = false
	if a.focus != 1: print("FAIL Testata focus=", a.focus); ok = false
	if ok: print("OK #64 Testata: 1 ferita, azzoppa, +1 focus")

	# 2) Bersaglio fuori arco: Testata non colpisce se il nemico è dietro.
	b.cell = -HexGrid.DIRS[0]; b.wounds.clear(); b.hobble = 0
	var log2: Array = []
	duel._resolve_card(0, {}, log2)
	if b.wounds.size() != 0: print("FAIL fuori-arco ferite=", b.wounds.size()); ok = false
	else: print("OK arco: nemico dietro non colpito")

	# 3) Arco Respingente (#62): attacco tutto-attorno, spinge se riesce.
	var s3 := GameState.new()
	var a3 := _mk("Warrior", Domain.Stance.NEUTRAL)
	var b3 := _mk("Ronin", Domain.Stance.NEUTRAL)
	b3.cell = HexGrid.DIRS[1] * 1   # adiacente
	s3.fighters.append(a3); s3.fighters.append(b3)
	var d3 := Duel.new(s3)
	a3.planned = 62
	d3._resolve_chosen_speeds({})
	d3._resolve_card(0, {}, log)
	# il bersaglio deve essere stato colpito (1 ferita) e spinto via
	if b3.wounds.size() < 1: print("FAIL Arco Resp ferite=", b3.wounds.size()); ok = false
	else: print("OK #62 Arco Respingente: colpito (", b3.wounds.size(), " ferita) e spinto a ", b3.cell)

	# 4) Meditazione effetti (#34 Ritirata Composta): +1 focus, pesca 3.
	var s4 := GameState.new()
	var a4 := _mk("Ronin", Domain.Stance.NEUTRAL)
	a4.draw_pile.assign([21, 22, 23, 24, 25])
	s4.fighters.append(a4)
	var d4 := Duel.new(s4)
	a4.planned = 34
	var before := a4.hand.size()
	d4._resolve_card(0, {}, log)
	if a4.focus != 1: print("FAIL Ritirata focus=", a4.focus); ok = false
	if a4.hand.size() != before + 3: print("FAIL Ritirata pescate=", a4.hand.size() - before); ok = false
	if a4.focus == 1 and a4.hand.size() == before + 3: print("OK #34 Ritirata: +1 focus, +3 carte")

	print("RISULTATO: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
