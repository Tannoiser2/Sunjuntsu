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
		var w = c.get("w")
		if typeof(w) != TYPE_STRING:
			w = int(w)   # JSON può dare float: normalizza per il confronto
		s["%d_%d" % [int(c.get("d")), int(c.get("k"))]] = w
	return s


func _ready() -> void:
	_test_roundtrip()
	_test_mutators()
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

	# Kamae e counter.
	ge.set_kamae_req("balance")
	ge._on_counter_changed("8, 6")
	var g2 := ge.to_geometry()
	_check(g2.get("kamae_req", "") == "balance", "kamae_req impostato")
	_check(g2.get("counter", []) == [8, 6], "counter parsato dagli interi")
	ge.queue_free()
