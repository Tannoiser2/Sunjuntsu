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

	print("RISULTATO: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
