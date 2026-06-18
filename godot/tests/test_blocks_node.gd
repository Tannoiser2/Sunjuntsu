## Test headless (scena): blocco fedele al regolamento 1.5 (p.11):
## (1) blocco nella cella dell'attaccante, oppure (2) ogni percorso più breve
## attaccante→difensore passa per un blocco. Terreno = blocco a ogni velocità.
extends Node


func _make_fighter(char: String, stance: int) -> GameState.Fighter:
	var f := GameState.Fighter.new()
	f.character = char
	f.stance = stance
	f.cell = Vector2i(0, 0)
	f.facing = 0
	f.wound_limit = 5
	f.hand_limit = 5
	return f


func _ready() -> void:
	var ok := true

	assert(Domain.initiative_options("9,8,7,6") == [9, 8, 7, 6])
	assert(Domain.initiative_options("5-2") == [2, 3, 4, 5])
	assert(Domain.initiative_options("=") == [])
	print("initiative_options OK")

	var s := GameState.new()
	var a := _make_fighter("Warrior", Domain.Stance.NEUTRAL)
	var d := _make_fighter("Ronin", Domain.Stance.NEUTRAL)
	s.fighters = [a, d]
	var duel := Duel.new(s)

	# ── Helper: percorso più breve ────────────────────────────────────────────
	a.cell = Vector2i(0, 0)
	var two := HexGrid.DIRS[0] * 2
	if not duel._has_clean_path(Vector2i(0, 0), two, {}):
		print("FAIL: percorso libero non trovato (nessun blocco)"); ok = false
	else:
		print("OK: percorso libero senza blocchi")
	if duel._has_clean_path(Vector2i(0, 0), two, {HexGrid.DIRS[0]: true}):
		print("FAIL: percorso 'libero' nonostante blocco sull'unico passaggio"); ok = false
	else:
		print("OK: blocco sull'unico passaggio → nessun percorso libero")

	# ── _attack_blocked con TERRENO sul percorso (cond. 2) ────────────────────
	a.cell = Vector2i(0, 0)
	d.cell = two            # distanza 2 in linea retta
	d.facing = 3
	duel._block_ready = {}
	duel._fizzled = {}
	s.blocked_cells = {}
	if duel._attack_blocked(0, 1, 5, {}):
		print("FAIL: attacco bloccato senza alcun blocco"); ok = false
	else:
		print("OK: nessun blocco → attacco non parato")
	s.blocked_cells = {HexGrid.DIRS[0]: true}
	if not duel._attack_blocked(0, 1, 5, {}):
		print("FAIL: terreno sul percorso non blocca"); ok = false
	else:
		print("OK: terreno sul percorso → attacco parato (cond. 2)")
	s.blocked_cells = {}

	# ── Blocco da difesa che COPRE la cella dell'attaccante (cond. 1) ──────────
	# Attaccante in (0,0) guardando avanti; difensore davanti che guarda l'attaccante.
	var def_id := 63                       # Blocco Cinereo: blocca il fronte (d=0)
	var def_opts: Array = Domain.initiative_options(str(CardDB.card(def_id).get("initiative", "")))
	# Scegli un attacco che colpisca la cella del difensore e con velocità nel range difesa.
	a.cell = Vector2i(0, 0); a.facing = 0
	d.cell = HexGrid.DIRS[0]; d.facing = 3   # guarda verso l'attaccante (dir 3)
	var atk_id := -1
	var atk_speed := -1
	for cid in CardDB.by_id.keys():
		var c := CardDB.card(cid)
		if c.get("type", "") != "attack":
			continue
		var sp := Domain.pick_initiative(str(c.get("initiative", "")), true)
		if not def_opts.has(sp):
			continue
		var cells := Duel.attack_v2_cells(a.cell, a.facing, CardDB.geometry(cid), 1)
		if cells.has(d.cell):
			atk_id = cid; atk_speed = sp; break
	print("Attacco scelto: #%d velocità %d (difesa #%d opz %s)" % [atk_id, atk_speed, def_id, str(def_opts)])
	if atk_id == -1:
		print("FAIL: nessun attacco adatto trovato"); ok = false
	else:
		a.planned = atk_id
		d.planned = def_id
		duel._resolve_chosen_speeds({})
		duel._fizzled = {}
		duel._block_ready = {1: int(duel._chosen.get(1, -1))}
		print("chosen att=%d dif=%d" % [int(duel._chosen[0]), int(duel._chosen[1])])
		# Difensore guarda l'attaccante → la cella (0,0) è coperta dal blocco frontale.
		d.wounds.clear()
		var log: Array = []
		duel._resolve_card(0, duel._block_ready, log)
		if d.wounds.size() != 0:
			print("FAIL: la difesa copriva l'attaccante ma non ha parato"); ok = false
		else:
			print("OK: difesa che copre la cella dell'attaccante → parato")
		# Ora il difensore guarda altrove (blocco NON copre l'attaccante) → ferita.
		d.facing = 0
		d.wounds.clear()
		duel._block_ready = {1: int(duel._chosen.get(1, -1))}
		var log2: Array = []
		duel._resolve_card(0, duel._block_ready, log2)
		if d.wounds.size() == 0:
			print("FAIL: blocco non copre l'attaccante ma ha comunque parato"); ok = false
		else:
			print("OK: blocco che non copre l'attaccante → attacco a segno")

	print("RISULTATO: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
