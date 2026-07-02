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
	"draw", "flip_kamae", "focus", "foe_change_kamae", "foe_discard", "foe_draw",
	"foe_lose_focus", "foe_reveal_hand", "foe_stun", "foe_switch_kamae",
	"foe_mill", "heal", "hobble", "link_anchor", "mill", "place_traps",
	"pull", "push", "reduce_damage",
	"replace_wound_bleed",
	"reset_deck", "rotate_target", "search_draw", "spend_focus",
	"state_add", "state_clear", "state_set", "stun_self",
	"swap_positions", "switch_kamae",
]

## Verbi che richiedono il campo `state` (nome dello stato persistente).
const STATE_VERBS := ["state_add", "state_clear", "state_set"]

## Bersagli ammessi per `heal.what` (rimozione ferite/stati, §3.20).
const HEAL_WHAT := ["wound", "bleed", "stun", "hobble", "poison"]

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
		# `alt_initiative` (§3.1): { value: int > 0, kamae?/focus_cost?/state? }.
		if geom.has("alt_initiative"):
			var ai = geom["alt_initiative"]
			if not (ai is Dictionary) or int((ai as Dictionary).get("value", 0)) < 1:
				out.append(_issue("error", "alt_initiative",
					"alt_initiative non valido: atteso { value: int >= 1, gate opzionale }"))
			else:
				for kv in Kamae.gate_values(ai.get("kamae", "")):
					if not (str(kv) in KAMAE):
						out.append(_issue("error", "alt_initiative",
							"alt_initiative: kamae non valido '%s'" % str(kv)))
				if ai.has("state"):
					out.append_array(_check_state_req(ai["state"], "alt_initiative.state"))
		# Campi "RIMANE IN GIOCO" (§3.2): in_play_state stringa non vuota;
		# limit_mod con sole chiavi hand/wound/focus; expires.turns >= 1;
		# turn_start = lista effetti con verbi noti.
		if geom.has("in_play_state") and str(geom["in_play_state"]) == "":
			out.append(_issue("error", "in_play", "in_play_state vuoto"))
		for lk in geom.get("limit_mod", {}):
			if not (str(lk) in ["hand", "wound", "focus"]):
				out.append(_issue("error", "in_play", "limit_mod: chiave sconosciuta '%s'" % str(lk)))
		if geom.has("expires") and int(geom["expires"].get("turns", 0)) < 1:
			out.append(_issue("error", "in_play", "expires.turns deve essere >= 1"))
		for te in geom.get("turn_start", []):
			var tv := str(te.get("do", ""))
			if tv == "" or not (tv in EFFECT_VERBS):
				out.append(_issue("warning", "in_play", "turn_start: effetto sconosciuto '%s'" % tv))
		var has_in_play_fields: bool = geom.has("in_play_state") or geom.has("limit_mod") \
				or geom.has("expires") or not (geom.get("turn_start", []) as Array).is_empty()
		if has_in_play_fields and not bool(geom.get("stays_in_play", false)):
			out.append(_issue("warning", "in_play",
				"campi in-gioco presenti ma stays_in_play assente (non entreranno mai in gioco)"))
		# `face_defence` (doppia faccia Hachikō, §3.14): oggetto con la parte
		# della faccia difesa; senza `initiative` la faccia userebbe quella
		# dell'anagrafica (quasi certamente una dimenticanza di trascrizione).
		if geom.has("face_defence"):
			var fdv = geom["face_defence"]
			if not (fdv is Dictionary):
				out.append(_issue("error", "face", "face_defence deve essere un oggetto"))
			elif not (fdv as Dictionary).has("initiative"):
				out.append(_issue("warning", "face", "face_defence senza initiative propria"))
		# `play_when` (§3.26): finestre di gioco speciali supportate.
		if geom.has("play_when") and str(geom["play_when"]) != "defeated":
			out.append(_issue("error", "play_when",
				"play_when non valido: '%s' (supportato: defeated)" % str(geom["play_when"])))
		# `limit_set` (§3.26): valori assoluti dei limiti.
		for lsk in geom.get("limit_set", {}):
			if not (str(lsk) in ["wound", "hand"]) or int(geom["limit_set"][lsk]) < 1:
				out.append(_issue("error", "limit_set",
					"limit_set: chiave/valore non validi ('%s')" % str(lsk)))
		# `on_foe_discard` (§3.27).
		if geom.has("on_foe_discard") and str(geom["on_foe_discard"]) != "return_to_play":
			out.append(_issue("error", "on_foe_discard",
				"on_foe_discard non valido: '%s' (supportato: return_to_play)" % str(geom["on_foe_discard"])))
		# `targeting` (§3.4): mode "initiative", threshold int >= 1 se presente.
		if geom.has("targeting"):
			var tg = geom["targeting"]
			if not (tg is Dictionary) or str(tg.get("mode", "")) != "initiative":
				out.append(_issue("error", "targeting", "targeting.mode deve essere 'initiative'"))
			elif tg.has("threshold") and int(tg.get("threshold", 0)) < 1:
				out.append(_issue("error", "targeting", "targeting.threshold deve essere >= 1"))
		# `counter`: int (sempre attivo) o oggetto gated { on: [..], gate }.
		for entry in geom.get("counter", []):
			if entry is Dictionary:
				if (entry.get("on", []) as Array).is_empty():
					out.append(_issue("error", "counter",
						"voce counter gated senza lista 'on' di iniziative"))
				for kv in Kamae.gate_values(entry.get("kamae", "")):
					if not (str(kv) in KAMAE):
						out.append(_issue("error", "counter",
							"counter: kamae non valido '%s'" % str(kv)))
				if entry.has("state"):
					out.append_array(_check_state_req(entry["state"], "counter.state"))
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
			# place_traps: servono le celle, kind nel vocabolario.
			if verb == "place_traps":
				if (e.get("cells", []) as Array).is_empty():
					out.append(_issue("error", "effect", "place_traps senza celle"))
				for cdef in e.get("cells", []):
					if not (str(cdef.get("kind", "caltrop")) in ["caltrop", "decoy"]):
						out.append(_issue("error", "effect",
							"place_traps: kind non valido '%s'" % str(cdef.get("kind", ""))))
			# heal: bersaglio `what` nel vocabolario.
			if verb == "heal" and not (str(e.get("what", "wound")) in HEAL_WHAT):
				out.append(_issue("error", "effect",
					"heal: what non valido '%s'" % str(e.get("what", ""))))
			# n_from_state: nome di stato non vuoto.
			if e.has("n_from_state") and str(e["n_from_state"]) == "":
				out.append(_issue("error", "effect",
					"effetto '%s': n_from_state vuoto" % verb))
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
