## Albero Kamae — Senjutsu
##
## Gestisce lo spostamento dell'anello sull'albero (dati in
## data/cards/kamae_trees.json):
##  • "Cambia Kamae fino a X": scorri lungo i rami fino a X passi; ogni ramo
##    ROSA attraversato dà +1 focus.
##  • "Passa a Y": vai diretto alla posizione (nessun ramo, nessun focus).
##
## Le 4 posizioni valide (Kamae) sono aggression/balance/determination/neutral;
## il nodo "focus" (loto) è un passaggio sui rami rosa.
class_name Kamae
extends RefCounted

const STANCES := ["aggression", "balance", "determination", "neutral"]


static func _adj(tree: Dictionary) -> Dictionary:
	var a := {}
	for e in tree.get("edges", []):
		var x: String = e["a"]
		var y: String = e["b"]
		var pink: bool = e.get("pink", false)
		a.get_or_add(x, []).append({"to": y, "pink": pink})
		a.get_or_add(y, []).append({"to": x, "pink": pink})
	return a


## Destinazioni raggiungibili da `start` entro `n` passi lungo i rami.
## Restituisce { stance(String) : focus_massimo_guadagnato }.
static func change_targets(tree: Dictionary, start: String, n: int) -> Dictionary:
	var adj := _adj(tree)
	var best := {}   # node -> max focus raggiungendolo entro n passi
	# Stato: [node, passi_usati, focus]. Esplora tenendo il focus massimo.
	var frontier := [[start, 0, 0]]
	best[start] = 0
	while not frontier.is_empty():
		var cur = frontier.pop_front()
		var node: String = cur[0]
		var used: int = cur[1]
		var foc: int = cur[2]
		if used >= n:
			continue
		for edge in adj.get(node, []):
			var nf: int = foc + (1 if edge["pink"] else 0)
			var to: String = edge["to"]
			if not best.has(to) or nf > best[to] or used + 1 < _steps_to(best, to):
				# accetta se nuovo, o con più focus
				if not best.has(to) or nf > best[to]:
					best[to] = nf
				frontier.append([to, used + 1, nf])
	# Solo le posizioni Kamae valide (escludi il nodo "focus"), escludi start.
	var out := {}
	for node in best.keys():
		if node in STANCES and node != start:
			out[node] = best[node]
	return out


static func _steps_to(_best: Dictionary, _node: String) -> int:
	return 99  # segnaposto; manteniamo la ricerca semplice (n piccolo)
