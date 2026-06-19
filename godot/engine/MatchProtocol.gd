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
# Stati raggiungibili (cella → facing legali) calcolati UNA volta dalla posizione di
# partenza: la rotazione è limitata a questo insieme (come fa l'arena locale), così il
# budget di rotazione della carta non si "azzera" a ogni rotazione.
var _rreach: Dictionary = {}


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
	duel.resolution_order.connect(func(order): public_event.emit("order", {"order": order}))
	duel.fighter_updated.connect(func(_i): _emit_board())
	duel.turn_resolved.connect(func(log): public_event.emit("turn", {"log": log}))
	duel.duel_over.connect(func(w): finished.emit(w))


## Istantanea pubblica del campo per il TAVOLO (posizioni/ferite/focus/kamae).
func _board_data() -> Dictionary:
	var arr: Array = []
	for f in state.fighters:
		arr.append({
			"name": f.character, "cell": _cell_key(f.cell), "facing": f.facing,
			"wounds": f.wounds.size(), "limit": f.effective_wound_limit(),
			"stun": f.stun, "focus": f.focus, "kamae": Domain.STANCE_SLUG[f.stance],
			"hand": f.hand.size(), "deck": f.draw_pile.size(), "discard": f.discard.size(),
		})
	return {"fighters": arr, "round": state.round_num, "radius": state.map_radius}


func _emit_board() -> void:
	public_event.emit("board", _board_data())


func is_human(seat: int) -> bool:
	return seat >= 0 and seat < state.fighters.size() and not state.fighters[seat].is_ai


func start() -> void:
	duel.start()   # → phase_changed(PLANNING) → _prompt_planning()
	_emit_board()


# ─── Risposte dal giocatore ──────────────────────────────────────────────────

func respond(seat: int, kind: String, data: Dictionary) -> void:
	match kind:
		"plan":
			duel.plan_card(seat, int(data.get("card", -1)))
		"instant_replace":
			var picked := int(data.get("pick", -1))
			duel.apply_instant_replace(seat, picked)
			if picked != -1:
				# Carta sostituita: aggiorna le carte mostrate sul tavolo (animazione).
				var planned := {}
				for j in range(state.fighters.size()):
					planned[j] = state.fighters[j].planned
				public_event.emit("revealed", {"planned": planned, "replaced": seat})
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
	_compute_reach()
	prompt.emit(i, "resolve", _resolve_data())


## Calcola gli stati raggiungibili (cella → facing legali) dalla posizione ATTUALE,
## una sola volta all'inizio della risoluzione (o della parte bassa dello split).
func _compute_reach() -> void:
	_rreach = {}
	if _rseat == -1:
		return
	var f := state.fighters[_rseat]
	var g := _resolve_geom()
	if g.has("move"):
		_rreach = Move.reachable_by_cell(f.cell, f.facing, g["move"], state.is_blocked, Domain.STANCE_SLUG[f.stance])


## Geometria della carta in risoluzione (carta scelta o parte bassa dello split).
func _resolve_geom() -> Dictionary:
	if _rsplit:
		return duel.pending_split_geom()
	return CardDB.geometry(state.fighters[_rseat].planned)


func _resolve_data() -> Dictionary:
	var f := state.fighters[_rseat]
	var foe := state.opponent_of(f)
	var g := _resolve_geom()
	var legal_cells := {}
	var can_move: bool = (not _rmove_used) and g.has("move") and not f.movement_cancelled
	if can_move:
		# Celle di destinazione (dalla mappa raggiungibile fissa, esclusa quella attuale).
		for cell in _rreach.keys():
			if cell != f.cell:
				legal_cells[_cell_key(cell)] = _rreach[cell]
	# Facing legali nella cella ATTUALE: insieme FISSO calcolato a inizio risoluzione,
	# così il budget di rotazione della carta è rispettato e non si rigenera.
	var legal_facings: Array = (_rreach.get(f.cell, []) as Array)
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
		"foe": _cell_key(foe.cell) if foe != null else "",
		"targets": targets,
		"radius": state.map_radius,
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
		"skip_move":
			_rmove_used = true   # "non muovere": passa al passo rotazione/azioni
		"rotate":
			_do_rotate(int(data.get("facing", state.fighters[_rseat].facing)))
		"kamae":
			_do_kamae(str(data.get("slug", "")))
		"option":
			duel.set_option_choice(_rseat, data.get("alt", ""))
			public_event.emit("choice", {"seat": seat, "text": "sceglie: " + _option_label(_resolve_geom(), data.get("alt", ""))})
		"confirm":
			_do_confirm()
			return
	# Azione non finale: aggiorna il tavolo e re-invia il prompt.
	_emit_board()
	if _rseat != -1:
		prompt.emit(_rseat, "resolve", _resolve_data())


func _do_move(cell: Vector2i) -> void:
	var f := state.fighters[_rseat]
	if _rmove_used or f.movement_cancelled:
		return
	if not _rreach.has(cell) or cell == f.cell:
		return
	f.cell = cell
	# Facing: mantieni l'attuale se legale, altrimenti il legale più vicino.
	var facings: Array = _rreach[cell]
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
	# Solo i facing dell'insieme FISSO calcolato a inizio risoluzione: la rotazione
	# resta limitata al budget della carta (non si rigenera a ogni passo).
	var allowed: Array = (_rreach.get(f.cell, []) as Array)
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
		_compute_reach()
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
	var g := CardDB.geometry(state.fighters[_rseat].planned)
	var out: Array = []
	for k in duel.option_keys(_rseat):
		out.append({"alt": k, "label": _option_label(g, k)})
	return out


## Etichetta leggibile di un'opzione OPPURE: concatena le frasi dei suoi effetti.
func _option_label(g: Dictionary, alt) -> String:
	var parts: Array = []
	for e in g.get("effects", []):
		if str(e.get("alt", "")) == str(alt):
			parts.append(_effect_phrase(e))
	return " + ".join(parts) if not parts.is_empty() else str(alt)


## Frase breve e leggibile per un singolo effetto v2.
func _effect_phrase(e: Dictionary) -> String:
	var n := int(e.get("n", 1))
	var s := ""
	match str(e.get("do", "")):
		"draw": s = "Pesca %d" % n
		"search_draw": s = "Cerca e pesca %d" % n
		"focus": s = "+%d focus" % n
		"change_kamae": s = "Cambia Kamae"
		"switch_kamae": s = "Passa a %s" % Domain.STANCE_NAMES.get(Domain.STANCE_FROM_SLUG.get(str(e.get("to","")), -1), str(e.get("to","")))
		"discard_self": s = "Scarta %d" % n
		"stun_self": s = "Prendi %d stordito" % n
		"foe_stun": s = "Avversario +%d stordito" % n
		"push": s = "Spingi %d" % n
		"pull": s = "Tira %d" % n
		"rotate_target": s = "Ruota avversario %d" % n
		"foe_lose_focus": s = "Avversario −%d focus" % n
		"foe_discard": s = "Avversario scarta %d" % n
		"spend_focus": s = "Spendi focus"
		"replace_wound_bleed": s = "Ferita→sanguinante"
		"bleed": s = "Sanguinante"
		"hobble": s = "Azzoppa %d" % n
		"swap_positions": s = "Scambia posizione"
		"reduce_damage": s = "Riduci danno %d" % n
		"reset_deck": s = "Rimescola il mazzo"
		"cancel_movement": s = "Annulla movimento avv."
		"cancel_abilities": s = "Annulla abilità avv."
		"block_initiative": s = "Blocco ampio +%d" % n
		_: s = str(e.get("do", "?"))
	if int(e.get("focus_cost", 0)) > 0:
		s += " (◈%d)" % int(e.get("focus_cost", 0))
	return s


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
