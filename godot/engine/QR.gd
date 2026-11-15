class_name QR
extends RefCounted
## Codice QR (modalità byte, correzione L, versioni 1-5) per l'indirizzo della pagina del telefono.

const DATI := [0, 19, 34, 55, 80, 108]        ## byte di dati per versione (correzione L)
const EC := [0, 7, 10, 15, 20, 26]            ## byte di correzione per versione
const ALLINEA := [0, 0, 18, 22, 26, 30]       ## posizione del motivo di allineamento


## Matrice di bool (true = modulo nero), lato = 17 + 4 * versione.
static func matrice(testo: String) -> Array:
	var byte := testo.to_utf8_buffer()
	var v := 1
	while v <= 5 and byte.size() + 2 > DATI[v]:
		v += 1
	if v > 5:
		push_error("testo troppo lungo per il QR")
		return []
	# flusso di bit: modalità 0100, lunghezza 8 bit, dati, terminatore, riempimento
	var bit: Array = []
	_metti(bit, 4, 4)
	_metti(bit, byte.size(), 8)
	for x in byte:
		_metti(bit, x, 8)
	var cap: int = DATI[v] * 8
	for _i in mini(4, cap - bit.size()):
		bit.append(0)
	while bit.size() % 8 != 0:
		bit.append(0)
	var dati: Array = []
	for i in range(0, bit.size(), 8):
		var b := 0
		for j in 8:
			b = (b << 1) | int(bit[i + j])
		dati.append(b)
	var pad := [0xEC, 0x11]
	var k := 0
	while dati.size() < DATI[v]:
		dati.append(pad[k % 2])
		k += 1
	var tutti: Array = dati + _reed_solomon(dati, EC[v])
	var n := 17 + 4 * v
	var m: Array = []
	var fisso: Array = []
	for y in n:
		var r: Array = []
		var f: Array = []
		r.resize(n)
		f.resize(n)
		r.fill(false)
		f.fill(false)
		m.append(r)
		fisso.append(f)
	# motivi di posizione e separatori
	for c in [[0, 0], [n - 7, 0], [0, n - 7]]:
		for dy in range(-1, 8):
			for dx in range(-1, 8):
				var x: int = c[0] + dx
				var y: int = c[1] + dy
				if x < 0 or y < 0 or x >= n or y >= n:
					continue
				var nero: bool = dx >= 0 and dx <= 6 and dy >= 0 and dy <= 6 and (dx == 0 or dx == 6 or dy == 0 or dy == 6 or (dx >= 2 and dx <= 4 and dy >= 2 and dy <= 4))
				m[y][x] = nero
				fisso[y][x] = true
	# linee di temporizzazione
	for i in range(8, n - 8):
		m[6][i] = i % 2 == 0
		m[i][6] = i % 2 == 0
		fisso[6][i] = true
		fisso[i][6] = true
	# allineamento
	if v >= 2:
		var a: int = ALLINEA[v]
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				m[a + dy][a + dx] = maxi(absi(dx), absi(dy)) != 1
				fisso[a + dy][a + dx] = true
	# modulo scuro e zone del formato
	m[n - 8][8] = true
	fisso[n - 8][8] = true
	for i in 9:
		fisso[8][i] = true
		fisso[i][8] = true
	for i in 8:
		fisso[8][n - 1 - i] = true
		fisso[n - 1 - i][8] = true
	# posa dei dati a zig-zag
	var flusso: Array = []
	for b in tutti:
		_metti(flusso, b, 8)
	var idx := 0
	var su := true
	var col := n - 1
	while col > 0:
		if col == 6:
			col -= 1
		for i in n:
			var y: int = (n - 1 - i) if su else i
			for dx in 2:
				var x: int = col - dx
				if fisso[y][x]:
					continue
				var b := false
				if idx < flusso.size():
					b = flusso[idx] == 1
				idx += 1
				# maschera 0: (riga + colonna) pari
				if (x + y) % 2 == 0:
					b = not b
				m[y][x] = b
		su = not su
		col -= 2
	# informazioni di formato: correzione L (01), maschera 0
	var fmt: int = _formato((1 << 3) | 0)
	var bitf := func(i: int) -> bool: return ((fmt >> i) & 1) == 1
	for i in 6:
		m[i][8] = bitf.call(i)
	m[7][8] = bitf.call(6)
	m[8][8] = bitf.call(7)
	m[8][7] = bitf.call(8)
	for i in range(9, 15):
		m[8][14 - i] = bitf.call(i)
	for i in 8:
		m[8][n - 1 - i] = bitf.call(i)
	for i in range(8, 15):
		m[n - 15 + i][8] = bitf.call(i)
	return m


static func _metti(arr: Array, val: int, nb: int) -> void:
	for i in range(nb - 1, -1, -1):
		arr.append((val >> i) & 1)


static func _formato(d: int) -> int:
	var r := d << 10
	for i in range(14, 9, -1):
		if (r >> i) & 1:
			r ^= 0x537 << (i - 10)
	return ((d << 10) | r) ^ 0x5412


static func _gf_mul(a: int, b: int) -> int:
	var r := 0
	while b > 0:
		if b & 1:
			r ^= a
		a <<= 1
		if a & 0x100:
			a ^= 0x11D
		b >>= 1
	return r


static func _reed_solomon(dati: Array, n: int) -> Array:
	# polinomio generatore
	var gen: Array = [1]
	var root := 1
	for _i in n:
		var nuovo: Array = []
		nuovo.resize(gen.size() + 1)
		nuovo.fill(0)
		for j in gen.size():
			nuovo[j] ^= gen[j]
			nuovo[j + 1] ^= _gf_mul(gen[j], root)
		gen = nuovo
		root = _gf_mul(root, 2)
	var res: Array = []
	res.resize(n)
	res.fill(0)
	for b in dati:
		var f: int = b ^ int(res[0])
		res.pop_front()
		res.append(0)
		for j in n:
			res[j] ^= _gf_mul(gen[j + 1], f)
	return res


## Immagine del codice con margine bianco di 4 moduli.
static func immagine(testo: String, px: int = 6) -> Image:
	var m := matrice(testo)
	var n := m.size()
	var lato := (n + 8) * px
	var img := Image.create(lato, lato, false, Image.FORMAT_RGB8)
	img.fill(Color.WHITE)
	for y in n:
		for x in n:
			if m[y][x]:
				img.fill_rect(Rect2i((x + 4) * px, (y + 4) * px, px, px), Color.BLACK)
	return img
