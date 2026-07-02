## Test headless: gate unificato (Gate.gd) + stati persistenti per-fighter
## (Fighter.states, verbi state_add/state_set/state_clear, gate `state` sugli
## effetti, `state_req` sulla giocabilità, passthrough campi sconosciuti
## nell'editor geometria). Vedi docs/GATE_AUDIT.md e roadmap meccaniche Fase 2.
extends Node

var ok := true

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("OK: ", msg)
	else:
		ok = false
		print("FAIL: ", msg)


func _mk(ch: String) -> GameState.Fighter:
	var f := GameState.Fighter.new()
	f.character = ch; f.stance = Domain.Stance.NEUTRAL; f.cell = Vector2i(0, 0)
	f.wound_limit = 8; f.hand_limit = 9
	return f


func _ready() -> void:
	# ── Gate.state_req_ok: tutte le forme del requisito ──────────────────────
	_check(Gate.state_req_ok(null, {}), "state_req null = nessun vincolo")
	_check(Gate.state_req_ok("", {}), "state_req stringa vuota = nessun vincolo")
	_check(not Gate.state_req_ok("ombra", {}), "state_req 'ombra' fallisce senza stato")
	_check(Gate.state_req_ok("ombra", {"ombra": 1}), "state_req 'ombra' ok con flag attivo")
	_check(Gate.state_req_ok({"contratti": 2}, {"contratti": 3}), "state_req dict soddisfatto (3 >= 2)")
	_check(not Gate.state_req_ok({"contratti": 2}, {"contratti": 1}), "state_req dict non soddisfatto (1 < 2)")
	_check(not Gate.state_req_ok({"a": 1, "b": 1}, {"a": 1}), "state_req dict = AND fra le chiavi")

	# ── Gate.allows / auto_allows: kamae + stato + focus in AND ─────────────
	var part := {"kamae": ["balance", "determination"], "state": "ninja", "focus_cost": 1}
	_check(not Gate.allows(part, "aggression", {"ninja": 1}), "allows: kamae OR non soddisfatto")
	_check(not Gate.allows(part, "balance", {}), "allows: stato mancante")
	_check(Gate.allows(part, "balance", {"ninja": 1}), "allows: kamae OR + stato ok (focus ignorato)")
	_check(not Gate.auto_allows(part, "balance", {"ninja": 1}), "auto_allows: focus_cost > 0 si salta")
	_check(Gate.auto_allows({}, "aggression", {}), "auto_allows: gate vuoto = sempre valido")

	# ── Fighter.states: helper add/set/spend/erase ───────────────────────────
	var f := _mk("Yojimbo")
	f.state_add("contratti", 1)
	f.state_add("contratti", 2)
	_check(f.state_get("contratti") == 3, "state_add accumula (1+2=3)")
	f.state_add("contratti", -2)
	_check(f.state_get("contratti") == 1, "state_add negativo spende (3-2=1)")
	f.state_add("contratti", -5)
	_check(not f.states.has("contratti"), "stato a <=0 viene rimosso dal dizionario")
	f.state_set("ombra", 1)
	f.state_set("ombra", 0)
	_check(not f.states.has("ombra"), "state_set 0 rimuove il flag")

	# ── Verbi state_* via Duel._apply_effects ────────────────────────────────
	var s := GameState.new()
	var a := _mk("Assassino"); var b := _mk("Warrior")
	s.fighters = [a, b]
	var duel := Duel.new(s)
	duel._apply_effects(0, 1, {"effects": [{"do": "state_add", "state": "ombra"}]}, "always", [])
	_check(a.state_get("ombra") == 1, "state_add (n default 1) attiva lo stato")
	duel._apply_effects(0, 1, {"effects": [{"do": "state_set", "state": "disperazione", "n": 4}]}, "always", [])
	_check(a.state_get("disperazione") == 4, "state_set imposta il valore assoluto")
	duel._apply_effects(0, 1, {"effects": [{"do": "state_clear", "state": "ombra"}]}, "always", [])
	_check(a.state_get("ombra") == 0, "state_clear azzera lo stato")
	_check(b.states.is_empty(), "i verbi state_* toccano solo chi gioca la carta")

	# ── Gate `state` su un effetto normale (applicato solo se lo stato c'è) ──
	b.focus = 0
	duel._apply_effects(1, 0, {"effects": [{"do": "focus", "n": 2, "state": "furia"}]}, "always", [])
	_check(b.focus == 0, "effetto gated da stato assente: saltato")
	b.state_set("furia", 1)
	duel._apply_effects(1, 0, {"effects": [{"do": "focus", "n": 2, "state": "furia"}]}, "always", [])
	_check(b.focus == 2, "effetto gated da stato presente: applicato")

	# ── Giocabilità: state_req su una geometria fittizia ─────────────────────
	const TID := 90001
	CardDB.set_geometry(TID, {"name": "TEST STATO", "type": "attack", "state_req": "ombra"})
	var g := _mk("Assassino")
	_check(not Duel.playable(g, TID), "playable: state_req blocca senza stato")
	g.state_set("ombra", 1)
	_check(Duel.playable(g, TID), "playable: state_req soddisfatto")
	CardDB.set_geometry(TID, {})   # pulizia

	# ── Editor: passthrough dei campi non modellati (round-trip) ─────────────
	var ge := GeometryEditor.new()
	add_child(ge)
	var src := {
		"name": "PASSTHROUGH", "type": "attack",
		"non_blockable": true,
		"play_cost": {"focus": 1},
		"state_req": {"contratti": 2},
		"attack": {"cells": [{"d": 0, "k": 1, "w": 1}]},
		"move": {"opts": [{"atoms": [{"t": "step", "dir": 0, "n": 1, "opt": false, "if_success": "focus:1"}]}]},
		"effects": [
			{"do": "spend_focus", "all": true},
			{"do": "state_add", "state": "contratti", "n": 1},
		],
		"split": {"initiative": 3, "wound_kind": "bleed",
			"attack": {"cells": [{"d": 0, "k": 1, "w": 1}]}},
	}
	ge.load_geometry("attack", src, "6")
	var out := ge.to_geometry()
	_check(bool(out.get("non_blockable", false)), "editor preserva non_blockable")
	_check(int(out.get("play_cost", {}).get("focus", 0)) == 1, "editor preserva play_cost")
	_check(out.get("state_req", {}).get("contratti", 0) == 2, "editor preserva state_req")
	var out_effs: Array = out.get("effects", [])
	var kept_all := false
	var kept_state := false
	for e in out_effs:
		if str(e.get("do", "")) == "spend_focus" and bool(e.get("all", false)):
			kept_all = true
		if str(e.get("do", "")) == "state_add" and str(e.get("state", "")) == "contratti":
			kept_state = true
	_check(kept_all, "editor preserva il campo 'all' di spend_focus")
	_check(kept_state, "editor preserva il campo 'state' dei verbi state_*")
	var out_atoms: Array = out.get("move", {}).get("opts", [{}])[0].get("atoms", [])
	_check(not out_atoms.is_empty() and str(out_atoms[0].get("if_success", "")) == "focus:1",
		"editor preserva i campi sconosciuti sugli atomi di movimento")
	_check(str(out.get("split", {}).get("wound_kind", "")) == "bleed",
		"editor preserva i campi sconosciuti dentro split")
	_check(int(out.get("split", {}).get("initiative", 0)) == 3, "split.initiative invariata")

	# ═══ Fase 3 ═══════════════════════════════════════════════════════════

	# ── n_from_state: quantità moltiplicata da uno stato (es. Contratti) ─────
	var s4 := GameState.new()
	var y := _mk("Yojimbo"); var w := _mk("Warrior")
	s4.fighters = [y, w]
	var d4 := Duel.new(s4)
	y.focus = 0
	d4._apply_effects(0, 1, {"effects": [{"do": "focus", "n_from_state": "contratti"}]}, "always", [])
	_check(y.focus == 0, "n_from_state: a 0 istanze l'effetto non scatta")
	y.state_set("contratti", 2)
	d4._apply_effects(0, 1, {"effects": [{"do": "focus", "n_from_state": "contratti"}]}, "always", [])
	_check(y.focus == 2, "n_from_state: focus x contratti (2)")

	# ── foe_draw / foe_reveal_hand / foe_switch_kamae ────────────────────────
	w.draw_pile = [10, 11, 12]; w.hand = []
	d4._apply_effects(0, 1, {"effects": [{"do": "foe_draw", "n": 2}]}, "always", [])
	_check(w.hand.size() == 2, "foe_draw fa pescare l'avversario")
	var log4: Array = []
	d4._apply_effects(0, 1, {"effects": [{"do": "foe_reveal_hand"}]}, "always", log4)
	_check(not log4.is_empty() and "mano" in str(log4[0]), "foe_reveal_hand registra l'evento")
	w.stance = Domain.Stance.AGGRESSION
	d4._apply_effects(0, 1, {"effects": [{"do": "foe_switch_kamae", "to": "balance"}]}, "always", [])
	_check(w.stance == Domain.Stance.BALANCE, "foe_switch_kamae forza la Kamae avversaria")

	# ── heal: rimozione ferite/stati propri ─────────────────────────────────
	y.wounds = ["wound", "bleed", "wound"]; y.stun = 2
	d4._apply_effects(0, 1, {"effects": [{"do": "heal", "n": 1, "what": "bleed"}]}, "always", [])
	_check(not y.wounds.has("bleed"), "heal what=bleed rimuove il sanguinante")
	d4._apply_effects(0, 1, {"effects": [{"do": "heal", "n": 2, "what": "stun"}]}, "always", [])
	_check(y.stun == 0, "heal what=stun rimuove gli stordimenti")
	d4._apply_effects(0, 1, {"effects": [{"do": "heal", "n": 1}]}, "always", [])
	_check(y.wounds.size() == 1, "heal default rimuove 1 ferita")

	# ── discard casuale: conta giusta, pesca casuale ─────────────────────────
	w.hand = [10, 11, 12]; w.discard = []
	d4._apply_effects(0, 1, {"effects": [{"do": "foe_discard", "n": 2, "random": true}]}, "always", [])
	_check(w.hand.size() == 1 and w.discard.size() == 2, "foe_discard random scarta il numero giusto")

	# ── counter gated (§3.10): voce int sempre attiva + voce gated ──────────
	const CID := 90002
	CardDB.set_geometry(CID, {"name": "T-COUNTER", "type": "defence",
		"counter": [5, {"on": [8, 7], "kamae": "determination"}]})
	var s5 := GameState.new()
	var att5 := _mk("Warrior"); att5.cell = Vector2i(0, 0)
	var def5 := _mk("Ronin"); def5.cell = HexGrid.DIRS[0]; def5.planned = CID
	def5.hand = [64]   # attacco non-core da scartare per il counter
	s5.fighters = [att5, def5]
	var d5 := Duel.new(s5)
	d5._try_counter(1, 0, 8, [])   # vel 8: gated Determinazione, def5 è NEUTRAL
	_check(att5.wounds.is_empty(), "counter gated: NON scatta fuori Kamae")
	def5.stance = Domain.Stance.DETERMINATION
	d5._try_counter(1, 0, 8, [])
	_check(att5.wounds.size() == 1, "counter gated: scatta nella Kamae giusta")
	def5.hand = [64]
	d5._try_counter(1, 0, 5, [])
	_check(att5.wounds.size() == 2, "counter: voce int sempre attiva")
	CardDB.set_geometry(CID, {})

	# ── alt_initiative (§3.1): gate su kamae/focus/state ─────────────────────
	const AID := 90003
	CardDB.set_geometry(AID, {"name": "T-ALT", "type": "attack",
		"alt_initiative": {"value": 8, "state": "disperazione"}})
	var s6 := GameState.new()
	var f6 := _mk("Onna-Bugeisha"); f6.planned = AID
	s6.fighters = [f6, _mk("Warrior")]
	var d6 := Duel.new(s6)
	_check(d6._alt_initiative_value(0) == -1, "alt_initiative: -1 senza lo stato richiesto")
	f6.state_set("disperazione", 1)
	_check(d6._alt_initiative_value(0) == 8, "alt_initiative: valore col gate soddisfatto")
	CardDB.set_geometry(AID, {"name": "T-ALT", "type": "attack",
		"alt_initiative": {"value": 8, "focus_cost": 1}})
	_check(d6._alt_initiative_value(0) == -1, "alt_initiative: a pagamento si salta in auto")
	CardDB.set_geometry(AID, {})

	# ── editor: passthrough voci counter gated ───────────────────────────────
	var ge2 := GeometryEditor.new()
	add_child(ge2)
	ge2.load_geometry("defence", {"name": "T", "type": "defence",
		"counter": [5, {"on": [8, 7], "kamae": "determination"}]}, "5")
	var out2 := ge2.to_geometry()
	var cvals: Array = out2.get("counter", [])
	var has_int := false
	var has_gated := false
	for entry in cvals:
		if entry is Dictionary and (entry.get("on", []) as Array).size() == 2:
			has_gated = true
		elif int(entry) == 5:
			has_int = true
	_check(has_int and has_gated, "editor preserva le voci counter gated")

	# ═══ Fase 4 ═══════════════════════════════════════════════════════════

	# ── Zona "in gioco": enter/exit con in_play_state e limit_mod ────────────
	const PID := 90004
	CardDB.set_geometry(PID, {"name": "T-PLAY", "type": "meditation",
		"stays_in_play": true, "in_play_state": "illuminata",
		"limit_mod": {"hand": 1, "focus": 1}})
	var s7 := GameState.new()
	var m := _mk("Monaco"); var mf := _mk("Warrior")
	s7.fighters = [m, mf]
	var d7 := Duel.new(s7)
	var base_hand := m.hand_limit
	d7._enter_play(0, PID)
	_check(m.in_play.has(PID), "enter_play: la carta è in gioco")
	_check(m.state_get("illuminata") == 1, "enter_play: in_play_state incrementato")
	_check(m.hand_limit == base_hand + 1 and m.focus_limit == 4, "enter_play: limit_mod applicato")
	m.gain_focus(9)
	_check(m.focus == 4, "gain_focus rispetta il focus_limit alzato")
	_check(d7.remove_from_play(0, PID), "remove_from_play: rimozione riuscita")
	_check(m.state_get("illuminata") == 0, "remove_from_play: in_play_state decrementato")
	_check(m.hand_limit == base_hand and m.focus_limit == 3 and m.focus == 3,
		"remove_from_play: limiti ripristinati e focus riallineato")
	_check(m.discard.has(PID), "remove_from_play: la carta va negli scarti")

	# ── turn_start: effetti a inizio turno (prima del Draw) ──────────────────
	const TSID := 90005
	CardDB.set_geometry(TSID, {"name": "T-TURNSTART", "type": "attack",
		"stays_in_play": true, "turn_start": [{"do": "foe_mill", "n": 1}]})
	d7._enter_play(0, TSID)
	mf.draw_pile = [10, 11, 12]; mf.discard = []
	m.draw_pile = [20, 21]; mf.is_ai = true   # l'IA salta il Draw: isola il mill
	d7._begin_turn()
	_check(mf.discard.size() == 1 and mf.draw_pile.size() == 2,
		"turn_start: foe_mill scarta dalla cima del mazzo avversario a inizio turno")
	d7.remove_from_play(0, TSID)
	CardDB.set_geometry(TSID, {})

	# ── expires: la carta scade dopo N fine-turno ────────────────────────────
	const EID := 90006
	CardDB.set_geometry(EID, {"name": "T-EXPIRES", "type": "meditation",
		"stays_in_play": true, "expires": {"turns": 2}})
	var s8 := GameState.new()
	var e8 := _mk("Ronin"); var e8b := _mk("Warrior")
	e8.draw_pile = [10, 11, 12, 13]; e8b.is_ai = true; e8b.draw_pile = [30, 31, 32]
	s8.fighters = [e8, e8b]
	var d8 := Duel.new(s8)
	d8._enter_play(0, EID)
	d8._cleanup([])
	_check(e8.in_play.has(EID), "expires: ancora in gioco dopo 1 turno")
	d8._cleanup([])
	_check(not e8.in_play.has(EID) and e8.discard.has(EID), "expires: scaduta dopo 2 turni")
	CardDB.set_geometry(EID, {})
	CardDB.set_geometry(PID, {})

	# ── targeting per confronto iniziativa (§3.4) ────────────────────────────
	const RID := 90007
	CardDB.set_geometry(RID, {"name": "T-RANGED", "type": "attack",
		"targeting": {"mode": "initiative", "w": 1}})
	var s9 := GameState.new()
	var r9 := _mk("Navigatore"); r9.planned = RID
	var t9 := _mk("Warrior"); t9.cell = HexGrid.DIRS[0]; t9.planned = 64   # adiacente: Range default 1
	s9.fighters = [r9, t9]
	var d9 := Duel.new(s9)
	d9._chosen = {0: 7, 1: 4}
	d9._resolve_attack_top(0, CardDB.geometry(RID), "T-RANGED", [], null)
	_check(t9.wounds.size() == 1, "targeting initiative: colpisce con iniziativa superiore (7>4)")
	d9._chosen = {0: 3, 1: 4}
	d9._resolve_attack_top(0, CardDB.geometry(RID), "T-RANGED", [], null)
	_check(t9.wounds.size() == 1, "targeting initiative: NON colpisce con iniziativa inferiore (3<4)")
	CardDB.set_geometry(RID, {"name": "T-RANGED", "type": "attack",
		"targeting": {"mode": "initiative", "threshold": 4, "w": 1}})
	d9._chosen = {0: 7, 1: 4}
	d9._resolve_attack_top(0, CardDB.geometry(RID), "T-RANGED", [], null)
	_check(t9.wounds.size() == 1, "targeting threshold: 4 non è sotto la soglia 4")
	d9._chosen = {0: 7, 1: 3}
	d9._resolve_attack_top(0, CardDB.geometry(RID), "T-RANGED", [], null)
	_check(t9.wounds.size() == 2, "targeting threshold: 3 sotto la soglia 4 colpisce")
	CardDB.set_geometry(RID, {"name": "T-RANGED", "type": "attack",
		"targeting": {"mode": "initiative", "w_from_gap": true}})
	d9._chosen = {0: 7, 1: 4}
	d9._resolve_attack_top(0, CardDB.geometry(RID), "T-RANGED", [], null)
	_check(t9.wounds.size() == 5, "targeting w_from_gap: ferite pari al divario (7-4=3)")
	CardDB.set_geometry(RID, {})

	# ── mill / foe_mill ──────────────────────────────────────────────────────
	var s10 := GameState.new()
	var m10 := _mk("Yojimbo"); var m10b := _mk("Warrior")
	s10.fighters = [m10, m10b]
	var d10 := Duel.new(s10)
	m10.draw_pile = [10, 11, 12]
	d10._apply_effects(0, 1, {"effects": [{"do": "mill", "n": 2}]}, "always", [])
	_check(m10.draw_pile.size() == 1 and m10.discard.size() == 2, "mill scarta dalla propria cima")
	m10b.draw_pile = [20]
	d10._apply_effects(0, 1, {"effects": [{"do": "foe_mill", "n": 3}]}, "always", [])
	_check(m10b.draw_pile.is_empty() and m10b.discard.size() == 1, "foe_mill si ferma a mazzo vuoto")

	# ── Occultato: condizioni di uscita (carta-regola #161) ─────────────────
	var s11 := GameState.new()
	var n11 := _mk("Ninja"); var n11b := _mk("Warrior")
	n11.draw_pile = [10, 11]; n11b.is_ai = true; n11b.draw_pile = [30]
	s11.fighters = [n11, n11b]
	var d11 := Duel.new(s11)
	d11._begin_turn()   # fotografa la baseline
	n11.state_set("occultato", 1)
	d11._stealth_entered = {}   # simulare uno stato preso nei turni scorsi
	d11._cleanup([])
	_check(n11.state_get("occultato") == 1, "occultato: resta senza eventi di uscita")
	n11.wounds.append("wound")   # subisce una ferita nel turno
	d11._cleanup([])
	_check(n11.state_get("occultato") == 0, "occultato: esce dopo una ferita subita")
	n11.state_set("occultato", 1)
	d11._attack_ok[0] = true
	d11._stealth_entered = {}
	d11._cleanup([])
	_check(n11.state_get("occultato") == 0, "occultato: esce dopo un attacco riuscito")
	n11.state_set("occultato", 1)
	d11._attack_ok[0] = true
	d11._stealth_entered = {0: true}   # ENTRATO in questo turno: non esce
	d11._cleanup([])
	_check(n11.state_get("occultato") == 1, "occultato: il re-ingresso nel turno prevale")

	print("RISULTATO: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
