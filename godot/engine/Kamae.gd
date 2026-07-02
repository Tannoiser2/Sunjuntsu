## Albero Kamae — Senjutsu
##
## Gestisce lo spostamento dell'anello sull'albero (dati in
## data/cards/kamae_trees.json):
##  • "Cambia Kamae fino a X": scorri lungo i rami fino a X passi; ogni ramo
##    ROSA attraversato dà +1 focus.
##  • "Passa a Y": vai diretto alla posizione (nessun ramo, nessun focus).
##
## Le posizioni valide (Kamae) sono aggression/balance/determination/neutral,
## più la quinta "distance" (onda blu, solo sull'albero del Navigatore);
## il nodo "focus" (loto) è un passaggio sui rami rosa.
## Gli archi con doppie frecce sulla carta fisica sono A SENSO UNICO
## (campo `dir: true` = percorribile solo da `a` verso `b`).
class_name Kamae
extends RefCounted

const STANCES := ["aggression", "balance", "determination", "neutral", "distance"]


## Gate Kamae (condizione "se sei in …"). Un gate può essere:
##   • assente / "" / [] / null  → nessun vincolo (sempre valido);
##   • una stringa (una sola Kamae) → forma classica;
##   • un Array di slug (più Kamae in OR) → valido in UNA QUALSIASI di esse.
## `gate_allows` dice se la stance corrente soddisfa il gate.
static func gate_allows(gate, stance_slug: String) -> bool:
	if gate == null:
		return true
	if gate is Array:
		return gate.is_empty() or (stance_slug in gate)
	var s := str(gate)
	return s == "" or s == stance_slug


## Vero se il gate non pone alcun vincolo (vuoto). Utile per distinguere le
## varianti "senza gate" (fallback) da quelle gated.
static func gate_is_empty(gate) -> bool:
	if gate == null:
		return true
	if gate is Array:
		return gate.is_empty()
	return str(gate) == ""


## Normalizza un gate (String, Array o assente) a una lista di slug — vuota se
## nessun vincolo. Evita di ripetere l'if String/Array in ogni chiamante.
static func gate_values(gate) -> Array:
	if gate == null:
		return []
	if gate is Array:
		return (gate as Array).duplicate()
	var s := str(gate)
	return [s] if s != "" else []



static func _adj(tree: Dictionary) -> Dictionary:
	var a := {}
	for e in tree.get("edges", []):
		var x: String = e["a"]
		var y: String = e["b"]
		var pink: bool = e.get("pink", false)
		a.get_or_add(x, []).append({"to": y, "pink": pink})
		if not bool(e.get("dir", false)):   # senza frecce: percorribile nei due sensi
			a.get_or_add(y, []).append({"to": x, "pink": pink})
	return a


## Destinazioni raggiungibili da `start` entro `n` passi lungo i rami
## (rispettando i sensi unici). Restituisce
## { stance(String) : focus_massimo_guadagnato }.
static func change_targets(tree: Dictionary, start: String, n: int) -> Dictionary:
	var adj := _adj(tree)
	var best := {}   # stance -> max focus con cui è raggiungibile entro n passi
	# Espansione a livelli: al passo k, `level` mappa nodo -> focus massimo di
	# un cammino di ESATTAMENTE k passi che ci arriva. Fermarsi prima è sempre
	# possibile: `best` raccoglie il massimo su tutti i livelli 1..n.
	var level := {start: 0}
	for _step in range(maxi(0, n)):
		var next := {}
		for node in level:
			for edge in adj.get(node, []):
				var nf: int = int(level[node]) + (1 if edge["pink"] else 0)
				if nf > int(next.get(edge["to"], -1)):
					next[edge["to"]] = nf
		for node in next:
			if node in STANCES and node != start and int(next[node]) > int(best.get(node, -1)):
				best[node] = next[node]
		level = next
	return best
