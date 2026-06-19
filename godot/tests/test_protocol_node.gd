## Tappa 1 multiplayer: gioca una PARTITA 1v1 COMPLETA usando SOLO il protocollo
## decisioni (MatchProtocol): ogni scelta passa per prompt→respond, come farà la rete.
## Un "bot" risponde ai prompt (sceglie carta, si avvicina, ruota verso il nemico,
## conferma). Verifica che la partita arrivi a una fine coerente.
##
## Le risposte sono DIFFERITE (call_deferred) per evitare ricorsione profonda:
## un "ply" per frame, lo stack resta basso.
extends Node

var mp: MatchProtocol
var _over := false
var _winner := -99
var _prompts := 0
var _turns := 0

func _mk(ch: String, cell: Vector2i, facing: int) -> GameState.Fighter:
	var f := GameState.Fighter.new()
	f.character = ch; f.stance = Domain.Stance.NEUTRAL
	f.cell = cell; f.facing = facing
	f.wound_limit = 8; f.hand_limit = 5; f.is_ai = false
	return f

func _ready() -> void:
	var s := GameState.new()
	s.fighters = [_mk("Warrior", Vector2i(-3, 1), 0), _mk("Ronin", Vector2i(3, -1), 3)]
	s.fighters[0].draw_pile = CardDB.draw_pile_for("warrior"); s.fighters[0].draw_pile.shuffle()
	s.fighters[1].draw_pile = CardDB.draw_pile_for("ronin"); s.fighters[1].draw_pile.shuffle()
	# Orientamento iniziale verso l'avversario.
	s.fighters[0].facing = AI.facing_toward(s.fighters[0].cell, s.fighters[1].cell)
	s.fighters[1].facing = AI.facing_toward(s.fighters[1].cell, s.fighters[0].cell)
	mp = MatchProtocol.new(s)
	mp.prompt.connect(_on_prompt)
	mp.public_event.connect(func(kind, _d):
		if kind == "turn": _turns += 1)
	mp.finished.connect(func(w): _over = true; _winner = w)
	mp.start()

func _on_prompt(seat: int, kind: String, data: Dictionary) -> void:
	_prompts += 1
	if _prompts > 8000:
		return
	var resp := _decide(seat, kind, data)
	# Risposta DIFFERITA: rompe la catena sincrona, niente ricorsione profonda.
	var cb := func(): if not _over and mp != null: mp.respond(seat, kind, resp)
	cb.call_deferred()

func _decide(seat: int, kind: String, data: Dictionary) -> Dictionary:
	match kind:
		"plan":
			var pick := -1
			for c in data.get("hand", []):
				if bool(c.get("playable", false)): pick = int(c.get("id", -1)); break
			if pick == -1:
				var h: Array = data.get("hand", [])
				if not h.is_empty(): pick = int(h[0].get("id", -1))
			return {"card": pick}
		"instant_replace", "instant_play":
			return {"pick": -1}   # il bot non usa istantanee
		"resolve":
			return _decide_resolve(seat, data)
	return {}

func _decide_resolve(seat: int, data: Dictionary) -> Dictionary:
	var f := mp.state.fighters[seat]
	var foe := mp.state.opponent_of(f)
	# 1) Avvicìnati: scegli la cella legale più vicina al nemico.
	if not bool(data.get("move_used", false)):
		var best := ""; var bestd := 999
		for key in (data.get("legalCells", {}) as Dictionary).keys():
			var cell: Vector2i = MatchProtocol._key_cell(key)
			if cell == f.cell: continue
			var d := HexGrid.distance(cell, foe.cell)
			if d < bestd: bestd = d; best = key
		if best != "":
			return {"action": "move", "cell": best}
	# 2) Orientati verso il nemico, se la rotazione lo consente.
	var want := AI.facing_toward(f.cell, foe.cell)
	if want != f.facing and (data.get("legalFacings", []) as Array).has(want):
		return {"action": "rotate", "facing": want}
	# 3) Conferma (attacco/risoluzione dalla posizione attuale).
	return {"action": "confirm"}

func _process(_dt: float) -> void:
	if _over:
		_finish()
	elif _prompts > 8000:
		print("FAIL: troppi prompt (loop?) =", _prompts)
		print("RISULTATO: FAIL")
		get_tree().quit(1)

func _finish() -> void:
	set_process(false)
	var ok := true
	var a := mp.state.fighters[0]
	var b := mp.state.fighters[1]
	print("OK: partita via PROTOCOLLO conclusa in %d turni, %d prompt" % [_turns, _prompts])
	var who := "Pareggio" if _winner < 0 else "Giocatore %d (%s)" % [_winner + 1, mp.state.fighters[_winner].character]
	print("    Vincitore: %s | G1 ferite %d/%d, G2 ferite %d/%d" % [
		who, a.wounds.size(), a.effective_wound_limit(), b.wounds.size(), b.effective_wound_limit()])
	if _turns < 1:
		print("FAIL: nessun turno completato"); ok = false
	if _winner >= 0:
		if mp.state.fighters[_winner].is_defeated():
			print("FAIL: vincitore risulta sconfitto"); ok = false
		elif not mp.state.fighters[1 - _winner].is_defeated():
			print("FAIL: perdente non sconfitto"); ok = false
		else:
			print("OK: stato finale coerente (vincitore vivo, perdente sconfitto)")
	print("RISULTATO: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
