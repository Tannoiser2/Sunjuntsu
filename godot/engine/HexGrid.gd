## Matematica esagonale per la mappa di Senjutsu.
##
## Coordinate assiali (q, r), orientamento FLAT-TOP, conversione diretta a
## coordinate mondo 3D sul piano XZ (Y = altezza). Tutte le funzioni sono
## statiche — nessuno stato interno.
##
## Adattato dall'impianto usato in Combat Commander, semplificato ad assiali.
class_name HexGrid
extends RefCounted

# Direzioni assiali dei sei vicini (flat-top).
const DIRS: Array[Vector2i] = [
	Vector2i( 1,  0), Vector2i( 1, -1), Vector2i( 0, -1),
	Vector2i(-1,  0), Vector2i(-1,  1), Vector2i( 0,  1),
]


# ─── Topologia ────────────────────────────────────────────────────────────────

static func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in DIRS:
		out.append(cell + d)
	return out


## Ruota un offset assiale di `steps` passi da 60°, coerente con l'indicizzazione
## delle direzioni del motore: DIRS[d] ruotato di `steps` -> DIRS[d + steps].
## Usato per orientare le celle di una carta secondo il facing del combattente.
static func rotate(cell: Vector2i, steps: int) -> Vector2i:
	var q := cell.x
	var r := cell.y
	for _i in range(((steps % 6) + 6) % 6):
		var nq := q + r
		var nr := -q
		q = nq
		r = nr
	return Vector2i(q, r)


## Distanza in esagoni (metrica cubica).
static func distance(a: Vector2i, b: Vector2i) -> int:
	var ac := _to_cube(a)
	var bc := _to_cube(b)
	return int((abs(ac.x - bc.x) + abs(ac.y - bc.y) + abs(ac.z - bc.z)) / 2)


static func _to_cube(c: Vector2i) -> Vector3i:
	var x := c.x
	var z := c.y
	var y := -x - z
	return Vector3i(x, y, z)


static func _from_cube(cube: Vector3) -> Vector2i:
	# Arrotondamento cubico per la conversione da mondo.
	var rx: float = roundf(cube.x)
	var ry: float = roundf(cube.y)
	var rz: float = roundf(cube.z)
	var dx: float = absf(rx - cube.x)
	var dy: float = absf(ry - cube.y)
	var dz: float = absf(rz - cube.z)
	if dx > dy and dx > dz:
		rx = -ry - rz
	elif dy > dz:
		ry = -rx - rz
	else:
		rz = -rx - ry
	return Vector2i(int(rx), int(rz))


# ─── Conversione mondo 3D (piano XZ) ─────────────────────────────────────────

## Centro dell'esagono (q, r) in coordinate mondo, dato il raggio `size`.
static func hex_to_world(cell: Vector2i, size: float) -> Vector3:
	var x := size * 1.5 * cell.x
	var z := size * sqrt(3.0) * (cell.y + cell.x / 2.0)
	return Vector3(x, 0.0, z)


## Esagono più vicino a una posizione mondo (per il click su mappa).
static func world_to_hex(pos: Vector3, size: float) -> Vector2i:
	var q := (2.0 / 3.0 * pos.x) / size
	var r := (-1.0 / 3.0 * pos.x + sqrt(3.0) / 3.0 * pos.z) / size
	return _from_cube(Vector3(q, -q - r, r))


# ─── Area e raggio ───────────────────────────────────────────────────────────

## Tutti gli esagoni entro `radius` da `center` (disco esagonale).
static func hexes_in_range(center: Vector2i, radius: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dq in range(-radius, radius + 1):
		for dr in range(max(-radius, -dq - radius), min(radius, -dq + radius) + 1):
			out.append(center + Vector2i(dq, dr))
	return out


## Anello di esagoni a distanza esatta `radius` dal centro.
static func ring(center: Vector2i, radius: int) -> Array[Vector2i]:
	if radius <= 0:
		return [center]
	var out: Array[Vector2i] = []
	var cell := center + DIRS[4] * radius
	for i in range(6):
		for _j in range(radius):
			out.append(cell)
			cell += DIRS[i]
	return out


# ─── Pathfinding (BFS su celle valide) ───────────────────────────────────────

## Esagoni raggiungibili entro `budget` passi, escludendo celle bloccate/occupate.
## `is_blocked` è un Callable(Vector2i) -> bool.
static func reachable(start: Vector2i, budget: int, is_blocked: Callable) -> Array[Vector2i]:
	var visited := {start: 0}
	var frontier: Array[Vector2i] = [start]
	var result: Array[Vector2i] = []
	while not frontier.is_empty():
		var cur: Vector2i = frontier.pop_front()
		var spent: int = visited[cur]
		if spent >= budget:
			continue
		for nb in neighbors(cur):
			if visited.has(nb):
				continue
			if is_blocked.call(nb):
				continue
			visited[nb] = spent + 1
			frontier.append(nb)
			result.append(nb)
	return result
