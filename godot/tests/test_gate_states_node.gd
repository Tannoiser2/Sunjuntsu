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

	print("RISULTATO: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
