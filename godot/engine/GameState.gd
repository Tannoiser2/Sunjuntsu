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
	var kamae: int = Domain.Rank.STEEL         ## ramo kamae (rank) — legacy
	var stance: int = Domain.Stance.NEUTRAL    ## posizione dell'anello Kamae
	var hobbles: Array = []                    ## azzoppamenti attivi (orientamento 0..3 di ogni carta)
	var focus: int = 0                         ## gettoni focus (max 3, vedi regolamento)
	var hand: Array = []                       ## carte in mano (id int)
	var draw_pile: Array = []                  ## mazzo da pescare (id int)
	var discard: Array = []                    ## scarti (id int)
	var wounds: Array = []                     ## ferite subite (stringhe: "wound"/"bleed")
	var stun: int = 0                          ## carte stordimento accumulate
	var poison: int = 0                        ## veleni virulenti attivi (riducono il limite)
	var damage_reduction: int = 0              ## riduzione danno persistente (es. Armatura Pesante)
	var movement_cancelled: bool = false       ## il movimento di questo turno è annullato (es. Grido di Guerra)
	var block_initiative_bonus: int = 0        ## allarga l'intervallo d'iniziativa del blocco (es. Blocco Ampio)
	var wound_limit: int = 6                   ## limite ferite (dalla carta personaggio)
	var hand_limit: int = 5                    ## limite carte in mano
	var advantage: bool = false                ## possiede il segnalino vantaggio
	var planned: int = -1                      ## carta programmata (id int, -1 = nessuna)
	var is_ai: bool = false

	const MAX_FOCUS := 3

	func gain_focus(n: int) -> void:
		focus = clampi(focus + n, 0, MAX_FOCUS)

	# ── Azzoppamenti (Hobble, regolamento 1.5 p.13) ──────────────────────────
	## Ogni carta azzoppato è posata diritta (orientamento 0) nel turno in cui la
	## subisci e in quel turno NON riduce l'iniziativa. A ogni fine turno ruota di
	## 90° (orientamento +1); quando tornerebbe diritta (4) viene scartata.
	func add_hobble(n: int) -> void:
		for _i in range(maxi(1, n)):
			hobbles.append(0)

	## Numero di azzoppamenti ATTIVI (già ruotati almeno una volta): −1 iniziativa cad.
	func hobble_count() -> int:
		var c := 0
		for o in hobbles:
			if int(o) >= 1:
				c += 1
		return c

	## Fine turno: ruota tutti gli azzoppamenti; scarta quelli che tornano diritti.
	func tick_hobbles() -> void:
		var keep: Array = []
		for o in hobbles:
			var no := int(o) + 1
			if no < 4:
				keep.append(no)
		hobbles = keep

	## Limite ferite effettivo (ridotto dai veleni virulenti, minimo 1).
	func effective_wound_limit() -> int:
		return maxi(1, wound_limit - poison)

	func remaining_wounds() -> int:
		return effective_wound_limit() - wounds.size()

	func has_bleed() -> bool:
		return wounds.has("bleed")

	## Pesca una carta dal mazzo. Regola 1.5: se il mazzo è vuoto, invece di
	## pescare subisci una ferita (nessun rimescolo degli scarti).
	func draw_one() -> int:
		if draw_pile.is_empty():
			wounds.append("deck")   # "decking out": ferita invece di pescare
			return -1
		var id: int = draw_pile.pop_back()
		hand.append(id)
		return id

	func is_defeated() -> bool:
		# Sconfitta: ferite (incl. sanguinanti) >= limite effettivo, oppure
		# carte stordimento in mano = limite mano.
		if wounds.size() >= effective_wound_limit():
			return true
		if stun >= hand_limit:
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


## Tipo di terreno nella cella ("" se non c'è terreno). I valori in blocked_cells
## possono essere stringhe-tipo ("obstacle"/"bamboo"/"burning"/"torii"); per
## retrocompatibilità un valore non-stringa è trattato come "obstacle".
func terrain_at(cell: Vector2i) -> String:
	if not blocked_cells.has(cell):
		return ""
	var v = blocked_cells[cell]
	return v if v is String else "obstacle"


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
