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
	# kamae_req può essere stringa singola o Array in OR: basta soddisfarne una.
	var req_list := Kamae.gate_values(geom.get("kamae_req", ""))
	if not req_list.is_empty() and Domain.STANCE_FROM_SLUG.has(req_list[0]):
		a.stance = Domain.STANCE_FROM_SLUG[req_list[0]]
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


# ─── Spiegazione in italiano della carta ─────────────────────────────────────
#
# Traduce la geometria (movimento, arco, difesa, effetti, contrattacco) in frasi
# leggibili — "a iniziativa 7 muovo di 2 avanti, se ho Aggressività ruoto di 1,
# poi pesco 2 carte…". Pensata per la finestra "Spiega carta" dell'editor.

const _KAMAE_IT := {
	"aggression": "Aggressività", "balance": "Equilibrio",
	"determination": "Determinazione", "neutral": "Neutra", "any": "una qualsiasi Kamae",
}
const _DIR_IT := {
	0: "in avanti", 1: "in avanti a destra", 2: "indietro a destra",
	3: "all'indietro", 4: "indietro a sinistra", 5: "in avanti a sinistra", -1: "in una direzione a scelta",
}
const _VERB_IT := {
	"push": "spingi il bersaglio", "draw": "peschi", "focus": "ottieni focus",
	"foe_lose_focus": "l'avversario perde focus", "foe_discard": "l'avversario scarta",
	"discard_self": "scarti una carta", "change_kamae": "cambi Kamae lungo un ramo",
	"switch_kamae": "passi a una Kamae", "hobble": "azzoppi il bersaglio",
	"foe_stun": "stordisci l'avversario", "stun_self": "subisci uno stordimento",
	"swap_positions": "scambi posizione col bersaglio", "rotate_target": "ruoti il bersaglio",
	"link_anchor": "colleghi l'àncora all'asterisco (gli effetti vanno sul colpito)",
	"reduce_damage": "riduci il danno subito", "replace_wound_bleed": "trasformi la ferita in sanguinante",
	"block_initiative": "blocchi un'iniziativa", "cancel_abilities": "annulli le abilità avversarie",
	"cancel_movement": "annulli il movimento avversario", "change_ai_behaviour": "cambi il comportamento del nemico",
	"search_draw": "cerchi nel mazzo e peschi", "spend_focus": "spendi focus",
	"reset_deck": "rimescoli il mazzo", "foe_discard_hand": "l'avversario scarta la mano",
	"foe_draw": "l'avversario pesca", "foe_reveal_hand": "guardi la mano dell'avversario",
	"foe_switch_kamae": "forzi l'avversario in una Kamae",
	"foe_change_kamae": "sposti l'avversario lungo il suo albero Kamae",
	"heal": "rimuovi ferite/stati", "mill": "scarti dalla cima del mazzo",
	"place_traps": "piazzi segnalini trappola sulla griglia",
	"flip_kamae": "volti la carta Kamae (due facce, Hachikō)",
	"foe_mill": "l'avversario scarta dalla cima del mazzo",
	"state_add": "aggiungi allo stato persistente",
	"state_set": "imposti lo stato persistente", "state_clear": "azzeri lo stato persistente",
	"bleed": "infliggi un sanguinante", "pull": "attiri il bersaglio",
	"change_approach": "sposti l'approccio del nemico",
}


## Restituisce una lista di frasi (italiano) che spiegano cosa fa la carta.
static func explain(card: Dictionary, geom: Dictionary) -> Array:
	var out: Array = []
	var type := str(geom.get("type", card.get("type", "attack")))
	var type_it: String = {"attack": "Attacco", "defence": "Difesa", "meditation": "Meditazione", "core": "Carta base"}.get(type, type)
	# Intestazione: tipo, iniziativa, costo focus, kamae richiesto.
	var head: String = type_it
	var init := str(card.get("initiative", "")).strip_edges()
	if init != "" and init != "-":
		head += " · iniziativa %s" % init
	var foc := int(card.get("focus", 0))
	if foc > 0:
		head += " · costo %d focus" % foc
	out.append(head + ".")
	var req = geom.get("kamae_req", "")
	if typeof(req) == TYPE_STRING and req != "":
		out.append("Giocabile solo in Kamae %s." % _KAMAE_IT.get(req, req))
	elif req is Array and not (req as Array).is_empty():
		out.append("Giocabile solo in Kamae: %s." % _gate_join(req))

	# Costo iniziale (es. "SCARTA 1 CARTA"): sulla carta stampata precede
	# sempre il movimento, ma è salvato in effects[] insieme al resto — va
	# estratto e mostrato qui, altrimenti finisce spiegato per ultimo.
	var effects: Array = (geom.get("effects", []) as Array).duplicate()
	for i in effects.size():
		var e = effects[i]
		if e is Dictionary and e.get("do", "") == "discard_self" and not e.has("when") and not e.has("alt"):
			var s := _effect_phrase(e)
			if s != "":
				out.append(s)
			effects.remove_at(i)
			break

	# Movimento (opzioni alternative).
	var mv = geom.get("move", {})
	var opts: Array = mv.get("opts", []) if typeof(mv) == TYPE_DICTIONARY else []
	for i in opts.size():
		var phrase := _atoms_phrase(opts[i].get("atoms", []))
		if phrase == "":
			continue
		if opts.size() > 1:
			out.append(("Movimento (opzione %d): " % (i + 1)) + phrase + ".")
		else:
			out.append("Movimento: " + phrase + ".")

	# Arco d'attacco / difesa (anche varianti gated da Kamae).
	if geom.has("attacks"):
		for v in geom.get("attacks", []):
			out.append(_attack_phrase(v.get("cells", []), v.get("kamae", "")))
	elif geom.has("attack"):
		out.append(_attack_phrase(geom["attack"].get("cells", []), ""))
	if geom.has("defences"):
		for v in geom.get("defences", []):
			out.append(_defence_phrase(v.get("cells", []), v.get("kamae", "")))
	elif geom.has("defence"):
		out.append(_defence_phrase(geom["defence"].get("cells", []), ""))

	# Contrattacco.
	var counter = geom.get("counter", [])
	if counter is Array and not (counter as Array).is_empty():
		out.append("Contrattacco se pari l'attacco a iniziativa %s." % ", ".join((counter as Array).map(func(x): return str(x))))

	# Effetti (ordinati) — il costo iniziale, se presente, è già stato estratto sopra.
	for e in effects:
		var s := _effect_phrase(e)
		if s != "":
			out.append(s)

	# Seconda iniziativa (carta split: parte bassa).
	if geom.has("split") and geom["split"] is Dictionary:
		var sp: Dictionary = geom["split"]
		var sp_init := str(sp.get("initiative", "?"))
		out.append("— Seconda iniziativa (%s) —" % sp_init)
		for opt in sp.get("move", {}).get("opts", []):
			var phrase := _atoms_phrase(opt.get("atoms", []))
			if phrase != "":
				out.append("Movimento: " + phrase + ".")
		if sp.has("attack"):
			out.append(_attack_phrase(sp["attack"].get("cells", []), ""))
		for e in sp.get("effects", []):
			if e is Dictionary:
				var s := _effect_phrase(e)
				if s != "":
					out.append(s)

	if out.size() <= 1:
		out.append("(Nessun effetto geometrico trascritto: solo anagrafica.)")
	return out


static func _gate_join(g) -> String:
	if g is Array:
		return " o ".join((g as Array).map(func(s): return _KAMAE_IT.get(str(s), str(s))))
	return _KAMAE_IT.get(str(g), str(g))


## Sequenza di atomi di movimento in una frase ("muovi di 2 avanti, poi ruoti di 1").
static func _atoms_phrase(atoms: Array) -> String:
	var parts: Array = []
	for a in atoms:
		var t := str(a.get("t", "step"))
		var n := int(a.get("n", 1))
		var verb := "puoi " if a.get("opt", false) else "devi "
		var frag := ""
		match t:
			"step":
				var d = a.get("dir", a.get("dirs", 0))
				var dir_txt := ""
				if d is Array:
					dir_txt = " o ".join((d as Array).map(func(x): return _DIR_IT.get(int(x), str(x))))
				else:
					dir_txt = _DIR_IT.get(int(d), str(d))
				frag = "%smuoverti di %d %s" % [verb, n, dir_txt]
			"rot":
				frag = "%sruotare di %d" % [verb, n]
			"anchor":
				frag = "%spiazzare l'àncora (fiocco) ×%d" % [verb, n]
			_:
				frag = "%s%s ×%d" % [verb, t, n]
		var gate = a.get("kamae", "")
		if typeof(gate) == TYPE_STRING and gate != "":
			frag += " (se in %s)" % _KAMAE_IT.get(gate, gate)
		elif gate is Array and not (gate as Array).is_empty():
			frag += " (se in %s)" % _gate_join(gate)
		var fc := int(a.get("focus_cost", 0))
		if fc > 0:
			frag += " pagando %d focus" % fc
		parts.append(frag)
	return ", poi ".join(parts)


static func _attack_phrase(cells: Array, kamae) -> String:
	if cells.is_empty():
		return "Attacco senza celle (forse a distanza)."
	var total := 0
	var execs := 0
	var bleeds := 0
	for c in cells:
		var w = c.get("w", 1)
		if str(w) == "exec": execs += 1
		elif str(w) == "bleed": bleeds += 1
		else: total += int(w)
	var bits: Array = []
	if total > 0: bits.append("%d ferita/e" % total)
	if bleeds > 0: bits.append("%d sanguinante/i" % bleeds)
	if execs > 0: bits.append("%d esecuzione/i" % execs)
	var s := "Colpisci %d cella/e dell'arco (%s)" % [cells.size(), ", ".join(bits) if not bits.is_empty() else "nessuna ferita"]
	if typeof(kamae) == TYPE_STRING and kamae != "":
		s += ", se in Kamae %s" % _KAMAE_IT.get(kamae, kamae)
	return s + "."


static func _defence_phrase(cells: Array, kamae) -> String:
	if cells.is_empty():
		return "Difesa senza celle."
	var val := 0
	for c in cells:
		val += int(c.get("v", 1))
	var s := "Blocchi %d cella/e (valore totale %d)" % [cells.size(), val]
	if typeof(kamae) == TYPE_STRING and kamae != "":
		s += ", se in Kamae %s" % _KAMAE_IT.get(kamae, kamae)
	return s + "."


## Verbi la cui quantità si legge come "carte" / "focus" / "di N"; gli altri
## non usano `n`. Default: nessuna quantità.
const _QTY_CARDS := ["draw", "foe_discard", "foe_draw", "search_draw"]
const _QTY_FOCUS := ["focus", "spend_focus", "foe_lose_focus"]
const _QTY_DI := ["push", "rotate_target", "reduce_damage", "change_kamae", "block_initiative"]

static func _effect_phrase(e: Dictionary) -> String:
	var verb := str(e.get("do", ""))
	var s := str(_VERB_IT.get(verb, verb))
	var n := int(e.get("n", 0))
	if n != 0:
		if verb in _QTY_CARDS:
			s += " %d carta/e" % n
		elif verb in _QTY_FOCUS:
			s += " %d" % n
		elif verb in _QTY_DI:
			s += " di %d" % n
	if e.has("to"):
		s += " %s" % _KAMAE_IT.get(str(e.get("to", "")), str(e.get("to", "")))
	# Condizioni: quando + kamae gate + costo focus.
	var conds: Array = []
	if str(e.get("when", "")) == "on_hit":
		conds.append("se l'attacco va a segno")
	var gate = e.get("kamae", "")
	if typeof(gate) == TYPE_STRING and gate != "":
		conds.append("se in Kamae %s" % _KAMAE_IT.get(gate, gate))
	elif gate is Array and not (gate as Array).is_empty():
		conds.append("se in Kamae %s" % _gate_join(gate))
	var fc := int(e.get("focus_cost", 0))
	if fc > 0:
		conds.append("pagando %d focus" % fc)
	var prefix := "In alternativa, " if e.has("alt") else ""
	if not conds.is_empty():
		return "%s%s (%s)." % [prefix, s, ", ".join(conds)]
	return "%s%s." % [prefix, s]


## Prima cella bersaglio (attacco, o difesa) relativa all'attaccante con facing 0,
## così l'avversario fittizio cade nell'arco. Default: fronte adiacente.
static func _first_cell(geom: Dictionary) -> Vector2i:
	var cells: Array = geom.get("attack", {}).get("cells", [])
	if cells.is_empty():
		cells = geom.get("defence", {}).get("cells", [])
	if not cells.is_empty():
		var c0 = cells[0]
		if c0.has("q"):
			return Vector2i(int(c0.get("q", 0)), int(c0.get("r", 0)))
		return HexGrid.DIRS[int(c0.get("d", 0)) % 6] * maxi(1, int(c0.get("k", 1)))
	return HexGrid.DIRS[0]
