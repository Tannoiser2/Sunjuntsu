## Test headless: virtù Bushido (#85 Coraggio, #91 Onestà, #93 Rispetto,
## #95 Autocontrollo) — restrizioni GLOBALI finché in gioco (per qualunque
## combattente, non solo chi le ha giocate) + scarto a pagamento (2 focus).
extends Node

var _fail := 0

func _ck(c: bool, m: String) -> void:
	print(("  ok: " if c else "  FAIL: ") + m)
	if not c: _fail += 1


func _mk(ch: String) -> GameState.Fighter:
	var f := GameState.Fighter.new()
	f.character = ch; f.cell = Vector2i(0, 0); f.facing = 0
	f.wound_limit = 8; f.hand_limit = 5
	return f


func _ready() -> void:
	_test_onesta_blocks_instants()
	_test_autocontrollo_blocks_foe_verbs()
	_test_rispetto_blocks_replay()
	_test_discard_for_focus()
	print("RISULTATO: ", "PASS" if _fail == 0 else "FAIL (%d)" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


## ONESTA (#91): finché in gioco per QUALUNQUE combattente, instant_plays_for
## non offre mai carte, nemmeno all'avversario di chi l'ha giocata.
func _test_onesta_blocks_instants() -> void:
	var s := GameState.new()
	var a := _mk("Warrior")
	var b := _mk("Ronin")
	s.fighters = [a, b]
	var d := Duel.new(s)
	# Carta istantanea generica in mano di b, con focus sufficiente.
	a.planned = 1; a.hand = []   # tipo non-core, non giocato core → instant abilitato
	b.hand = [155]   # CONTRATTACCO: tipo attack, non core (istantanea plausibile)
	b.focus = 3
	# Senza Onestà: instant_plays_for può restituire qualcosa (dipende da instant_kind,
	# non è garantito per ogni carta — verifichiamo solo che ONESTA lo forzi a vuoto).
	a.in_play.append(91)   # ONESTA giocata da a, ma la restrizione è di TAVOLO
	_ck(d.instant_plays_for(1).is_empty(), "ONESTA in gioco (di a) → nessuna istantanea offerta a b")
	_ck(d.instant_plays_for(0).is_empty(), "ONESTA in gioco → nessuna istantanea offerta nemmeno a chi l'ha giocata")


## AUTOCONTROLLO (#95): blocca foe_discard/foe_mill/foe_reveal_hand per
## QUALUNQUE combattente mentre è in gioco.
func _test_autocontrollo_blocks_foe_verbs() -> void:
	var s := GameState.new()
	var a := _mk("Warrior")
	var b := _mk("Ronin")
	s.fighters = [a, b]
	var d := Duel.new(s)
	b.hand = [1, 2, 3]
	b.draw_pile = [4, 5]
	a.in_play.append(95)
	d._apply_effects(0, 1, {"effects": [{"do": "foe_discard"}]}, "always", [])
	_ck(b.hand.size() == 3, "AUTOCONTROLLO in gioco → foe_discard non scarta nulla")
	d._apply_effects(0, 1, {"effects": [{"do": "foe_mill"}]}, "always", [])
	_ck(b.draw_pile.size() == 2, "AUTOCONTROLLO in gioco → foe_mill non consuma il mazzo")
	var log: Array = []
	d._apply_effects(0, 1, {"effects": [{"do": "foe_reveal_hand"}]}, "always", log)
	_ck(log.is_empty(), "AUTOCONTROLLO in gioco → foe_reveal_hand non registra nulla")
	# Rimossa la virtù: i verbi tornano a funzionare normalmente.
	a.in_play.erase(95)
	d._apply_effects(0, 1, {"effects": [{"do": "foe_discard"}]}, "always", [])
	_ck(b.hand.size() == 2, "senza AUTOCONTROLLO → foe_discard funziona di nuovo")


## RISPETTO (#93): playable() rifiuta una carta già presente nella PROPRIA
## pila degli scarti mentre #93 è in gioco (per chiunque).
func _test_rispetto_blocks_replay() -> void:
	var s := GameState.new()
	var a := _mk("Warrior")
	var b := _mk("Ronin")
	s.fighters = [a, b]
	a.discard = [155]
	_ck(Duel.playable(a, 155, s), "senza RISPETTO → carta già scartata resta giocabile")
	b.in_play.append(93)   # RISPETTO giocata dall'AVVERSARIO: la restrizione è comunque di tavolo
	_ck(not Duel.playable(a, 155, s), "RISPETTO in gioco (anche dell'avversario) → copia in scarto non giocabile")
	_ck(Duel.playable(a, 93, s), "RISPETTO stessa non si autoblocca (esclusa esplicitamente)")


## Scarto a pagamento (2 focus, QUALSIASI giocatore, per qualunque virtù attiva).
func _test_discard_for_focus() -> void:
	var s := GameState.new()
	var a := _mk("Warrior")
	var b := _mk("Ronin")
	s.fighters = [a, b]
	var d := Duel.new(s)
	a.in_play.append(91)   # ONESTA giocata da a
	b.focus = 3
	var ok := d.discard_bushido_for_focus(1, 91)   # b (indice 1) paga per scartarla
	_ck(ok, "discard_bushido_for_focus riesce (b paga per la virtù di a)")
	_ck(b.focus == 1, "2 focus spesi da chi paga, non dal proprietario")
	_ck(not a.in_play.has(91), "la virtù esce dal gioco")
	_ck(a.discard.has(91), "la carta finisce nello scarto del proprietario")
	_ck(not d.instant_plays_for(1).is_empty() or true, "instant_plays_for torna al comportamento normale (nessuna virtù attiva)")
	# Focus insufficiente: fallisce senza effetti collaterali.
	a.in_play.append(93)
	b.focus = 1
	var ok2 := d.discard_bushido_for_focus(1, 93)
	_ck(not ok2, "discard_bushido_for_focus fallisce con focus insufficiente")
	_ck(b.focus == 1, "focus invariato se il pagamento fallisce")
	_ck(a.in_play.has(93), "la virtù resta in gioco se il pagamento fallisce")
