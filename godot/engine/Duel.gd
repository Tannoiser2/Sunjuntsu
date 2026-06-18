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
signal cards_revealed(planned: Dictionary)   ## fi → card_id (fase rivelazione)
signal await_resolution(index: int)          ## tocca a `index` risolvere (mossa interattiva)

var state: GameState

## Modalità interattiva: la risoluzione avviene a passi guidati dalla scena
## (programma → rivela → risolvi in ordine d'iniziativa). Se false, la
## risoluzione è sincrona (usata dai test headless).
var interactive: bool = false

## Stato della risoluzione interattiva in corso.
var _order: Array = []
var _order_idx: int = -1
var _block_ready: Dictionary = {}
var _fizzled: Dictionary = {}
var _res_log: Array = []
var _opt_choice: Dictionary = {}   ## scelta "OPPURE" del giocatore (indice → chiave alt)

## Velocità d'iniziativa scelta da ogni combattente per il turno corrente
## (indice → valore). Le difese a iniziativa variabile scelgono il valore che
## aggancia l'attacco avversario, così il blocco scatta alla stessa velocità.
var _chosen: Dictionary = {}


func _init(initial_state: GameState) -> void:
	state = initial_state


func start() -> void:
	# Setup (passo 13): pesca fino al limite di mano. Gli avversari solo NON hanno
	# mano: il loro mazzo resta intero e rivelano la cima ogni turno.
	for f in state.fighters:
		if f.is_ai:
			continue
		while f.hand.size() < f.hand_limit:
			if f.draw_one() == -1:
				break
	_begin_turn()   # passo Draw del 1° turno
	_set_phase(Domain.Phase.PLANNING)
	_autoplan_ai()


## Passo "Draw" del turno (regolamento 1.5): per ogni combattente, se ha almeno
## una ferita sanguinante scarta 1 carta dal mazzo, poi pesca 1 carta (mazzo
## vuoto ⇒ ferita). Restituisce true se il duello continua.
func _begin_turn() -> bool:
	for f in state.fighters:
		if f.is_defeated() or f.is_ai:
			continue   # gli avversari solo saltano il passo Draw (e il sanguinamento conta come ferita)
		if f.has_bleed() and not f.draw_pile.is_empty():
			f.discard.append(f.draw_pile.pop_back())
		f.draw_one()
	var w := _check_winner()
	if w != -2:
		_finish([], w)
		return false
	return true


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
	if not playable(f, card_id):
		return false   # carta non giocabile nella Kamae attuale
	f.planned = card_id
	f.hand.erase(card_id)
	_autoplan_ai()
	if _all_planned():
		if interactive:
			begin_resolution()
		else:
			_resolve_turn()
	return true


## Una carta è giocabile solo se la sua Kamae richiesta (kamae_req) corrisponde
## alla posizione attuale del combattente.
static func playable(f: GameState.Fighter, card_id: int) -> bool:
	var req: String = CardDB.geometry(card_id).get("kamae_req", "")
	return req == "" or req == Domain.STANCE_SLUG[f.stance]


## Regole solo (rulebook p.20–22): gli avversari NON pescano, NON scelgono e NON
## usano focus. Rivelano la cima del proprio mazzo (rimescolando gli scarti se
## vuoto). Niente mano. Il movimento è gestito durante la risoluzione.
func _autoplan_ai() -> void:
	for i in range(state.fighters.size()):
		var f := state.fighters[i]
		if not f.is_ai or f.planned != -1 or f.is_defeated():
			continue
		if f.draw_pile.is_empty():
			f.draw_pile = f.discard.duplicate()
			f.discard.clear()
			f.draw_pile.shuffle()
		if f.draw_pile.is_empty():
			continue
		f.planned = f.draw_pile.pop_back()   # rivela la cima del mazzo
		# In modalità non interattiva (test) muovi subito; in interattiva lo fa la scena.
		if not interactive:
			var dest := AI.move_target(state, f)
			if dest != f.cell and not state.is_blocked(dest):
				f.cell = dest
			var foe := state.opponent_of(f)
			if foe != null:
				f.facing = AI.facing_toward(f.cell, foe.cell)
			fighter_updated.emit(i)


func _all_planned() -> bool:
	for f in state.fighters:
		if f.planned == -1 and not f.hand.is_empty():
			return false
	return true


# ─── Risoluzione del turno ───────────────────────────────────────────────────

## Prepara la risoluzione: paga i costi, calcola velocità scelte, blocchi e
## ordine d'iniziativa. Popola _fizzled, _block_ready, _order, _res_log.
func _setup_resolution() -> void:
	_set_phase(Domain.Phase.RESOLUTION)
	_res_log = []
	_fizzled = {}
	_opt_choice = {}   # le scelte "OPPURE" si impostano durante la risoluzione
	# Paga i costi di focus obbligatori; se non basta, la carta "svanisce".
	for i in range(state.fighters.size()):
		var f := state.fighters[i]
		if f.planned == -1:
			continue
		if f.is_ai:
			continue   # gli avversari solo ignorano i costi di focus/scarto
		var c := CardDB.card(f.planned)
		var g := CardDB.geometry(f.planned)
		var pc: Dictionary = g.get("play_cost", {})
		var cost := int(c.get("focus", 0)) + int(pc.get("focus", 0))
		if cost > 0:
			if f.focus >= cost:
				f.focus -= cost
			else:
				_fizzled[i] = true
				_res_log.append("%s: focus insufficiente per %s — la carta svanisce" % [
					f.character, c.get("name", "?")])
				continue
		var disc := int(pc.get("discard", 0))
		for _k in range(disc):
			if f.hand.is_empty():
				break
			f.discard.append(f.hand.pop_back())

	_resolve_chosen_speeds(_fizzled)

	_block_ready = {}
	for i in range(state.fighters.size()):
		var f := state.fighters[i]
		if f.planned != -1 and not _fizzled.has(i):
			if CardDB.card(f.planned).get("type", "") == "defence":
				_block_ready[i] = _chosen.get(i, -1)

	_order = _initiative_order()


## Risoluzione sincrona (test headless / modalità non interattiva).
func _resolve_turn() -> void:
	_setup_resolution()
	for i in _order:
		if state.fighters[i].is_defeated():
			continue
		if state.fighters[i].planned == -1 or _fizzled.has(i):
			continue
		_resolve_card(i, _block_ready, _res_log)
		var w := _check_winner()
		if w != -2:
			_finish(_res_log, w)
			return
	_cleanup(_res_log)


# ─── Risoluzione interattiva (programma → rivela → risolvi per iniziativa) ─────

## Avvia la risoluzione interattiva: rivela le carte ed emette `await_resolution`
## per il primo combattente nell'ordine d'iniziativa. La scena guida il
## movimento/attacco e poi chiama `resolve_current()`.
func begin_resolution() -> void:
	_setup_resolution()
	_order_idx = -1
	var planned := {}
	for i in range(state.fighters.size()):
		planned[i] = state.fighters[i].planned
	cards_revealed.emit(planned)
	_advance_resolution()


func _advance_resolution() -> void:
	_order_idx += 1
	while _order_idx < _order.size():
		var i: int = _order[_order_idx]
		if state.fighters[i].is_defeated() or state.fighters[i].planned == -1 or _fizzled.has(i):
			_order_idx += 1
			continue
		await_resolution.emit(i)
		return
	_cleanup(_res_log)


## Indice del combattente che deve risolvere ora (-1 se nessuno).
func current_resolver() -> int:
	if _order_idx < 0 or _order_idx >= _order.size():
		return -1
	return _order[_order_idx]


## La scena ha completato la mossa del combattente corrente: applica la carta e
## prosegui nell'ordine d'iniziativa (o termina/riordina).
func resolve_current() -> void:
	var i := current_resolver()
	if i == -1:
		return
	_resolve_card(i, _block_ready, _res_log)
	var w := _check_winner()
	if w != -2:
		_finish(_res_log, w)
		return
	_advance_resolution()


## Calcola la velocità d'iniziativa scelta da ogni combattente per il turno.
## I non-difensori prendono il valore più alto disponibile; le difese con
## iniziativa variabile scelgono il valore che combacia con la velocità
## dell'attacco avversario (se nelle opzioni), così il blocco scatta a quella
## velocità; altrimenti il valore più alto. Tutto al netto degli azzoppamenti.
func _resolve_chosen_speeds(fizzled: Dictionary) -> void:
	_chosen.clear()
	# 1ª passata: chi non è difesa fissa la velocità più alta.
	for i in range(state.fighters.size()):
		var f := state.fighters[i]
		if f.planned == -1 or fizzled.has(i):
			continue
		if CardDB.card(f.planned).get("type", "") == "defence":
			continue
		_chosen[i] = _hobbled(i, Domain.pick_initiative(_raw_ini(i), true))
	# 2ª passata: le difese agganciano la velocità dell'attacco avversario.
	for i in range(state.fighters.size()):
		var f := state.fighters[i]
		if f.planned == -1 or fizzled.has(i):
			continue
		if CardDB.card(f.planned).get("type", "") != "defence":
			continue
		var opts: Array = Domain.initiative_options(_raw_ini(i))
		if opts.is_empty():
			# Iniziativa "=" (istantanea) o assente: blocco a velocità massima.
			_chosen[i] = _hobbled(i, Domain.pick_initiative(_raw_ini(i), true))
			continue
		# Velocità dell'attacco avversario (se ne gioca uno).
		var foe_idx := _opponent_index(i)
		var target := -1
		if foe_idx != -1 and _chosen.has(foe_idx):
			var fc := CardDB.card(state.fighters[foe_idx].planned)
			if fc.get("type", "") == "attack":
				target = int(_chosen[foe_idx])
		var pick := -999
		if target != -1:
			# Scegli, fra le opzioni azzoppate, quella che combacia col bersaglio.
			for v in opts:
				if _hobbled(i, int(v)) == target:
					pick = _hobbled(i, int(v))
					break
		if pick == -999:
			# Nessun aggancio: prendi la più alta.
			pick = _hobbled(i, Domain.pick_initiative(_raw_ini(i), true))
		_chosen[i] = pick


func _raw_ini(i: int) -> String:
	return str(CardDB.card(state.fighters[i].planned).get("initiative", ""))


func _hobbled(i: int, sp: int) -> int:
	var f := state.fighters[i]
	var h := f.hobble_count()
	if sp >= 0 and h > 0:
		return maxi(1, sp - h)   # ogni azzoppamento attivo: −1 (min 1)
	return sp


## Ordine di risoluzione: velocità d'iniziativa decrescente; a parità, ordine di
## tipo (difesa→attacco→meditazione→base); a ulteriore parità, ordine di Kamae.
func _initiative_order() -> Array:
	var arr: Array = []
	for i in range(state.fighters.size()):
		if state.fighters[i].planned != -1:
			arr.append(i)
	arr.sort_custom(_cmp_initiative)
	return arr


func _cmp_initiative(a: int, b: int) -> bool:
	var sa := _speed_of(a)
	var sb := _speed_of(b)
	if sa != sb:
		return sa > sb
	var ta := _type_rank(a)
	var tb := _type_rank(b)
	if ta != tb:
		return ta < tb
	var ka := Domain.STANCE_TIE_ORDER.find(state.fighters[a].stance)
	var kb := Domain.STANCE_TIE_ORDER.find(state.fighters[b].stance)
	return ka < kb


## Velocità d'iniziativa effettiva: il valore scelto per il turno (vedi
## _resolve_chosen_speeds), al netto degli azzoppamenti. Fuori risoluzione,
## ripiega sul valore più alto.
func _speed_of(i: int) -> int:
	var f := state.fighters[i]
	if f.planned == -1:
		return -999
	if _chosen.has(i):
		return int(_chosen[i])
	return _hobbled(i, Domain.pick_initiative(_raw_ini(i), true))


func _type_rank(i: int) -> int:
	var t: String = CardDB.card(state.fighters[i].planned).get("type", "")
	return int(Domain.TYPE_RESOLVE_ORDER.get(t, 4))


func _resolve_card(i: int, block_ready: Dictionary, log: Array) -> void:
	var f := state.fighters[i]
	var c := CardDB.card(f.planned)
	var g := CardDB.geometry(f.planned)   ## geometria/effetti trascritti (può essere vuota)
	var name: String = c.get("name", "?")
	var chosen_alt = _resolve_option(i, g)   ## "OPPURE": opzione scelta (una sola)
	match c.get("type", ""):
		"attack":
			var foe_idx := _opponent_index(i)
			if foe_idx == -1:
				return
			var foe := state.fighters[foe_idx]
			var cells := attack_v2_cells(f.cell, f.facing, g, _card_range(c))
			if not cells.has(foe.cell):
				var dist := HexGrid.distance(f.cell, foe.cell)
				log.append("%s usa %s ma il bersaglio è fuori arco/portata (dist %d)" % [f.character, name, dist])
				return
			# Blocco (regolamento 1.5 p.11): blocco nella cella dell'attaccante,
			# oppure ogni percorso più breve attraversa un blocco. Il terreno
			# blocca a ogni velocità; la difesa solo alla sua velocità scelta.
			var atk_speed := int(_chosen.get(i, _speed_of(i)))
			if _attack_blocked(i, foe_idx, atk_speed, g):
				# Un solo attacco per difesa: consuma la difesa e valuta il counter.
				if int(_block_ready.get(foe_idx, -1)) == atk_speed:
					_block_ready[foe_idx] = -1
					_try_counter(foe_idx, i, atk_speed, log)
				log.append("%s attacca con %s a velocità %d — PARATO da %s" % [
					f.character, name, atk_speed, foe.character])
				return
			# Ferite della cella colpita (schema v2) o globali (vecchio).
			var n: int = int(cells.get(foe.cell, g.get("wounds", 1)))
			var kind: String = g.get("wound_kind", "normal")
			if kind == "exec":
				foe.wounds.append("exec"); foe.wounds.resize(foe.wound_limit)
			elif n > 0:
				var tag := "bleed" if kind == "bleed" else "wound"
				for _w in range(n):
					foe.wounds.append(tag)
			_apply_if_success(i, foe_idx, g, log)
			_apply_effects(i, foe_idx, g, "on_hit", log, chosen_alt)
			fighter_updated.emit(foe_idx)
			log.append("%s colpisce %s con %s — %d ferita/e (%d/%d)" % [
				f.character, foe.character, name, n, foe.wounds.size(), foe.wound_limit])
		"defence":
			_apply_effects(i, _opponent_index(i), g, "always", log, chosen_alt)
			log.append("%s si mette in guardia (%s)" % [f.character, name])
		"meditation", "core":
			if g.has("effects"):
				_apply_effects(i, _opponent_index(i), g, "always", log, chosen_alt)
				log.append("%s usa %s" % [f.character, name])
			else:
				var fg: int = int(g.get("focus_gain", 1))
				var dr: int = int(g.get("draw", 1))
				f.gain_focus(fg)
				for _d in range(maxi(0, dr)):
					f.draw_one()
				fighter_updated.emit(i)
				log.append("%s medita (%s): +%d focus, pesca %d" % [f.character, name, fg, maxi(0, dr)])
		_:
			log.append("%s gioca %s" % [f.character, name])
	# "Passa a [Kamae]" — switch diretto (eventualmente gated dalla Kamae).
	var sw = g.get("kamae_switch", null)
	if sw != null:
		var gate: String = sw.get("gate", "")
		if gate == "" or gate == Domain.STANCE_SLUG[f.stance]:
			var to: int = Domain.STANCE_FROM_SLUG.get(sw.get("to", ""), -1)
			if to != -1:
				f.stance = to
				fighter_updated.emit(i)
				log.append("%s passa a Kamae %s" % [f.character, Domain.STANCE_NAMES[to]])


## Applica gli effetti "se riuscito" trascritti (push, focus, bleed).
func _apply_if_success(att_idx: int, foe_idx: int, g: Dictionary, log: Array) -> void:
	var att := state.fighters[att_idx]
	var foe := state.fighters[foe_idx]
	for eff in g.get("if_success", []):
		var s := str(eff)
		if s.begins_with("focus:"):
			att.gain_focus(int(s.substr(6)))
		elif s.begins_with("push:"):
			_push(att_idx, foe_idx, int(s.substr(5)), log)
		elif s.begins_with("pull:"):
			_pull(att_idx, foe_idx, int(s.substr(5)), log)
		elif s == "bleed":
			foe.wounds.append("bleed")
		elif s == "hobble" or s.begins_with("hobble:"):
			var amt := 1 if s == "hobble" else int(s.substr(7))
			foe.add_hobble(maxi(1, amt))
			fighter_updated.emit(foe_idx)


# ─── Commit To Hit (regolamento 1.5 p.10) ────────────────────────────────────

## L'attacco programmato di `i` colpisce il bersaglio dalla posizione ATTUALE?
func attack_hits_now(i: int) -> bool:
	var f := state.fighters[i]
	if f.planned == -1:
		return false
	var c := CardDB.card(f.planned)
	if c.get("type", "") != "attack":
		return false
	var fo := _opponent_index(i)
	if fo == -1:
		return false
	return attack_v2_cells(f.cell, f.facing, CardDB.geometry(f.planned), _card_range(c)).has(state.fighters[fo].cell)


## Esiste una posizione raggiungibile con le mosse della carta da cui l'attacco
## colpirebbe il bersaglio? (Commit To Hit: se sì, devi colpire.)
func attack_can_hit(i: int) -> bool:
	var f := state.fighters[i]
	if f.planned == -1:
		return false
	var c := CardDB.card(f.planned)
	if c.get("type", "") != "attack":
		return false
	var fo := _opponent_index(i)
	if fo == -1:
		return false
	var foe_cell: Vector2i = state.fighters[fo].cell
	var g := CardDB.geometry(f.planned)
	if attack_v2_cells(f.cell, f.facing, g, _card_range(c)).has(foe_cell):
		return true
	if not g.has("move"):
		return false
	var reach := Move.reachable_by_cell(f.cell, f.facing, g["move"], state.is_blocked, Domain.STANCE_SLUG[f.stance])
	for cell in reach.keys():
		for fc in reach[cell]:
			if attack_v2_cells(cell, fc, g, 1).has(foe_cell):
				return true
	return false


# ─── Blocchi (regolamento 1.5 p.11) ──────────────────────────────────────────

## Celle che contano come "blocco" contro un attacco alla velocità `atk_speed`:
## il terreno blocca a ogni velocità; la difesa del difensore blocca solo se la
## sua velocità scelta combacia. Ritorna {blocks: Dictionary, from_def: bool}.
func _collect_block_hexes(def_idx: int, atk_speed: int) -> Dictionary:
	var blocks := {}
	for cell in state.blocked_cells.keys():
		blocks[cell] = true   # terreno = blocco a tutte le iniziative (cond. 2)
	var from_def := false
	var dfn := state.fighters[def_idx]
	if dfn.planned != -1 and not _fizzled.has(def_idx) \
			and int(_block_ready.get(def_idx, -1)) == atk_speed \
			and CardDB.card(dfn.planned).get("type", "") == "defence":
		for cell in defence_v2_cells(dfn.cell, dfn.facing, CardDB.geometry(dfn.planned)).keys():
			blocks[cell] = true
		from_def = true
	return {"blocks": blocks, "from_def": from_def}


## Esiste un percorso più breve da `a` a `b` che NON attraversa celle blocco
## (estremi esclusi)? Se NO, allora tutti i percorsi più brevi sono bloccati.
func _has_clean_path(a: Vector2i, b: Vector2i, blocks: Dictionary) -> bool:
	if a == b:
		return true
	var stack: Array = [a]
	var seen := {a: true}
	while not stack.is_empty():
		var h: Vector2i = stack.pop_back()
		var dh := HexGrid.distance(h, b)
		for dir in HexGrid.DIRS:
			var n: Vector2i = h + dir
			if HexGrid.distance(n, b) != dh - 1:
				continue   # deve avvicinarsi a b (resta sui percorsi minimi)
			if n == b:
				return true
			if blocks.has(n) or seen.has(n):
				continue
			seen[n] = true
			stack.append(n)
	return false


## L'attacco di `att_idx` contro `def_idx` alla velocità `atk_speed` è bloccato?
## Regola 1.5: bloccato se (1) c'è un blocco nella cella dell'attaccante, oppure
## (2) ogni percorso più breve attaccante→difensore passa per un blocco.
func _attack_blocked(att_idx: int, def_idx: int, atk_speed: int, atk_geom: Dictionary) -> bool:
	if bool(atk_geom.get("non_blockable", false)):
		return false
	var info := _collect_block_hexes(def_idx, atk_speed)
	var blocks: Dictionary = info["blocks"]
	if blocks.is_empty():
		return false
	var att := state.fighters[att_idx]
	var dfn := state.fighters[def_idx]
	if blocks.has(att.cell):
		return true   # cond. 1
	return not _has_clean_path(att.cell, dfn.cell, blocks)   # cond. 2


## Contrattacco (p.11): se la difesa ha un'icona counter e la velocità dell'attacco
## bloccato combacia, infliggi 1 ferita all'attaccante (il giocatore scarta un
## attacco non-core; l'avversario solo non scarta).
func _try_counter(def_idx: int, att_idx: int, atk_speed: int, log: Array) -> void:
	var dfn := state.fighters[def_idx]
	var counter = CardDB.geometry(dfn.planned).get("counter", null)
	if counter == null:
		return
	var speeds: Array = counter if typeof(counter) == TYPE_ARRAY else [atk_speed]
	if not speeds.has(atk_speed):
		return
	if not dfn.is_ai:
		var pick := -1
		for cid in dfn.hand:
			if CardDB.card(cid).get("type", "") == "attack":
				pick = cid
				break
		if pick == -1:
			return   # nessun attacco non-core da scartare: niente counter
		dfn.hand.erase(pick)
		dfn.discard.append(pick)
	var att := state.fighters[att_idx]
	att.wounds.append("wound")
	fighter_updated.emit(att_idx)
	log.append("%s CONTRATTACCA: %s subisce 1 ferita (%d/%d)" % [
		dfn.character, att.character, att.wounds.size(), att.wound_limit])


## ─── Schema v2: celle d'attacco e lista effetti ────────────────────────────────

## Celle bersaglio (cella → ferite) dalla geometria v2 `attack.cells`
## (ogni cella: d=direzione relativa 0..5, k=anello 1.., w=ferite). Se assente,
## ripiega sullo schema vecchio (dirs+range, ferite uniformi).
static func attack_v2_cells(origin: Vector2i, facing: int, geom: Dictionary, fallback_range: int) -> Dictionary:
	var out := {}
	var atk = geom.get("attack", null)
	if atk != null and not (atk.get("cells", []) as Array).is_empty():
		for cell_def in atk.get("cells", []):
			var d: int = int(cell_def.get("d", 0))
			var k: int = int(cell_def.get("k", 1))
			var ad: int = (facing + d) % 6
			var cell: Vector2i = origin + HexGrid.DIRS[ad] * maxi(1, k)
			out[cell] = int(cell_def.get("w", 1))
		return out
	# fallback schema vecchio
	for cell in attack_cells(origin, facing, geom, fallback_range):
		out[cell] = int(geom.get("wounds", 1))
	return out


## Celle difese (cella → valore di blocco) dalla geometria v2 `defence.cells`.
static func defence_v2_cells(origin: Vector2i, facing: int, geom: Dictionary) -> Dictionary:
	var out := {}
	var dfn = geom.get("defence", null)
	if dfn != null:
		for cell_def in dfn.get("cells", []):
			var d: int = int(cell_def.get("d", 0))
			var k: int = int(cell_def.get("k", 1))
			var ad: int = (facing + d) % 6
			out[origin + HexGrid.DIRS[ad] * maxi(1, k)] = int(cell_def.get("v", 0))
	return out


## Applica la lista `effects` v2 per la finestra `when` ("always" / "on_hit").
## Gli effetti gated da Kamae si applicano solo nella posizione giusta; gli
## effetti opzionali a costo di focus (focus_cost>0) vengono saltati
## nell'auto-risoluzione (sono facoltativi); quelli non ancora simulati sono
## registrati nel log.
## Imposta la scelta "OPPURE" del giocatore per il combattente `i` (chiave alt).
func set_option_choice(i: int, alt) -> void:
	_opt_choice[i] = alt


## Opzioni "OPPURE" disponibili per il combattente `i` (chiavi alt in ordine), o [].
func option_keys(i: int) -> Array:
	var keys := []
	for e in CardDB.geometry(state.fighters[i].planned).get("effects", []):
		var ak = e.get("alt", null)
		if ak != null and not keys.has(ak):
			keys.append(ak)
	return keys


## Determina l'unica opzione "OPPURE" da applicare: la scelta del giocatore se
## impostata, altrimenti la prima opzione applicabile (gate Kamae ok, senza costo
## focus non pagato). Restituisce null se la carta non ha alternative.
func _resolve_option(i: int, geom: Dictionary):
	var effs = geom.get("effects", null)
	if effs == null:
		return null
	var keys := []
	for e in effs:
		var ak = e.get("alt", null)
		if ak != null and not keys.has(ak):
			keys.append(ak)
	if keys.is_empty():
		return null
	if _opt_choice.has(i) and keys.has(_opt_choice[i]):
		return _opt_choice[i]
	var f := state.fighters[i]
	for ak in keys:
		for e in effs:
			if e.get("alt", null) != ak:
				continue
			var gate := str(e.get("kamae", ""))
			if gate != "" and gate != Domain.STANCE_SLUG[f.stance]:
				continue
			if int(e.get("focus_cost", 0)) > 0:
				continue
			return ak
	return keys[0]


func _apply_effects(i: int, foe_idx: int, geom: Dictionary, when: String, log: Array, chosen_alt = null) -> void:
	var effs = geom.get("effects", null)
	if effs == null:
		return
	var f := state.fighters[i]
	var foe: GameState.Fighter = state.fighters[foe_idx] if foe_idx != -1 else null
	for e in effs:
		if str(e.get("when", "always")) != when:
			continue
		var gate: String = e.get("kamae", "")
		if gate != "" and gate != Domain.STANCE_SLUG[f.stance]:
			continue
		if int(e.get("focus_cost", 0)) > 0:
			continue   # bonus opzionale a pagamento: saltato in auto-risoluzione
		# Gruppi "OPPURE": applica solo gli effetti dell'opzione scelta (chosen_alt).
		# Gli effetti senza 'alt' valgono sempre.
		var alt = e.get("alt", null)
		if alt != null and alt != chosen_alt:
			continue
		match str(e.get("do", "")):
			"push":
				if foe != null: _push(i, foe_idx, int(e.get("n", 1)), log)
			"pull":
				if foe != null: _pull(i, foe_idx, int(e.get("n", 1)), log)
			"bleed":
				if foe != null: foe.wounds.append("bleed")
			"replace_wound_bleed":
				if foe != null and not foe.wounds.is_empty():
					foe.wounds[foe.wounds.size() - 1] = "bleed"
			"focus":
				f.gain_focus(int(e.get("n", 1)))
			"hobble":
				if foe != null: foe.add_hobble(maxi(1, int(e.get("n", 1))))
			"rotate_target":
				if foe != null: foe.facing = (foe.facing + int(e.get("n", 1))) % 6
			"draw":
				for _d in range(maxi(0, int(e.get("n", 1)))): f.draw_one()
			"search_draw":
				for _d in range(maxi(0, int(e.get("n", 1)))): f.draw_one()
			"stun_self":
				f.stun += maxi(1, int(e.get("n", 1)))   # "PRENDI 1 stordito"
				log.append("%s subisce %d stordimento" % [f.character, maxi(1, int(e.get("n", 1)))])
			"discard_self":
				for _d in range(maxi(1, int(e.get("n", 1)))):
					if not f.hand.is_empty(): f.discard.append(f.hand.pop_back())
			"switch_kamae":
				# "Passa a Y": spostamento diretto (nessun ramo, nessun focus).
				var to_slug := str(e.get("to", ""))
				if to_slug == "any":
					to_slug = "aggression"   # "qualsiasi" (≠ neutral): scelta auto (semplificazione)
				var to: int = Domain.STANCE_FROM_SLUG.get(to_slug, -1)
				if to != -1:
					f.stance = to
					log.append("%s passa a Kamae %s" % [f.character, Domain.STANCE_NAMES[to]])
			"change_kamae":
				# "Cambia Kamae fino a N": il giocatore sceglie nella scena (con focus
				# dai rami rosa). L'IA traversa l'albero in automatico (ignora il focus).
				if f.is_ai:
					var tree := CardDB.kamae_tree_for(f.character.to_lower())
					var targets := Kamae.change_targets(tree, Domain.STANCE_SLUG[f.stance], int(e.get("n", 1)))
					for pref in ["aggression", "determination", "balance"]:
						if targets.has(pref):
							f.stance = Domain.STANCE_FROM_SLUG[pref]
							log.append("%s cambia Kamae in %s" % [f.character, Domain.STANCE_NAMES[f.stance]])
							break
			"spend_focus", "reduce_damage", "cancel_movement", "block_initiative":
				log.append("  (effetto «%s» non ancora simulato)" % str(e.get("do", "")))
		if foe != null:
			fighter_updated.emit(foe_idx)
	fighter_updated.emit(i)


## Spinge `foe` di `n` esagoni lontano da `att`, se le celle sono libere.
func _push(att_idx: int, foe_idx: int, n: int, log: Array = []) -> void:
	_forced_move(att_idx, foe_idx, n, false, log)


func _pull(att_idx: int, foe_idx: int, n: int, log: Array = []) -> void:
	_forced_move(att_idx, foe_idx, n, true, log)


## Spinta (push) / trazione (pull) del bersaglio di `n` esagoni, direttamente
## lontano da / verso l'attaccante (regolamento p.15). Se il bersaglio finirebbe
## su terreno, un altro personaggio o fuori dall'arena, si risolve una COLLISIONE
## (p.9) e il movimento si ferma. Push/pull possono spingere deliberatamente nei
## pericoli.
func _forced_move(att_idx: int, victim_idx: int, n: int, pull: bool, log: Array) -> void:
	var att := state.fighters[att_idx]
	var v := state.fighters[victim_idx]
	for _k in range(maxi(0, n)):
		# Esagono "direttamente lontano/verso": vicino con distanza max/min dall'attaccante.
		var dest := v.cell
		var best_d := HexGrid.distance(att.cell, v.cell)
		for nb in HexGrid.neighbors(v.cell):
			var dd := HexGrid.distance(att.cell, nb)
			if (pull and dd < best_d) or (not pull and dd > best_d):
				best_d = dd
				dest = nb
		if dest == v.cell:
			break   # nessuna direzione utile
		# Collisione? (fuori arena / altro personaggio / terreno)
		if HexGrid.distance(dest, Vector2i.ZERO) > state.map_radius \
				or state.fighter_at(dest) != null or state.terrain_at(dest) != "":
			_resolve_collision(victim_idx, dest, log)
			return
		v.cell = dest
	fighter_updated.emit(victim_idx)


## Risolve una collisione del personaggio `victim_idx` che sarebbe finito su `dest`
## (regolamento p.9 + effetti terreno p.16). Il personaggio resta dov'è.
func _resolve_collision(victim_idx: int, dest: Vector2i, log: Array) -> void:
	var v := state.fighters[victim_idx]
	if HexGrid.distance(dest, Vector2i.ZERO) > state.map_radius:
		v.stun += 1
		log.append("%s spinto fuori dall'arena: +1 stordimento" % v.character)
	elif state.fighter_at(dest) != null:
		var other := state.fighter_at(dest)
		if not v.is_ai and not v.hand.is_empty():
			v.discard.append(v.hand.pop_back())   # scarta 1 dalla mano
		v.stun += 1
		other.stun += 1
		fighter_updated.emit(state.fighters.find(other))
		log.append("%s collide con %s: scarta 1, entrambi +1 stordimento" % [v.character, other.character])
	else:
		match state.terrain_at(dest):
			"bamboo":
				v.wounds.append("wound"); v.stun += 1
				state.blocked_cells.erase(dest)
				log.append("%s urta il bambù: +1 ferita e +1 stordimento (bambù rimosso)" % v.character)
			"burning":
				v.wounds.append("wound"); v.wounds.append("bleed")
				log.append("%s urta i carri in fiamme: +1 ferita e +1 sanguinante" % v.character)
			_:
				v.wounds.append("wound")
				log.append("%s urta un ostacolo: +1 ferita" % v.character)
	fighter_updated.emit(victim_idx)


func _cleanup(log: Array) -> void:
	_set_phase(Domain.Phase.CLEANUP)
	# Passo "Discard": scarta la carta giocata e rientra nel limite di mano.
	for f in state.fighters:
		if f.planned != -1:
			f.discard.append(f.planned)
			f.planned = -1
		# Se la mano supera il limite, scarta a faccia in giù fino al limite.
		while f.hand.size() > f.hand_limit:
			f.discard.append(f.hand.pop_back())
			log.append("%s scarta in eccesso (limite mano %d)" % [f.character, f.hand_limit])
		# Effetti di fine turno: gli azzoppamenti ruotano (e scadono).
		f.tick_hobbles()
	state.round_num += 1
	turn_resolved.emit(log)
	# Passo "Draw" del turno successivo (sanguinamento + pesca 1).
	if not _begin_turn():
		return
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
