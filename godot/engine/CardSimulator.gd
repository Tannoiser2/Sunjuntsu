## Tester di carta — Senjutsu (editor, Fase 5)
##
## Risolve la carta (il "gemello" che stai editando) in un Duel reale contro un
## avversario fittizio, riusando il motore (Duel/GameState) senza GUI 3D, e
## restituisce l'esito: ferite inflitte, posizione, e il log di risoluzione.
##
## Logica pura/headless-testabile. Inietta temporaneamente carta+geometria in
## CardDB sotto un id riservato, risolve, e ripristina lo stato.
class_name CardSimulator
extends RefCounted

const SIM_ID := 999998   ## id temporaneo (fuori dal pool e dagli id-utente reali)


## Simula `card` (anagrafica) + `geom` (geometria) contro un avversario `dummy`.
## Restituisce { hit, target_wounds, target_tags, attacker_cell, attacker_facing,
## attacker_focus, target_cell, log }.
static func simulate(card: Dictionary, geom: Dictionary, dummy := "Ronin") -> Dictionary:
	# Inietta sotto SIM_ID, preservando un eventuale valore preesistente.
	var had_card := CardDB.by_id.has(SIM_ID)
	var prev_card = CardDB.by_id.get(SIM_ID, null)
	var had_geom := CardDB.geom.has(SIM_ID)
	var prev_geom = CardDB.geom.get(SIM_ID, null)

	var sc := card.duplicate(true)
	sc["id"] = SIM_ID
	if not sc.has("type"):
		sc["type"] = str(geom.get("type", "attack"))
	CardDB.by_id[SIM_ID] = sc
	CardDB.geom[SIM_ID] = geom

	var res := _run(str(card.get("char", "Warrior")), geom, dummy)

	# Ripristina.
	if had_card:
		CardDB.by_id[SIM_ID] = prev_card
	else:
		CardDB.by_id.erase(SIM_ID)
	if had_geom:
		CardDB.geom[SIM_ID] = prev_geom
	else:
		CardDB.geom.erase(SIM_ID)
	return res


static func _run(character: String, geom: Dictionary, dummy: String) -> Dictionary:
	var gs := GameState.new()

	var a := GameState.Fighter.new()
	a.character = character
	a.cell = Vector2i.ZERO
	a.facing = 0
	a.wound_limit = 6
	a.hand_limit = 5
	a.focus = 5
	a.stance = Domain.Stance.NEUTRAL
	var req := str(geom.get("kamae_req", ""))
	if Domain.STANCE_FROM_SLUG.has(req):
		a.stance = Domain.STANCE_FROM_SLUG[req]
	a.planned = SIM_ID

	var b := GameState.Fighter.new()
	b.character = dummy
	b.cell = _first_cell(geom)   # piazzato in arco quando possibile
	b.facing = 3                  # rivolto verso l'attaccante
	b.wound_limit = 6
	b.hand_limit = 5
	b.stance = Domain.Stance.NEUTRAL
	b.planned = -1

	gs.fighters.append(a)
	gs.fighters.append(b)

	var duel := Duel.new(gs)
	var log: Array = []
	duel._resolve_chosen_speeds({})
	duel._resolve_card(0, {}, log)

	return {
		"hit": b.wounds.size() > 0,
		"target_wounds": b.wounds.size(),
		"target_tags": b.wounds.duplicate(),
		"attacker_cell": a.cell,
		"attacker_facing": a.facing,
		"attacker_focus": a.focus,
		"target_cell": b.cell,
		"log": log,
	}


## Prima cella bersaglio (attacco, o difesa) relativa all'attaccante con facing 0,
## così l'avversario fittizio cade nell'arco. Default: fronte adiacente.
static func _first_cell(geom: Dictionary) -> Vector2i:
	var cells: Array = geom.get("attack", {}).get("cells", [])
	if cells.is_empty():
		cells = geom.get("defence", {}).get("cells", [])
	if not cells.is_empty():
		var c0 = cells[0]
		return HexGrid.DIRS[int(c0.get("d", 0)) % 6] * maxi(1, int(c0.get("k", 1)))
	return HexGrid.DIRS[0]
