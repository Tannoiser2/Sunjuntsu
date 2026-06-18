## Test headless (deterministico): il flusso interattivo regge molti turni senza
## incepparsi (regressione del freeze al 2° turno).
extends Node
var duel: Duel
var awaits := 0
var over := [false, -1]
func _ready():
	seed(20260618)
	var ok := true
	var s := GameState.new()
	var a := GameState.Fighter.new(); a.character="Warrior"; a.is_ai=false; a.cell=Vector2i(0,0); a.facing=0; a.wound_limit=10; a.hand_limit=5
	var b := GameState.Fighter.new(); b.character="Ronin"; b.is_ai=true; b.cell=HexGrid.DIRS[0]; b.facing=3; b.wound_limit=10; b.hand_limit=5
	a.draw_pile=CardDB.draw_pile_for("warrior"); a.draw_pile.shuffle()
	b.draw_pile=CardDB.draw_pile_for("ronin"); b.draw_pile.shuffle()
	s.fighters.append(a); s.fighters.append(b)
	duel=Duel.new(s); duel.interactive=true
	duel.await_resolution.connect(func(i):
		awaits+=1
		if awaits>500: return
		var f=s.fighters[i]
		if f.is_ai:
			var foe=s.opponent_of(f)
			if foe!=null:
				var dest=AI.move_target(s,f)
				if dest!=f.cell and not s.is_blocked(dest): f.cell=dest
				f.facing=AI.facing_toward(f.cell,foe.cell)
		duel.resolve_current())
	duel.duel_over.connect(func(w): over[0]=true; over[1]=w)
	duel.start()
	var turns := 0
	while not over[0] and turns < 60:
		if s.phase != Domain.Phase.PLANNING:
			print("FAIL: fase bloccata (non PLANNING) al turno ", turns, " = ", s.phase); ok=false; break
		var played := false
		for cid in a.hand.duplicate():
			if Duel.playable(a, cid):
				played = duel.plan_card(0, cid)
				if played: break
		if not played:
			break   # mano senza carte giocabili: terminazione legittima
		turns += 1
	if awaits > 500:
		print("FAIL: loop di risoluzione fuori controllo (", awaits, " await)"); ok=false
	elif turns < 10 and not over[0]:
		print("FAIL: progredito solo di ", turns, " turni (atteso il superamento del 2°)"); ok=false
	else:
		print("OK: ", turns, " turni senza inceppi (over=", over[0], " vincitore=", over[1], ")")
	print("RISULTATO: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
