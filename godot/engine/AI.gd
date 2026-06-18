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
