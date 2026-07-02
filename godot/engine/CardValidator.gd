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
	"bleed", "block_initiative", "cancel_abilities", "cancel_movement",
	"change_ai_behaviour", "change_approach", "change_kamae", "discard_self",
	"draw", "focus", "foe_discard", "foe_lose_focus", "foe_stun", "hobble",
	"link_anchor", "pull", "push", "reduce_damage", "replace_wound_bleed",
	"reset_deck", "rotate_target", "search_draw", "spend_focus",
	"state_add", "state_clear", "state_set", "stun_self",
	"swap_positions", "switch_kamae",
]

## Verbi che richiedono il campo `state` (nome dello stato persistente).
const STATE_VERBS := ["state_add", "state_clear", "state_set"]

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
		# kamae_req può essere una stringa singola o un Array in OR (Kamae.gate_values).
		var kr_list := Kamae.gate_values(geom.get("kamae_req", ""))
		for kr in kr_list:
			if not (str(kr) in KAMAE):
				out.append(_issue("error", "kamae_req", "kamae_req non valido: '%s'" % kr))
		# Le verifiche "senza celle" valgono solo se la geometria è stata avviata
		# (altrimenti è semplicemente "senza geometria", segnalato dall'indicatore ◇).
		var has_atk := _has_combat_cells(geom, "attack", "attacks")
		var has_def := _has_combat_cells(geom, "defence", "defences")
		var has_content := has_atk or has_def \
			or not (geom.get("move", {}).get("opts", []) as Array).is_empty() \
			or not (geom.get("effects", []) as Array).is_empty() \
			or not (geom.get("counter", []) as Array).is_empty() \
			or not kr_list.is_empty()
		if has_content:
			if gt == "attack" and not has_atk \
					and not _has_combat_cells(geom.get("split", {}), "attack", "attacks"):
				out.append(_issue("warning", "no_attack", "carta d'attacco senza celle/ferite"))
			if gt == "defence" and not has_def:
				out.append(_issue("warning", "no_defence", "carta di difesa senza celle di blocco"))
		# `state_req` (giocabilità gated dallo stato persistente): stessa forma
		# del campo `state` dei gate (Gate.gd) — stringa o dizionario nome→minimo.
		if geom.has("state_req"):
			out.append_array(_check_state_req(geom["state_req"], "state_req"))
		for e in geom.get("effects", []):
			var verb := str(e.get("do", ""))
			if verb != "" and not (verb in EFFECT_VERBS):
				out.append(_issue("warning", "effect", "effetto sconosciuto: '%s'" % verb))
			# Stance bersaglio = 4 stance reali; switch_kamae ammette anche "any"
			# ("qualsiasi", risolto da Duel.gd). Niente falsi errori su neutral/any.
			# Il gate può essere anche un Array in OR (Kamae.gate_values): si
			# valida ogni voce, senza str() sull'Array intero (falso errore).
			if e.has("kamae"):
				for kv in Kamae.gate_values(e["kamae"]):
					if str(kv) != "" and not (str(kv) in STANCES):
						out.append(_issue("error", "effect_kamae",
							"effetto '%s': kamae non valido '%s'" % [verb, str(kv)]))
			# Verbi di stato persistente: serve il nome dello stato.
			if (verb in STATE_VERBS) and str(e.get("state", "")) == "":
				out.append(_issue("error", "effect_state",
					"effetto '%s' senza campo state (nome dello stato)" % verb))
			# Gate di stato su un effetto qualsiasi (campo `state` non-verbo).
			elif e.has("state") and not (verb in STATE_VERBS):
				out.append_array(_check_state_req(e["state"], "effetto '%s'.state" % verb))
			if e.has("to"):
				var tv := str(e["to"])
				if tv != "" and tv != "any" and not (tv in STANCES):
					out.append(_issue("error", "effect_kamae",
						"effetto '%s': to non valido '%s'" % [verb, tv]))
	return out


## Valida un requisito di stato persistente (forma del campo `state`/`state_req`
## dei gate, vedi Gate.gd): stringa non vuota, oppure Dictionary nome→minimo
## intero >= 1. `where` è l'etichetta del campo per il messaggio.
static func _check_state_req(req, where: String) -> Array:
	var out: Array = []
	if req is Dictionary:
		if (req as Dictionary).is_empty():
			out.append(_issue("warning", "state_req", "%s: dizionario vuoto" % where))
		for state_name in req:
			if str(state_name) == "":
				out.append(_issue("error", "state_req", "%s: nome di stato vuoto" % where))
			if int(req[state_name]) < 1:
				out.append(_issue("error", "state_req",
					"%s: minimo non valido per '%s' (%s, atteso >= 1)" % [where, str(state_name), str(req[state_name])]))
	elif str(req) == "":
		out.append(_issue("warning", "state_req", "%s: vuoto" % where))
	return out


## Celle di combattimento presenti in forma singola (`attack`) O plurale
## gated-da-kamae (`attacks[]`) — il vecchio controllo guardava solo la singola
## e dava falsi "senza celle" sulle carte a varianti.
static func _has_combat_cells(geom: Dictionary, single: String, plural: String) -> bool:
	if not (geom.get(single, {}).get("cells", []) as Array).is_empty():
		return true
	for v in geom.get(plural, []):
		if v is Dictionary and not (v.get("cells", []) as Array).is_empty():
			return true
	return false


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
