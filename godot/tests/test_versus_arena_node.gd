## Test d'INTEGRAZIONE 1v1 locale (hot-seat): istanzia la VERA scena Arena in
## modalità versus e pilota il flusso come farebbe la UI (programma G1 → passa il
## dispositivo → programma G2 → risoluzione per iniziativa di ENTRAMBI → nuovo turno).
## Verifica i punti chiave dell'orchestrazione (Arena.gd), non solo il motore.
extends Node

var _awaits: Array = []

func _ready() -> void:
	await _run()

func _play_first_playable(arena, pi: int) -> bool:
	var f = arena.state.fighters[pi]
	for id in f.hand.duplicate():
		arena._on_card_played({"id": id, "name": CardDB.card(id).get("name", "?"), "file": CardDB.image_for(id)})
		if f.planned == id:
			return true
	return false

func _drive_resolution(arena) -> void:
	# Conferma le risoluzioni finché il turno non torna in pianificazione (o game over).
	var guard := 0
	while guard < 60:
		if arena._phase_mode == "instant":
			arena._on_instant_chosen(-1)        # salta le carte istantanee
		elif arena._phase_mode == "resolving":
			arena._confirm_resolution()
		elif arena._phase_mode == "planning" or arena.state.phase == Domain.Phase.GAME_OVER:
			return
		else:
			# fase transitoria ("wait"/"handoff"): un frame e riprova
			await get_tree().process_frame
		guard += 1

func _run() -> void:
	var ok := true
	Domain.game_mode = "versus"
	var arena = preload("res://scenes/Arena.tscn").instantiate()
	add_child(arena)
	await get_tree().process_frame
	await get_tree().process_frame

	# Conta le emissioni await_resolution (deve toccare a ENTRAMBI gli umani).
	arena._duel.await_resolution.connect(func(i): _awaits.append(i))

	# ── Nessuna IA: entrambi umani, entrambi con una mano ──
	if arena._versus != true or arena.state.fighters[0].is_ai or arena.state.fighters[1].is_ai:
		print("FAIL: in versus un combattente è ancora IA"); ok = false
	elif arena.state.fighters[0].hand.is_empty() or arena.state.fighters[1].hand.is_empty():
		print("FAIL: un giocatore non ha la mano"); ok = false
	else:
		print("OK: 1v1 = due umani, entrambi con mano (G1=%d, G2=%d)" % [
			arena.state.fighters[0].hand.size(), arena.state.fighters[1].hand.size()])

	# ── G1 programma → deve scattare l'HANDOFF (passaggio dispositivo) ──
	if arena._phase_mode != "planning" or arena._planning_player != 0:
		print("FAIL: stato iniziale non in pianificazione G1"); ok = false
	var p0 := _play_first_playable(arena, 0)
	if not p0:
		print("FAIL: G1 non riesce a programmare nessuna carta"); ok = false
	elif arena._phase_mode != "handoff":
		print("FAIL: dopo G1 non parte l'handoff (fase=%s)" % arena._phase_mode); ok = false
	elif arena.state.phase != Domain.Phase.PLANNING:
		print("FAIL: la risoluzione è partita prima di G2"); ok = false
	else:
		print("OK: G1 programma (coperta) → handoff, in attesa di G2")

	# ── Conferma handoff → tocca a G2 programmare ──
	arena._confirm_resolution()
	if arena._phase_mode != "planning" or arena._planning_player != 1:
		print("FAIL: l'handoff non passa il turno a G2 (fase=%s, pp=%d)" % [arena._phase_mode, arena._planning_player]); ok = false
	else:
		print("OK: dispositivo passato → tocca al Giocatore 2 programmare")

	# ── G2 programma → parte la RISOLUZIONE interattiva ──
	var p1 := _play_first_playable(arena, 1)
	# Eventuale fase di sostituzione istantanea: salta.
	var sg := 0
	while arena._phase_mode == "instant" and sg < 6:
		arena._on_instant_chosen(-1)
		sg += 1
	if not p1:
		print("FAIL: G2 non riesce a programmare nessuna carta"); ok = false
	elif arena._phase_mode != "resolving":
		print("FAIL: dopo G2 non parte la risoluzione (fase=%s)" % arena._phase_mode); ok = false
	else:
		print("OK: G2 programma → rivelazione e risoluzione per iniziativa")

	# ── Risoluzione: deve toccare a ENTRAMBI gli umani ──
	await _drive_resolution(arena)
	if not (_awaits.has(0) and _awaits.has(1)):
		print("FAIL: la risoluzione non ha coinvolto entrambi (await=%s)" % str(_awaits)); ok = false
	else:
		print("OK: risoluzione interattiva per entrambi i giocatori (await=%s)" % str(_awaits))

	# ── Dopo il turno: torna in pianificazione, di nuovo dal Giocatore 1 ──
	if arena.state.phase == Domain.Phase.GAME_OVER:
		print("OK: il duello è terminato durante il 1° turno (valido)")
	elif arena._phase_mode != "planning" or arena._planning_player != 0:
		print("FAIL: nuovo turno non riparte da G1 (fase=%s, pp=%d)" % [arena._phase_mode, arena._planning_player]); ok = false
	else:
		print("OK: nuovo turno → di nuovo programmazione dal Giocatore 1")

	arena.queue_free()
	print("RISULTATO: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
