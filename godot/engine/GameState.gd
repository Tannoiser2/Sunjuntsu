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
	var hand: Array = []                       ## carte in mano (id int)
	var draw_pile: Array = []                  ## mazzo da pescare (id int)
	var discard: Array = []                    ## scarti (id int)
	var wounds: Array = []                     ## ferite subite (zone/carte ferita)
	var planned: int = -1                      ## carta programmata questo turno (id int, -1 = nessuna)

	func is_defeated() -> bool:
		# Soglia da definire sui dati reali; segnaposto.
		return wounds.size() >= 6


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
