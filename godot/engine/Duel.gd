## Motore del duello — Senjutsu
##
## Implementa la sequenza del turno del regolamento 1.5 su un GameState:
##   pesca → scelta (faccia in giù) → rivelazione simultanea → paga focus →
##   ordine per iniziativa → risoluzione (attacco / blocco / meditazione) →
##   ferite → controllo sconfitta → riordino.
##
## Logica pura (testabile headless): emette segnali che la scena 3D ascolta.
##
## ── Approssimazioni dichiarate ───────────────────────────────────────────────
## La GEOMETRIA degli attacchi (quali esagoni del corpo colpisce ogni carta) è
## stampata solo sulla faccia delle carte e NON è disponibile in forma dati:
## qui un attacco a segno infligge 1 ferita e una difesa rivelata blocca il primo
## attacco del turno. Contro/zone/step verranno raffinati quando avremo i dati
## geometrici. Vedi DESIGN.md.
class_name Duel
extends RefCounted

signal phase_changed(phase: int)
signal turn_resolved(log: Array)          ## righe testuali di cosa è successo
signal fighter_updated(index: int)        ## stato cambiato (ferite/focus/mano)
signal duel_over(winner_index: int)

var state: GameState


func _init(initial_state: GameState) -> void:
	state = initial_state


func start() -> void:
	for f in state.fighters:
		while f.hand.size() < f.hand_limit:
			if f.draw_one() == -1:
				break
	_set_phase(Domain.Phase.PLANNING)
	_autoplan_ai()


func _set_phase(p: int) -> void:
	state.phase = p
	phase_changed.emit(p)


# ─── Programmazione ──────────────────────────────────────────────────────────

## Il giocatore (umano) programma una carta dalla propria mano.
func plan_card(fighter_index: int, card_id: int) -> bool:
	if state.phase != Domain.Phase.PLANNING:
		return false
	var f := state.fighters[fighter_index]
	if not f.hand.has(card_id):
		return false
	f.planned = card_id
	f.hand.erase(card_id)
	_autoplan_ai()
	if _all_planned():
		_resolve_turn()
	return true


func _autoplan_ai() -> void:
	for i in range(state.fighters.size()):
		var f := state.fighters[i]
		if f.is_ai and f.planned == -1 and not f.hand.is_empty():
			# Movimento posizionale dell'IA prima di rivelare.
			var dest := AI.move_target(state, f)
			if dest != f.cell:
				f.cell = dest
			# L'IA si orienta verso l'avversario.
			var foe := state.opponent_of(f)
			if foe != null:
				f.facing = AI.facing_toward(f.cell, foe.cell)
			fighter_updated.emit(i)
			var pick := AI.choose_card(state, f)
			if pick != -1:
				f.planned = pick
				f.hand.erase(pick)


func _all_planned() -> bool:
	for f in state.fighters:
		if f.planned == -1 and not f.hand.is_empty():
			return false
	return true


# ─── Risoluzione del turno ───────────────────────────────────────────────────

func _resolve_turn() -> void:
	_set_phase(Domain.Phase.RESOLUTION)
	var log: Array = []

	# Paga i costi di focus obbligatori; se non basta, la carta "svanisce".
	var fizzled := {}
	for i in range(state.fighters.size()):
		var f := state.fighters[i]
		if f.planned == -1:
			continue
		var c := CardDB.card(f.planned)
		var cost := int(c.get("focus", 0))
		if cost > 0:
			if f.focus >= cost:
				f.focus -= cost
			else:
				fizzled[i] = true
				log.append("%s: focus insufficiente per %s — la carta svanisce" % [
					f.character, c.get("name", "?")])

	# Difese rivelate (non svanite): blocco disponibile per il turno.
	var block_ready := {}
	for i in range(state.fighters.size()):
		var f := state.fighters[i]
		if f.planned != -1 and not fizzled.has(i):
			if CardDB.card(f.planned).get("type", "") == "defence":
				block_ready[i] = true

	# Ordine di iniziativa (più alta agisce prima).
	for i in _initiative_order():
		if state.fighters[i].is_defeated():
			continue
		if state.fighters[i].planned == -1 or fizzled.has(i):
			continue
		_resolve_card(i, block_ready, log)
		var w := _check_winner()
		if w != -2:
			_finish(log, w)
			return

	_cleanup(log)


func _initiative_order() -> Array:
	var arr: Array = []
	for i in range(state.fighters.size()):
		arr.append(i)
	arr.sort_custom(func(a, b): return _speed_of(a) > _speed_of(b))
	return arr


func _speed_of(i: int) -> int:
	var f := state.fighters[i]
	if f.planned == -1:
		return -999
	return Domain.initiative_value(str(CardDB.card(f.planned).get("initiative", "")))


func _resolve_card(i: int, block_ready: Dictionary, log: Array) -> void:
	var f := state.fighters[i]
	var c := CardDB.card(f.planned)
	var g := CardDB.geometry(f.planned)   ## geometria/effetti trascritti (può essere vuota)
	var name: String = c.get("name", "?")
	match c.get("type", ""):
		"attack":
			var foe_idx := _opponent_index(i)
			if foe_idx == -1:
				return
			var foe := state.fighters[foe_idx]
			var cells := attack_cells(f.cell, f.facing, g, _card_range(c))
			if not cells.has(foe.cell):
				var dist := HexGrid.distance(f.cell, foe.cell)
				log.append("%s usa %s ma il bersaglio è fuori arco/portata (dist %d)" % [f.character, name, dist])
				return
			if block_ready.get(foe_idx, false):
				block_ready[foe_idx] = false
				log.append("%s attacca con %s — %s PARA!" % [f.character, name, foe.character])
				return
			var n: int = int(g.get("wounds", 1))
			var kind: String = g.get("wound_kind", "normal")
			if kind == "exec":
				foe.wounds.append("exec"); foe.wounds.resize(foe.wound_limit)
			else:
				var tag := "bleed" if kind == "bleed" else "wound"
				for _w in range(maxi(1, n)):
					foe.wounds.append(tag)
			_apply_if_success(i, foe_idx, g, log)
			fighter_updated.emit(foe_idx)
			log.append("%s colpisce %s con %s — %d ferita/e (%d/%d)" % [
				f.character, foe.character, name, maxi(1, n), foe.wounds.size(), foe.wound_limit])
		"defence":
			log.append("%s si mette in guardia (%s)" % [f.character, name])
		"meditation":
			var fg: int = int(g.get("focus_gain", 1))
			var dr: int = int(g.get("draw", 1))
			f.gain_focus(fg)
			for _d in range(maxi(0, dr)):
				f.draw_one()
			fighter_updated.emit(i)
			log.append("%s medita (%s): +%d focus, pesca %d" % [f.character, name, fg, maxi(0, dr)])
		_:
			log.append("%s gioca %s" % [f.character, name])


## Applica gli effetti "se riuscito" trascritti (push, focus, bleed).
func _apply_if_success(att_idx: int, foe_idx: int, g: Dictionary, log: Array) -> void:
	var att := state.fighters[att_idx]
	var foe := state.fighters[foe_idx]
	for eff in g.get("if_success", []):
		var s := str(eff)
		if s.begins_with("focus:"):
			att.gain_focus(int(s.substr(6)))
		elif s.begins_with("push:"):
			_push(att_idx, foe_idx, int(s.substr(5)))
		elif s == "bleed":
			foe.wounds.append("bleed")


## Spinge `foe` di `n` esagoni lontano da `att`, se le celle sono libere.
func _push(att_idx: int, foe_idx: int, n: int) -> void:
	var att := state.fighters[att_idx]
	var foe := state.fighters[foe_idx]
	for _k in range(n):
		var best := foe.cell
		var best_d := HexGrid.distance(att.cell, foe.cell)
		for nb in HexGrid.neighbors(foe.cell):
			if state.is_blocked(nb):
				continue
			if HexGrid.distance(att.cell, nb) > best_d:
				best_d = HexGrid.distance(att.cell, nb)
				best = nb
		if best == foe.cell:
			break
		foe.cell = best
	fighter_updated.emit(foe_idx)


func _cleanup(log: Array) -> void:
	_set_phase(Domain.Phase.CLEANUP)
	for f in state.fighters:
		if f.planned != -1:
			f.discard.append(f.planned)
			f.planned = -1
		# Sanguinamento: a inizio turno scarti la prima carta del mazzo (max 1).
		if f.has_bleed() and not f.draw_pile.is_empty():
			f.discard.append(f.draw_pile.pop_back())
			log.append("%s sanguina: scarta una carta dal mazzo" % f.character)
		if f.hand.size() < f.hand_limit:
			f.draw_one()
	state.round_num += 1
	turn_resolved.emit(log)
	_set_phase(Domain.Phase.PLANNING)
	_autoplan_ai()


func _finish(log: Array, winner: int) -> void:
	_set_phase(Domain.Phase.GAME_OVER)
	turn_resolved.emit(log)
	duel_over.emit(winner)


# ─── Utility ─────────────────────────────────────────────────────────────────

func _opponent_index(i: int) -> int:
	for j in range(state.fighters.size()):
		if j != i:
			return j
	return -1


## -2 = nessun vincitore ancora; altrimenti indice del vincitore (o -1 = pari).
func _check_winner() -> int:
	var alive: Array = []
	for i in range(state.fighters.size()):
		if not state.fighters[i].is_defeated():
			alive.append(i)
	if alive.size() == state.fighters.size():
		return -2
	if alive.size() == 1:
		return alive[0]
	return -1


## Esagoni bersaglio di un attacco, dato origine, direzione (facing) e geometria.
## Usa gli archi relativi trascritti (`dirs`, 0=fronte orario) estesi fino a
## `range`. Se la geometria non ha `dirs`, ripiega su "tutti gli esagoni entro
## la portata" (comportamento astratto).
static func attack_cells(origin: Vector2i, facing: int, geom: Dictionary, fallback_range: int) -> Array[Vector2i]:
	var rng: int = int(geom.get("range", fallback_range))
	rng = maxi(1, rng)
	var dirs = geom.get("dirs", [])
	var out: Array[Vector2i] = []
	if dirs.is_empty():
		for cell in HexGrid.hexes_in_range(origin, rng):
			if cell != origin:
				out.append(cell)
		return out
	for d in dirs:
		var ad: int = (facing + int(d)) % 6
		for k in range(1, rng + 1):
			out.append(origin + HexGrid.DIRS[ad] * k)
	return out


static func _card_range(c: Dictionary) -> int:
	for kw in c.get("keywords", []):
		var s := str(kw).to_lower()
		if s.begins_with("range"):
			var digits := ""
			for ch in s:
				if ch.is_valid_int():
					digits += ch
			if digits != "":
				return int(digits)
	return 1
