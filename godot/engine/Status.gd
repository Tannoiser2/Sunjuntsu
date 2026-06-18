## Catalogo carte di STATO — Senjutsu
##
## Le ferite, lo stordimento, gli azzoppamenti e i veleni nel gioco fisico sono
## CARTE (cartoncini dalla riserva), non semplici segnalini. Qui le modelliamo come
## carte con ID NEGATIVO (per non collidere con le carte abilità, sempre positive)
## così possono essere mostrate con la loro arte reale (assets/cards/status/) e
## avere nome/testo. Le regole sono applicate dal motore (Duel/GameState).
##
## Testo trascritto fedelmente da CARTE/Ferite.pdf (edizione ITA).
class_name Status
extends RefCounted

# ── ID delle carte di stato (negativi) ───────────────────────────────────────
const STUN := -1                 ## Stordimento
const HOBBLE := -2               ## Azzoppato
const WOUND := -3                ## Ferita
const BLEED := -4                ## Ferita sanguinante
const POISON_VIRULENT := -5      ## Veleno virulento
const POISON_DEBILITATING := -6  ## Veleno debilitante
const POISON_FOG := -7           ## Nebbia di confusione
const POISON_PARALYZING := -8    ## Tossina paralizzante
const POISON_HEMORRHAGIC := -9   ## Tossina emorragica

## Catalogo: id → { name, slug, file, category, text }.
## category: "stun" | "hobble" | "wound" | "poison" — per raggrupparle nell'HUD.
const CATALOG := {
	STUN: {
		"name": "Stordimento", "slug": "stordimento", "file": "status/stordimento.webp",
		"category": "stun",
		"text": "Incide sul limite di carte in mano. Non può essere scartata dalla mano. Puoi giocarla come una carta abilità. Se hai in mano un numero di Stordimento pari al limite di mano, vieni sconfitto.",
	},
	HOBBLE: {
		"name": "Azzoppato", "slug": "azzoppato", "file": "status/azzoppato.webp",
		"category": "hobble",
		"text": "Rimane in gioco. Finché è attiva, riduci di 1 la velocità d'iniziativa delle carte abilità (minimo 1). A fine turno ruota di 90° in senso orario; se diritta, scartala.",
	},
	WOUND: {
		"name": "Ferita", "slug": "ferita", "file": "status/ferita.webp",
		"category": "wound",
		"text": "Rimane in gioco. Vale 1 ferita. Se hai un numero di carte Ferita pari al limite di ferite del personaggio, vieni sconfitto.",
	},
	BLEED: {
		"name": "Ferita Sanguinante", "slug": "ferita_sanguinante", "file": "status/ferita_sanguinante.webp",
		"category": "wound",
		"text": "Rimane in gioco. Vale 1 ferita. Finché hai almeno 1 carta sanguinante, all'inizio del turno prima di pescare scarta a faccia in giù la prima carta del mazzo (massimo 1). Sconfitta come la Ferita.",
	},
	POISON_VIRULENT: {
		"name": "Veleno Virulento", "slug": "veleno_virulento", "file": "status/veleno_virulento.webp",
		"category": "poison",
		"text": "Rimane in gioco. Finché è attiva, riduci di 1 il limite di ferite del personaggio. A fine turno ruota di 90°; se diritta, scartala.",
	},
	POISON_DEBILITATING: {
		"name": "Veleno Debilitante", "slug": "veleno_debilitante", "file": "status/veleno_debilitante.webp",
		"category": "poison",
		"text": "Mischia questa carta tra le prime 5 del mazzo. Quando scegli le carte abilità, se l'hai in mano devi sceglierla.",
	},
	POISON_FOG: {
		"name": "Nebbia di Confusione", "slug": "nebbia_confusione", "file": "status/nebbia_confusione.webp",
		"category": "poison",
		"text": "Rimane in gioco. Finché è attiva, ogni turno devi scegliere a caso la carta abilità e non puoi giocarne come istantanee. A fine turno ruota di 180°; se diritta, scartala.",
	},
	POISON_PARALYZING: {
		"name": "Tossina Paralizzante", "slug": "tossina_paralizzante", "file": "status/tossina_paralizzante.webp",
		"category": "poison",
		"text": "Rimane in gioco. Finché è attiva, non puoi cambiare o passare a un'altra Kamae, né spendere o ottenere focus. A fine turno ruota di 180°; se diritta, scartala.",
	},
	POISON_HEMORRHAGIC: {
		"name": "Tossina Emorragica", "slug": "tossina_emorragica", "file": "status/tossina_emorragica.webp",
		"category": "poison",
		"text": "Rimane in gioco. Finché è attiva, all'inizio del turno prima di pescare scarta a faccia in giù la prima carta del mazzo. A fine turno ruota di 90°; se diritta, scartala.",
	},
}


## True se `id` è una carta di stato (id negativo presente nel catalogo).
static func is_status(id: int) -> bool:
	return CATALOG.has(id)


## Dati-carta di una carta di stato (name/type/file/...), nel formato di CardDB.card().
static func card(id: int) -> Dictionary:
	if not CATALOG.has(id):
		return {}
	var e: Dictionary = CATALOG[id]
	return {
		"id": id, "name": e["name"], "type": "status",
		"category": e["category"], "text": e["text"], "file": e["file"],
		"keywords": ["Stato"],
	}


## Percorso immagine (relativo ad assets/cards/) della carta di stato, o "".
static func image_for(id: int) -> String:
	if CATALOG.has(id):
		return CATALOG[id]["file"]
	return ""


## ID della carta-ferita corrispondente a un'entrata di GameState.Fighter.wounds.
## "bleed" → Ferita Sanguinante; tutto il resto ("wound"/"deck"/"exec") → Ferita.
static func wound_card_id(tag: String) -> int:
	return BLEED if tag == "bleed" else WOUND
