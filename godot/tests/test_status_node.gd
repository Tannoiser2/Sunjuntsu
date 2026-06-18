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

	# ── Carte di STATO: catalogo + arte ──────────────────────────────────────
	if not Status.is_status(Status.WOUND) or CardDB.card(Status.WOUND).get("name", "") != "Ferita":
		print("FAIL: carta-ferita non nel catalogo"); ok = false
	elif CardDB.image_for(Status.BLEED) == "" or CardDB.card(Status.STUN).get("name", "") != "Stordimento":
		print("FAIL: carte di stato senza nome/immagine"); ok = false
	else:
		print("OK: carte di stato nel catalogo con nome+immagine (Ferita/Sanguinante/Stordimento…)")

	# ── Le ferite si espongono come CARTE (per id) ───────────────────────────
	var fc := GameState.Fighter.new()
	fc.wounds = ["wound", "bleed", "deck"]
	fc.add_hobble(1)
	fc.stun = 2
	var ids := fc.status_card_ids()
	var n_wound := ids.count(Status.WOUND)     # "wound" + "deck"
	var n_bleed := ids.count(Status.BLEED)
	var n_stun := ids.count(Status.STUN)
	if n_wound != 2 or n_bleed != 1 or n_stun != 2 or not ids.has(Status.HOBBLE):
		print("FAIL: mappa ferite→carte errata (W%d B%d S%d) %s" % [n_wound, n_bleed, n_stun, str(ids)]); ok = false
	else:
		print("OK: ferite/sanguinanti/stordimenti/azzoppamenti esposti come carte")

	# ── Lo stordimento OCCUPA il limite di mano (pesca/tieni meno carte abilità) ──
	var g := GameState.Fighter.new()
	g.character = "Warrior"; g.hand_limit = 5; g.wound_limit = 8
	g.stun = 2
	g.hand = [119, 119, 119]                       # 3 carte abilità non-core
	var d2 := Duel.new(GameState.new())
	# Gli slot usati = abilità (3) + stordimenti (2) = 5 = limite.
	if d2._hand_used(g) != 5:
		print("FAIL: lo stordimento non conta negli slot di mano (usati=%d)" % d2._hand_used(g)); ok = false
	else:
		print("OK: lo stordimento conta verso il limite di mano (3 abilità + 2 stun = 5)")
	# Scarto in eccesso: con 6 abilità + 2 stun e limite 5, scende a 3 abilità (lo stun non si scarta).
	g.hand = [119, 119, 119, 119, 119, 119]
	while d2._hand_used(g) > g.hand_limit:
		if not d2._discard_one_noncore(g):
			break
	if d2._noncore_in_hand(g) != 3 or g.stun != 2:
		print("FAIL: scarto eccesso errato con stordimento (abilità=%d stun=%d)" % [d2._noncore_in_hand(g), g.stun]); ok = false
	else:
		print("OK: lo stordimento non si scarta; si scartano le abilità in eccesso (→3)")

	print("RISULTATO: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
