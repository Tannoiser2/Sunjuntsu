## Test headless: ciclo di vita dell'azzoppamento (Hobble, regolamento 1.5 p.13).
extends Node

func _ready() -> void:
	var ok := true
	var s := GameState.new()
	var f := GameState.Fighter.new()
	f.character = "Warrior"; f.cell = Vector2i(0,0); f.wound_limit = 5; f.hand_limit = 5
	s.fighters = [f, GameState.Fighter.new()]
	var duel := Duel.new(s)

	# Turno in cui lo subisci: NON riduce l'iniziativa.
	f.add_hobble(1)
	if f.hobble_count() != 0 or duel._hobbled(0, 5) != 5:
		print("FAIL: azzoppamento attivo nel turno in cui è subìto"); ok = false
	else:
		print("OK: nel turno del colpo l'azzoppamento non riduce l'iniziativa")

	# Dopo la fine turno (ruota): diventa attivo, −1 iniziativa.
	f.tick_hobbles()
	if f.hobble_count() != 1 or duel._hobbled(0, 5) != 4:
		print("FAIL: dopo 1 turno non riduce di 1 (sp=%d)" % duel._hobbled(0, 5)); ok = false
	else:
		print("OK: dal turno dopo riduce l'iniziativa di 1")

	# Minimo 1.
	if duel._hobbled(0, 1) != 1:
		print("FAIL: iniziativa sotto 1 (=%d)" % duel._hobbled(0, 1)); ok = false
	else:
		print("OK: iniziativa minima 1")

	# Scade dopo 3 turni attivi (ruota fino a tornare diritta).
	f.tick_hobbles(); f.tick_hobbles(); f.tick_hobbles()
	if not f.hobbles.is_empty() or duel._hobbled(0, 5) != 5:
		print("FAIL: azzoppamento non scaduto (restano %d)" % f.hobbles.size()); ok = false
	else:
		print("OK: azzoppamento scaduto e rimosso")

	# Due azzoppamenti = −2.
	f.add_hobble(2); f.tick_hobbles()
	if duel._hobbled(0, 9) != 7:
		print("FAIL: due azzoppamenti non riducono di 2 (=%d)" % duel._hobbled(0, 9)); ok = false
	else:
		print("OK: due azzoppamenti → −2 iniziativa")

	print("RISULTATO: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
