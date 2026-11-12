class_name Hex
extends RefCounted
## Matematica esagonale (coordinate assiali, esagoni "flat-top").
## Orientamenti 0..5 in senso orario partendo da Nord.

const DIRS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0)]
const NOMI_DIR := ["Fronte", "Fronte-Dx", "Retro-Dx", "Retro", "Retro-Sx", "Fronte-Sx"]


static func dist(a: Vector2i, b: Vector2i) -> int:
	var dq := a.x - b.x
	var dr := a.y - b.y
	return (absi(dq) + absi(dr) + absi(dq + dr)) / 2


## Da (colonna, riga) "odd-q" ad assiali.
static func da_offset(col: int, row: int) -> Vector2i:
	return Vector2i(col, row - (col - (col & 1)) / 2)


## Centro dell'esagono in unità piane (lato = size): x a destra, y in basso.
static func centro(c: Vector2i, size: float = 1.0) -> Vector2:
	return Vector2(1.5 * c.x, sqrt(3.0) * (c.y + c.x / 2.0)) * size


## Segue un percorso di direzioni relative al fronte ("0", "01", "55"...).
static func walk(pos: Vector2i, face: int, path: String) -> Vector2i:
	var p := pos
	for ch in path:
		p += DIRS[(face + int(ch)) % 6]
	return p


static func euclid(a: Vector2i, b: Vector2i) -> float:
	return centro(a).distance_to(centro(b))


## Orientamento (0..5) che da `a` guarda il più possibile verso `b`.
static func verso(a: Vector2i, b: Vector2i) -> int:
	var best := 0
	var bd := 1e9
	for d in 6:
		var dd := euclid(a + DIRS[d], b)
		if dd < bd - 0.001:
			bd = dd
			best = d
	return best


## Vero se OGNI percorso più breve da `a` a `b` attraversa una cella bloccata
## (regola dei blocchi). Con a e b adiacenti non ci sono celle intermedie: falso.
static func percorsi_bloccati(a: Vector2i, b: Vector2i, bloccate: Array) -> bool:
	var d := dist(a, b)
	if d <= 1:
		return false
	var pila: Array = [a]
	var visti := {}
	while not pila.is_empty():
		var c: Vector2i = pila.pop_back()
		if visti.has(c):
			continue
		visti[c] = true
		for k in 6:
			var n: Vector2i = c + DIRS[k]
			if dist(n, b) != dist(c, b) - 1:
				continue
			if n == b:
				return false
			if not bloccate.has(n):
				pila.append(n)
	return true
