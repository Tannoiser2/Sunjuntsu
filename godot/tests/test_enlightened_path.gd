## Test headless: meccanica loti di "Sentiero Illuminato" (#953, IA Monaco).
## Accumulo su attacco/blocco riuscito + soglie 3+/5+/7+ + azzeramento all'uscita.
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
	_test_award()
	_test_thresholds()
	_test_immune_hook()
	_test_reset_on_leave()
	print("RISULTATO: ", "PASS" if _fail == 0 else "FAIL (%d)" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)


## _award_enlightened aggiunge 1 loto solo se #953 è in gioco per quel combattente.
func _test_award() -> void:
	var s := GameState.new()
	var a := _mk("Monk")
	var b := _mk("Ronin")
	s.fighters = [a, b]
	var d := Duel.new(s)
	var log: Array = []
	d._award_enlightened(0, log)
	_ck(a.enlightened_lotus == 0, "senza Sentiero Illuminato in gioco → nessun loto")
	a.in_play.append(953)
	d._award_enlightened(0, log)
	d._award_enlightened(0, log)
	_ck(a.enlightened_lotus == 2, "con #953 in gioco → +1 loto per successo (2 successi = 2 loti)")


## Le tre soglie di potenziamento sui metodi del Fighter.
func _test_thresholds() -> void:
	var f := _mk("Monk")
	f.enlightened_lotus = 2
	_ck(f.effective_wound_limit() == f.wound_limit, "2 loti → nessun bonus al limite ferite")
	_ck(not f.enlightened_immune(), "2 loti → non immune")
	_ck(f.enlightened_attack_bonus() == 0, "2 loti → nessun bonus attacco")
	f.enlightened_lotus = 3
	_ck(f.effective_wound_limit() == f.wound_limit + 1, "3 loti → +1 al limite ferite")
	f.enlightened_lotus = 4
	_ck(not f.enlightened_immune(), "4 loti → ancora non immune")
	f.enlightened_lotus = 5
	_ck(f.enlightened_immune(), "5 loti → immune agli effetti di stato")
	_ck(f.enlightened_attack_bonus() == 0, "5 loti → attacchi ancora senza bonus")
	f.enlightened_lotus = 7
	_ck(f.enlightened_attack_bonus() == 1, "7 loti → tutti gli attacchi +1 ferita")


## _immune() rispetta l'immunità Illuminata (5+ loti) per qualunque verbo.
func _test_immune_hook() -> void:
	var s := GameState.new()
	var a := _mk("Monk")
	var b := _mk("Ronin")
	s.fighters = [a, b]
	var d := Duel.new(s)
	_ck(not d._immune(a, "foe_discard"), "0 loti → non immune a foe_discard")
	a.enlightened_lotus = 5
	_ck(d._immune(a, "foe_discard"), "5 loti → immune a foe_discard")
	_ck(d._immune(a, "foe_lose_focus"), "5 loti → immune anche a foe_lose_focus (tutti gli stati)")


## Quando #953 esce dal gioco, i loti si azzerano e i bonus svaniscono.
func _test_reset_on_leave() -> void:
	var s := GameState.new()
	var a := _mk("Monk")
	var b := _mk("Ronin")
	s.fighters = [a, b]
	var d := Duel.new(s)
	a.in_play.append(953)
	a.enlightened_lotus = 6
	_ck(a.enlightened_immune(), "prima: immune con 6 loti")
	_ck(a.effective_wound_limit() == a.wound_limit + 1, "prima: +1 limite ferite")
	d.remove_from_play(0, 953)
	_ck(a.enlightened_lotus == 0, "dopo remove_from_play → loti azzerati")
	_ck(not a.enlightened_immune(), "dopo → non più immune")
	_ck(a.effective_wound_limit() == a.wound_limit, "dopo → limite ferite tornato normale")
	_ck(a.discard.has(953), "dopo → carta negli scarti")
