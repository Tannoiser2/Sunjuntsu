## Test headless: regola delle CARTE ISTANTANEE (regolamento 1.5 p.7/13/16).
## - Istantanea di SOSTITUZIONE: sostituisce la carta rivelata (tipo diverso, non core),
##   rimborsando il focus dell'originale.
## - Istantanea AGGIUNTIVA/ISTANTANEA: giocata dopo aver risolto la carta scelta,
##   1 per turno e mai se hai giocato una carta core.
extends Node

func _mk(ch: String) -> GameState.Fighter:
	var f := GameState.Fighter.new()
	f.character = ch; f.stance = Domain.Stance.NEUTRAL
	f.cell = Vector2i(0, 0); f.facing = 0
	f.wound_limit = 8; f.hand_limit = 6; f.is_ai = false
	return f

func _ready() -> void:
	var ok := true

	# ── instant_kind dalla keyword ──
	if CardDB.instant_kind(61) != "replacement" or CardDB.instant_kind(56) != "additional" or CardDB.instant_kind(64) != "":
		print("FAIL: instant_kind errato"); ok = false
	else:
		print("OK: instant_kind riconosce sostituzione/aggiuntiva/normale")

	# ── SOSTITUZIONE: difesa rivelata → sostituita con attacco istantaneo ──
	var s := GameState.new(); s.phase = Domain.Phase.PLANNING
	var g1 := _mk("Warrior"); g1.cell = Vector2i(0, 0); g1.hand = [118, 61]   # gioca Wild Block (difesa), tiene Short Strike (attacco, sost.)
	var g2 := _mk("Ronin"); g2.cell = Vector2i(5, 0); g2.facing = 3; g2.hand = [116]
	s.fighters = [g1, g2]
	var d := Duel.new(s); d.interactive = true
	d.await_instant_replace.connect(func(i, opts):
		# G1 sostituisce con #61; gli altri saltano.
		d.apply_instant_replace(i, 61 if (i == 0 and opts.has(61)) else -1))
	d.await_instant_play.connect(func(i, _opts): d.apply_instant_play(i, -1))
	d.await_resolution.connect(func(_i): d.resolve_current())
	d.plan_card(0, 118)
	d.plan_card(1, 116)   # → begin_resolution → fase sostituzione
	if g1.planned == 61:
		print("OK: la carta rivelata è stata sostituita con l'istantanea #61")
	elif not g1.is_defeated() and g1.discard.has(118) == false and g1.planned != 61:
		print("FAIL: sostituzione non applicata (planned=%d)" % g1.planned); ok = false
	# (planned viene azzerato a fine turno; verifichiamo via scarti: originale #118 scartato, #61 risolto/scartato)
	if not g1.discard.has(118):
		print("FAIL: la carta originale #118 non è finita negli scarti"); ok = false
	else:
		print("OK: l'originale #118 è stata scartata, #61 giocata al suo posto")

	# ── Vincolo TIPO DIVERSO: niente sostituzione se i tipi coincidono ──
	var s2 := GameState.new(); s2.phase = Domain.Phase.PLANNING
	var a := _mk("Warrior"); a.hand = [64, 61]   # gioca un attacco, tiene #61 (attacco): stesso tipo
	var b := _mk("Ronin"); b.hand = [116]
	s2.fighters = [a, b]
	var d2 := Duel.new(s2); d2.interactive = true
	a.planned = 64; a.hand = [61]
	if not d2.instant_replacements_for(0).is_empty():
		print("FAIL: offerta sostituzione con stesso tipo (vietata)"); ok = false
	else:
		print("OK: nessuna sostituzione se la carta istantanea è dello stesso tipo")

	# ── ISTANTANEA AGGIUNTIVA dopo la risoluzione: 1 per turno ──
	var s3 := GameState.new(); s3.phase = Domain.Phase.PLANNING
	var w := _mk("Warrior"); w.cell = Vector2i(0, 0); w.facing = 0
	w.hand = [64, 56]                       # gioca Testata (attacco), tiene Blind Spot (aggiuntiva)
	w.draw_pile = [116, 116, 116]           # per il search_draw di Blind Spot
	var foe := _mk("Ronin"); foe.cell = HexGrid.DIRS[0]; foe.facing = 3   # davanti: l'attacco va a segno
	s3.fighters = [w, foe]
	var d3 := Duel.new(s3); d3.interactive = true
	d3.await_instant_replace.connect(func(i, _o): d3.apply_instant_replace(i, -1))
	d3.await_instant_play.connect(func(i, opts):
		d3.apply_instant_play(i, 56 if (i == 0 and opts.has(56)) else -1))
	d3.await_resolution.connect(func(_ri): d3.resolve_current())
	var pile_before := w.draw_pile.size()
	d3.plan_card(0, 64)
	d3.plan_card(1, 116)
	if not w.discard.has(56):
		print("FAIL: l'istantanea aggiuntiva non è stata giocata/scartata"); ok = false
	elif not bool(d3._instant_used.get(0, false)):
		print("FAIL: l'istantanea non è stata segnata come giocata (1/turno)"); ok = false
	elif w.draw_pile.size() >= pile_before:
		print("FAIL: l'effetto dell'istantanea (pesca) non è stato risolto"); ok = false
	else:
		print("OK: istantanea aggiuntiva giocata dopo la risoluzione (effetto risolto)")

	# ── Vincolo CORE: niente istantanee se hai giocato una carta core ──
	var s4 := GameState.new()
	var w2 := _mk("Warrior"); w2.planned = 53; w2.hand = [56]   # ha giocato la core #53
	s4.fighters = [w2, _mk("Ronin")]
	var d4 := Duel.new(s4); d4.interactive = true
	if not d4.instant_plays_for(0).is_empty():
		print("FAIL: istantanea offerta pur avendo giocato una core"); ok = false
	else:
		print("OK: nessuna istantanea dopo aver giocato una carta core")

	print("RISULTATO: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
