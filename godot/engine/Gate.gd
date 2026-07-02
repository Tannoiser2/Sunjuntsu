## Gate unificato — Senjutsu (vedi docs/GATE_AUDIT.md)
##
## Un "gate" è la condizione ricorrente "questa (carta | sotto-parte) vale solo
## se…" espressa dagli stessi campi piatti ovunque appaia (atomi di movimento,
## varianti di combattimento, effetti, counter, alt_initiative, …):
##   • `kamae`: String o Array (OR fra più Kamae) — vedi Kamae.gate_allows;
##   • `focus_cost`: int — costo in focus (0/assente = gratis);
##   • `state`: String ("ombra" ≡ almeno 1) o Dictionary nome→minimo richiesto
##     (es. {"contratti": 2}, AND fra le chiavi) — letto da Fighter.states.
## I campi presenti valgono in AND fra loro; tutti assenti = sempre valido.
##
## Convenzione d'uso (stessa regola già in vigore per effetti e celle):
## in AUTO-risoluzione le parti a pagamento (focus_cost > 0) si SALTANO
## (`auto_allows`); in partita interattiva si offre il pagamento al giocatore.
class_name Gate
extends RefCounted


## Il gate Kamae della parte è soddisfatto dalla stance corrente?
static func kamae_ok(part: Dictionary, stance_slug: String) -> bool:
	return Kamae.gate_allows(part.get("kamae", ""), stance_slug)


## Il requisito di stato `req` (valore grezzo del campo `state`) è soddisfatto
## dagli stati persistenti `states` (Fighter.states)? Forme ammesse:
##   null / ""            → nessun vincolo;
##   "ombra"              → states["ombra"] >= 1;
##   {"contratti": 2, …}  → ogni chiave >= minimo (AND).
static func state_req_ok(req, states: Dictionary) -> bool:
	if req == null:
		return true
	if req is Dictionary:
		for state_name in req:
			if int(states.get(str(state_name), 0)) < int(req[state_name]):
				return false
		return true
	var s := str(req)
	return s == "" or int(states.get(s, 0)) >= 1


## Come `state_req_ok`, leggendo il campo `state` della parte.
static func state_ok(part: Dictionary, states: Dictionary) -> bool:
	return state_req_ok(part.get("state", null), states)


## Condizioni di STATO del gate (Kamae + stati persistenti), senza il focus:
## usare quando il pagamento è gestito a parte (partita interattiva).
static func allows(part: Dictionary, stance_slug: String, states: Dictionary = {}) -> bool:
	return kamae_ok(part, stance_slug) and state_ok(part, states)


## Parte di gate di un EFFETTO: sui verbi `state_*` il campo `state` è il
## NOME dello stato bersaglio, non una condizione — va escluso dal gate,
## altrimenti "ENTRA IN Occultato" richiederebbe di essere già Occultato
## (bug scovato dal primo giro di test reali su Godot 4.6.3).
static func effect_gate(e: Dictionary) -> Dictionary:
	if str(e.get("do", "")).begins_with("state_") and e.has("state"):
		var copy := e.duplicate()
		copy.erase("state")
		return copy
	return e


## Costo in focus della parte (0 se assente).
static func cost(part: Dictionary) -> int:
	return int(part.get("focus_cost", 0))


## Gate completo per l'AUTO-risoluzione: condizioni di stato soddisfatte E
## nessun costo focus (le parti a pagamento sono facoltative e si saltano).
static func auto_allows(part: Dictionary, stance_slug: String, states: Dictionary = {}) -> bool:
	return allows(part, stance_slug, states) and cost(part) == 0
