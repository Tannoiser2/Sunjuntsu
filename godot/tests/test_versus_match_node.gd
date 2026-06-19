## "Prova" 1v1: gioca una PARTITA COMPLETA hot-seat sulla vera scena Arena fino
## alla sconfitta di un giocatore. Pilota programmazione+handoff e, in risoluzione,
## posiziona l'attaccante in modo che il colpo vada a segno (come farebbe un umano),
## così si esercitano davvero ferite/blocchi/contrattacchi nel contesto 1v1.
extends Node

var _over := false
var _winner := -99

func _ready() -> void:
	await _run()

func _play_first_playable(arena, pi: int) -> bool:
	var f = arena.state.fighters[pi]
	for id in f.hand.duplicate():
		arena._on_card_played({"id": id, "name": CardDB.card(id).get("name", "?"), "file": CardDB.image_for(id)})
		if f.planned == id:
			return true
	return false

## Se la carta in risoluzione di `i` è un attacco, sposta la pedina su un esagono
## da cui il colpo raggiunge l'avversario (simula la scelta del giocatore).
func _position_for_attack(arena, i: int) -> void:
	var f = arena.state.fighters[i]
	var foe = arena.state.fighters[1 - i]
	var c = CardDB.card(f.planned)
	if c.get("type", "") != "attack":
		return
	var g = CardDB.geometry(f.planned)
	var rng = Duel._card_range(c)
	for nb in HexGrid.neighbors(foe.cell):
		if arena.state.fighter_at(nb) != null:
			continue
		for fac in range(6):
			if Duel.attack_v2_cells(nb, fac, g, rng).has(foe.cell):
				f.cell = nb
				f.facing = fac
				return

func _run() -> void:
	var ok := true
	Domain.game_mode = "versus"
	var arena = preload("res://scenes/Arena.tscn").instantiate()
	add_child(arena)
	await get_tree().process_frame
	await get_tree().process_frame
	arena._duel.duel_over.connect(func(w):
		_over = true
		_winner = w)

	var turns := 0
	var guard := 0
	while not _over and guard < 200:
		guard += 1
		if arena._phase_mode != "planning":
			await get_tree().process_frame
			continue
		# Programmazione G1 → handoff → G2
		if not _play_first_playable(arena, 0):
			break
		if arena._phase_mode == "handoff":
			arena._confirm_resolution()
		if _over:
			break
		if not _play_first_playable(arena, 1):
			break
		# RIVELAZIONE: «Avanti» avvia la risoluzione.
		if arena._phase_mode == "reveal":
			arena._confirm_resolution()
		# Risoluzione: salta le istantanee, posiziona per colpire e conferma, per entrambi
		var rg := 0
		while not _over and rg < 24 and arena._phase_mode in ["resolving", "instant", "reveal"]:
			if arena._phase_mode == "instant":
				arena._on_instant_chosen(-1)
			elif arena._phase_mode == "reveal":
				arena._confirm_resolution()
			else:
				_position_for_attack(arena, arena._resolving_index)
				arena._confirm_resolution()
			rg += 1
		turns += 1

	# ── Esito ──
	if not _over:
		print("FAIL: la partita non si è conclusa in %d turni" % turns); ok = false
	else:
		var a = arena.state.fighters[0]
		var b = arena.state.fighters[1]
		var who := "Pareggio" if _winner < 0 else "Giocatore %d (%s)" % [_winner + 1, arena.state.fighters[_winner].character]
		print("OK: partita 1v1 conclusa in %d turni (round %d)" % [turns, arena.state.round_num])
		print("    Vincitore: %s" % who)
		print("    G1 %s: ferite %d/%d, stun %d, mazzo %d, scarti %d" % [
			a.character, a.wounds.size(), a.effective_wound_limit(), a.stun, a.draw_pile.size(), a.discard.size()])
		print("    G2 %s: ferite %d/%d, stun %d, mazzo %d, scarti %d" % [
			b.character, b.wounds.size(), b.effective_wound_limit(), b.stun, b.draw_pile.size(), b.discard.size()])
		# Coerenza: il vincitore NON è sconfitto; il perdente (se non pari) sì.
		if _winner >= 0:
			if arena.state.fighters[_winner].is_defeated():
				print("FAIL: il vincitore risulta sconfitto"); ok = false
			elif not arena.state.fighters[1 - _winner].is_defeated():
				print("FAIL: il perdente non risulta sconfitto"); ok = false
			else:
				print("OK: stato coerente (vincitore vivo, perdente sconfitto)")

	arena.queue_free()
	print("RISULTATO: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
