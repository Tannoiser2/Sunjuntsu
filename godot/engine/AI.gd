## IA della modalità solo — Senjutsu
##
## Sceglie la carta che l'avversario controllato dal computer gioca, con
## un'euristica ispirata alle "AI deck tables" (solo_AI_tables_v1.xlsx):
## la scelta dipende dalla distanza dal bersaglio e dal tipo di carta
## (attacco a portata, difesa se minacciato, meditazione/avvicinamento altrimenti).
##
## NOTA: il sistema solo ufficiale di Senjutsu usa un "mazzo IA" costruito da
## gruppi di carte (I–VIII) con regole speciali per personaggio. Questa è una
## prima euristica funzionale; il mazzo IA completo è lavoro futuro (vedi DESIGN).
class_name AI
extends RefCounted


## Restituisce l'id della carta da giocare dalla mano di `me`, o -1 se passa.
static func choose_card(state: GameState, me: GameState.Fighter) -> int:
	if me.hand.is_empty():
		return -1
	var foe := state.opponent_of(me)
	var dist := 99 if foe == null else HexGrid.distance(me.cell, foe.cell)

	var attacks: Array = []
	var defences: Array = []
	var meditations: Array = []
	for id in me.hand:
		# Salta le carte non giocabili nella Kamae attuale.
		var req = CardDB.geometry(id).get("kamae_req", "")
		if not Kamae.gate_allows(req, Domain.STANCE_SLUG[me.stance]):
			continue
		var c := CardDB.card(id)
		match c.get("type", ""):
			"attack":     attacks.append(id)
			"defence":    defences.append(id)
			"meditation": meditations.append(id)

	# 1) Se il bersaglio è a portata di un attacco affrontabile col focus, attacca.
	var best_atk := _best_affordable(me, attacks, dist)
	if best_atk != -1:
		return best_atk

	# 2) Se è minacciato (poche ferite o nemico adiacente) e ha una difesa, difende.
	if foe != null and (dist <= 1 or me.remaining_wounds() <= 2) and not defences.is_empty():
		return _best_affordable(me, defences, 99)

	# 3) Altrimenti medita per accumulare focus / pescare.
	if not meditations.is_empty():
		return _best_affordable(me, meditations, 99)

	# 4) Ripiego: la prima carta affrontabile, o la prima in mano.
	for id in me.hand:
		if _affordable(me, id):
			return id
	return me.hand[0]


## Direzione di movimento dell'IA: avvicinati al nemico se fuori portata.
## Restituisce la cella di destinazione adiacente, o la cella attuale.
static func move_target(state: GameState, me: GameState.Fighter) -> Vector2i:
	var foe := state.opponent_of(me)
	if foe == null:
		return me.cell
	var best := me.cell
	var best_d := HexGrid.distance(me.cell, foe.cell)
	for nb in HexGrid.neighbors(me.cell):
		if state.is_blocked(nb):
			continue
		var d := HexGrid.distance(nb, foe.cell)
		if d < best_d:
			best_d = d
			best = nb
	return best


## Pianifica posizione+facing dell'IA secondo le PRIORITÀ del solitario (regolamento
## p.22), in base all'atteggiamento (offensivo/difensivo), alla portata preferita e
## all'approccio. Enumera gli stati raggiungibili dalla mossa della carta (`geom`),
## ne valuta le metriche e sceglie il migliore. Ritorna {cell, facing}.
##
## Priorità (chiave lessicografica, dalla più alta):
##  Offensivo: colpire → più ferite → vicino alle spalle → non colpibile →
##             verso la portata → angolo d'approccio → fronteggiare.
##  Difensivo: non colpibile → colpire → più ferite → verso la portata →
##             vicino alle spalle → approccio → fronteggiare.
static func plan_move(state: GameState, me: GameState.Fighter, geom: Dictionary) -> Dictionary:
	var foe := state.opponent_of(me)
	if foe == null:
		return {"cell": me.cell, "facing": me.facing}
	var stance_slug: String = Domain.STANCE_SLUG[me.stance]
	var states: Array = Move.reachable_states(me.cell, me.facing, geom.get("move", null), state.is_blocked, stance_slug, me.states)
	var start := Vector3i(me.cell.x, me.cell.y, me.facing)
	if not states.has(start):
		states.append(start)
	# Celle minacciate dall'attacco del giocatore (per la metrica "non colpibile").
	var threat := {}
	if foe.planned != -1:
		var fg := CardDB.geometry(foe.planned)
		if fg.has("attack") or fg.has("attacks"):
			for cell in Duel.attack_v2_cells(foe.cell, foe.facing, fg, 1, foe.stance):
				threat[cell] = true
	var has_atk: bool = geom.has("attack") or geom.has("attacks")
	var rear: Vector2i = foe.cell + HexGrid.DIRS[(foe.facing + 3) % 6]
	var desired_dir: int = _approach_dir(foe.facing, me.ai_approach)
	var best_state := start
	var best_key: Array = []
	for s in states:
		var c := Vector2i(s.x, s.y)
		var fc := int(s.z)
		var can_atk := 0
		var wounds := 0
		if has_atk:
			var cells := Duel.attack_v2_cells(c, fc, geom, 1, me.stance)
			if cells.has(foe.cell):
				can_atk = 1
				wounds = int(cells[foe.cell])
		var safe := 0 if threat.has(c) else 1
		var rear_s := -HexGrid.distance(c, rear)
		var range_s := -absi(HexGrid.distance(c, foe.cell) - me.ai_preferred_range)
		var appr_s := -_ang_diff(facing_toward(foe.cell, c), desired_dir)
		var face_s := -_ang_diff(fc, facing_toward(c, foe.cell))
		var key: Array
		if me.ai_stance == "defensive":
			key = [safe, can_atk, wounds, range_s, rear_s, appr_s, face_s]
		else:
			key = [can_atk, wounds, rear_s, safe, range_s, appr_s, face_s]
		if best_key.is_empty() or _key_gt(key, best_key):
			best_key = key
			best_state = s
	return {"cell": Vector2i(best_state.x, best_state.y), "facing": int(best_state.z)}


## Confronto lessicografico di due chiavi (true se `a` è migliore di `b`).
static func _key_gt(a: Array, b: Array) -> bool:
	for i in range(a.size()):
		if a[i] != b[i]:
			return a[i] > b[i]
	return false


static func _ang_diff(a: int, b: int) -> int:
	return mini((a - b + 6) % 6, (b - a + 6) % 6)


## Direzione (relativa al facing del giocatore) da cui l'IA approccia.
static func _approach_dir(foe_facing: int, approach: String) -> int:
	match approach:
		"left": return (foe_facing + 5) % 6
		"right": return (foe_facing + 1) % 6
		"rear": return (foe_facing + 3) % 6
		_: return foe_facing   # "front"


## Direzione (0..5) che punta meglio dalla cella `from` verso `to`.
static func facing_toward(from: Vector2i, to: Vector2i) -> int:
	var best := 0
	var best_d := 9999
	for d in range(6):
		var step := from + HexGrid.DIRS[d]
		var dist := HexGrid.distance(step, to)
		if dist < best_d:
			best_d = dist
			best = d
	return best


static func _affordable(me: GameState.Fighter, id: int) -> bool:
	return me.focus >= int(CardDB.card(id).get("focus", 0))


## Sceglie tra `ids` la carta affrontabile con portata sufficiente, preferendo
## l'iniziativa più alta. `dist` = distanza dal bersaglio (99 = ignora portata).
static func _best_affordable(me: GameState.Fighter, ids: Array, dist: int) -> int:
	var best := -1
	var best_ini := -999
	for id in ids:
		if not _affordable(me, id):
			continue
		var c := CardDB.card(id)
		if dist != 99 and dist > _card_range(c):
			continue
		var ini := Domain.initiative_value(str(c.get("initiative", "")))
		if ini > best_ini:
			best_ini = ini
			best = id
	return best


## Portata di una carta: 1 (mischia) salvo keyword RangeN.
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
