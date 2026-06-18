## Test headless (scena): blocco per aggancio di velocità d'iniziativa.
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

	var atk_id := -1
	var atk_speed := -1
	for cid in CardDB.by_id.keys():
		var c := CardDB.card(cid)
		if c.get("type", "") == "attack":
			var sp := Domain.pick_initiative(str(c.get("initiative", "")), true)
			if sp >= 6 and sp <= 9:
				atk_id = cid
				atk_speed = sp
				break
	print("Attacco scelto: #%d velocità %d" % [atk_id, atk_speed])

	var def_id := 63
	var def_opts: Array = Domain.initiative_options(str(CardDB.card(def_id).get("initiative", "")))
	print("Difesa #%d opzioni %s" % [def_id, str(def_opts)])
	if atk_id == -1 or not def_opts.has(atk_speed):
		print("Setup non valido per il test di aggancio")
		ok = false
	else:
		var s := GameState.new()
		var a := _make_fighter("Warrior", Domain.Stance.NEUTRAL)
		var d := _make_fighter("Ronin", Domain.Stance.NEUTRAL)
		a.cell = Vector2i(0, 0); a.facing = 0
		d.cell = HexGrid.DIRS[0]
		s.fighters = [a, d]
		var duel := Duel.new(s)
		a.planned = atk_id
		d.planned = def_id
		var log: Array = []
		duel._resolve_chosen_speeds({})
		print("chosen attaccante=%d difensore=%d" % [int(duel._chosen[0]), int(duel._chosen[1])])
		if int(duel._chosen[1]) != atk_speed:
			print("FAIL: la difesa non ha agganciato la velocità dell'attacco")
			ok = false
		else:
			print("OK: difesa aggancia velocità %d" % atk_speed)
		var wounds_before := d.wounds.size()
		var block_ready := {1: int(duel._chosen[1])}
		duel._resolve_card(0, block_ready, log)
		if d.wounds.size() != wounds_before:
			print("FAIL: l'attacco ha inflitto ferite nonostante il blocco")
			ok = false
		else:
			print("OK: attacco parato, nessuna ferita")
		# Contro-prova: difesa che NON aggancia (velocità diversa) → ferita.
		d.wounds.clear()
		var block_miss := {1: atk_speed - 100}
		var log2: Array = []
		duel._resolve_card(0, block_miss, log2)
		if d.wounds.size() == 0:
			print("FAIL: l'attacco non ha colpito pur senza blocco valido")
			ok = false
		else:
			print("OK: senza aggancio l'attacco infligge ferite")
		for line in log:
			print("  log: ", line)

	print("RISULTATO: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
