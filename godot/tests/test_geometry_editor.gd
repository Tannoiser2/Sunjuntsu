## Test headless di GeometryEditor: round-trip di serializzazione dello Schema v2
## e mutatori (celle attacco/difesa, atomi di movimento, kamae, counter).
## Non scrive su disco.
extends Node

var _failures: int = 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok: ", msg)
	else:
		_failures += 1
		push_error("FAIL: " + msg)
		print("  FAIL: ", msg)


func _atk_set(g: Dictionary) -> Dictionary:
	var s := {}
	for c in g.get("attack", {}).get("cells", []):
		var ax: Vector2i
		if c.has("q"):
			ax = Vector2i(int(c.get("q")), int(c.get("r")))
		else:
			ax = HexGrid.DIRS[int(c.get("d")) % 6] * maxi(1, int(c.get("k")))
		var w = c.get("w")
		if typeof(w) != TYPE_STRING:
			w = int(w)   # JSON può dare float: normalizza per il confronto
		s["%d_%d" % [ax.x, ax.y]] = w
	return s


func _cell_label(ge: GeometryEditor, ax: Vector2i) -> String:
	if ge._defence.has(ax):
		return "shield"
	if ge._attack.has(ax):
		var w = ge._attack[ax]
		if typeof(w) == TYPE_STRING:
			return str(w)
		return "w2" if int(w) == 2 else "w1"
	return "empty"


func _ready() -> void:
	_test_roundtrip()
	_test_mutators()
	_test_move_fidelity()
	_test_effects()
	if _failures == 0:
		print("GEOMETRY EDITOR DONE ok")
		get_tree().quit(0)
	else:
		print("GEOMETRY EDITOR DONE failures=", _failures)
		get_tree().quit(1)


func _test_roundtrip() -> void:
	print("[roundtrip #55]")
	var orig := CardDB.geometry(55)
	_check(not orig.is_empty(), "carta #55 ha geometria")
	var ge := GeometryEditor.new()
	add_child(ge)
	ge.load_geometry("attack", orig)
	var out := ge.to_geometry()
	# Le celle d'attacco devono coincidere (insiemi (d,k)->w).
	var a0 := _atk_set(orig)
	var a1 := _atk_set(out)
	_check(a0 == a1, "celle d'attacco invariate dopo round-trip (%d celle)" % a0.size())
	_check(out.get("type", "") == "attack", "tipo conservato")
	_check(str(out.get("kamae_req", "")) == str(orig.get("kamae_req", "")), "kamae_req conservato")
	# Movimento: stesso numero di opzioni/atomi.
	var o0: int = orig.get("move", {}).get("opts", []).size()
	var o1: int = out.get("move", {}).get("opts", []).size()
	_check(o0 == o1, "numero di opzioni di movimento invariato (%d)" % o0)
	# Idempotenza: ricaricare l'output non cambia nulla.
	ge.load_geometry("attack", out)
	_check(_atk_set(ge.to_geometry()) == a1, "idempotente al secondo round-trip")
	ge.queue_free()


func _test_mutators() -> void:
	print("[mutatori da zero]")
	var ge := GeometryEditor.new()
	add_child(ge)
	ge.load_geometry("attack", {})
	_check(ge.to_geometry().get("attack", null) == null, "geometria vuota: nessun attacco")

	# Drag simulato: piazza ferite e scudo.
	ge.set_attack_cell(0, 1, 2)
	ge.set_attack_cell(1, 1, "exec")
	ge.set_defence_cell(3, 1, 1)
	var g := ge.to_geometry()
	_check(_atk_set(g) == {"0_1": 2, "1_1": "exec"}, "celle d'attacco impostate")
	_check(g.get("defence", {}).get("cells", []).size() == 1, "cella di difesa impostata")

	# Pulizia di una cella.
	ge.clear_cell(0, 1)
	_check(_atk_set(ge.to_geometry()) == {"1_1": "exec"}, "clear_cell rimuove la cella")

	# Movimento: una sequenza con passo + rotazione opzionale.
	var oi := ge.add_opt()
	ge.add_move_atom(oi, {"t": "step", "dir": 0, "n": 1, "opt": false})
	ge.add_move_atom(oi, {"t": "rot", "dir": 0, "n": 2, "opt": true})
	var atoms: Array = ge.to_geometry().get("move", {}).get("opts", [])[0].get("atoms", [])
	_check(atoms.size() == 2, "due atomi nella sequenza")
	_check(atoms[0].get("t") == "step" and atoms[0].has("dir"), "passo serializza la direzione")
	_check(atoms[1].get("t") == "rot" and not atoms[1].has("dir"), "rotazione senza direzione")
	_check(atoms[1].get("opt") == true, "atomo opzionale marcato")

	# Clic-ciclo su un esagono del nido d'ape: vuoto→w1→w2→exec→bleed→shield→vuoto.
	var any_cell = ge._hex_cells.values()[0]
	var ck: Vector2i = any_cell.ax
	var seq := []
	for _i in range(7):
		ge._on_cell_cycle(any_cell)
		seq.append(_cell_label(ge, ck))
	_check(seq == ["w1", "w2", "exec", "bleed", "shield", "empty", "w1"],
		"clic cicla gli stati dell'esagono (%s)" % str(seq))
	ge.clear_cell(ck.x, ck.y)

	# Kamae e counter.
	ge.set_kamae_req("balance")
	ge._on_counter_changed("8, 6")
	var g2 := ge.to_geometry()
	_check(g2.get("kamae_req", "") == "balance", "kamae_req impostato")
	_check(g2.get("counter", []) == [8, 6], "counter parsato dagli interi")
	ge.queue_free()


func _test_move_fidelity() -> void:
	print("[movimento: fedeltà dirs/kamae/focus/-1]")
	# #57 ha: step dirs[0,3] kamae focus_cost, step dir -1 focus_cost, rot kamae.
	var ge := GeometryEditor.new()
	add_child(ge)
	ge.load_geometry("attack", CardDB.geometry(57))
	var atoms: Array = ge.to_geometry().get("move", {}).get("opts", [])[0].get("atoms", [])
	_check(atoms.size() == 3, "#57: 3 atomi preservati (%d)" % atoms.size())
	_check(atoms[0].get("dirs", []) == [0, 3], "scelta di direzioni {dirs:[0,3]} preservata")
	_check(str(atoms[0].get("kamae", "")) == "aggression", "kamae sull'atomo preservato")
	_check(int(atoms[1].get("dir", 0)) == -1, "passo libero (dir -1) preservato")
	_check(int(atoms[1].get("focus_cost", 0)) == 1, "focus_cost sull'atomo preservato")
	_check(atoms[2].get("t") == "rot" and str(atoms[2].get("kamae", "")) == "determination",
		"rotazione con kamae preservata")
	ge.queue_free()

	# Round-trip a due opzioni (#60: OPPURE).
	var ge2 := GeometryEditor.new()
	add_child(ge2)
	ge2.load_geometry("attack", CardDB.geometry(60))
	_check(ge2.to_geometry().get("move", {}).get("opts", []).size() == 2, "#60: due alternative OPPURE preservate")
	ge2.queue_free()


func _test_effects() -> void:
	print("[effetti]")
	# Round-trip su #53 (5 effetti do/n/alt).
	var orig := CardDB.geometry(53)
	var ge := GeometryEditor.new()
	add_child(ge)
	ge.load_geometry(str(orig.get("type", "core")), orig)
	var out := ge.to_geometry()
	var e0: Array = orig.get("effects", [])
	var e1: Array = out.get("effects", [])
	_check(e1.size() == e0.size(), "stesso numero di effetti dopo round-trip (%d)" % e0.size())
	_check(e1.size() > 0 and e1[0].get("do") == e0[0].get("do"), "primo verbo conservato")
	_check(e1.size() > 0 and e1[0].get("alt") == e0[0].get("alt"), "campo alt conservato")
	_check(not e1[0].has("when"), "campi vuoti omessi nella serializzazione")
	ge.queue_free()

	# Mutatore: aggiungi effetto pre-popolato.
	var ge2 := GeometryEditor.new()
	add_child(ge2)
	ge2.load_geometry("attack", {})
	ge2.add_effect({"do": "push", "n": 1, "when": "on_hit"})
	ge2.add_effect({"do": ""})   # verbo vuoto: deve sparire nella serializzazione
	var eff: Array = ge2.to_geometry().get("effects", [])
	_check(eff.size() == 1, "effetto senza verbo scartato")
	_check(eff[0].get("do") == "push" and eff[0].get("when") == "on_hit", "effetto aggiunto serializzato")
	_check(not eff[0].has("kamae") and not eff[0].has("focus_cost"), "campi non impostati omessi")
	ge2.queue_free()
