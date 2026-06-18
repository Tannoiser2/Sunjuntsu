## Stato di un duello — Senjutsu
##
## Oggetto puro (RefCounted): nessun nodo, serializzabile. Contiene tutto ciò
## che serve a risolvere un turno, così la stessa logica vale per solo e
## multiplayer. La presentazione 3D legge da qui.
class_name GameState
extends RefCounted

## Stato di un singolo combattente.
class Fighter:
	var character: String = "Warrior"          ## personaggio (chiave in CardDB)
	var cell: Vector2i = Vector2i.ZERO        ## posizione sulla mappa esagonale
	var facing: int = 0                        ## direzione (0..5), indice in HexGrid.DIRS
	var kamae: int = Domain.Rank.STEEL         ## ramo kamae corrente
	var focus: int = 0                         ## gettoni focus (max 3, vedi regolamento)
	var hand: Array = []                       ## carte in mano (id int)
	var draw_pile: Array = []                  ## mazzo da pescare (id int)
	var discard: Array = []                    ## scarti (id int)
	var wounds: Array = []                     ## ferite subite (stringhe: "wound"/"bleed")
	var stun: int = 0                          ## carte stordimento accumulate
	var wound_limit: int = 6                   ## limite ferite (dalla carta personaggio)
	var hand_limit: int = 5                    ## limite carte in mano
	var advantage: bool = false                ## possiede il segnalino vantaggio
	var planned: int = -1                      ## carta programmata (id int, -1 = nessuna)
	var is_ai: bool = false

	const MAX_FOCUS := 3

	func gain_focus(n: int) -> void:
		focus = clampi(focus + n, 0, MAX_FOCUS)

	func remaining_wounds() -> int:
		return wound_limit - wounds.size()

	## Pesca una carta dal mazzo; rimescola gli scarti se vuoto.
	func draw_one() -> int:
		if draw_pile.is_empty():
			draw_pile = discard.duplicate()
			discard.clear()
			draw_pile.shuffle()
		if draw_pile.is_empty():
			return -1
		var id: int = draw_pile.pop_back()
		hand.append(id)
		return id

	func is_defeated() -> bool:
		# Sconfitta: ferite (incl. sanguinanti) al limite, oppure stun >= ferite rimaste.
		if wounds.size() >= wound_limit:
			return true
		if stun > 0 and stun >= remaining_wounds():
			return true
		return false


var fighters: Array[Fighter] = []
var phase: int = Domain.Phase.SETUP
var round_num: int = 1
var map_radius: int = 6                         ## arena esagonale di raggio N
var blocked_cells: Dictionary = {}              ## Vector2i -> true (ostacoli)


func add_fighter(character: String, cell: Vector2i) -> Fighter:
	var f := Fighter.new()
	f.character = character
	f.cell = cell
	fighters.append(f)
	return f


func fighter_at(cell: Vector2i) -> Fighter:
	for f in fighters:
		if f.cell == cell:
			return f
	return null


## True se la cella è fuori arena, occupata o ostacolo.
func is_blocked(cell: Vector2i) -> bool:
	if HexGrid.distance(cell, Vector2i.ZERO) > map_radius:
		return true
	if blocked_cells.has(cell):
		return true
	return fighter_at(cell) != null


func opponent_of(f: Fighter) -> Fighter:
	for other in fighters:
		if other != f:
			return other
	return null
