## Protocollo decisioni — Senjutsu (Tappa 1 del multiplayer companion)
##
## Strato SOPRA il motore (`Duel`/`GameState`) che trasforma ogni punto-decisione del
## turno in un MESSAGGIO DATI ("prompt") per un giocatore, e applica la sua RISPOSTA
## chiamando il motore. È puro (RefCounted), testabile headless e senza rete: sarà la
## base condivisa da client telefono e tavolo (vedi docs/MULTIPLAYER_PLAN.md).
##
## Flusso: per ogni seat umano il protocollo emette `prompt(seat, kind, data)`; il
## chiamante risponde con `respond(seat, kind, data)`. Gli eventi pubblici
## (rivelazione/colpi/log/fine) arrivano su `public_event`. I seat IA sono gestiti in
## automatico (come fa l'arena in solitaria).
class_name MatchProtocol
extends RefCounted

## Una scelta da presentare al giocatore `seat`. kind:
##  "plan" | "instant_replace" | "resolve" | "instant_play"
signal prompt(seat: int, kind: String, data: Dictionary)
## Evento pubblico per il tavolo (rivelazione, combattimento, log, stato).
signal public_event(kind: String, data: Dictionary)
## Duello terminato (winner: indice o -1 pareggio).
signal finished(winner: int)

var state: GameState
var duel: Duel

# Stato della risoluzione interattiva del seat umano corrente.
var _rseat: int = -1
var _rmove_used: bool = false
var _rkamae_used: bool = false
var _rsplit: bool = false


func _init(initial_state: GameState) -> void:
	state = initial_state
	duel = Duel.new(state)
	duel.interactive = true
	duel.phase_changed.connect(_on_phase_changed)
	duel.cards_revealed.connect(func(p): public_event.emit("revealed", {"planned": p}))
	duel.await_instant_replace.connect(_on_await_instant_replace)
	duel.await_resolution.connect(_on_await_resolution)
	duel.await_instant_play.connect(_on_await_instant_play)
	duel.combat_event.connect(func(kind, a, t, info): public_event.emit("combat", {"kind": kind, "attacker": a, "target": t, "info": info}))
	duel.turn_resolved.connect(func(log): public_event.emit("turn", {"log": log}))
	duel.duel_over.connect(func(w): finished.emit(w))


func is_human(seat: int) -> bool:
	return seat >= 0 and seat < state.fighters.size() and not state.fighters[seat].is_ai


func start() -> void:
	duel.start()   # → phase_changed(PLANNING) → _prompt_planning()


# ─── Risposte dal giocatore ──────────────────────────────────────────────────

func respond(seat: int, kind: String, data: Dictionary) -> void:
	match kind:
		"plan":
			duel.plan_card(seat, int(data.get("card", -1)))
		"instant_replace":
			duel.apply_instant_replace(seat, int(data.get("pick", -1)))
		"instant_play":
			duel.apply_instant_play(seat, int(data.get("pick", -1)))
		"resolve":
			_apply_resolve_action(seat, data)


# ─── Programmazione ──────────────────────────────────────────────────────────

func _on_phase_changed(p: int) -> void:
	if p == Domain.Phase.PLANNING:
		_prompt_planning()


func _prompt_planning() -> void:
	for i in range(state.fighters.size()):
		var f := state.fighters[i]
		if is_human(i) and f.planned == -1 and not f.hand.is_empty():
			prompt.emit(i, "plan", _plan_data(i))


func _plan_data(i: int) -> Dictionary:
	var f := state.fighters[i]
	var cards: Array = []
	for cid in f.hand:
		var c := CardDB.card(cid)
		var cost := int(c.get("focus", 0))
		cards.append({
			"id": cid, "name": c.get("name", "?"), "type": c.get("type", ""),
			"focus": cost, "file": CardDB.image_for(cid),
			"playable": Duel.playable(f, cid) and f.focus >= cost,
		})
	return {"hand": cards, "focus": f.focus, "kamae": Domain.STANCE_SLUG[f.stance]}


# ─── Rivelazione: sostituzione istantanea ────────────────────────────────────

func _on_await_instant_replace(i: int, options: Array) -> void:
	if not is_human(i):
		duel.apply_instant_replace(i, -1)
		return
	prompt.emit(i, "instant_replace", {
		"options": _card_briefs(options),
		"revealed": _card_briefs([state.fighters[i].planned])[0],
	})


# ─── Risoluzione ─────────────────────────────────────────────────────────────

func _on_await_resolution(i: int) -> void:
	if is_human(i):
		_begin_resolve(i)
	else:
		_ai_resolve(i)


## Risoluzione automatica del seat IA (priorità solitario), come fa l'arena.
func _ai_resolve(i: int) -> void:
	var f := state.fighters[i]
	var foe := state.opponent_of(f)
	if foe != null:
		var g := CardDB.geometry(f.planned)
		if not f.movement_cancelled and g.has("move"):
			var plan := AI.plan_move(state, f, g)
			f.cell = plan["cell"]; f.facing = plan["facing"]
		elif foe != null:
			f.facing = AI.facing_toward(f.cell, foe.cell)
	duel.resolve_current()


func _begin_resolve(i: int) -> void:
	_rseat = i
	_rmove_used = false
	_rkamae_used = false
	_rsplit = false
	prompt.emit(i, "resolve", _resolve_data())


## Geometria della carta in risoluzione (carta scelta o parte bassa dello split).
func _resolve_geom() -> Dictionary:
	if _rsplit:
		return duel.pending_split_geom()
	return CardDB.geometry(state.fighters[_rseat].planned)


func _resolve_data() -> Dictionary:
	var f := state.fighters[_rseat]
	var g := _resolve_geom()
	var legal_cells := {}
	var legal_facings: Array = []
	var can_move: bool = (not _rmove_used) and g.has("move") and not f.movement_cancelled
	if can_move:
		var reach := Move.reachable_by_cell(f.cell, f.facing, g["move"], state.is_blocked, Domain.STANCE_SLUG[f.stance])
		for cell in reach.keys():
			if cell != f.cell:
				legal_cells[_cell_key(cell)] = reach[cell]
		legal_facings = (reach.get(f.cell, []) as Array)
	elif g.has("move"):
		# Dopo il movimento: i facing legali nella cella attuale (per la rotazione).
		var reach2 := Move.reachable_by_cell(f.cell, f.facing, g.get("move", {}), state.is_blocked, Domain.STANCE_SLUG[f.stance]) if g.has("move") else {}
		legal_facings = (reach2.get(f.cell, []) as Array)
	# Bersagli d'attacco visibili (per l'anteprima sul telefono).
	var targets: Array = []
	if g.get("type", "") == "attack" or g.has("attack"):
		for cell in Duel.attack_v2_cells(f.cell, f.facing, g, 1):
			targets.append(_cell_key(cell))
	return {
		"card": CardDB.card(state.fighters[_rseat].planned).get("name", "Parte bassa") if not _rsplit else "Parte bassa",
		"split": _rsplit,
		"move_used": _rmove_used,
		"legalCells": legal_cells,
		"legalFacings": legal_facings,
		"facing": f.facing,
		"cell": _cell_key(f.cell),
		"targets": targets,
		"kamae": _kamae_reachable(),
		"options": _option_briefs(),
		"canConfirm": true,
	}


func _apply_resolve_action(seat: int, data: Dictionary) -> void:
	if seat != _rseat:
		return
	match str(data.get("action", "")):
		"move":
			_do_move(_key_cell(str(data.get("cell", ""))))
		"rotate":
			_do_rotate(int(data.get("facing", state.fighters[_rseat].facing)))
		"kamae":
			_do_kamae(str(data.get("slug", "")))
		"option":
			duel.set_option_choice(_rseat, data.get("alt", ""))
		"confirm":
			_do_confirm()
			return
	# Azione non finale: re-invia il prompt aggiornato.
	if _rseat != -1:
		prompt.emit(_rseat, "resolve", _resolve_data())


func _do_move(cell: Vector2i) -> void:
	var f := state.fighters[_rseat]
	if _rmove_used or f.movement_cancelled:
		return
	var g := _resolve_geom()
	if not g.has("move"):
		return
	var reach := Move.reachable_by_cell(f.cell, f.facing, g["move"], state.is_blocked, Domain.STANCE_SLUG[f.stance])
	if not reach.has(cell) or cell == f.cell:
		return
	f.cell = cell
	# Facing: mantieni l'attuale se legale, altrimenti il legale più vicino.
	var facings: Array = reach[cell]
	if not facings.is_empty() and not facings.has(f.facing):
		var best: int = int(facings[0]); var best_d := 99
		for fc in facings:
			var dd: int = mini((int(fc) - f.facing + 6) % 6, (f.facing - int(fc) + 6) % 6)
			if dd < best_d: best_d = dd; best = int(fc)
		f.facing = best
	_rmove_used = true


func _do_rotate(facing: int) -> void:
	var f := state.fighters[_rseat]
	var g := _resolve_geom()
	var allowed: Array = []
	if g.has("move"):
		allowed = (Move.reachable_by_cell(f.cell, f.facing, g["move"], state.is_blocked, Domain.STANCE_SLUG[f.stance]).get(f.cell, []) as Array)
	if allowed.has(facing):
		f.facing = facing
	elif not g.has("move") and int(g.get("rotates", 0)) > 0:
		f.facing = (facing + 6) % 6


func _do_kamae(slug: String) -> void:
	if _rkamae_used or _rsplit:
		return
	var f := state.fighters[_rseat]
	var targets := _kamae_reachable()
	if not targets.has(slug):
		return
	f.gain_focus(int(targets[slug]))
	f.stance = Domain.STANCE_FROM_SLUG[slug]
	_rkamae_used = true


func _do_confirm() -> void:
	if _rsplit:
		_rsplit = false
		_rseat = -1
		duel.resolve_split_now()
		return
	_rseat = -1
	duel.resolve_current()
	if duel.has_pending_split():
		# Entra nella parte bassa (iniziativa divisa): nuovo loop di risoluzione.
		_rseat = _split_owner()
		_rsplit = true
		_rmove_used = false
		_rkamae_used = true   # niente cambio Kamae nella parte bassa
		prompt.emit(_rseat, "resolve", _resolve_data())


# ─── Istantanea aggiuntiva ───────────────────────────────────────────────────

func _on_await_instant_play(i: int, options: Array) -> void:
	if not is_human(i):
		duel.apply_instant_play(i, -1)
		return
	prompt.emit(i, "instant_play", {"options": _card_briefs(options)})


# ─── Helper dati ─────────────────────────────────────────────────────────────

## Parametri dell'effetto change_kamae della carta in risoluzione, o {}.
func _change_kamae_params(g: Dictionary) -> Dictionary:
	for e in g.get("effects", []):
		if str(e.get("do", "")) == "change_kamae":
			return {"n": int(e.get("n", 1)), "gate": str(e.get("kamae", ""))}
	return {}


func _kamae_reachable() -> Dictionary:
	if _rkamae_used or _rsplit or _rseat == -1:
		return {}
	var f := state.fighters[_rseat]
	var g := CardDB.geometry(f.planned)
	var params := _change_kamae_params(g)
	if params.is_empty():
		return {}
	var gate: String = params.get("gate", "")
	if gate != "" and gate != Domain.STANCE_SLUG[f.stance]:
		return {}
	var tree := CardDB.kamae_tree_for(f.character.to_lower())
	return Kamae.change_targets(tree, Domain.STANCE_SLUG[f.stance], int(params.get("n", 1)))


func _option_briefs() -> Array:
	if _rsplit or _rseat == -1:
		return []
	var out: Array = []
	for k in duel.option_keys(_rseat):
		out.append({"alt": k})
	return out


func _card_briefs(ids: Array) -> Array:
	var out: Array = []
	for id in ids:
		var c := CardDB.card(int(id))
		out.append({"id": int(id), "name": c.get("name", "?"), "type": c.get("type", ""), "focus": int(c.get("focus", 0)), "file": CardDB.image_for(int(id))})
	return out


func _split_owner() -> int:
	return duel.current_resolver()


static func _cell_key(c: Vector2i) -> String:
	return "%d,%d" % [c.x, c.y]


static func _key_cell(s: String) -> Vector2i:
	var parts := s.split(",")
	if parts.size() == 2:
		return Vector2i(int(parts[0]), int(parts[1]))
	return Vector2i.ZERO
