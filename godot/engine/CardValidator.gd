## Validazione carte — Senjutsu (Fase 3 dell'editor)
##
## Logica pura e headless-testabile: data una carta (anagrafica + geometria +
## immagine) restituisce la lista dei problemi, ciascuno con un livello:
##   "error"   = bloccante (dato non valido / incoerente col vocabolario)
##   "warning" = non bloccante (probabile dimenticanza / da verificare)
##
## Vedi docs/CARD_EDITOR_ROADMAP.md §6 Fase 3.
class_name CardValidator
extends RefCounted

const KAMAE := ["aggression", "balance", "determination"]
## Stance bersaglio per gli effetti: include "neutral" (le stance reali sono 4,
## vedi Kamae.gd). `kamae_req` resta sulle 3 stance "attive" (non si richiede neutral).
const STANCES := ["aggression", "balance", "determination", "neutral"]
const RANKS := ["Wood", "Steel", "Gold", "Jade", "-"]

## Verbi `effects[].do` noti (GEOMETRY_SCHEMA.md §Effetti).
const EFFECT_VERBS := [
	"block_initiative", "cancel_abilities", "cancel_movement", "change_ai_behaviour",
	"change_kamae", "discard_self", "draw", "focus", "foe_discard", "foe_lose_focus",
	"foe_stun", "hobble", "link_anchor", "push", "reduce_damage", "replace_wound_bleed",
	"reset_deck", "rotate_target", "search_draw", "spend_focus", "stun_self",
	"swap_positions", "switch_kamae",
]

## Keyword note "statiche" (oltre a quelle presenti nei dati reali).
const STATIC_KEYWORDS := [
	"Attack", "Defence", "Attack/Defence", "Meditation", "Core",
	"Instant", "Instant Replacement", "Instant Additional",
	"Prepared", "Bushido", "Weapon", "Solo", "Nightmare", "Silver Frost",
	"Range1", "Range2", "Range3", "Range4", "Range5", "Range6",
]


static func _issue(level: String, code: String, msg: String) -> Dictionary:
	return {"level": level, "code": code, "msg": msg}


## Valida una carta. `ctx` opzionale: { known_keywords: Dictionary(set),
## duplicate: bool }. Restituisce Array[ {level, code, msg} ].
static func validate(card: Dictionary, geom: Dictionary, image, ctx := {}) -> Array:
	var out: Array = []

	# rank
	var rank := str(card.get("rank", "-"))
	if not (rank in RANKS):
		out.append(_issue("error", "rank", "rank non valido: '%s'" % rank))

	# type incoerente coi keywords
	var kws = card.get("keywords", [])
	var t := str(card.get("type", ""))
	if t != "":
		var derived := CardStore.derive_type(kws)
		if derived != t:
			out.append(_issue("warning", "type",
				"type '%s' incoerente coi keywords (atteso '%s')" % [t, derived]))

	# keyword sconosciute
	var known: Dictionary = ctx.get("known_keywords", {})
	if known.is_empty():
		known = _static_kw_set()
	if kws is Array:
		for k in kws:
			if not known.has(str(k)):
				out.append(_issue("warning", "keyword", "keyword sconosciuta: '%s'" % str(k)))

	# immagine mancante
	if str(image) == "":
		out.append(_issue("warning", "image", "immagine mancante"))

	# id duplicato
	if bool(ctx.get("duplicate", false)):
		out.append(_issue("error", "dup_id", "id duplicato"))

	# geometria
	if not geom.is_empty():
		var gt := str(geom.get("type", ""))
		var kr := str(geom.get("kamae_req", ""))
		if kr != "" and not (kr in KAMAE):
			out.append(_issue("error", "kamae_req", "kamae_req non valido: '%s'" % kr))
		# Le verifiche "senza celle" valgono solo se la geometria è stata avviata
		# (altrimenti è semplicemente "senza geometria", segnalato dall'indicatore ◇).
		var has_content := not (geom.get("attack", {}).get("cells", []) as Array).is_empty() \
			or not (geom.get("defence", {}).get("cells", []) as Array).is_empty() \
			or not (geom.get("move", {}).get("opts", []) as Array).is_empty() \
			or not (geom.get("effects", []) as Array).is_empty() \
			or not (geom.get("counter", []) as Array).is_empty() \
			or str(geom.get("kamae_req", "")) != ""
		if has_content:
			if gt == "attack" and (geom.get("attack", {}).get("cells", []) as Array).is_empty():
				out.append(_issue("warning", "no_attack", "carta d'attacco senza celle/ferite"))
			if gt == "defence" and (geom.get("defence", {}).get("cells", []) as Array).is_empty():
				out.append(_issue("warning", "no_defence", "carta di difesa senza celle di blocco"))
		for e in geom.get("effects", []):
			var verb := str(e.get("do", ""))
			if verb != "" and not (verb in EFFECT_VERBS):
				out.append(_issue("warning", "effect", "effetto sconosciuto: '%s'" % verb))
			# Stance bersaglio = 4 stance reali; switch_kamae ammette anche "any"
			# ("qualsiasi", risolto da Duel.gd). Niente falsi errori su neutral/any.
			if e.has("kamae"):
				var kv := str(e["kamae"])
				if kv != "" and not (kv in STANCES):
					out.append(_issue("error", "effect_kamae",
						"effetto '%s': kamae non valido '%s'" % [verb, kv]))
			if e.has("to"):
				var tv := str(e["to"])
				if tv != "" and tv != "any" and not (tv in STANCES):
					out.append(_issue("error", "effect_kamae",
						"effetto '%s': to non valido '%s'" % [verb, tv]))
	return out


static func _static_kw_set() -> Dictionary:
	var d := {}
	for k in STATIC_KEYWORDS:
		d[k] = true
	return d


## Insieme keyword "noto" = vocabolario statico ∪ keyword presenti nei dati reali
## (così i nomi delle armi non risultano "sconosciuti").
static func known_keywords_set() -> Dictionary:
	var d := _static_kw_set()
	for c in CardDB.cards:
		for k in c.get("keywords", []):
			d[str(k)] = true
	return d


## Comodità: valida una carta per id leggendo da CardDB.
static func validate_id(id: int) -> Array:
	var dup := 0
	for c in CardDB.cards:
		if int(c.get("id", -999999)) == id:
			dup += 1
	return validate(CardDB.card(id), CardDB.geometry(id), CardDB.image_for(id),
		{"known_keywords": known_keywords_set(), "duplicate": dup > 1})
