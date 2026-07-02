## Dominio di gioco — Senjutsu: Battle for Japan
##
## Enum, costanti e tabelle di lookup. Autoload singleton: Domain.XXX
## I valori riflettono i dati reali dell'Excel di deckbuilding e del
## regolamento 1.5 (vedi DESIGN.md).
extends Node


# ─── Kamae / Rami (Rank delle carte) ─────────────────────────────────────────
# Nel deckbuilding le carte hanno un "Rank": Wood, Steel, Gold, Jade — i quattro
# rami del kamae, in ordine crescente di potenza. "-" = carta senza ramo (Core).

enum Rank { NONE, WOOD, STEEL, GOLD, JADE }

const RANK_FROM_STRING := {
	"-": Rank.NONE, "wood": Rank.WOOD, "steel": Rank.STEEL,
	"gold": Rank.GOLD, "jade": Rank.JADE,
}
const RANK_LABELS := {
	Rank.NONE: "—", Rank.WOOD: "Legno", Rank.STEEL: "Acciaio",
	Rank.GOLD: "Oro", Rank.JADE: "Giada",
}
const RANK_COLORS := {
	Rank.NONE:  Color(0.6, 0.6, 0.6),
	Rank.WOOD:  Color(0.45, 0.65, 0.35),
	Rank.STEEL: Color(0.55, 0.6, 0.68),
	Rank.GOLD:  Color(0.85, 0.7, 0.25),
	Rank.JADE:  Color(0.2, 0.7, 0.55),
}


# ─── Kamae (posizioni di combattimento) ──────────────────────────────────────
# L'anello scorre sull'albero Kamae. Le 4 posizioni + ordine per spareggio
# iniziativa (Aggressività, Equilibrio, Determinazione, Neutra).

enum Stance { AGGRESSION, BALANCE, DETERMINATION, NEUTRAL, DISTANCE }

const STANCE_NAMES := {
	Stance.AGGRESSION: "Aggressività",
	Stance.BALANCE: "Equilibrio",
	Stance.DETERMINATION: "Determinazione",
	Stance.NEUTRAL: "Neutra",
	Stance.DISTANCE: "Distanza",   # quinta Kamae (onda blu), solo Navigatore
}
const STANCE_FROM_STRING := {
	"aggression": Stance.AGGRESSION, "aggressivita": Stance.AGGRESSION,
	"balance": Stance.BALANCE, "equilibrio": Stance.BALANCE,
	"determination": Stance.DETERMINATION, "determinazione": Stance.DETERMINATION,
	"neutral": Stance.NEUTRAL, "neutra": Stance.NEUTRAL,
	"distance": Stance.DISTANCE, "distanza": Stance.DISTANCE,
}
## Ordine di spareggio iniziativa a parità di velocità+tipo (dall'asterisco).
const STANCE_TIE_ORDER := [Stance.AGGRESSION, Stance.BALANCE, Stance.DETERMINATION, Stance.NEUTRAL, Stance.DISTANCE]

const STANCE_SLUG := {
	Stance.AGGRESSION: "aggression", Stance.BALANCE: "balance",
	Stance.DETERMINATION: "determination", Stance.NEUTRAL: "neutral",
	Stance.DISTANCE: "distance",
}
const STANCE_FROM_SLUG := {
	"aggression": Stance.AGGRESSION, "balance": Stance.BALANCE,
	"determination": Stance.DETERMINATION, "neutral": Stance.NEUTRAL,
	"distance": Stance.DISTANCE,
}


# ─── Tipi di carta (dal campo Keywords) ──────────────────────────────────────

enum CardType { ATTACK, DEFENCE, MEDITATION, CORE, OTHER }

const CARD_TYPE_FROM_STRING := {
	"attack": CardType.ATTACK, "defence": CardType.DEFENCE,
	"meditation": CardType.MEDITATION, "core": CardType.CORE,
	"other": CardType.OTHER,
}
const CARD_TYPE_LABELS := {
	CardType.ATTACK: "Attacco", CardType.DEFENCE: "Difesa",
	CardType.MEDITATION: "Meditazione", CardType.CORE: "Base",
	CardType.OTHER: "Altro",
}

## Ordine di risoluzione a parità di velocità: prima Difesa, poi Attacco,
## poi Meditazione, infine Base (regolamento 1.5).
const TYPE_RESOLVE_ORDER := {
	"defence": 0, "attack": 1, "meditation": 2, "core": 3, "other": 4,
}

## Velocità d'iniziativa scelta da un valore grezzo. Per iniziativa variabile
## (lista "7,6,5,4,3" o range "6-2") restituisce il massimo se prefer_high,
## altrimenti il minimo. "=" e "-" → -1 (istantanee / nessuna).
static func pick_initiative(raw: String, prefer_high: bool = true) -> int:
	var s := raw.strip_edges()
	if s == "" or s == "=" or s == "-":
		return -1
	var nums: Array[int] = []
	# range "a-b"
	if "-" in s and not ("," in s):
		var parts := s.split("-")
		if parts.size() == 2 and parts[0].strip_edges().is_valid_int() and parts[1].strip_edges().is_valid_int():
			var a := int(parts[0]); var b := int(parts[1])
			return maxi(a, b) if prefer_high else mini(a, b)
	for tok in s.replace("/", ",").split(","):
		var t := tok.strip_edges()
		if t.is_valid_int():
			nums.append(int(t))
	if nums.is_empty():
		return -1
	nums.sort()
	return nums[nums.size() - 1] if prefer_high else nums[0]


## Tutti i valori d'iniziativa selezionabili (per range "a-b" o lista "7,6,5").
## "=" e "-" → lista vuota.
static func initiative_options(raw: String) -> Array:
	var s := raw.strip_edges()
	if s == "" or s == "=" or s == "-":
		return []
	if "-" in s and not ("," in s):
		var parts := s.split("-")
		if parts.size() == 2 and parts[0].strip_edges().is_valid_int() and parts[1].strip_edges().is_valid_int():
			var a := int(parts[0]); var b := int(parts[1])
			var out: Array = []
			for v in range(mini(a, b), maxi(a, b) + 1):
				out.append(v)
			return out
	var nums: Array = []
	for tok in s.replace("/", ",").split(","):
		var t := tok.strip_edges()
		if t.is_valid_int():
			nums.append(int(t))
	return nums


# ─── Personaggi giocabili (con asset disponibili) ────────────────────────────
# Il pool completo (24 tipi) è in data/cards/card_pool.json; questi sono i
# guerrieri di partenza per cui abbiamo carte/miniature.

const PLAYABLE := ["Warrior", "Ronin"]   ## default se il menu non ha scelto

## Roster selezionabile dal menu (ordine di presentazione: base poi espansioni)
## e nomi italiani per la UI. Le chiavi sono quelle di geometry.characters.
const ROSTER := ["Warrior", "Ronin", "Master", "Student", "Assassin", "Ninja",
	"Onna-Bugeisha", "Yojimbo", "Ashigaru", "Hachiko", "Monk", "Sailor",
	"Wakou", "Yasuke"]
const CHAR_NAMES_IT := {
	"Warrior": "Guerriero", "Ronin": "Ronin", "Master": "Maestro",
	"Student": "Allievo", "Assassin": "Assassino", "Ninja": "Ninja",
	"Onna-Bugeisha": "Onna-Bugeisha", "Yojimbo": "Yojimbo",
	"Ashigaru": "Ashigaru", "Hachiko": "Hachikō", "Monk": "Monaco",
	"Sailor": "Navigatore", "Wakou": "Wakou", "Yasuke": "Yasuke",
}

## Modalità scelta dal menu: "solo" (vs IA) o "versus" (1v1 locale hot-seat).
## L'Arena la legge all'avvio per configurare le pedine e il flusso del turno.
var game_mode: String = "solo"

## Combattenti scelti nel menu ([P1, P2], chiavi personaggio). Vuoto = default
## PLAYABLE (retro-compatibile con test e avvii diretti dell'Arena).
var selected_chars: Array = []

## URL del relay WebSocket per il tavolo online (companion). In LAN punta al PC che
## ospita il server (server/server.js). Default: localhost.
var ws_url: String = "ws://127.0.0.1:8080"


# ─── Zone del corpo / ferite ─────────────────────────────────────────────────
# Gli attacchi indicano le caselle del corpo colpite; le difese le proteggono.
# Schema esatto da rifinire sul regolamento (Reference Sheet).

enum BodyZone { HEAD, BODY, ARMS, LEGS }
const BODY_ZONE_LABELS := {
	BodyZone.HEAD: "Testa", BodyZone.BODY: "Corpo",
	BodyZone.ARMS: "Braccia", BodyZone.LEGS: "Gambe",
}


# ─── Fasi del turno ──────────────────────────────────────────────────────────

enum Phase { SETUP, PLANNING, REVEAL, RESOLUTION, WOUNDS, CLEANUP, GAME_OVER }

const PHASE_LABELS := {
	Phase.SETUP: "Posizionamento",
	Phase.PLANNING: "Programmazione — scegli le carte",
	Phase.REVEAL: "Rivelazione",
	Phase.RESOLUTION: "Risoluzione",
	Phase.WOUNDS: "Ferite",
	Phase.CLEANUP: "Riordino",
	Phase.GAME_OVER: "Duello terminato",
}


# ─── Geometria mappa esagonale ───────────────────────────────────────────────

const HEX_SIZE := 1.0       ## raggio esagono (centro→vertice) in unità mondo
const HEX_HEIGHT := 0.15    ## spessore tessera 3D


# ─── Helper ──────────────────────────────────────────────────────────────────

static func parse_rank(s: String) -> int:
	return RANK_FROM_STRING.get(s.to_lower().strip_edges(), Rank.NONE)

static func parse_card_type(s: String) -> int:
	return CARD_TYPE_FROM_STRING.get(s.to_lower().strip_edges(), CardType.OTHER)

## L'iniziativa nell'Excel può essere un numero, "=", "-" o una lista
## ("7,6,5,4,3"). Restituisce il primo numero utile, o -1 se assente.
static func initiative_value(raw: String) -> int:
	for tok in raw.replace("/", ",").split(","):
		var t := tok.strip_edges()
		if t.is_valid_int():
			return int(t)
	return -1
