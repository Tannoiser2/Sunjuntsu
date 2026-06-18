## Test headless: il flusso interattivo regge PIÙ turni senza incepparsi.
extends Node
var duel: Duel
var awaits := 0
var resolved := 0
func _ready():
	var ok := true
	var s := GameState.new()
	var a := GameState.Fighter.new(); a.character="Warrior"; a.is_ai=false; a.cell=Vector2i(0,0); a.facing=0; a.wound_limit=12; a.hand_limit=5
	var b := GameState.Fighter.new(); b.character="Ronin"; b.is_ai=true; b.cell=HexGrid.DIRS[0]; b.facing=3; b.wound_limit=12; b.hand_limit=5
	a.draw_pile=CardDB.draw_pile_for("warrior"); a.draw_pile.shuffle()
	b.draw_pile=CardDB.draw_pile_for("ronin"); b.draw_pile.shuffle()
	s.fighters.append(a); s.fighters.append(b)
	duel=Duel.new(s); duel.interactive=true
	duel.await_resolution.connect(func(i):
		awaits+=1
		if awaits>60: return   # salvagente anti-loop
		duel.resolve_current())
	duel.turn_resolved.connect(func(log): resolved+=1)
	duel.start()
	var completed := 0
	for t in range(5):
		if a.is_defeated() or b.is_defeated(): break
		if s.phase != Domain.Phase.PLANNING:
			print("FAIL: fase non PLANNING al turno ", t, " = ", s.phase); ok=false; break
		var played := false
		for cid in a.hand.duplicate():
			if Duel.playable(a, cid):
				played = duel.plan_card(0, cid)
				if played: break
		if not played:
			print("FAIL: turno ", t, " nessuna carta giocabile"); ok=false; break
		completed += 1
	if awaits > 60:
		print("FAIL: troppe risoluzioni (loop infinito)"); ok=false
	if completed < 5 and not (a.is_defeated() or b.is_defeated()):
		print("FAIL: completati solo ", completed, " turni su 5"); ok=false
	else:
		print("OK: completati ", completed, " turni (turn_resolved=", resolved, ")")
	print("RISULTATO: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
