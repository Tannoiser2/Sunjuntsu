## Tappa 2 multiplayer: LOOPBACK locale. Un TAVOLO (MatchHost) e DUE CLIENT
## (MatchClient) comunicano via LoopbackChannel (messaggi JSON, consegna differita).
## Ogni client-bot decide SOLO dai dati del prompt (non vede lo stato completo):
## simula due telefoni. Verifica che una partita 1v1 arrivi a fine coerente
## passando interamente per il canale.
extends Node

var host: MatchHost
var channel: LoopbackChannel
var clients: Array = []
var _over := false
var _winner := -99
var _msgs := 0

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
	s.fighters[0].facing = AI.facing_toward(s.fighters[0].cell, s.fighters[1].cell)
	s.fighters[1].facing = AI.facing_toward(s.fighters[1].cell, s.fighters[0].cell)

	channel = LoopbackChannel.new()
	host = MatchHost.new(s, channel)
	for seat in [0, 1]:
		var c := MatchClient.new(seat, channel)
		c.prompt_received.connect(_on_client_prompt.bind(c))
		c.finished.connect(func(w): _over = true; _winner = w)
		clients.append(c)
	host.start()

## Un client riceve un prompt: decide solo dai dati e risponde via canale.
func _on_client_prompt(kind: String, data: Dictionary, client: MatchClient) -> void:
	_msgs += 1
	if _msgs > 12000:
		return
	var resp := _decide(kind, data)
	client.respond(kind, resp)

func _decide(kind: String, data: Dictionary) -> Dictionary:
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
			return {"pick": -1}
		"resolve":
			return _decide_resolve(data)
	return {}

func _decide_resolve(data: Dictionary) -> Dictionary:
	var own := _pk(str(data.get("cell", "0,0")))
	var foe := _pk(str(data.get("foe", "0,0")))
	if not bool(data.get("move_used", false)):
		var best := ""; var bestd := 999
		for key in (data.get("legalCells", {}) as Dictionary).keys():
			var cell := _pk(str(key))
			if cell == own: continue
			var d := HexGrid.distance(cell, foe)
			if d < bestd: bestd = d; best = str(key)
		if best != "":
			return {"action": "move", "cell": best}
	var want := AI.facing_toward(own, foe)
	if want != int(data.get("facing", 0)) and (data.get("legalFacings", []) as Array).has(want):
		return {"action": "rotate", "facing": want}
	return {"action": "confirm"}

func _pk(s: String) -> Vector2i:
	var p := s.split(",")
	return Vector2i(int(p[0]), int(p[1])) if p.size() == 2 else Vector2i.ZERO

func _process(_dt: float) -> void:
	if _over:
		_finish()
	elif _msgs > 12000:
		print("FAIL: troppi messaggi (loop?) =", _msgs)
		print("RISULTATO: FAIL"); get_tree().quit(1)

func _finish() -> void:
	set_process(false)
	var ok := true
	var st := host.protocol.state
	var a := st.fighters[0]; var b := st.fighters[1]
	print("OK: partita via CANALE (host+2 client loopback) conclusa, %d messaggi" % _msgs)
	var who := "Pareggio" if _winner < 0 else "Giocatore %d (%s)" % [_winner + 1, st.fighters[_winner].character]
	print("    Vincitore: %s | G1 %d/%d, G2 %d/%d" % [who, a.wounds.size(), a.effective_wound_limit(), b.wounds.size(), b.effective_wound_limit()])
	if _winner >= 0:
		if st.fighters[_winner].is_defeated() or not st.fighters[1 - _winner].is_defeated():
			print("FAIL: stato finale incoerente"); ok = false
		else:
			print("OK: stato finale coerente (vincitore vivo, perdente sconfitto)")
	else:
		print("FAIL: nessun vincitore"); ok = false
	print("RISULTATO: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
