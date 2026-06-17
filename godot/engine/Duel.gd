## Motore del duello — Senjutsu
##
## Orchestrazione delle fasi del turno su un GameState. Logica pura (testabile
## headless): emette segnali che la scena 3D ascolta per animare.
##
## NOTA: la risoluzione dettagliata (iniziativa, colpi per zona, difese, ferite)
## è ancora uno scheletro. Va completata sui dati reali delle carte — vedi
## DESIGN.md sezione "Risoluzione del combattimento".
class_name Duel
extends RefCounted

signal phase_changed(phase: int)
signal card_planned(fighter_index: int, card_id: int)
signal cards_revealed(plans: Array)
signal fighter_moved(fighter_index: int, to: Vector2i)
signal wound_applied(fighter_index: int, zone: int)
signal duel_over(winner_index: int)

var state: GameState


func _init(initial_state: GameState) -> void:
	state = initial_state


func start() -> void:
	_set_phase(Domain.Phase.PLANNING)


func _set_phase(p: int) -> void:
	state.phase = p
	phase_changed.emit(p)


## Un giocatore programma la carta da giocare questo turno.
func plan_card(fighter_index: int, card_id: int) -> void:
	if state.phase != Domain.Phase.PLANNING:
		return
	var f := state.fighters[fighter_index]
	f.planned = card_id
	card_planned.emit(fighter_index, card_id)
	if _all_planned():
		_reveal()


func _all_planned() -> bool:
	for f in state.fighters:
		if f.planned == -1:
			return false
	return true


func _reveal() -> void:
	_set_phase(Domain.Phase.REVEAL)
	var plans: Array = []
	for f in state.fighters:
		plans.append(f.planned)
	cards_revealed.emit(plans)
	_resolve()


## Scheletro di risoluzione: ordina per iniziativa e applica gli effetti.
func _resolve() -> void:
	_set_phase(Domain.Phase.RESOLUTION)
	var order := _initiative_order()
	for idx in order:
		var f := state.fighters[idx]
		var card := CardDB.card(f.planned)
		if card.is_empty():
			continue
		_apply_card(idx, card)
		if _check_winner() != -1:
			return
	_cleanup()


## Indici dei combattenti ordinati per iniziativa decrescente (più veloce prima).
func _initiative_order() -> Array:
	var idx := range(state.fighters.size())
	var arr: Array = []
	for i in idx:
		arr.append(i)
	arr.sort_custom(func(a, b):
		return _speed_of(a) > _speed_of(b))
	return arr


func _speed_of(fighter_index: int) -> int:
	var card := CardDB.card(state.fighters[fighter_index].planned)
	return Domain.initiative_value(str(card.get("initiative", "")))


## Applica gli effetti base di una carta (movimento incluso). Da estendere.
func _apply_card(fighter_index: int, card: Dictionary) -> void:
	var move: int = int(card.get("move", 0))
	if move > 0:
		# Il movimento effettivo (scelta cella) sarà guidato dall'input/IA;
		# qui resta da collegare. Vedi DESIGN.md.
		pass
	# Attacco/difesa/ferite: TODO sui dati reali.


func _check_winner() -> int:
	for i in range(state.fighters.size()):
		if state.fighters[i].is_defeated():
			var winner := 1 - i if state.fighters.size() == 2 else -1
			_set_phase(Domain.Phase.GAME_OVER)
			duel_over.emit(winner)
			return winner
	return -1


func _cleanup() -> void:
	_set_phase(Domain.Phase.CLEANUP)
	for f in state.fighters:
		if f.planned != -1:
			f.discard.append(f.planned)
			f.planned = -1
	state.round_num += 1
	_set_phase(Domain.Phase.PLANNING)
