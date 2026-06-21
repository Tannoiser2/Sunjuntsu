## Motore di movimento fedele — Senjutsu
##
## Calcola gli stati (cella + facing) raggiungibili applicando la specifica di
## movimento di una carta, secondo il regolamento 1.5:
##   • Step X: muove X esagoni in una direzione relativa al facing (0=avanti,
##     senso orario; -1 = qualsiasi direzione). Freccia piena = obbligatorio,
##     vuota = opzionale.
##   • Rotate X: ruota fino a X passi a sinistra/destra (curva piena = obblig.).
##   • Anchor (❄): marcatore-àncora sulla Griglia di Posizione — NON muove la
##     pedina. Una carta Abilità può collegarlo a un asterisco (*) applicando
##     quegli effetti al personaggio colpito.
##   • Più atomi sulla stessa riga: ordine/combinazione liberi (a meno di "then"
##     → ordered=true). Più righe "OPPURE" → opzioni alternative.
##
## Formato spec (in geometry.json, campo "move"):
##   {"opts": [ {"ordered": false, "atoms": [
##        {"t":"step","dir":0,"n":1,"opt":false},
##        {"t":"rot","n":1,"opt":true} ]} ]}
class_name Move
extends RefCounted


## Stati raggiungibili come Array[Vector3i] (x=q, y=r, z=facing 0..5).
## `stance_slug` filtra gli atomi gated dalla Kamae: un atomo con campo "kamae"
## si applica solo se uguale alla stance corrente ("" = nessun filtro).
static func reachable_states(cell: Vector2i, facing: int, spec, is_blocked: Callable, stance_slug: String = "") -> Array:
	var seen := {}
	var start := Vector3i(cell.x, cell.y, facing)
	if spec == null or typeof(spec) != TYPE_DICTIONARY or (spec.get("opts", []) as Array).is_empty():
		seen[_k(start)] = start
		return seen.values()
	for opt in spec.get("opts", []):
		var atoms: Array = []
		for a in opt.get("atoms", []):
			var gate: String = a.get("kamae", "")
			if gate == "" or gate == stance_slug:
				atoms.append(a)
		var ordered: bool = opt.get("ordered", false)
		_enum(start, atoms, ordered, is_blocked, seen)
	return seen.values()


## Mappa cella → Array[int] dei facing legali ottenibili muovendoci.
static func reachable_by_cell(cell: Vector2i, facing: int, spec, is_blocked: Callable, stance_slug: String = "") -> Dictionary:
	var out := {}
	for s in reachable_states(cell, facing, spec, is_blocked, stance_slug):
		var c := Vector2i(s.x, s.y)
		if not out.has(c):
			out[c] = []
		if not out[c].has(s.z):
			out[c].append(s.z)
	return out


static func _k(s: Vector3i) -> String:
	return "%d,%d,%d" % [s.x, s.y, s.z]


static func _enum(state: Vector3i, remaining: Array, ordered: bool, is_blocked: Callable, seen: Dictionary) -> void:
	# Stato terminale valido solo se tutti gli atomi rimasti sono opzionali.
	var all_opt := true
	for a in remaining:
		if not a.get("opt", false):
			all_opt = false
			break
	if all_opt:
		seen[_k(state)] = state
	if remaining.is_empty():
		return
	var idxs: Array = [0] if ordered else range(remaining.size())
	for i in idxs:
		var atom: Dictionary = remaining[i]
		var rest: Array = remaining.duplicate()
		rest.remove_at(i)
		for ns in _apply(atom, state, is_blocked):
			_enum(ns, rest, ordered, is_blocked, seen)
		if atom.get("opt", false):
			_enum(state, rest, ordered, is_blocked, seen)   # salta l'atomo opzionale


static func _apply(atom: Dictionary, state: Vector3i, is_blocked: Callable) -> Array:
	var out: Array = []
	if atom.get("t", "") == "anchor":
		# ❄ Fiocco di neve: NON è un movimento. È un marcatore-àncora sulla
		# Griglia di Posizione; una carta Abilità può collegarlo a un asterisco
		# (*) e applicare quegli effetti al personaggio colpito. Di per sé non
		# sposta la pedina: l'atomo è "soddisfatto" senza cambiare stato.
		return [state]
	if atom.get("t", "") == "rot":
		var n: int = int(atom.get("n", 1))
		for k in range(-n, n + 1):
			if k == 0:
				continue
			out.append(Vector3i(state.x, state.y, (state.z + k + 6) % 6))
		return out
	# step
	var nn: int = int(atom.get("n", 1))
	# "dirs": elenco esplicito di direzioni relative (es. arco frontale [5,0,1]).
	# Altrimenti "dir" singola (-1 = qualsiasi direzione).
	var dirs: Array
	if atom.has("dirs"):
		dirs = atom.get("dirs", [])
	else:
		var dir: int = int(atom.get("dir", 0))
		dirs = ([dir] if dir >= 0 else [0, 1, 2, 3, 4, 5])
	for d in dirs:
		var ad: int = (state.z + int(d)) % 6
		var cur := Vector2i(state.x, state.y)
		var ok := true
		for _s in range(nn):
			cur += HexGrid.DIRS[ad]
			if is_blocked.call(cur):
				ok = false
				break
		if ok:
			out.append(Vector3i(cur.x, cur.y, state.z))
	return out
