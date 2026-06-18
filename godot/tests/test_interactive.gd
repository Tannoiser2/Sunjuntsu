extends Node
func _mk(ch,stance) -> GameState.Fighter:
	var f=GameState.Fighter.new(); f.character=ch; f.stance=stance
	f.cell=Vector2i(0,0); f.facing=0; f.wound_limit=5; f.hand_limit=5
	return f
func _ready():
	var ok=true
	var s=GameState.new()
	var a=_mk("Warrior",Domain.Stance.NEUTRAL); a.is_ai=false; a.cell=Vector2i(0,0); a.facing=0
	var b=_mk("Ronin",Domain.Stance.NEUTRAL); b.is_ai=true; b.cell=HexGrid.DIRS[0]; b.facing=3
	a.draw_pile.assign(CardDB.draw_pile_for("warrior"))
	b.draw_pile.assign(CardDB.draw_pile_for("ronin"))
	s.fighters.append(a); s.fighters.append(b)
	var duel=Duel.new(s)
	duel.interactive=true
	var revealed=[false]
	var resolved_steps=[0]
	var turn_done=[false]
	duel.cards_revealed.connect(func(p): revealed[0]=true)
	duel.await_resolution.connect(func(i):
		resolved_steps[0]+=1
		# simula: il giocatore/IA risolve subito (nessun movimento)
		duel.resolve_current())
	duel.turn_resolved.connect(func(log): turn_done[0]=true)
	duel.start()
	var disc_before=a.discard.size()
	# programma una carta giocabile
	var played=false
	for cid in a.hand.duplicate():
		if Duel.playable(a,cid):
			played=duel.plan_card(0,cid); 
			if played: break
	if not played: print("FAIL: nessuna carta giocabile"); ok=false
	if not revealed[0]: print("FAIL: cards_revealed non emesso"); ok=false
	else: print("OK: rivelazione emessa")
	if resolved_steps[0] < 1: print("FAIL: await_resolution non emesso"); ok=false
	else: print("OK: await_resolution emesso ", resolved_steps[0], " volte")
	if not turn_done[0]: print("FAIL: turn_resolved non emesso (turno non completato)"); ok=false
	else: print("OK: turno completato (cleanup)")
	if a.discard.size() <= disc_before: print("FAIL: nessuno scarto"); ok=false
	else: print("OK: carta scartata (scarti ", a.discard.size(), ")")
	# Regola 1.5: si pesca 1 carta a inizio turno (mano = limite+1 prima di scegliere).
	if a.hand.size() != a.hand_limit + 1: print("FAIL: pesca inizio turno errata =", a.hand.size(), " atteso ", a.hand_limit+1); ok=false
	else: print("OK: pescata 1 a inizio turno, mano =", a.hand.size())
	print("RISULTATO: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
