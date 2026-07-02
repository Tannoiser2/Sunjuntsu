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
	# Parametri IA solitaria (regolamento p.20-22): atteggiamento, portata, approccio.
	var ai_stance: String = "offensive"        ## "offensive" | "defensive"
	var ai_preferred_range: int = 1            ## distanza che l'IA cerca di mantenere
	var ai_approach: String = "front"          ## "front" | "left" | "right" | "rear"
	var wound_limit: int = 6                   ## limite ferite (dalla carta personaggio)
	var hand_limit: int = 5                    ## limite carte in mano
	var advantage: bool = false                ## possiede il segnalino vantaggio
	var planned: int = -1                      ## carta programmata (id int, -1 = nessuna)
	## Faccia scelta per una carta a doppia faccia (Hachikō, §3.14):
	## "" = normale/attacco (comportamento classico), "defence" = usa il
	## blocco `face_defence` della geometria (iniziativa/movimento/effetti propri).
	var planned_face: String = ""
	var is_ai: bool = false
	## Carte "RIMANE IN GIOCO" (roadmap §3.2): id delle carte a faccia in su
	## davanti al combattente. Entrano da _cleanup/_resolve_instant_card
	## (geometria con `stays_in_play`), escono via Duel.remove_from_play.
	var in_play: Array = []
	## Turni di permanenza per carta in gioco (cid → conteggio), per il campo
	## `expires` (es. #106 che ruota di 90° a fine turno e scade da diritta).
	var in_play_ticks: Dictionary = {}
	## Limite focus corrente (di norma MAX_FOCUS; le carte in gioco possono
	## alzarlo via `limit_mod`, es. Anima Illuminata #265).
	var focus_limit: int = 3
	## Stati/risorse persistenti per-fighter (decisione §5.1 roadmap meccaniche):
	## dizionario libero nome → int, che sopravvive tra i turni finché una carta
	## non lo modifica. Copre Disperazione, Contratti, stato Ombra/Ninja, ciclo
	## Illuminata, carte "rimangono in gioco". Flag = 0/assente (off) o >=1 (on).
	## Letto dai gate (Gate.state_ok) e scritto dai verbi state_* (Duel.gd).
	var states: Dictionary = {}

	const MAX_FOCUS := 3

	## Stati per la valutazione dei GATE: quelli persistenti più i DERIVATI
	## dalla scheda personaggio (`characters.<nome>.derived_states` in
	## geometry.json). Caso reale: Disperazione dell'Onna-Bugeisha —
	## carta-regola #292: "FINCHÉ ha 3 o più ferite/sanguinanti la
	## Disperazione è attiva" → { "disperazione": { "wounds_min": 3 } }.
	func gate_states() -> Dictionary:
		var ds: Dictionary = CardDB.character_stats(character).get("derived_states", {})
		if ds.is_empty():
			return states
		var out := states.duplicate()
		for state_name in ds:
			var rule: Dictionary = ds[state_name]
			if rule.has("wounds_min") and wounds.size() >= int(rule["wounds_min"]):
				out[state_name] = maxi(1, int(out.get(state_name, 0)))
		return out

	# ── Stati persistenti (contatori/flag nominati) ──────────────────────────
	## Valore corrente dello stato `state_name` (0 se assente).
	func state_get(state_name: String) -> int:
		return int(states.get(state_name, 0))

	## Somma `n` (anche negativo, per spendere) allo stato; a <=0 lo rimuove.
	func state_add(state_name: String, n: int) -> void:
		state_set(state_name, state_get(state_name) + n)

	## Imposta lo stato al valore assoluto `n`; a <=0 lo rimuove.
	func state_set(state_name: String, n: int) -> void:
		if state_name == "":
			return
		if n <= 0:
			states.erase(state_name)
		else:
			states[state_name] = n

	func gain_focus(n: int) -> void:
		focus = clampi(focus + n, 0, focus_limit)

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

	## Carte di STATO attualmente "in possesso" del combattente, come ID carta
	## (negativi, vedi Status.gd), espanse una per copia: ferite (normali e
	## sanguinanti), azzoppamenti, stordimenti, veleni. Servono a mostrarle come
	## CARTE nell'HUD (il gioco fisico le tiene come cartoncini, non segnalini).
	func status_card_ids() -> Array:
		var out: Array = []
		for tag in wounds:
			out.append(Status.wound_card_id(str(tag)))
		for _h in hobbles:
			out.append(Status.HOBBLE)
		for _s in range(stun):
			out.append(Status.STUN)
		for _p in range(poison):
			out.append(Status.POISON_VIRULENT)
		return out

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
## Segnalini trappola sulla griglia (piedi di corvo, carta-regola #160, §3.28):
## Vector2i -> { kind: "caltrop"|"decoy", owner: int, hidden: bool }.
## Piazzati dal verbo effetto `place_traps` (Duel); scattano con spring_traps.
var traps: Dictionary = {}


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


## Scatta l'eventuale trappola nella cella di `f` (carta-regola #160):
## piede di corvo = 1 ferita + AZZOPPATO; diversivo = nessun effetto.
## In entrambi i casi il segnalino si rimuove. Ritorna le righe di log.
## Da chiamare a ogni ingresso in cella (motore: push/pull/mosse obbligatorie;
## scena: conferma del movimento del giocatore).
func spring_traps(f: Fighter) -> Array:
	if not traps.has(f.cell):
		return []
	var t: Dictionary = traps[f.cell]
	traps.erase(f.cell)
	if str(t.get("kind", "")) == "decoy":
		return ["%s scopre un diversivo (nessun effetto)" % f.character]
	f.wounds.append("wound")
	f.add_hobble(1)
	return ["%s calpesta i piedi di corvo: 1 ferita e AZZOPPATO" % f.character]


func opponent_of(f: Fighter) -> Fighter:
	for other in fighters:
		if other != f:
			return other
	return null
