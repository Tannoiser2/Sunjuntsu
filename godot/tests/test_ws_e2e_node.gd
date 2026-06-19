## Tappa 3 multiplayer E2E: TAVOLO (MatchHost) + 2 TELEFONI (MatchClient) collegati
## via WebSocket REALE al relay Node (server/server.js), che deve girare su :8123.
## I telefoni decidono solo dai dati del prompt: una partita 1v1 completa passa per
## la rete fino a fine coerente. Lanciato dallo script tests/run_ws_e2e.sh.
extends Node

const URL := "ws://127.0.0.1:8123"
const CODE := "E2E1"

var host: MatchHost
var table_ch: WebSocketChannel
var clients: Array = []
var _state: GameState
var _joined := {}
var _started := false
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
	_state = GameState.new()
	_state.fighters = [_mk("Warrior", Vector2i(-3, 1), 0), _mk("Ronin", Vector2i(3, -1), 3)]
	_state.fighters[0].draw_pile = CardDB.draw_pile_for("warrior"); _state.fighters[0].draw_pile.shuffle()
	_state.fighters[1].draw_pile = CardDB.draw_pile_for("ronin"); _state.fighters[1].draw_pile.shuffle()
	_state.fighters[0].facing = AI.facing_toward(_state.fighters[0].cell, _state.fighters[1].cell)
	_state.fighters[1].facing = AI.facing_toward(_state.fighters[1].cell, _state.fighters[0].cell)

	table_ch = WebSocketChannel.new(); add_child(table_ch)
	table_ch.created.connect(_on_created)
	table_ch.peer.connect(_on_peer)
	table_ch.open(URL, {"t": "create", "code": CODE})

	for seat in [0, 1]:
		var ch := WebSocketChannel.new(); add_child(ch)
		var cl := MatchClient.new(seat, ch)
		cl.prompt_received.connect(_on_prompt.bind(cl))
		cl.finished.connect(func(w): _over = true; _winner = w)
		ch.open(URL, {"t": "join", "code": CODE, "seat": seat})
		clients.append(cl)

	# Timeout di sicurezza.
	get_tree().create_timer(40.0).timeout.connect(func():
		if not _over:
			print("FAIL: timeout (rete non ha completato la partita)")
			print("RISULTATO: FAIL"); get_tree().quit(1))

func _on_created(_code: String) -> void:
	host = MatchHost.new(_state, table_ch)
	_maybe_start()

func _on_peer(event: String, seat: int) -> void:
	if event == "join":
		_joined[seat] = true
		_maybe_start()

func _maybe_start() -> void:
	if not _started and host != null and _joined.has(0) and _joined.has(1):
		_started = true
		host.start()

func _on_prompt(kind: String, data: Dictionary, client: MatchClient) -> void:
	_msgs += 1
	if _msgs > 20000:
		return
	client.respond(kind, _decide(kind, data))

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

func _finish() -> void:
	set_process(false)
	var ok := true
	var st := host.protocol.state
	var a := st.fighters[0]; var b := st.fighters[1]
	print("OK: partita E2E via WEBSOCKET conclusa, %d messaggi" % _msgs)
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
