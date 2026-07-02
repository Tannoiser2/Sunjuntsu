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
## Fase RIVELAZIONE (regolamento 1.5 p.16): `index` può sostituire la carta rivelata con
## un'Istantanea di Sostituzione. options = Array[int] di carte giocabili (vuoto possibile).
signal await_instant_replace(index: int, options: Array)
## Fase RISOLUZIONE: dopo aver risolto la carta scelta, `index` può giocare 1 carta
## istantanea (Aggiuntiva/Istantanea). options = Array[int].
signal await_instant_play(index: int, options: Array)
## Evento puramente VISIVO per la scena (animazioni di combattimento). Non influenza
## la logica. kind: "hit" | "blocked" | "counter" | "collision".
signal combat_event(kind: String, attacker: int, target: int, info: Dictionary)
## Ordine di risoluzione per iniziativa, per la UI: Array di {i, speed, type}.
signal resolution_order(order: Array)

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
var _pending_split: Dictionary = {}   ## parte bassa (iniziativa divisa) del giocatore in attesa

## Carte istantanee (regolamento 1.5 p.13/16).
var _replace_idx: int = -1            ## indice corrente nella fase di sostituzione
var _instant_used: Dictionary = {}    ## indice → ha già giocato 1 istantanea questo turno
var _attack_ok: Dictionary = {}       ## indice → il suo attacco è andato a segno (per le reazioni)
var _block_ok: Dictionary = {}        ## indice → il suo blocco è riuscito

## Velocità d'iniziativa scelta da ogni combattente per il turno corrente
## (indice → valore). Le difese a iniziativa variabile scelgono il valore che
## aggancia l'attacco avversario, così il blocco scatta alla stessa velocità.
var _chosen: Dictionary = {}


func _init(initial_state: GameState) -> void:
	state = initial_state


## Una carta è "core" (Speciale o Arma core): inizia in mano, non conta verso il
## limite di mano e non può MAI essere scartata (regolamento p.10). Comprende sia la
## carta abilità core (type "core") sia la carta arma core (keyword "Core").
static func is_core(cid: int) -> bool:
	var c := CardDB.card(cid)
	return str(c.get("type", "")) == "core" or ("Core" in c.get("keywords", []))


## Carte non-core in mano (le core non contano verso il limite).
func _noncore_in_hand(f: GameState.Fighter) -> int:
	var n := 0
	for cid in f.hand:
		if not is_core(cid):
			n += 1
	return n


## Slot di mano OCCUPATI verso il limite: carte abilità non-core + carte
## Stordimento (anch'esse "incidono sul limite di carte in mano", regolamento).
## Le carte di stordimento riducono quindi quante carte abilità puoi pescare/tenere.
func _hand_used(f: GameState.Fighter) -> int:
	return _noncore_in_hand(f) + f.stun


## Scarta UNA carta non-core A CASO dalla mano (selezione casuale, §3.19).
func _discard_random_noncore(f: GameState.Fighter) -> bool:
	var idxs: Array = []
	for k in range(f.hand.size()):
		if not is_core(f.hand[k]):
			idxs.append(k)
	if idxs.is_empty():
		return false
	var k: int = idxs[randi() % idxs.size()]
	f.discard.append(f.hand[k])
	f.hand.remove_at(k)
	return true


## Scarta UNA carta non-core dalla mano (le core non si scartano). True se riuscito.
func _discard_one_noncore(f: GameState.Fighter) -> bool:
	for k in range(f.hand.size() - 1, -1, -1):
		if not is_core(f.hand[k]):
			f.discard.append(f.hand[k]); f.hand.remove_at(k)
			return true
	return false


func start() -> void:
	# Setup (regolamento p.4): le carte CORE partono in mano; le altre si rimescolano
	# nel mazzo. Le core non contano verso il limite e non rientrano mai nel mazzo.
	# Gli avversari solo NON hanno mano: rivelano la cima del mazzo ogni turno.
	for f in state.fighters:
		if f.is_ai:
			continue
		var rest: Array = []
		for cid in f.draw_pile:
			if is_core(cid):
				if not f.hand.has(cid):
					f.hand.append(cid)
			else:
				rest.append(cid)
		f.draw_pile = rest
		while _hand_used(f) < f.hand_limit:
			if f.draw_one() == -1:
				break
	_begin_turn()   # passo Draw del 1° turno
	_set_phase(Domain.Phase.PLANNING)
	_autoplan_ai()


## Passo "Draw" del turno (regolamento 1.5): per ogni combattente, se ha almeno
## una ferita sanguinante scarta 1 carta dal mazzo, poi pesca 1 carta (mazzo
## vuoto ⇒ ferita). Restituisce true se il duello continua.
func _begin_turn() -> bool:
	# Azzera gli stati "una tantum" del turno (la riduzione danno persistente NO).
	for f in state.fighters:
		f.movement_cancelled = false
		f.block_initiative_bonus = 0
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
## alla posizione attuale del combattente e l'eventuale requisito di stato
## persistente (`state_req`, stessa forma del campo `state` dei gate — vedi
## Gate.gd) è soddisfatto dai suoi Fighter.states.
static func playable(f: GameState.Fighter, card_id: int) -> bool:
	var g := CardDB.geometry(card_id)
	if not Kamae.gate_allows(g.get("kamae_req", ""), Domain.STANCE_SLUG[f.stance]):
		return false
	return Gate.state_req_ok(g.get("state_req", null), f.states)


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
			var g := CardDB.geometry(f.planned)
			if g.has("move"):
				var plan := AI.plan_move(state, f, g)   # priorità solitario
				f.cell = plan["cell"]; f.facing = plan["facing"]
			else:
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
	_pay_costs()
	_finalize_resolution_setup()


## Passo "paga i costi" della Rivelazione (focus obbligatori/opzionali, scarti).
func _pay_costs() -> void:
	_set_phase(Domain.Phase.RESOLUTION)
	_res_log = []
	_fizzled = {}
	_opt_choice = {}   # le scelte "OPPURE" si impostano durante la risoluzione
	_pending_split = {}
	_instant_used = {}
	_attack_ok = {}
	_block_ok = {}
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
			if not _discard_one_noncore(f):
				break   # niente non-core da scartare (le core non si scartano)


## Passo "scegli iniziative variabili + calcola ordine" della Rivelazione.
## Va eseguito DOPO l'eventuale sostituzione istantanea (che cambia la carta).
func _finalize_resolution_setup() -> void:
	_resolve_chosen_speeds(_fizzled)

	_block_ready = {}
	for i in range(state.fighters.size()):
		var f := state.fighters[i]
		if f.planned != -1 and not _fizzled.has(i):
			if CardDB.card(f.planned).get("type", "") == "defence":
				_block_ready[i] = _chosen.get(i, -1)

	_order = _initiative_order()
	# Ordine di risoluzione per iniziativa (per la UI del tavolo).
	var ord: Array = []
	for i in _order:
		if state.fighters[i].planned == -1 or _fizzled.has(i):
			continue
		ord.append({"i": i, "speed": _speed_of(i), "type": str(CardDB.card(state.fighters[i].planned).get("type", ""))})
	resolution_order.emit(ord)


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
	_pay_costs()
	var planned := {}
	for i in range(state.fighters.size()):
		planned[i] = state.fighters[i].planned
	cards_revealed.emit(planned)
	# Rivelazione p.16: dopo aver pagato i costi, ogni umano può SOSTITUIRE la carta
	# rivelata con un'Istantanea di Sostituzione, poi si calcolano iniziative e ordine.
	_replace_idx = -1
	_advance_replacement()


# ─── Fase RIVELAZIONE: Istantanee di Sostituzione (regolamento 1.5 p.7/13/16) ──

## Carte in mano di `i` che possono sostituire la carta rivelata: Istantanee di
## Sostituzione di tipo DIVERSO (Attacco/Difesa/Meditazione), non core, e che `i`
## può permettersi (recuperando il focus della carta originale).
func instant_replacements_for(i: int) -> Array:
	var f := state.fighters[i]
	if f.is_ai or f.planned == -1 or is_core(f.planned):
		return []
	var orig_type: String = CardDB.card(f.planned).get("type", "")
	var orig_cost := _focus_cost_of(f.planned)
	var out: Array = []
	for cid in f.hand:
		if CardDB.instant_kind(cid) != "replacement" or is_core(cid):
			continue
		if CardDB.card(cid).get("type", "") == orig_type:
			continue   # deve essere di tipo diverso
		if f.focus + orig_cost < _focus_cost_of(cid):
			continue   # non può pagarla nemmeno col rimborso
		out.append(cid)
	return out


## Costo focus totale di una carta (focus carta + play_cost).
func _focus_cost_of(cid: int) -> int:
	return int(CardDB.card(cid).get("focus", 0)) + int(CardDB.geometry(cid).get("play_cost", {}).get("focus", 0))


## Avanza la fase di sostituzione: offre la scelta al prossimo umano con opzioni;
## quando finita, calcola iniziative/ordine e parte la risoluzione.
func _advance_replacement() -> void:
	_replace_idx += 1
	while _replace_idx < state.fighters.size():
		var opts := instant_replacements_for(_replace_idx)
		if not opts.is_empty():
			await_instant_replace.emit(_replace_idx, opts)
			return
		_replace_idx += 1
	_finalize_resolution_setup()
	_order_idx = -1
	_advance_resolution()


## La scena ha deciso: `new_id` = carta di sostituzione (o -1 per tenere la carta).
func apply_instant_replace(i: int, new_id: int) -> void:
	if new_id != -1 and instant_replacements_for(i).has(new_id):
		var f := state.fighters[i]
		var orig: int = f.planned
		f.focus = mini(GameState.Fighter.MAX_FOCUS, f.focus + _focus_cost_of(orig))  # rimborso
		f.focus = maxi(0, f.focus - _focus_cost_of(new_id))                            # nuovo costo
		f.discard.append(orig)        # la carta originale viene scartata
		f.hand.erase(new_id)
		f.planned = new_id
		_fizzled.erase(i)
		_res_log.append("%s sostituisce %s con %s (istantanea)" % [
			f.character, CardDB.card(orig).get("name", "?"), CardDB.card(new_id).get("name", "?")])
	_advance_replacement()


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
	if not _pending_split.is_empty():
		return   # in pausa: il giocatore deve risolvere la parte bassa (resolve_split_now)
	_post_resolve(i)


## Dopo aver risolto la carta scelta da `i`: offre (interattivo) di giocare 1 carta
## istantanea (Aggiuntiva/Istantanea), poi prosegue l'ordine d'iniziativa.
func _post_resolve(i: int) -> void:
	if interactive:
		var opts := instant_plays_for(i)
		if not opts.is_empty():
			await_instant_play.emit(i, opts)
			return
	_continue_after_resolver()


func _continue_after_resolver() -> void:
	var w := _check_winner()
	if w != -2:
		_finish(_res_log, w)
		return
	_advance_resolution()


# ─── Fase RISOLUZIONE: Istantanee Aggiuntive / Istantanee (regolamento 1.5 p.13) ──

## Carte istantanee (Aggiuntive/Istantanee) che `i` può giocare ORA: massimo 1 per
## turno e solo se NON ha giocato una carta core (regolamento p.13).
func instant_plays_for(i: int) -> Array:
	var f := state.fighters[i]
	if f.is_ai or bool(_instant_used.get(i, false)) or f.planned == -1 or is_core(f.planned):
		return []
	var out: Array = []
	for cid in f.hand:
		var k := CardDB.instant_kind(cid)
		if (k == "additional" or k == "instant") and not is_core(cid):
			if f.focus >= _focus_cost_of(cid):
				out.append(cid)
	return out


## La scena ha deciso: `id` = carta istantanea da giocare ora (o -1 per saltare).
func apply_instant_play(i: int, id: int) -> void:
	if id != -1 and instant_plays_for(i).has(id):
		_resolve_instant_card(i, id)
	_continue_after_resolver()


## Risolve una carta istantanea giocata in reazione (fuori dalla scelta del turno).
func _resolve_instant_card(i: int, id: int) -> void:
	var f := state.fighters[i]
	var foe_idx := _opponent_index(i)
	var c := CardDB.card(id)
	var g := CardDB.geometry(id)
	var name: String = c.get("name", "?")
	f.focus = maxi(0, f.focus - _focus_cost_of(id))
	f.hand.erase(id)
	_instant_used[i] = true
	var alt = _resolve_option(i, g)
	match c.get("type", ""):
		"attack":
			_resolve_attack_top(i, g, name, _res_log, alt)
		"defence":
			_apply_effects(i, foe_idx, g, "always", _res_log, alt)
		_:
			_apply_effects(i, foe_idx, g, "always", _res_log, alt)
	# Effetti "se a segno": valgono come reazione se il TUO attacco è andato a segno.
	if bool(_attack_ok.get(i, false)):
		_apply_effects(i, foe_idx, g, "on_hit", _res_log, alt)
	f.discard.append(id)
	_res_log.append("%s gioca l'istantanea %s" % [f.character, name])


## True se la parte bassa (iniziativa divisa) del giocatore attende la risoluzione.
func has_pending_split() -> bool:
	return not _pending_split.is_empty()


## Geometria della parte bassa (per overlay/movimento nella scena).
func pending_split_geom() -> Dictionary:
	if _pending_split.is_empty():
		return {}
	var sp: Dictionary = _pending_split["split"]
	var g := {"type": "attack"}
	if sp.has("move"): g["move"] = sp["move"]
	if sp.has("attack"): g["attack"] = sp["attack"]
	if sp.has("wound_kind"): g["wound_kind"] = sp["wound_kind"]
	return g


## Iniziativa (velocità) della parte bassa in attesa, per l'etichetta UI.
func pending_split_initiative() -> int:
	if _pending_split.is_empty():
		return -1
	return int((_pending_split["split"] as Dictionary).get("initiative", -1))


## La scena ha posizionato la pedina per la parte bassa: applica l'attacco della
## parte bassa dalla posizione CORRENTE (niente auto-mossa) e prosegui l'ordine.
func resolve_split_now() -> void:
	if _pending_split.is_empty():
		return
	var i: int = _pending_split["i"]
	var split: Dictionary = _pending_split["split"]
	var name: String = _pending_split["name"]
	_pending_split = {}
	_resolve_split_bottom(i, split, name, _res_log, false)   # do_move=false: usa la posizione scelta
	_continue_after_resolver()


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
		var sp := Domain.pick_initiative(_raw_ini(i), true)
		var altv := _alt_initiative_value(i)
		if altv > sp:
			sp = altv   # auto-risoluzione: usa l'alternativa se più veloce
		_chosen[i] = _hobbled(i, sp)
	# 2ª passata: le difese agganciano la velocità dell'attacco avversario.
	for i in range(state.fighters.size()):
		var f := state.fighters[i]
		if f.planned == -1 or fizzled.has(i):
			continue
		if CardDB.card(f.planned).get("type", "") != "defence":
			continue
		var opts: Array = Domain.initiative_options(_raw_ini(i))
		var altv := _alt_initiative_value(i)
		if altv != -1 and not opts.has(altv):
			opts.append(altv)   # l'alternativa può agganciare l'attacco avversario
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
			# Nessun aggancio: prendi la più alta (alternativa inclusa).
			var base := Domain.pick_initiative(_raw_ini(i), true)
			if altv > base:
				base = altv
			pick = _hobbled(i, base)
		_chosen[i] = pick


func _raw_ini(i: int) -> String:
	return str(CardDB.card(state.fighters[i].planned).get("initiative", ""))


## Iniziativa alternativa (roadmap §3.1): riquadro [N] extra stampato sulla
## carta, utilizzabile AL POSTO di quella stampata se il gate (kamae/focus/
## state, vedi Gate.gd) è soddisfatto. NON è uno split (che è una seconda
## azione): è una velocità diversa per la stessa azione. In auto-risoluzione
## vale la regola dei bonus: si usa solo se gratis (Gate.auto_allows); la
## scelta interattiva del giocatore arriverà con la UI. -1 = non disponibile.
func _alt_initiative_value(i: int) -> int:
	var f := state.fighters[i]
	var alt = CardDB.geometry(f.planned).get("alt_initiative", null)
	if alt is Dictionary and Gate.auto_allows(alt, Domain.STANCE_SLUG[f.stance], f.states):
		return int(alt.get("value", -1))
	return -1


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
			_resolve_attack_top(i, g, name, log, chosen_alt)
			if g.has("split"):
				# Per il giocatore (interattivo) la parte bassa la guida la scena
				# (muovi/attacca + Conferma); per IA/headless si auto-risolve.
				if interactive and not f.is_ai:
					_pending_split = {"i": i, "split": g["split"], "name": name}
				else:
					_resolve_split_bottom(i, g["split"], name, log)
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


## Risolve la parte SOPRA di un attacco (eventuale parte SOTTO la gestisce lo split).
func _resolve_attack_top(i: int, g: Dictionary, name: String, log: Array, chosen_alt) -> void:
	var f := state.fighters[i]
	var foe_idx := _opponent_index(i)
	if foe_idx == -1:
		return
	var foe := state.fighters[foe_idx]
	var cells := attack_v2_cells(f.cell, f.facing, g, _card_range(CardDB.card(f.planned)), f.stance)
	if not cells.has(foe.cell):
		log.append("%s usa %s ma il bersaglio è fuori arco/portata (dist %d)" % [
			f.character, name, HexGrid.distance(f.cell, foe.cell)])
		return
	var atk_speed := int(_chosen.get(i, _speed_of(i)))
	if _attack_blocked(i, foe_idx, atk_speed, g):
		_block_ok[foe_idx] = true   # il blocco del difensore è riuscito (reazioni "se blocco riuscito")
		combat_event.emit("blocked", i, foe_idx, {})
		if int(_block_ready.get(foe_idx, -1)) == atk_speed:
			_block_ready[foe_idx] = -1
			_try_counter(foe_idx, i, atk_speed, log)
		log.append("%s attacca con %s a velocità %d — PARATO da %s" % [
			f.character, name, atk_speed, foe.character])
		return
	var raw = cells.get(foe.cell, g.get("wounds", 1))
	var act := _active_variant(g, "attack", "attacks", f.stance)
	var kind: String = "exec" if str(raw) == "exec" else str(act.get("wound_kind", g.get("wound_kind", "normal")))
	var n: int = 0 if str(raw) == "exec" else int(raw)
	if kind == "exec":
		foe.wounds.append("exec"); foe.wounds.resize(foe.wound_limit)
	elif n > 0:
		if foe.damage_reduction > 0:
			n = maxi(1, n - foe.damage_reduction)   # riduzione persistente (min 1)
		var tag := "bleed" if kind == "bleed" else "wound"
		for _w in range(n):
			foe.wounds.append(tag)
	# Ferite gated da focus: cella con focus_cost/w_focus (es. asterisco viola).
	# Saltate in auto-risoluzione come i bonus-effetti a pagamento (riga ~1056).
	# TODO: quando la UI espone la scelta focus, chiamare qui _apply_focus_wound().
	_attack_ok[i] = true   # attacco a segno (reazioni "se attacco riuscito")
	combat_event.emit("hit", i, foe_idx, {"n": n})
	_apply_if_success(i, foe_idx, g, log)
	_apply_effects(i, foe_idx, g, "on_hit", log, chosen_alt)
	fighter_updated.emit(foe_idx)
	log.append("%s colpisce %s con %s — %d ferita/e (%d/%d)" % [
		f.character, foe.character, name, n, foe.wounds.size(), foe.wound_limit])


## Risolve la parte SOTTO di una carta a iniziativa divisa (regolamento p.14).
## La parte sotto è mandatoria: per il giocatore si auto-risolve (mossa obbligatoria
## verso il facing) subito dopo la parte sopra; il suo attacco usa l'iniziativa
## della parte sotto (così il blocco si differenzia per velocità).
func _resolve_split_bottom(i: int, split: Dictionary, name: String, log: Array, do_move: bool = true) -> void:
	var f := state.fighters[i]
	var foe_idx := _opponent_index(i)
	if foe_idx == -1:
		return
	var foe := state.fighters[foe_idx]
	if do_move and split.has("move"):
		_auto_move_mandatory(i, split["move"])
		fighter_updated.emit(i)
	var bspeed := _hobbled(i, int(split.get("initiative", _speed_of(i))))
	if split.has("attack"):
		var pg := {"attack": split["attack"]}
		var cells := attack_v2_cells(f.cell, f.facing, pg, 1)
		if cells.has(foe.cell):
			if _attack_blocked(i, foe_idx, bspeed, pg):
				combat_event.emit("blocked", i, foe_idx, {})
				if int(_block_ready.get(foe_idx, -1)) == bspeed:
					_block_ready[foe_idx] = -1
					_try_counter(foe_idx, i, bspeed, log)
				log.append("%s (parte bassa di %s, vel %d) — PARATO da %s" % [
					f.character, name, bspeed, foe.character])
			else:
				var raw = cells.get(foe.cell, 1)
				var kind: String = "exec" if str(raw) == "exec" else split.get("wound_kind", "normal")
				var n: int = 0 if str(raw) == "exec" else int(raw)
				if kind == "exec":
					foe.wounds.append("exec"); foe.wounds.resize(foe.wound_limit)
				else:
					if foe.damage_reduction > 0:
						n = maxi(1, n - foe.damage_reduction)
					var tag := "bleed" if kind == "bleed" else "wound"
					for _w in range(n):
						foe.wounds.append(tag)
				combat_event.emit("hit", i, foe_idx, {"n": n})
				fighter_updated.emit(foe_idx)
				log.append("%s colpisce %s (parte bassa, vel %d) — %d ferita/e (%d/%d)" % [
					f.character, foe.character, bspeed, n, foe.wounds.size(), foe.wound_limit])
	if split.has("effects"):
		_apply_effects(i, foe_idx, {"effects": split["effects"]}, "always", log, null)


## Applica automaticamente le mosse OBBLIGATORIE di una specifica (prima opzione),
## relative al facing del combattente. Usata per la parte bassa degli split.
func _auto_move_mandatory(i: int, move_spec: Dictionary) -> void:
	var f := state.fighters[i]
	var opts: Array = move_spec.get("opts", [])
	if opts.is_empty():
		return
	for a in opts[0].get("atoms", []):
		if bool(a.get("opt", true)):
			continue   # solo le mosse obbligatorie
		if a.get("t", "") == "rot":
			f.facing = (f.facing + int(a.get("n", 1))) % 6
		elif a.get("t", "") == "step":
			var dirs: Array = a.get("dirs", [])
			if dirs.is_empty():
				var dd := int(a.get("dir", 0))
				dirs = [dd if dd >= 0 else 0]
			for _s in range(int(a.get("n", 1))):
				var ad: int = (f.facing + int(dirs[0])) % 6
				var dest: Vector2i = f.cell + HexGrid.DIRS[ad]
				if not state.is_blocked(dest):
					f.cell = dest


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
	return attack_v2_cells(f.cell, f.facing, CardDB.geometry(f.planned), _card_range(c), f.stance).has(state.fighters[fo].cell)


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
	if attack_v2_cells(f.cell, f.facing, g, _card_range(c), f.stance).has(foe_cell):
		return true
	if not g.has("move"):
		return false
	var reach := Move.reachable_by_cell(f.cell, f.facing, g["move"], state.is_blocked, Domain.STANCE_SLUG[f.stance], f.states)
	for cell in reach.keys():
		for fc in reach[cell]:
			if attack_v2_cells(cell, fc, g, 1, f.stance).has(foe_cell):
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
	# Il blocco è efficace alla velocità scelta, allargata da Blocco Ampio (±bonus).
	var bonus: int = dfn.block_initiative_bonus
	var ready_sp: int = int(_block_ready.get(def_idx, -1))
	var matches: bool = ready_sp != -1 and absi(ready_sp - atk_speed) <= bonus
	if dfn.planned != -1 and not _fizzled.has(def_idx) \
			and matches \
			and CardDB.card(dfn.planned).get("type", "") == "defence":
		for cell in defence_v2_cells(dfn.cell, dfn.facing, CardDB.geometry(dfn.planned), dfn.stance).keys():
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
	# Le voci della lista possono essere int (sempre attive) oppure oggetti
	# gated { "on": [7,6], "kamae"/"state"/"focus_cost" } (roadmap §3.10):
	# la voce vale solo se il gate del difensore è soddisfatto (Gate.gd).
	var speeds: Array = []
	if typeof(counter) == TYPE_ARRAY:
		for entry in counter:
			if entry is Dictionary:
				if Gate.auto_allows(entry, Domain.STANCE_SLUG[dfn.stance], dfn.states):
					for v in entry.get("on", []):
						speeds.append(int(v))
			else:
				speeds.append(int(entry))
	else:
		speeds = [atk_speed]
	if not speeds.has(atk_speed):
		return
	if not dfn.is_ai:
		var pick := -1
		for cid in dfn.hand:
			if CardDB.card(cid).get("type", "") == "attack" and not is_core(cid):
				pick = cid
				break
		if pick == -1:
			return   # nessun attacco non-core da scartare: niente counter
		dfn.hand.erase(pick)
		dfn.discard.append(pick)
	var att := state.fighters[att_idx]
	att.wounds.append("wound")
	combat_event.emit("counter", def_idx, att_idx, {})
	fighter_updated.emit(att_idx)
	log.append("%s CONTRATTACCA: %s subisce 1 ferita (%d/%d)" % [
		dfn.character, att.character, att.wounds.size(), att.wound_limit])


## ─── Schema v2: celle d'attacco e lista effetti ────────────────────────────────

## Celle bersaglio (cella → ferite) dalla geometria v2 `attack.cells`
## (ogni cella: d=direzione relativa 0..5, k=anello 1.., w=ferite). Se assente,
## ripiega sullo schema vecchio (dirs+range, ferite uniformi).
static func attack_v2_cells(origin: Vector2i, facing: int, geom: Dictionary, fallback_range: int, stance: int = -1) -> Dictionary:
	var out := {}
	var atk := _active_variant(geom, "attack", "attacks", stance)
	if not atk.is_empty() and not (atk.get("cells", []) as Array).is_empty():
		for cell_def in atk.get("cells", []):
			out[origin + _cell_offset(cell_def, facing)] = cell_def.get("w", 1)   # int o "exec"
		return out
	if geom.has("attacks") or geom.get("attack", null) != null:
		return out   # ci sono varianti d'attacco ma nessuna attiva nella kamae corrente
	# fallback schema vecchio
	for cell in attack_cells(origin, facing, geom, fallback_range):
		out[cell] = int(geom.get("wounds", 1))
	return out


## Difesa v2 `defence.cells` (cella → valore di blocco). Supporta più varianti
## `defences` gated da kamae: si usa quella attiva per la `stance` del difensore.
static func defence_v2_cells(origin: Vector2i, facing: int, geom: Dictionary, stance: int = -1) -> Dictionary:
	var out := {}
	var dfn := _active_variant(geom, "defence", "defences", stance)
	for cell_def in dfn.get("cells", []):
		out[origin + _cell_offset(cell_def, facing)] = int(cell_def.get("v", 0))
	return out


## Variante di combattimento (attacco o difesa) attiva data la kamae (stance):
## `array_key` (es. "attacks") è una lista di varianti, ciascuna con un eventuale
## gate `kamae`; `single_key` (es. "attack") è la forma classica a variante unica
## (retro-compatibile). Sceglie la variante gated che combacia con la stance,
## altrimenti quella senza gate. In risoluzione (stance>=0) senza match → {}.
static func _active_variant(geom: Dictionary, single_key: String, array_key: String, stance: int) -> Dictionary:
	var variants: Array = []
	if geom.has(array_key):
		for v in geom[array_key]:
			if v is Dictionary:
				variants.append(v)
	elif geom.get(single_key, null) != null:
		variants.append(geom[single_key])
	if variants.is_empty():
		return {}
	var slug := ""
	if stance >= 0 and stance < Domain.STANCE_SLUG.size():
		slug = str(Domain.STANCE_SLUG[stance])
	var ungated := {}
	var has_ungated := false
	for v in variants:
		var k = v.get("kamae", "")
		if Kamae.gate_is_empty(k):
			ungated = v; has_ungated = true
		elif Kamae.gate_allows(k, slug):
			return v                      # variante gated attiva (anche OR)
	if has_ungated:
		return ungated
	return variants[0] if stance < 0 else {}


## Offset (assiale) di una cella carta dato il facing. Supporta lo schema nuovo
## a coordinate piene {q,r} (qualsiasi esagono del vicinato) e quello legacy a
## 6 direzioni {d,k} (raggio); entrambi risolvono in modo identico per i raggi.
static func _cell_offset(cell_def: Dictionary, facing: int) -> Vector2i:
	if cell_def.has("q"):
		return HexGrid.rotate(Vector2i(int(cell_def.get("q", 0)), int(cell_def.get("r", 0))), facing)
	var d: int = int(cell_def.get("d", 0))
	var k: int = int(cell_def.get("k", 1))
	return HexGrid.DIRS[(facing + d) % 6] * maxi(1, k)


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
			if not Gate.auto_allows(e, Domain.STANCE_SLUG[f.stance], f.states):
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
		# Gate unificato (Gate.gd): Kamae + stato persistente; i bonus opzionali
		# a pagamento (focus_cost > 0) si saltano in auto-risoluzione.
		if not Gate.auto_allows(e, Domain.STANCE_SLUG[f.stance], f.states):
			continue
		# Gruppi "OPPURE": applica solo gli effetti dell'opzione scelta (chosen_alt).
		# Gli effetti senza 'alt' valgono sempre.
		var alt = e.get("alt", null)
		if alt != null and alt != chosen_alt:
			continue
		# Quantità a entità variabile (roadmap §3.13): `n_from_state` moltiplica
		# `n` per il valore di uno stato persistente (es. "PER OGNI CONTRATTO
		# COMPLETATO"). A zero istanze l'effetto non scatta.
		var n_eff := int(e.get("n", 1))
		var nsrc := str(e.get("n_from_state", ""))
		if nsrc != "":
			n_eff *= f.state_get(nsrc)
			if n_eff <= 0:
				continue
		match str(e.get("do", "")):
			"push":
				if foe != null: _push(i, foe_idx, n_eff, log)
			"pull":
				if foe != null: _pull(i, foe_idx, n_eff, log)
			"bleed":
				if foe != null: foe.wounds.append("bleed")
			"replace_wound_bleed":
				if foe != null and not foe.wounds.is_empty():
					foe.wounds[foe.wounds.size() - 1] = "bleed"
			"focus":
				f.gain_focus(n_eff)
			"hobble":
				if foe != null: foe.add_hobble(maxi(1, n_eff))
			"foe_stun":
				if foe != null:
					foe.stun += maxi(1, n_eff)
					log.append("%s: %s subisce %d stordimento" % [f.character, foe.character, maxi(1, n_eff)])
			"swap_positions":
				if foe != null:
					var tmp := f.cell; f.cell = foe.cell; foe.cell = tmp
					log.append("%s scambia posizione con %s" % [f.character, foe.character])
			"rotate_target":
				if foe != null: foe.facing = (foe.facing + n_eff) % 6
			"draw":
				for _d in range(maxi(0, n_eff)): f.draw_one()
			"search_draw":
				for _d in range(maxi(0, n_eff)): f.draw_one()
			"stun_self":
				f.stun += maxi(1, n_eff)   # "PRENDI 1 stordito"
				log.append("%s subisce %d stordimento" % [f.character, maxi(1, n_eff)])
			"discard_self":
				for _d in range(maxi(1, n_eff)):
					var random_pick := bool(e.get("random", false))
					if random_pick:
						if not _discard_random_noncore(f):
							break
					elif not _discard_one_noncore(f):
						break
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
					var targets := Kamae.change_targets(tree, Domain.STANCE_SLUG[f.stance], n_eff)
					for pref in ["aggression", "determination", "balance"]:
						if targets.has(pref):
							f.stance = Domain.STANCE_FROM_SLUG[pref]
							log.append("%s cambia Kamae in %s" % [f.character, Domain.STANCE_NAMES[f.stance]])
							break
			"spend_focus":
				# Spende i propri focus: tutti, tutti-tranne-N, o un numero fisso.
				if bool(e.get("all", false)):
					f.focus = 0
				elif e.has("all_but"):
					f.focus = mini(f.focus, int(e.get("all_but", 0)))
				else:
					f.focus = maxi(0, f.focus - n_eff)
			"foe_lose_focus":
				if foe != null: foe.focus = maxi(0, foe.focus - n_eff)
			"foe_discard":
				if foe != null:
					for _d in range(maxi(1, n_eff)):
						if foe.hand.is_empty():
							break
						# `random: true` = scarto a caso (roadmap §3.19), altrimenti
						# dall'ultima pescata (comportamento storico).
						var k := (randi() % foe.hand.size()) if bool(e.get("random", false)) else foe.hand.size() - 1
						foe.discard.append(foe.hand[k])
						foe.hand.remove_at(k)
			"foe_draw":
				# Fa pescare l'avversario (roadmap §3.18).
				if foe != null:
					for _d in range(maxi(0, n_eff)):
						foe.draw_one()
			"foe_reveal_hand":
				# Effetto informativo (roadmap §3.5): la UI mostrerà la mano;
				# qui si registra solo l'evento.
				if foe != null:
					log.append("%s guarda la mano di %s (%d carte)" % [f.character, foe.character, foe.hand.size()])
			"foe_switch_kamae":
				# Forza la Kamae dell'AVVERSARIO (roadmap §3.7). "any" non ha una
				# scelta sensata forzata: prudenzialmente porta a Neutrale.
				if foe != null:
					var fslug := str(e.get("to", ""))
					if fslug == "any":
						fslug = "neutral"
					var fto: int = Domain.STANCE_FROM_SLUG.get(fslug, -1)
					if fto != -1:
						foe.stance = fto
						log.append("%s forza %s in Kamae %s" % [f.character, foe.character, Domain.STANCE_NAMES[fto]])
			"foe_change_kamae":
				# Sposta l'avversario lungo il suo albero fino a n rami
				# (approssimazione auto: stessa preferenza di change_kamae).
				if foe != null:
					var ftree := CardDB.kamae_tree_for(foe.character.to_lower())
					var ftargets := Kamae.change_targets(ftree, Domain.STANCE_SLUG[foe.stance], n_eff)
					for pref in ["neutral", "balance", "determination", "aggression"]:
						if ftargets.has(pref):
							foe.stance = Domain.STANCE_FROM_SLUG[pref]
							log.append("%s sposta %s in Kamae %s" % [f.character, foe.character, Domain.STANCE_NAMES[foe.stance]])
							break
			"heal":
				# Guarigione/rimozione stato (roadmap §3.20): `what` indica cosa
				# rimuovere (wound/bleed/stun/hobble/poison), n quante istanze;
				# `all: true` = tutte ("SCARTA TUTTI GLI EFFETTI DI STATO").
				var what := str(e.get("what", "wound"))
				var n_heal := 99 if bool(e.get("all", false)) else maxi(1, n_eff)
				match what:
					"stun":
						f.stun = maxi(0, f.stun - n_heal)
					"poison":
						f.poison = maxi(0, f.poison - n_heal)
					"hobble":
						for _h in range(n_heal):
							if f.hobbles.is_empty():
								break
							f.hobbles.pop_back()
					_:
						for _h in range(n_heal):
							var widx: int = f.wounds.rfind(what)
							if widx == -1:
								break
							f.wounds.remove_at(widx)
				log.append("%s rimuove %s %s" % [f.character, "tutti" if bool(e.get("all", false)) else str(n_heal), what])
			"reduce_damage":
				# Persistente (carta "rimane in gioco"): riduce ogni attacco subito.
				f.damage_reduction += maxi(1, n_eff)
				log.append("%s: riduzione danno +%d (persistente)" % [f.character, maxi(1, n_eff)])
			"reset_deck":
				# Rimescola nel mazzo le carte abilità NON-meditazione (mano + scarti) e rimescola.
				_reset_deck(f, log)
			"cancel_movement":
				if foe != null:
					foe.movement_cancelled = true
					log.append("%s annulla il movimento di %s" % [f.character, foe.character])
			"cancel_abilities":
				if foe != null and (foe.damage_reduction > 0 or foe.block_initiative_bonus > 0):
					foe.damage_reduction = 0
					foe.block_initiative_bonus = 0
					log.append("%s annulla le abilità attive di %s" % [f.character, foe.character])
			"block_initiative":
				f.block_initiative_bonus += maxi(1, n_eff)
				log.append("%s: intervallo blocco +%d" % [f.character, maxi(1, n_eff)])
			"state_add":
				# Stato persistente per-fighter: somma n (anche negativo, per spendere).
				var sn := str(e.get("state", ""))
				if sn != "":
					f.state_add(sn, n_eff)
					log.append("%s: stato '%s' → %d" % [f.character, sn, f.state_get(sn)])
			"state_set":
				var sn := str(e.get("state", ""))
				if sn != "":
					f.state_set(sn, n_eff)
					log.append("%s: stato '%s' = %d" % [f.character, sn, f.state_get(sn)])
			"state_clear":
				var sn := str(e.get("state", ""))
				if sn != "" and f.state_get(sn) > 0:
					f.state_set(sn, 0)
					log.append("%s: stato '%s' rimosso" % [f.character, sn])
			"change_ai_behaviour":
				# Carta solo: l'IA cambia atteggiamento (offensivo <-> difensivo).
				if f.is_ai:
					f.ai_stance = "defensive" if f.ai_stance == "offensive" else "offensive"
					log.append("%s cambia atteggiamento IA → %s" % [f.character, f.ai_stance])
			"change_approach":
				# Carta solo: sposta il segnalino approccio alla posizione successiva
				# (frecce nere sulla carta avversario): fronte → destra → spalle → sinistra.
				if f.is_ai:
					var ring := ["front", "right", "rear", "left"]
					var idx: int = ring.find(f.ai_approach)
					f.ai_approach = ring[(idx + 1) % ring.size()] if idx != -1 else "front"
					log.append("%s sposta l'approccio IA → %s" % [f.character, f.ai_approach])
		if foe != null:
			fighter_updated.emit(foe_idx)
	fighter_updated.emit(i)


## "Reset Deck" (es. Istinto Bruciante): rimescola nel mazzo tutte le carte abilità
## NON-meditazione presenti in mano e negli scarti, poi rimescola il mazzo.
func _reset_deck(f: GameState.Fighter, log: Array) -> void:
	var moved := 0
	for src in [f.hand, f.discard]:
		var keep := []
		for cid in src:
			if str(CardDB.card(cid).get("type", "")) == "meditation" or is_core(cid):
				keep.append(cid)
			else:
				f.draw_pile.append(cid); moved += 1
		src.assign(keep)
	f.draw_pile.shuffle()
	log.append("%s rimescola nel mazzo %d carte non-meditazione" % [f.character, moved])


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
	combat_event.emit("collision", victim_idx, victim_idx, {})
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
	# Passo "Discard": la carta giocata va negli scarti, MA le core tornano in mano
	# (non si scartano mai, regolamento p.10). Poi rientra nel limite di mano.
	for f in state.fighters:
		if f.planned != -1:
			if is_core(f.planned) and not f.is_ai:
				if not f.hand.has(f.planned):
					f.hand.append(f.planned)   # la core torna in mano
			else:
				f.discard.append(f.planned)
			f.planned = -1
		# Se gli slot di mano usati (abilità + stordimenti) superano il limite, scarta
		# carte abilità (lo stordimento non si scarta mai dalla mano).
		while _hand_used(f) > f.hand_limit:
			if not _discard_one_noncore(f):
				break
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
