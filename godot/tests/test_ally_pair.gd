## Test headless: coppia alleata Ashigaru+Hachikō (§3.24/§3.25) — 1 umano
## (team 0) vs 2 IA alleate (team 1). Copre la primitiva team/alleato, il
## targeting per cella con più nemici, l'atomo di movimento "toward", il gate
## di adiacenza sintetico e un turno completo a 3 pedine senza inceppi.
extends Node

var _fail := 0

func _ck(c: bool, m: String) -> void:
	print(("  ok: " if c else "  FAIL: ") + m)
	if not c: _fail += 1


func _mk(ch: String, team: int, cell: Vector2i) -> GameState.Fighter:
	var f := GameState.Fighter.new()
	f.character = ch; f.team = team; f.cell = cell; f.facing = 0
	f.wound_limit = 8; f.hand_limit = 5
	return f


func _ready() -> void:
	_test_team_primitive()
	_test_cell_targeting()
	_test_toward_atom()
	_test_adjacency_gate()
	_test_full_turn_smoke()
	_test_menu_pairing()
	print("RISULTATO: ", "PASS" if _fail == 0 else "FAIL (%d)" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


## 1) opponent_of/ally_of con 3 combattenti: l'umano trova il nemico più
## vicino, i due alleati IA si trovano a vicenda, un alleato IA trova sempre
## l'umano (mai ambiguo anche con 2 nemici sul suo stesso team... anzi qui è
## l'umano ad avere 2 nemici, l'IA ne ha sempre e solo 1).
func _test_team_primitive() -> void:
	var s := GameState.new()
	var human := _mk("Warrior", 0, Vector2i(0, 0))
	var ia1 := _mk("Ashigaru", 1, Vector2i(2, 0))     # dist 2 dall'umano
	var ia2 := _mk("Hachiko", 1, Vector2i(5, 0))      # dist 5 dall'umano
	s.fighters = [human, ia1, ia2]
	_ck(s.opponent_of(human) == ia1, "opponent_of(umano) → IA più vicina")
	_ck(s.opponent_of(ia1) == human, "opponent_of(ia1) → sempre l'umano")
	_ck(s.opponent_of(ia2) == human, "opponent_of(ia2) → sempre l'umano")
	_ck(s.ally_of(ia1) == ia2, "ally_of(ia1) → ia2")
	_ck(s.ally_of(ia2) == ia1, "ally_of(ia2) → ia1")
	_ck(s.ally_of(human) == null, "ally_of(umano) → null (nessun alleato)")


## 2) Attacco per cella con 2 nemici possibili: solo chi sta fisicamente nella
## cella colpita subisce danno.
func _test_cell_targeting() -> void:
	var s := GameState.new()
	var human := _mk("Warrior", 0, Vector2i(0, 0))
	human.facing = 0
	var near_ia := _mk("Ashigaru", 1, HexGrid.DIRS[0])          # nella cella colpita
	var far_ia := _mk("Hachiko", 1, HexGrid.DIRS[0] * 3)        # fuori portata
	s.fighters = [human, near_ia, far_ia]
	var d := Duel.new(s)
	var geom := {"type": "attack", "attack": {"cells": [{"d": 0, "k": 1, "w": 1}]}}
	var cells: Dictionary = d.attack_v2_cells(human.cell, human.facing, geom, 1, human.stance)
	var hit_idx := d._cell_target_index(0, cells)
	_ck(hit_idx == 1, "_cell_target_index → l'IA nella cella colpita (idx 1)")
	# Nessuno dei due nella cella colpita: -1.
	near_ia.cell = Vector2i(9, 9)
	var cells2: Dictionary = d.attack_v2_cells(human.cell, human.facing, geom, 1, human.stance)
	_ck(d._cell_target_index(0, cells2) == -1, "_cell_target_index → -1 se nessun nemico è colpito")


## 3) Atomo di movimento "toward": si avvicina di 2 esagoni al bersaglio nel
## context (nessun vero pathfinding, solo passo greedy — vedi Move.gd).
func _test_toward_atom() -> void:
	var start := Vector2i(0, 0)
	var target := Vector2i(4, 0)
	var spec := {"opts": [{"ordered": true, "atoms": [
		{"t": "toward", "target": "foe", "n": 2, "opt": false}]}]}
	var context := {"foe_cell": target}
	var states: Array = Move.reachable_states(start, 0, spec, func(_c): return false, "", {}, context)
	_ck(states.size() == 1, "toward produce un solo stato risultante")
	if states.size() == 1:
		var s: Vector3i = states[0]
		var d0 := HexGrid.distance(start, target)
		var d1 := HexGrid.distance(Vector2i(s.x, s.y), target)
		_ck(d1 == d0 - 2, "toward n:2 si avvicina di 2 esagoni (dist %d → %d)" % [d0, d1])
	# Senza foe_cell nel context, l'atomo obbligatorio non produce stati (come
	# un passo bloccato) — il chiamante lo intercetta come "carta non giocabile".
	var states_no_ctx: Array = Move.reachable_states(start, 0, spec, func(_c): return false)
	_ck(states_no_ctx.is_empty(), "toward senza context → nessuno stato (atomo obbligatorio bloccato)")


## 4) Gate sintetico "adiacente_alleato" (#254 Bravo Cane): l'effetto scatta
## solo se l'alleato è a distanza 1.
func _test_adjacency_gate() -> void:
	var s := GameState.new()
	var f := _mk("Hachiko", 1, Vector2i(0, 0))
	var ally_near := _mk("Ashigaru", 1, HexGrid.DIRS[0])   # adiacente
	s.fighters = [f, ally_near]
	var d := Duel.new(s)
	var geom := {"effects": [{"do": "focus", "n": 1, "state": "adiacente_alleato"}]}
	f.focus = 0
	d._apply_effects(0, -1, geom, "always", [])
	_ck(f.focus == 1, "focus concesso quando l'alleato è adiacente (dist 1)")
	ally_near.cell = Vector2i(5, 5)   # ora lontano
	f.focus = 0
	d._apply_effects(0, -1, geom, "always", [])
	_ck(f.focus == 0, "focus NON concesso quando l'alleato non è adiacente")


## 5) Smoke test: turno completo a 3 pedine (1 umano + 2 IA alleate) senza
## inceppi, adattando il loop di test_multi_node.gd. NOTA: le carte Solitario
## di Ashigaru/Hachikō non hanno ancora geometria trascritta (gap noto,
## indipendente da questa feature — solo Ronin/Guerriero/Ninja ce l'hanno
## oggi), quindi le due IA rivelano perlopiù carte "vuote" (nessun move/
## attack): il test verifica comunque che l'impalcatura a 3 pedine (spawn,
## opponent_of/ally_of, ordine d'iniziativa, targeting per cella) non si
## blocchi, non che le IA colpiscano davvero l'umano.
func _test_full_turn_smoke() -> void:
	var s := GameState.new()
	var human := _mk("Warrior", 0, Vector2i(-3, 1))
	var ia1 := _mk("Ashigaru", 1, Vector2i(3, -1))
	var ia2 := _mk("Hachiko", 1, Vector2i(2, -2))
	human.is_ai = false; ia1.is_ai = true; ia2.is_ai = true
	human.draw_pile = CardDB.draw_pile_for("warrior"); human.draw_pile.shuffle()
	ia1.draw_pile = CardDB.solo_deck_for("ashigaru"); ia1.draw_pile.shuffle()
	ia2.draw_pile = CardDB.solo_deck_for("hachiko"); ia2.draw_pile.shuffle()
	s.fighters = [human, ia1, ia2]
	var duel := Duel.new(s); duel.interactive = true
	var awaits := 0
	var over := [false, -1]
	duel.await_instant_replace.connect(func(i, _o): duel.apply_instant_replace(i, -1))
	duel.await_instant_play.connect(func(i, _o): duel.apply_instant_play(i, -1))
	duel.await_resolution.connect(func(i):
		awaits += 1
		if awaits > 500: return
		var f: GameState.Fighter = s.fighters[i]
		if f.is_ai:
			var foe := s.opponent_of(f)
			if foe != null:
				var dest := AI.move_target(s, f)
				if dest != f.cell and not s.is_blocked(dest): f.cell = dest
				f.facing = AI.facing_toward(f.cell, foe.cell)
		duel.resolve_current()
		while duel.has_pending_split():
			duel.resolve_split_now())
	duel.duel_over.connect(func(w): over[0] = true; over[1] = w)
	duel.start()
	var turns := 0
	var ok := true
	while not over[0] and turns < 40:
		if s.phase != Domain.Phase.PLANNING:
			ok = false; break
		var played := false
		for cid in human.hand.duplicate():
			if Duel.playable(human, cid):
				played = duel.plan_card(0, cid)
				if played: break
		if not played:
			break
		turns += 1
	_ck(ok, "fase resta PLANNING tra un turno e l'altro (nessun blocco)")
	_ck(awaits <= 500, "loop di risoluzione non fuori controllo (%d await)" % awaits)
	_ck(turns >= 5 or over[0], "progredito (%d turni, over=%s)" % [turns, over[0]])
	if over[0]:
		_ck(over[1] == -1 or over[1] >= 0, "vincitore valido a fine duello (%s)" % over[1])


## 6) Menu: selezionare Ashigaru/Hachikō come avversario in Solitario
## aggiunge automaticamente il partner (3 personaggi totali). `Domain.
## selected_chars` è impostato SINCRONAMENTE prima del cambio scena (che è
## solo accodato/deferred): le asserzioni sotto sono valide a prescindere da
## cosa succeda dopo — get_tree().quit() a fine _ready() previene comunque
## che Arena.tscn arrivi mai a caricarsi in questo test.
func _test_menu_pairing() -> void:
	var m = load("res://scenes/Menu.tscn").instantiate()
	add_child(m)
	m._pending_mode = "solo"
	m._picked = ["Warrior"]   # P1 già scelto
	m._on_char_picked("Ashigaru")
	_ck(Domain.selected_chars.size() == 3, "3 personaggi selezionati dopo aver scelto Ashigaru")
	_ck(Domain.selected_chars == ["Warrior", "Ashigaru", "Hachiko"], "coppia auto-aggiunta corretta")
	# Un avversario normale (non in coppia) finalizza ancora a 2.
	m._pending_mode = "solo"
	m._picked = ["Warrior"]
	m._on_char_picked("Ronin")
	_ck(Domain.selected_chars.size() == 2, "avversario normale finalizza ancora a 2")
	m.queue_free()
