class_name Bot
extends RefCounted
## IA di base: gioca il mazzo come un giocatore, con euristiche semplici.
## (Le carte Solo ufficiali con Comportamenti/Atteggiamenti sono un passo successivo.)

var rng := RandomNumberGenerator.new()
var io := 0


func _init(indice: int, seme: int = 7) -> void:
	io = indice
	rng.seed = seme


func decidi(g: Game, req: Dictionary) -> int:
	var f: Dictionary = g.F[io]
	var opts: Array = req.opts
	var nem = null
	for o in g.F:
		if o.i != io and not o.dead:
			nem = o
	match req.kind:
		"place", "move":
			return _mossa(g, f, nem, req)
		"card":
			if req.get("scarto", false):
				return _peggiore(g, f, opts)
			if req.get("dal_mazzo", false) or req.text.contains("scarta una carta"):
				return rng.randi_range(0, opts.size() - 1)
			return _carta(g, f, nem, opts)
		"yesno":
			return 0
		"replace":
			return 0
		"speed":
			return _velocita(g, nem, opts)
		"instant", "counter":
			return 1
		"draw":
			for i in opts.size():
				if int(opts[i].v) <= maxi(0, f.deck.size() - 1):
					return i
			return opts.size() - 1
		"kamae":
			var best := 0
			var bv := -99.0
			for i in opts.size():
				var v := float(opts[i].get("focus", 0)) * (2.0 if f.focus < 3 else 0.0) + rng.randf()
				if opts[i].get("to", "") == "aggression":
					v += 1.0
				if v > bv:
					bv = v
					best = i
			return best
		"hex":
			return rng.randi_range(0, opts.size() - 1)
	return rng.randi_range(0, opts.size() - 1) if req.kind == "choice" and opts.size() > 2 else 0


func _mossa(g: Game, f: Dictionary, nem, req: Dictionary) -> int:
	var opts: Array = req.opts
	var best := 0
	var bv := 1e9
	var centro := Vector2i(3, -1)
	for i in opts.size():
		var p: Vector2i = opts[i].pos
		var bersaglio: Vector2i = centro
		var v := 0.0
		if nem != null and nem.pos.x < 50:
			bersaglio = nem.pos
			v += absf(Hex.dist(p, nem.pos) - 1.0) * 3.0
			# meglio non stare davanti al nemico
			if Hex.walk(nem.pos, nem.face, "0") == p:
				v += 0.7
		var guarda := Hex.verso(p, bersaglio)
		var diff: int = absi(int(opts[i].face) - guarda)
		v += minf(diff, 6 - diff) * 2.0 + rng.randf() * 0.5
		if req.kind == "place":
			v = minf(diff, 6 - diff) * 2.0 + rng.randf()
		if v < bv:
			bv = v
			best = i
	return best


func _carta(g: Game, f: Dictionary, nem, opts: Array) -> int:
	var best := 0
	var bv := -1e9
	var d := 9 if nem == null else Hex.dist(f.pos, nem.pos)
	var stun := g.conta_stun(f)
	for i in opts.size():
		var id: int = opts[i].card
		var v := rng.randf() * 3.0
		if id < 0:
			v += 2.0 + stun * 2.5
		else:
			var c := Carte.carta(id)
			match c.type:
				"attack":
					if g.carta_puo_colpire(f, id):
						v += 9.0 + _danno(c) * 3.0
					else:
						v += 0.5
					if c.get("core", false) and g.conta_mano(f) <= 1:
						v -= 3.0
				"defence":
					v += 5.5 if d <= 2 else 1.0
				"meditation":
					v += 4.0 + (2.0 if g.conta_mano(f) <= 3 else 0.0) + (1.5 if f.focus == 0 else 0.0)
				"core":
					v += 2.0 + (5.0 if g.conta_mano(f) <= 2 else 0.0)
		if v > bv:
			bv = v
			best = i
	return best


func _danno(c: Dictionary) -> float:
	var m := 0.0
	for s in c.segs:
		for l in s.lines:
			if l.t == "grid" and l.mode == "atk":
				for k in l.cells:
					var e: String = l.cells[k]
					m = maxf(m, 5.0 if e.begins_with("x") else (2.0 if e.begins_with("w2") else 1.0))
	return m


func _velocita(g: Game, nem, opts: Array) -> int:
	if nem != null and nem.play.has("id") and nem.play.id >= 0:
		var c := Carte.carta(nem.play.id)
		if c.type == "attack":
			var ini = nem.play.get("init", null)
			if ini == null and not (c.init is Array) and not (c.init is String):
				ini = g._con_hobble(nem, int(c.init))
				for ln in c.segs[0].lines:
					if ln.t == "alt" and ln.has("k") and ln.k == nem.kamae:
						ini = g._con_hobble(nem, int(ln.v))
			if ini != null:
				for i in opts.size():
					if g._con_hobble(g.F[io], int(opts[i].v)) == int(ini):
						return i
	return 0


func _peggiore(g: Game, f: Dictionary, opts: Array) -> int:
	var best := 0
	var bv := 1e9
	for i in opts.size():
		var c := Carte.carta(opts[i].card)
		var v := rng.randf() * 2.0 + int(c.focus) * 0.5
		if c.type == "attack":
			v += 2.0
		if c.has("instant"):
			v -= 1.0
		if v < bv:
			bv = v
			best = i
	return best
