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


# ─── Personaggi giocabili (con asset disponibili) ────────────────────────────
# Il pool completo (24 tipi) è in data/cards/card_pool.json; questi sono i
# guerrieri di partenza per cui abbiamo carte/miniature.

const PLAYABLE := ["Warrior", "Ronin"]   ## "Jin Sakai" da aggiungere (carte JPG custom)


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
