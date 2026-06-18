## Test headless: 1v1 locale (hot-seat) a livello di MOTORE.
## Verifica che con DUE combattenti umani (nessuna IA) il turno si programmi e
## risolva correttamente, sia in modo sincrono sia in modo interattivo
## (programma → rivela → risolvi per iniziativa).
extends Node

func _mk(ch: String) -> GameState.Fighter:
	var f := GameState.Fighter.new()
	f.character = ch
	f.stance = Domain.Stance.NEUTRAL
	f.cell = Vector2i(0, 0)
	f.facing = 0
	f.wound_limit = 8
	f.hand_limit = 5
	f.is_ai = false   # 1v1: entrambi umani
	return f

func _ready() -> void:
	var ok := true

	# ── Programmazione a due umani: nessuno auto-pianifica, servono ENTRAMBE le carte ──
	var s := GameState.new()
	var p1 := _mk("Warrior"); p1.cell = Vector2i(0, 0); p1.facing = 0; p1.hand = [64]   # Testata
	var p2 := _mk("Ronin"); p2.cell = HexGrid.DIRS[0]; p2.facing = 3; p2.hand = [64]
	s.fighters = [p1, p2]
	s.phase = Domain.Phase.PLANNING
	var d := Duel.new(s)
	d.interactive = false
	if not d.plan_card(0, 64):
		print("FAIL: G1 non riesce a programmare"); ok = false
	# Dopo che SOLO G1 ha programmato, il turno NON deve risolversi (manca G2).
	if s.phase != Domain.Phase.PLANNING:
		print("FAIL: il turno è partito prima che G2 programmasse (fase %d)" % s.phase); ok = false
	else:
		print("OK: con un solo giocatore programmato il turno resta in pianificazione")
	# Ora G2 programma → risoluzione sincrona completa.
	d.plan_card(1, 64)
	if s.phase != Domain.Phase.PLANNING:
		# dopo _cleanup torna a PLANNING per il turno successivo
		print("FAIL: dopo la risoluzione la fase non è tornata a pianificazione (%d)" % s.phase); ok = false
	else:
		print("OK: programmate entrambe → turno risolto e nuovo turno avviato")

	# ── Risoluzione INTERATTIVA a due umani: await_resolution per ENTRAMBI ──
	var s2 := GameState.new()
	var a := _mk("Warrior"); a.cell = Vector2i(0, 0); a.facing = 0; a.hand = [64]
	var b := _mk("Ronin"); b.cell = HexGrid.DIRS[0]; b.facing = 3; b.hand = [64]
	s2.fighters = [a, b]
	s2.phase = Domain.Phase.PLANNING
	var d2 := Duel.new(s2)
	d2.interactive = true
	var resolved_for: Array = []
	d2.await_resolution.connect(func(i):
		resolved_for.append(i)
		# La "scena" conferma subito la risoluzione del combattente i.
		d2.resolve_current())
	d2.plan_card(0, 64)
	d2.plan_card(1, 64)   # → begin_resolution() → await_resolution per ordine d'iniziativa
	if resolved_for.size() != 2 or not (resolved_for.has(0) and resolved_for.has(1)):
		print("FAIL: la risoluzione interattiva non ha coinvolto entrambi gli umani (%s)" % str(resolved_for)); ok = false
	else:
		print("OK: risoluzione interattiva → await_resolution emesso per entrambi (%s)" % str(resolved_for))

	# ── In 1v1 i combattenti hanno una MANO (non rivelano la cima come l'IA) ──
	var s3 := GameState.new()
	var c1 := _mk("Warrior"); c1.draw_pile = [64, 64, 64, 64, 64, 64, 64, 64]
	var c2 := _mk("Ronin"); c2.draw_pile = [64, 64, 64, 64, 64, 64, 64, 64]
	s3.fighters = [c1, c2]
	var d3 := Duel.new(s3)
	d3.start()
	if c1.hand.is_empty() or c2.hand.is_empty():
		print("FAIL: in 1v1 un combattente non ha pescato la mano"); ok = false
	else:
		print("OK: in 1v1 entrambi hanno una mano (G1=%d, G2=%d carte)" % [c1.hand.size(), c2.hand.size()])

	print("RISULTATO: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
