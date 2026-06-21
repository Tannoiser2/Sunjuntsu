## Test headless di GeometryEditor (modello a WIDGET): round-trip dello Schema v2,
## mutatori, fedeltà del movimento, widget componibili e varianti d'attacco.
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
	var cells: Array = []
	if g.has("attack"):
		cells = g["attack"].get("cells", [])
	elif g.has("attacks") and not (g["attacks"] as Array).is_empty():
		cells = g["attacks"][0].get("cells", [])
	var s := {}
	for c in cells:
		var ax: Vector2i
		if c.has("q"):
			ax = Vector2i(int(c.get("q")), int(c.get("r")))
		else:
			ax = HexGrid.DIRS[int(c.get("d")) % 6] * maxi(1, int(c.get("k")))
		var w = c.get("w")
		if typeof(w) != TYPE_STRING:
			w = int(w)
		s["%d_%d" % [ax.x, ax.y]] = w
	return s


func _types(ge: GeometryEditor) -> Array:
	var out := []
	for w in ge._widgets:
		out.append(str(w["type"]))
	return out


func _cell_label(cw: Dictionary, ax: Vector2i) -> String:
	if cw["defence"].has(ax):
		return "shield"
	if cw["attack"].has(ax):
		var w = cw["attack"][ax]
		if typeof(w) == TYPE_STRING:
			return str(w)
		return "w2" if int(w) == 2 else "w1"
	return "empty"


func _count_type(ge: GeometryEditor, type: String) -> int:
	var n := 0
	for w in ge._widgets:
		if w["type"] == type:
			n += 1
	return n


func _test_nesting() -> void:
	print("[annidamento + condizioni + drag]")
	var ge := GeometryEditor.new()
	add_child(ge)
	ge.load_geometry("attack", {})
	# Costruisci: Iniziativa(2) { combat(cond=balance), OPPURE { movement } }.
	var init_w := ge._new_widget("initiative")
	init_w["value"] = 2
	var combat := ge._new_widget("combat")
	combat["cond"] = "balance"
	combat["attack"][Vector2i(1, 0)] = 1
	var oppure := ge._new_widget("oppure")
	var mv := ge._new_widget("movement")
	mv["atoms"].append(ge._norm_atom({"t": "step", "dir": 0, "n": 1, "opt": false}))
	oppure["children"].append(mv)
	init_w["children"].append(combat)
	init_w["children"].append(oppure)
	ge._widgets = [init_w]

	# Serializza: il motore vede le foglie appiattite; il layout è ad albero.
	var g := ge.to_geometry()
	_check(g.has("attacks"), "foglia combat annidata (gated) appiattita per il motore")
	_check(g.get("move", {}).get("opts", []).size() == 1, "movimento in OPPURE → 1 opzione")
	_check(g["layout"][0]["type"] == "initiative", "layout ad albero serializzato")
	_check(int(g["layout"][0]["value"]) == 2, "valore iniziativa serializzato")

	# Round-trip: l'albero si ricostruisce identico.
	ge.load_geometry("attack", g)
	_check(ge._widgets.size() == 1 and ge._widgets[0]["type"] == "initiative", "iniziativa ricaricata")
	var ch: Array = ge._widgets[0]["children"]
	_check(ch.size() == 2, "due figli ricaricati")
	_check(ch[0]["type"] == "combat" and str(ch[0]["cond"]) == "balance", "condizione kamae preservata")
	_check(ch[1]["type"] == "oppure" and (ch[1]["children"] as Array).size() == 1, "OPPURE con un figlio")

	# Drag: niente cicli (un contenitore non entra in sé stesso).
	_check(not ge._can_move(ge._widgets[0], ch), "contenitore non spostabile nei propri figli")
	# Sposta la foglia movimento fuori, accanto all'iniziativa (in fondo al top).
	ge._move_to_end(ch[1]["children"][0], ch[1]["children"], ge._widgets)
	_check(ge._widgets.size() == 2 and ge._widgets[1]["type"] == "movement", "drag sposta il widget tra liste")
	ge.queue_free()


func _ready() -> void:
	_test_roundtrip()
	_test_mutators()
	_test_move_fidelity()
	_test_widgets()
	_test_attack_variants()
	_test_effects()
	_test_nesting()
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
	var a0 := _atk_set(orig)
	var a1 := _atk_set(out)
	_check(a0 == a1, "celle d'attacco invariate dopo round-trip (%d celle)" % a0.size())
	_check(out.get("type", "") == "attack", "tipo conservato")
	_check(str(out.get("kamae_req", "")) == str(orig.get("kamae_req", "")), "kamae_req conservato")
	var o0: int = orig.get("move", {}).get("opts", []).size()
	var o1: int = out.get("move", {}).get("opts", []).size()
	_check(o0 == o1, "numero di opzioni di movimento invariato (%d)" % o0)
	ge.load_geometry("attack", out)
	_check(_atk_set(ge.to_geometry()) == a1, "idempotente al secondo round-trip")
	ge.queue_free()


func _test_mutators() -> void:
	print("[mutatori da zero]")
	var ge := GeometryEditor.new()
	add_child(ge)
	ge.load_geometry("attack", {})
	_check(_types(ge) == ["combat"], "carta nuova: un widget Combattimento")
	_check(ge.to_geometry().get("attack", null) == null, "geometria vuota: nessun attacco")

	var cw := ge._first_combat()
	ge.set_attack_cell(0, 1, 2)
	ge.set_attack_cell(1, 1, "exec")
	ge.set_defence_cell(3, 1, 1)
	var g := ge.to_geometry()
	_check(_atk_set(g) == {"0_1": 2, "1_1": "exec"}, "celle d'attacco impostate")
	_check(g.get("defence", {}).get("cells", []).size() == 1, "cella di difesa impostata")
	ge.clear_cell(0, 1)
	_check(_atk_set(ge.to_geometry()) == {"1_1": "exec"}, "clear_cell rimuove la cella")

	# Clic-ciclo su un esagono.
	var ax := Vector2i(2, 0)
	var seq := []
	for _i in range(7):
		ge._cycle_cell(cw, ax)
		seq.append(_cell_label(cw, ax))
	_check(seq == ["w1", "w2", "exec", "bleed", "shield", "empty", "w1"],
		"clic cicla gli stati dell'esagono (%s)" % str(seq))
	ge._clear_cell(cw, ax)

	# Movimento.
	var oi := ge.add_opt()
	ge.add_move_atom(oi, {"t": "step", "dir": 0, "n": 1, "opt": false})
	ge.add_move_atom(oi, {"t": "rot", "n": 2, "opt": true})
	var atoms: Array = ge.to_geometry().get("move", {}).get("opts", [])[0].get("atoms", [])
	_check(atoms.size() == 2, "due atomi nella sequenza")
	_check(atoms[0].get("t") == "step" and atoms[0].has("dir"), "passo serializza la direzione")
	_check(atoms[1].get("t") == "rot" and not atoms[1].has("dir"), "rotazione senza direzione")
	_check(atoms[1].get("opt") == true, "atomo opzionale marcato")

	# Kamae e counter (widget).
	ge.set_kamae_req("balance")
	ge._widgets.append({"type": "counter", "values": [8, 6]})
	var g2 := ge.to_geometry()
	_check(g2.get("kamae_req", "") == "balance", "kamae_req impostato")
	_check(g2.get("counter", []) == [8, 6], "counter serializzato dal widget")
	ge.queue_free()


func _test_move_fidelity() -> void:
	print("[movimento: fedeltà dirs/kamae/focus/-1]")
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

	var ge2 := GeometryEditor.new()
	add_child(ge2)
	ge2.load_geometry("attack", CardDB.geometry(60))
	_check(ge2.to_geometry().get("move", {}).get("opts", []).size() == 2, "#60: due alternative OPPURE preservate")
	ge2.queue_free()


func _test_widgets() -> void:
	print("[widget componibili]")
	var ge := GeometryEditor.new()
	add_child(ge)
	ge.load_geometry("attack", {})
	_check(_types(ge) == ["combat"], "carta nuova: solo Combattimento")
	# Aggiungi un widget vuoto e trasformalo in Movimento.
	ge._widgets.append(ge._new_widget(""))
	ge._set_widget_type(ge._widgets.size() - 1, "movement")
	_check(_types(ge) == ["combat", "movement"], "widget aggiunto e trasformato in Movimento")
	# Più widget dello stesso tipo (Combattimento) sono ammessi.
	ge._widgets.append(ge._new_widget("combat"))
	_check(_count_type(ge, "combat") == 2, "due widget Combattimento ammessi")
	# Singleton: un secondo Kamae viene rifiutato.
	ge._widgets.append(ge._new_widget("kamae"))
	ge._widgets.append(ge._new_widget(""))
	ge._set_widget_type(ge._widgets.size() - 1, "kamae")
	_check(ge._widgets[ge._widgets.size() - 1]["type"] == "", "secondo Kamae rifiutato (singleton)")
	# Sposta su.
	var n := ge._widgets.size()
	ge._move_widget(1, -1)
	_check(ge._widgets[0]["type"] == "movement" and ge._widgets.size() == n, "«su» scambia i widget")
	ge.queue_free()

	# Persistenza del layout in caricamento.
	var ge2 := GeometryEditor.new()
	add_child(ge2)
	ge2.load_geometry("attack", {"layout": ["note", "combat"],
		"attack": {"cells": [{"q": 1, "r": 0, "w": 1}]}, "note": "x"})
	_check(_types(ge2) == ["note", "combat"], "layout salvato rispettato (%s)" % str(_types(ge2)))
	ge2.queue_free()


func _test_attack_variants() -> void:
	print("[varianti d'attacco gated da kamae]")
	var ge := GeometryEditor.new()
	add_child(ge)
	ge.load_geometry("attack", {})
	var c0 := ge._first_combat()
	c0["cond"] = "aggression"
	c0["attack"][Vector2i(1, 0)] = 2
	ge._widgets.append({"type": "combat", "cond": "balance",
		"attack": {Vector2i(1, -1): 1}, "defence": {}})
	var g := ge.to_geometry()
	_check(g.has("attacks") and (g["attacks"] as Array).size() == 2, "due varianti → schema `attacks`")
	_check(str(g["attacks"][0].get("kamae", "")) == "aggression", "kamae della prima variante serializzato")
	# Round-trip: ricarica → due widget Combattimento gated.
	ge.load_geometry("attack", g)
	_check(_count_type(ge, "combat") == 2, "due widget Combattimento dopo il round-trip")
	var kamae_set := {}
	for w in ge._widgets:
		if w["type"] == "combat":
			kamae_set[str(w["cond"])] = true
	_check(kamae_set.has("aggression") and kamae_set.has("balance"), "gate kamae preservati per widget")
	ge.queue_free()


func _test_effects() -> void:
	print("[effetti]")
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

	var ge2 := GeometryEditor.new()
	add_child(ge2)
	ge2.load_geometry("attack", {})
	ge2.add_effect({"do": "push", "n": 1, "when": "on_hit"})
	ge2.add_effect({"do": ""})   # verbo vuoto: scartato
	var eff: Array = ge2.to_geometry().get("effects", [])
	_check(eff.size() == 1, "effetto senza verbo scartato")
	_check(eff[0].get("do") == "push" and eff[0].get("when") == "on_hit", "effetto aggiunto serializzato")
	_check(not eff[0].has("kamae") and not eff[0].has("focus_cost"), "campi non impostati omessi")
	ge2.queue_free()
