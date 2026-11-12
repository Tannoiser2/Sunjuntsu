class_name Game
extends RefCounted
## Motore di regole di Senjutsu — Regolamento 1a edizione + errata, carte risolte
## riga per riga come stampate. Logica pura: ogni decisione passa da `_ask`, a cui
## risponde l'interfaccia (segnale `ask` + `answer`), un'IA (`deciders`) o un replay.

signal ask(req: Dictionary)
signal answered(idx: int)
signal logged(text: String)
signal event(ev: Dictionary)
signal finished(winner: int)

const ORDINE_TIPO := {"defence": 0, "attack": 1, "meditation": 2, "core": 3}
const MAX_FOCUS := 3

var db: Dictionary
var F: Array = []                 ## combattenti
var cells: Dictionary = {}        ## celle giocabili (Vector2i -> true)
var mappa: Dictionary = {}
var adv: Array = []               ## traccia vantaggio: adv[0] è in cima
var turn := 0
var over := false
var winner := -1
var rng := RandomNumberGenerator.new()
var deciders: Array = [Callable(), Callable()]
var journal: Array = []
var pending: Dictionary = {}
var queue: Array = []
var cur_init := -1
var blocks: Array = []
var fase := "setup"
var fonte: Dictionary = {}
var autore := -1             ## chi sta infliggendo l'effetto in corso
var primo_sangue := false
const CONTRATTI := {"reazione": "Reazione", "sangue": "Primo Sangue", "concentrazione": "Concentrazione",
	"furore": "Furore", "vedere": "Fagli Vedere", "attrezzi": "Gli Attrezzi del Mestiere"}   ## carta che sta producendo l'effetto in corso
var ritmo: Callable = Callable()   ## pausa visiva fornita dall'interfaccia


# ─────────────────────────── Avvio ───────────────────────────

func start(setup: Dictionary) -> void:
	prepara(setup)
	await _piazzamento()
	await _preparazione()
	while not over:
		await _turno()
	fase = "fine"
	_ev({"t": "fine", "winner": winner})
	finished.emit(winner)


func prepara(setup: Dictionary) -> void:
	db = Carte.db()
	rng.seed = int(setup.get("seed", 1))
	mappa = db.maps[setup.get("map", "villaggio")]
	for c in mappa.cells:
		cells[Hex.da_offset(int(c[0]), int(c[1]))] = true
	var i := 0
	for pl in setup.players:
		var cd: Dictionary = db.characters[pl.char]
		var ia: bool = pl.get("solo", false)
		var deck: Array = []
		var hand: Array = []
		if ia:
			deck = _mazzo_solo(pl.char, pl.get("incubo", false))
		else:
			for k in cd.deck:
				for _n in int(cd.deck[k]):
					deck.append(int(k))
			for k in cd.core:
				hand.append(int(k))
		_mischia(deck)
		F.append({"i": i, "name": pl.get("name", cd.name), "char": pl.char, "cd": cd,
			"pos": Vector2i(99, 99), "face": 0, "kamae": "neutral", "focus": 0,
			"wounds": 0, "bleeds": 0, "hand": hand, "deck": deck, "discard": [],
			"hobbles": [], "armour": false, "dead": false, "play": {},
			"instant_used": false, "no_move": false, "no_rot": false, "occ": false, "illum": [], "passi": 0, "contr": {}, "contr_nuovo": false, "reaz": false, "turn_tot": 0, "maxfocus": MAX_FOCUS, "turn_w": 0,
			"ai": ia, "lim": int(pl.get("ferite", db.solo.ferite)) if ia else int(cd.wounds),
			"mano": 99 if ia else int(cd.hand),
			"comp": rng.randi_range(0, 2), "post": "off" if rng.randi_range(0, 1) == 0 else "def",
			"raggio": int(db.solo[pl.char].raggio) if ia else 1, "stun_lato": 0, "reset": false})
		i += 1
	adv = [0, 1]
	if int(F[1].cd.advantage) > int(F[0].cd.advantage) and not F[1].ai:
		adv = [1, 0]


## Mazzo Solo di un personaggio: carte firma + una carta da ciascun mazzo di selezione
## indicato + una carta aggiuntiva (Regolamento, "Character AI Deck Construction").
func _mazzo_solo(pers: String, incubo: bool) -> Array:
	var d: Dictionary = db.solo[pers]
	var sel: Dictionary = {}
	for k in db.solo.selezione:
		var a: Array = []
		for x in db.solo.selezione[k]:
			a.append(int(x))
		_mischia(a)
		sel[k] = a
	var out: Array = []
	for x in d.firma:
		out.append(int(x))
	var mazzi: Array = d.mazzi.duplicate()
	if incubo:
		out.append(int(d.incubo))
		mazzi.erase("3")
	for k in mazzi:
		out.append(sel[k].pop_back())
	var extra: Array = d.extra.duplicate()
	out.append(sel[extra[rng.randi_range(0, extra.size() - 1)]].pop_back())
	return out


func _umano(f: Dictionary) -> Dictionary:
	for o in F:
		if o.i != f.i and not o.dead:
			return o
	return {}


func answer(idx: int) -> void:
	if not pending.is_empty():
		answered.emit(idx)


func _ask(p: int, kind: String, text: String, opts: Array, extra: Dictionary = {}) -> int:
	if opts.is_empty():
		return -1
	if opts.size() == 1 and not extra.get("mostra", false):
		return 0
	var req := {"p": p, "kind": kind, "text": text, "opts": opts}
	req.merge(extra)
	var idx := 0
	if deciders[p].is_valid():
		idx = int(deciders[p].call(self, req))
	else:
		pending = req
		ask.emit(req)
		idx = await answered
		pending = {}
	idx = clampi(idx, 0, opts.size() - 1)
	journal.append(idx)
	return idx


func _log(t: String) -> void:
	logged.emit(t)


func _ev(e: Dictionary) -> void:
	event.emit(e)


func _pausa(tipo: String) -> void:
	if ritmo.is_valid():
		await ritmo.call(tipo)


func _mischia(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


func _avversari(f: Dictionary) -> Array:
	var out: Array = []
	for o in F:
		if o.i != f.i and not o.dead:
			out.append(o)
	return out


func _in_cella(c: Vector2i):
	for o in F:
		if not o.dead and o.pos == c:
			return o
	return null


func _libera(c: Vector2i, me: int) -> bool:
	if not cells.has(c):
		return false
	var o = _in_cella(c)
	return o == null or o.i == me


func _ordine_asc() -> Array:
	var a := adv.duplicate()
	a.reverse()
	return a


func conta_mano(f: Dictionary) -> int:
	var n := 0
	for id in f.hand:
		if id < 0 or not Carte.carta(id).get("core", false):
			n += 1
	return n


func conta_stun(f: Dictionary) -> int:
	return f.hand.count(-1)


func hobble_attivi(f: Dictionary) -> int:
	var n := 0
	for h in f.hobbles:
		if h >= 1:
			n += 1
	return n


# ─────────────────────────── Preparazione ───────────────────────────

func _piazzamento() -> void:
	fase = "piazzamento"
	for p in _ordine_asc():
		var f: Dictionary = F[p]
		var opts: Array = []
		for c in mappa.start[p]:
			var cell := Hex.da_offset(int(c[0]), int(c[1]))
			if _in_cella(cell) != null:
				continue
			for d in 6:
				opts.append({"pos": cell, "face": d})
		var idx := await _ask(p, "place", "%s: scegli casella e orientamento di partenza" % f.name, opts)
		f.pos = opts[idx].pos
		f.face = opts[idx].face
		_ev({"t": "move", "p": p})


func _preparazione() -> void:
	fase = "preparazione"
	for f in F:
		if f.ai:
			continue
		var visti := {}
		for id in f.deck.duplicate():
			if visti.has(id) or not Carte.carta(id).get("prepared", false):
				continue
			visti[id] = true
			if conta_mano(f) >= int(f.mano):
				break
			var idx := await _ask(f.i, "yesno", "%s: vuoi iniziare con la carta preparata «%s» in mano?" % [f.name, Carte.nome(id)],
				[{"label": "Sì, la preparo"}, {"label": "No"}], {"card": id})
			if idx == 0:
				f.deck.erase(id)
				f.hand.append(id)
		_mischia(f.deck)
		if f.cd.get("contratti", false):
			var co: Array = []
			for k in CONTRATTI:
				co.append({"label": CONTRATTI[k], "k": k})
			var ic := await _ask(f.i, "choice", "%s: quale contratto lasci fuori? (ne tieni cinque)" % f.name, co)
			for k in CONTRATTI:
				if k != co[ic].k:
					f.contr[k] = {"done": false, "rot": 0, "mai": false, "visti": [], "via": false}
		if f.cd.get("occulta", false):
			var io2 := await _ask(f.i, "yesno", "%s: vuoi iniziare la partita Occultato?" % f.name, [{"label": "Sì, Occultato"}, {"label": "No, Rivelato"}])
			f.occ = io2 == 0
		while conta_mano(f) < int(f.mano) and not f.deck.is_empty():
			f.hand.append(f.deck.pop_back())
	_ev({"t": "state"})


# ─────────────────────────── Turno ───────────────────────────

func _turno() -> void:
	turn += 1
	blocks.clear()
	queue.clear()
	cur_init = -1
	for f in F:
		f.play = {}
		f.instant_used = false
		f.no_move = false
		f.no_rot = false
		f.turn_w = 0
		f.turn_tot = 0
		f.reaz = false
	_log("[b]— Turno %d —[/b]" % turn)
	_ev({"t": "turn"})
	# Ferite sanguinanti: prima della pesca si scarta la cima del mazzo (una sola volta).
	for f in F:
		if f.bleeds > 0 and not f.deck.is_empty():
			f.discard.append(f.deck.pop_back())
			_log("%s sanguina: scarta la prima carta del mazzo." % f.name)
	fase = "pesca"
	for f in F:
		if contratti_fatti(f) > 0:
			var oc: Array = [{"label": "Tieni i contratti"}]
			for k in f.contr:
				if f.contr[k].done and not f.contr[k].via:
					oc.append({"label": "Scarta «%s»: pesca 1" % CONTRATTI[k], "k": k, "m": "p"})
					oc.append({"label": "Scarta «%s»: +1 focus" % CONTRATTI[k], "k": k, "m": "f"})
			var jc := await _ask(f.i, "choice", "%s: vuoi scartare un contratto completato?" % f.name, oc)
			if jc > 0:
				f.contr[oc[jc].k].via = true
				if oc[jc].m == "p":
					_pesca(f, 1)
				else:
					_focus(f, 1)
				_log("%s scarta il contratto «%s»." % [f.name, CONTRATTI[oc[jc].k]])
	for f in F:
		if not f.ai:
			_pesca(f, 1)
	if _fine():
		return
	fase = "scelta"
	for p in _ordine_asc():
		await _scegli(F[p])
	if _fine():
		return
	fase = "rivela"
	for f in F:
		var id: int = f.play.id
		if id >= 0:
			_spendi(f, int(Carte.carta(id).focus))
		_log("%s rivela [b]%s[/b]." % [f.name, Carte.nome(id)])
		if f.ai and id == -2:
			_log("%s è avvelenato: salta il turno." % f.name)
		elif f.ai and id < 0:
			f.stun_lato += 1
			_log("%s è stordito: salta il turno (%d/%d stordimenti)." % [f.name, f.stun_lato, f.lim])
			if f.stun_lato >= int(f.lim):
				f.dead = true
				_log("[b]%s è sconfitto[/b]: troppi stordimenti." % f.name)
	if _fine():
		_ev({"t": "reveal"})
		return
	_ev({"t": "reveal"})
	await _pausa("reveal")
	for p in _ordine_asc():
		await _sostituzione(F[p])
	var ordine := _ordine_asc()
	ordine.sort_custom(func(a, b): return (not F[a].ai) and F[b].ai)
	for p in ordine:
		await _iniziativa(F[p])
	for p in ordine:
		await _iniz_segmenti(F[p])
	_ev({"t": "reveal"})
	await _pausa("init")
	fase = "risolvi"
	_costruisci_coda()
	await _risolvi_coda()
	if over:
		return
	await _fine_turno()


func _req_ok(f: Dictionary, c: Dictionary) -> bool:
	if not c.has("req"):
		return true
	if c.req is Array:
		return c.req.has(f.kamae)
	return c.req == f.kamae


func giocabile(f: Dictionary, id: int) -> bool:
	if id < 0:
		return true
	var c := Carte.carta(id)
	if c.init is String or c.get("no_play", false) or c.get("counter_only", false):
		return false
	if c.has("req_illum") and f.illum.size() < int(c.req_illum):
		return false
	if int(c.focus) > f.focus:
		return false
	if not _req_ok(f, c):
		return false
	return true


func _scegli(f: Dictionary) -> void:
	if f.ai:
		if f.deck.is_empty():
			_log("Il mazzo di %s è esaurito: subisce una ferita e lo rimescola." % f.name)
			f.wounds += f.bleeds
			f.bleeds = 0
			_danno(f, 1, 0)
			if f.dead:
				return
			f.deck = f.discard
			f.discard = []
			_mischia(f.deck)
		f.play = {"id": int(f.deck.pop_back())}
		_ev({"t": "chosen", "p": f.i})
		return
	var opts: Array = []
	var visti := {}
	if f.hand.has(-2):
		# Veleno Debilitante: se è in mano va scelto per forza.
		_log("%s deve giocare il Veleno Debilitante." % f.name)
		f.hand.erase(-2)
		f.play = {"id": -2}
		_ev({"t": "chosen", "p": f.i})
		return
	for id in f.hand:
		if visti.has(id) or not giocabile(f, id):
			continue
		visti[id] = true
		opts.append({"card": id, "label": Carte.nome(id)})
	var idx := await _ask(f.i, "card", "%s: scegli la carta da giocare coperta" % f.name, opts, {"mostra": true})
	var id2: int = opts[idx].card
	f.hand.erase(id2)
	f.play = {"id": id2}
	_ev({"t": "chosen", "p": f.i})


func _sostituzione(f: Dictionary) -> void:
	var id: int = f.play.id
	if id < 0 or Carte.carta(id).get("core", false):
		return
	var cur := Carte.carta(id)
	var opts: Array = [{"label": "Tieni «%s»" % cur.name, "card": id}]
	var visti := {}
	for h in f.hand:
		if h < 0 or visti.has(h):
			continue
		var c := Carte.carta(h)
		if c.get("instant", "") != "rep" or c.type == cur.type:
			continue
		if int(c.focus) > f.focus + int(cur.focus):
			continue
		if not _req_ok(f, c):
			continue
		visti[h] = true
		opts.append({"label": "Sostituisci con «%s»" % c.name, "card": h})
	if opts.size() == 1:
		return
	var idx := await _ask(f.i, "replace", "%s: vuoi usare una Sostituzione istantanea?" % f.name, opts)
	if idx == 0:
		return
	var nid: int = opts[idx].card
	f.focus += int(cur.focus) - int(Carte.carta(nid).focus)
	f.discard.append(id)
	f.hand.erase(nid)
	f.play = {"id": nid}
	f.instant_used = true
	_log("%s sostituisce la carta con [b]%s[/b]." % [f.name, Carte.nome(nid)])
	_ev({"t": "reveal"})


func _iniziativa(f: Dictionary) -> void:
	var id: int = f.play.id
	if id < 0:
		f.play.init = 0
		return
	var c := Carte.carta(id)
	if f.ai:
		var vv := 0
		if c.init is Array:
			vv = int(c.init[0])
			var pl := _umano(f)
			if not pl.is_empty() and pl.play.get("id", -1) >= 0 and Carte.carta(pl.play.id).type == "attack" and pl.play.has("init"):
				vv = clampi(int(pl.play.init) + hobble_attivi(f), int(c.init[1]), int(c.init[0]))
		else:
			vv = int(c.init)
		f.play.init = _con_hobble(f, vv)
		_log("%s: iniziativa [b]%d[/b]." % [f.name, f.play.init])
		return
	var base = c.init
	if c.get("zanmato", false):
		var nz := contratti_fatti(f)
		for k in f.contr:
			f.contr[k].via = true
		_log("%s scarta tutti i suoi contratti." % f.name)
		for _z in nz:
			var iz := await _ask(f.i, "choice", "%s: bonus per un contratto completato" % f.name, [{"label": "+1 iniziativa"}, {"label": "+1 ferita a questo attacco"}])
			if iz == 0:
				base = int(base) + 1
			else:
				f.play["bonus_w"] = int(f.play.get("bonus_w", 0)) + 1
	for ln in c.segs[0].lines:
		if ln.t != "alt":
			continue
		if ln.get("o", false):
			if f.occ:
				base = int(ln.v)
		elif ln.has("k"):
			if f.kamae == ln.k:
				base = int(ln.v)
		elif ln.has("f") and f.focus >= int(ln.f):
			var i0 := await _ask(f.i, "yesno", "%s: paghi %d focus per l'iniziativa %d?" % [f.name, int(ln.f), int(ln.v)],
				[{"label": "Sì"}, {"label": "No"}])
			if i0 == 0:
				_spendi(f, int(ln.f))
				base = int(ln.v)
	var v := 0
	if base is Array:
		var hi := int(base[0])
		var lo := int(base[1])
		if f.hand.has(83) and not f.instant_used and f.focus >= 1 and c.type != "meditation":
			var i1 := await _ask(f.i, "yesno", "%s: giochi «Blocco Ampio» (1 focus) per allargare l'intervallo d'iniziativa?" % f.name,
				[{"label": "Sì"}, {"label": "No"}], {"card": 83})
			if i1 == 0:
				_spendi(f, 1)
				f.hand.erase(83)
				f.discard.append(83)
				f.instant_used = true
				hi += 1
				lo = maxi(1, lo - 1)
				_log("%s gioca [b]Blocco Ampio[/b]." % f.name)
		var opts: Array = []
		for x in range(hi, lo - 1, -1):
			opts.append({"label": str(x), "v": x})
		var i2 := await _ask(f.i, "speed", "%s: scegli l'iniziativa di «%s»" % [f.name, c.name], opts)
		v = int(opts[i2].v)
	else:
		v = int(base)
	f.play.init = _con_hobble(f, v)
	_log("%s: iniziativa [b]%d[/b]." % [f.name, f.play.init])


## Parti successive con iniziativa variabile (es. «5-3»): si sceglie alla rivelazione.
func _iniz_segmenti(f: Dictionary) -> void:
	var id: int = f.play.get("id", -1)
	if id < 0:
		return
	var c := Carte.carta(id)
	for si in c.segs.size():
		if c.segs[si].get("init") is Array:
			var r: Array = c.segs[si].init
			var opts: Array = []
			for x in range(int(r[0]), int(r[1]) - 1, -1):
				opts.append({"label": str(x), "v": x})
			var ix := await _ask(f.i, "speed", "%s: scegli l'iniziativa della parte %d di «%s»" % [f.name, si + 1, c.name], opts)
			if not f.play.has("seg"):
				f.play["seg"] = {}
			f.play.seg[si] = int(opts[ix].v)


func _con_hobble(f: Dictionary, v: int) -> int:
	if v <= 0:
		return v
	return maxi(1, v - hobble_attivi(f))


func _costruisci_coda() -> void:
	queue.clear()
	for f in F:
		var id: int = f.play.id
		if id < 0:
			continue
		var c := Carte.carta(id)
		var rango: float = ORDINE_TIPO[c.type]
		if c.get("core", false) and c.type != "core":
			rango += 0.5
		for s in c.segs.size():
			if s > 0 and c.get("or", false):
				continue
			var ini: int = f.play.init
			if c.segs[s].has("init"):
				var grezza = c.segs[s].init
				if grezza is Array:
					grezza = f.play.get("seg", {}).get(s, grezza[0])
				ini = _con_hobble(f, int(grezza))
			queue.append({"p": f.i, "s": s, "init": ini, "rank": rango})
	_ordina_coda()


func _ordina_coda() -> void:
	queue.sort_custom(func(a, b):
		if a.init != b.init:
			return a.init > b.init
		if a.rank != b.rank:
			return a.rank < b.rank
		if a.p != b.p:
			return adv.find(a.p) < adv.find(b.p)
		return a.s < b.s)


func _pari(a: Dictionary, b: Dictionary) -> bool:
	return a.p != b.p and a.init == b.init and a.rank == b.rank


func _risolvi_coda() -> void:
	while not queue.is_empty() and not over:
		if queue.size() >= 2 and _pari(queue[0], queue[1]) and not queue[0].has("deciso"):
			var alto: int = adv[0]
			var idx := await _ask(alto, "choice", "%s ha il Vantaggio: stessa iniziativa e stesso tipo. Risolvi…" % F[alto].name,
				[{"label": "Per primo"}, {"label": "Per secondo"}])
			var primo: int = alto if idx == 0 else 1 - alto
			if queue[0].p != primo:
				var t = queue[0]
				queue[0] = queue[1]
				queue[1] = t
			queue[0].deciso = true
			queue[1].deciso = true
		var en: Dictionary = queue.pop_front()
		cur_init = en.init
		await _esegui_segmento(en)
		await _chiudi_blocchi()
		_fine()


func _esegui_segmento(en: Dictionary) -> void:
	var f: Dictionary = F[en.p]
	if f.dead:
		return
	var c := Carte.carta(f.play.id)
	if en.s == 0:
		f.passi = 0
	var ctx := {"card": c, "success": null, "hit": [], "abort": false, "main": true, "en": en}
	_log("[color=#7a1f1f]Iniziativa %d[/color] — %s risolve [b]%s[/b]%s." % [en.init, f.name, c.name,
		"" if c.segs.size() == 1 else " (parte %d)" % (en.s + 1)])
	_ev({"t": "resolve", "p": f.i, "card": c.id, "init": en.init})
	await _pausa("resolve")
	if f.ai and c.get("or", false) and en.s == 0:
		var dec := _decidi_or(f, c.segs[0].lines)
		if not dec.attacca:
			_log("%s non può attaccare: userà la seconda parte della carta." % f.name)
			queue.append({"p": f.i, "s": 1, "init": _con_hobble(f, int(c.segs[1].init)), "rank": en.rank})
			_ordina_coda()
			return
		ctx["piano"] = dec.piano
	var rimandato: bool = await _righe(f, c.segs[en.s].lines, 0, ctx)
	if not rimandato:
		await _fine_segmento(f, ctx)


func _fine_segmento(f: Dictionary, ctx: Dictionary) -> void:
	if over or f.dead or ctx.abort:
		return
	var en: Dictionary = ctx.en
	if f.contr_nuovo:
		f.contr_nuovo = false
		await _istantanea(f, "contract", ctx)
	if en.s == ctx.card.segs.size() - 1:
		await _istantanea(f, "after_card", ctx)


## Esegue le righe da `start`. Ritorna true se il resto è rimandato (blocco in attesa).
func _righe(f: Dictionary, lines: Array, start: int, ctx: Dictionary) -> bool:
	var i := start
	while i < lines.size():
		if over or f.dead or ctx.abort:
			return false
		var ln: Dictionary = lines[i]
		match ln.t:
			"ifs":
				if ctx.success != true:
					return false
			"move":
				if await _porta(f, ln, ctx, lines, i):
					await _muovi(f, ln, ctx, lines, i)
			"grid":
				if (ln.has("k") or ln.has("f")) and not await _porta(f, ln, ctx, lines, i):
					pass
				elif ln.mode == "atk":
					await _attacco(f, ln, lines, i, ctx)
				elif _blocco(f, ln, lines, i, ctx):
					return true
			"fx":
				if await _porta(f, ln, ctx, lines, i):
					for e in ln.fx:
						await _fx(f, e, ctx)
			"ranged":
				await _a_distanza(f, ln, ctx)
			"or":
				await _oppure(f, ln, ctx, lines, i)
		i += 1
	return false


func _iniz_bassa(o: Dictionary) -> int:
	var id: int = o.play.get("id", -1)
	if id < 0:
		return 0
	var c := Carte.carta(id)
	if c.init is Array and not o.ai:
		return mini(int(o.play.get("init", 0)), _con_hobble(o, int(c.init[1])))
	return int(o.play.get("init", 0))


## Attacco a distanza: colpisce un bersaglio entro la Distanza con iniziativa inferiore.
## Non usa la griglia e non si può bloccare. (Linea di vista: nessun terreno in campo.)
func _a_distanza(f: Dictionary, ln: Dictionary, ctx: Dictionary) -> void:
	var bers = null
	for o in _avversari(f):
		if Hex.dist(f.pos, o.pos) <= int(ln.get("r", 1)) and _iniz_bassa(o) < cur_init:
			bers = o
	_ev({"t": "attack", "p": f.i, "cells": [] if bers == null else [bers.pos]})
	await _pausa("attack")
	if bers == null:
		ctx.success = false
		_log("L'attacco a distanza di %s non ha bersagli validi." % f.name)
		return
	ctx.hit = [bers.i]
	await _colpisci(f, {"o": bers, "eff": ln.eff}, [], false, ctx)
	ctx.success = true
	for e in ln.get("fx", []):
		if not bers.dead and (not e.has("k") or e.k == f.kamae):
			await _fx(f, e, ctx)
	await _reazione_colpito(bers)
	_verifica_morte(bers)
	_svela(f)
	await _pausa("hit")
	if ctx.main and not over:
		if ctx.card.rank == "Gold":
			_contratto(f, "vedere")
		await _istantanea(f, "atk_ok", ctx)


func _svela(o: Dictionary) -> void:
	if o.get("occ", false):
		o.occ = false
		_log("%s non è più Occultato." % o.name)
		_ev({"t": "state"})


func _kamae_ok(f: Dictionary, ln: Dictionary) -> bool:
	if ln.get("o", false) and not f.get("occ", false):
		return false
	if not ln.has("k"):
		return true
	if ln.k is Array:
		return ln.k.has(f.kamae)
	return ln.k == f.kamae


## Condizioni della riga (banda Kamae / costo focus facoltativo).
func _porta(f: Dictionary, ln: Dictionary, ctx: Dictionary, lines: Array, i: int) -> bool:
	if not _kamae_ok(f, ln):
		return false
	if not ln.has("f"):
		return true
	var costo := int(ln.f)
	if f.focus < costo:
		return false
	# Commit To Hit: se solo pagando l'attacco può andare a segno, il costo è obbligatorio.
	if ln.t == "move" and ctx.card.type == "attack" and ctx.success == null:
		var senza := _puo_colpire(f, f.pos, f.face, lines, i + 1, f.focus)
		var con := false
		for s in _stati(f.pos, f.face, ln.parts, f.i).ok:
			if _puo_colpire(f, s[0], s[1], lines, i + 1, f.focus - costo):
				con = true
				break
		if con and not senza:
			_spendi(f, costo)
			_log("%s deve spendere %d focus (Commit To Hit)." % [f.name, costo])
			return true
	var idx := await _ask(f.i, "yesno", "%s: spendi %d focus per «%s»?" % [f.name, costo, Carte.riga(ln)],
		[{"label": "Sì, spendo %d focus" % costo}, {"label": "No"}], {"line": ln})
	if idx != 0:
		return false
	_spendi(f, costo)
	return true


func _opzioni_or(f: Dictionary, ln: Dictionary, focus: int) -> Array:
	var kam: Array = []
	var altre: Array = []
	for o in ln.opts:
		var g: Dictionary = o[0]
		if not _kamae_ok(f, g):
			continue
		if g.has("f") and focus < int(g.f):
			continue
		if g.has("k") or g.get("o", false):
			kam.append(o)
		else:
			altre.append(o)
	# Un'opzione legata alla Kamae in cui ti trovi è obbligatoria.
	return kam if not kam.is_empty() else altre


func _oppure(f: Dictionary, ln: Dictionary, ctx: Dictionary, lines: Array, i: int) -> void:
	var opts := _opzioni_or(f, ln, f.focus)
	if opts.is_empty():
		return
	if ctx.card.type == "attack" and ctx.success == null and opts.size() > 1:
		var buone: Array = []
		for o in opts:
			var resto: Array = _senza_porta(o) + lines.slice(i + 1)
			if _puo_colpire(f, f.pos, f.face, resto, 0, f.focus - int(o[0].get("f", 0))):
				buone.append(o)
		if not buone.is_empty():
			opts = buone
	var scelte: Array = []
	for o in opts:
		var t: Array = []
		for l in o:
			t.append(Carte.riga(l))
		scelte.append({"label": " · ".join(t)})
	var idx := await _ask(f.i, "choice", "%s: scegli un'opzione" % f.name, scelte)
	var scelta: Array = opts[idx]
	if scelta[0].has("f"):
		_spendi(f, int(scelta[0].f))
	var resto2: Array = _senza_porta(scelta) + lines.slice(i + 1)
	# Le righe dell'opzione si eseguono senza ripetere le condizioni già verificate.
	for k in scelta.size():
		var l2: Dictionary = resto2[k]
		if over or f.dead or ctx.abort:
			return
		if l2.t == "move":
			await _muovi(f, l2, ctx, resto2, k)
		elif l2.t == "fx":
			for e in l2.fx:
				await _fx(f, e, ctx)


func _senza_porta(o: Array) -> Array:
	var out: Array = []
	for l in o:
		var d: Dictionary = l.duplicate()
		d.erase("k")
		d.erase("f")
		out.append(d)
	return out


# ─────────────────────────── Movimento ───────────────────────────

## Stati finali (cella, orientamento) raggiungibili con le parti di una riga di movimento,
## in qualsiasi ordine e combinazione. `coll` = collisioni possibili delle mosse obbligatorie.
func _stati(pos: Vector2i, face: int, parts: Array, me: int) -> Dictionary:
	var st = null
	var ro = null
	for p in parts:
		if p.m == "step":
			st = p
		else:
			ro = p
	var sn: int = int(st.n) if st != null else 0
	var rn: int = int(ro.n) if ro != null else 0
	var dirs: Array = st.dirs if st != null else [0]
	var segni: Array = [1, -1] if ro != null else [1]
	var ok := {}
	var coll := {}
	var libero: bool = F.size() > me and F[me].cd.get("ubriaco", false) and sn > 1
	for d in ([dirs[0]] if libero else dirs):
		for sg in segni:
			var visti := {}
			var pila: Array = [[pos, face, 0, 0]]
			while not pila.is_empty():
				var s: Array = pila.pop_back()
				if visti.has(s):
					continue
				visti[s] = true
				var s_ok: bool = st == null or st.opt or s[2] == sn
				var r_ok: bool = ro == null or ro.opt or s[3] == rn
				if s_ok and r_ok:
					ok[[s[0], s[1]]] = true
				if st != null and s[2] < sn:
					for d2 in (dirs if libero else [d]):
						var np: Vector2i = s[0] + Hex.DIRS[(s[1] + int(d2)) % 6]
						if _libera(np, me):
							pila.append([np, s[1], s[2] + 1, s[3]])
						elif not st.opt:
							coll[np] = true
				if ro != null and s[3] < rn:
					pila.append([s[0], (s[1] + sg + 6) % 6, s[2], s[3] + 1])
	return {"ok": ok.keys(), "coll": coll.keys()}


func _muovi(f: Dictionary, ln: Dictionary, ctx: Dictionary, lines: Array, i: int) -> void:
	if f.no_move:
		_log("Il movimento di %s è cancellato." % f.name)
		return
	if f.no_rot and not f.ai:
		var senza: Array = []
		for pp in ln.parts:
			if pp.m != "rot":
				senza.append(pp)
		if senza.is_empty():
			return
		ln = ln.duplicate()
		ln.parts = senza
	if f.ai:
		if not ctx.has("piano") or ctx.piano.is_empty():
			ctx["piano"] = _pianifica(f, lines, i, ctx.success == null)
		var st: Array = ctx.piano.pop_front()
		if st[0] != f.pos or st[1] != f.face:
			f.pos = st[0]
			f.face = st[1]
			_ev({"t": "move", "p": f.i})
			await _pausa("move")
		return
	var r := _stati(f.pos, f.face, ln.parts, f.i)
	var stati: Array = r.ok
	if stati.is_empty():
		await _collisione(f, r.coll, ctx)
		return
	if ctx.card.type == "attack" and ctx.success == null:
		var buoni: Array = []
		for s in stati:
			if _puo_colpire(f, s[0], s[1], lines, i + 1, f.focus):
				buoni.append(s)
		if not buoni.is_empty():
			stati = buoni
	if stati.size() == 1 and stati[0][0] == f.pos and stati[0][1] == f.face:
		return
	var opts: Array = []
	for s in stati:
		opts.append({"pos": s[0], "face": s[1]})
	var idx := await _ask(f.i, "move", "%s: %s" % [f.name, Carte.riga(ln)], opts, {"line": ln})
	f.passi += Hex.dist(f.pos, opts[idx].pos)
	f.pos = opts[idx].pos
	f.face = opts[idx].face
	_ev({"t": "move", "p": f.i})
	await _pausa("move")


## Vero se, proseguendo dalle righe `i` in poi, l'attacco può avere un bersaglio.
func _puo_colpire(f: Dictionary, pos: Vector2i, face: int, lines: Array, i: int, focus: int) -> bool:
	while i < lines.size():
		var ln: Dictionary = lines[i]
		match ln.t:
			"ranged":
				for o in _avversari(f):
					if Hex.dist(pos, o.pos) <= int(ln.get("r", 1)):
						return true
				return false
			"grid":
				if ln.mode != "atk":
					return false
				if not _kamae_ok(f, ln) or focus < int(ln.get("f", 0)):
					i += 1
					continue
				for c in ln.cells:
					var o = _in_cella(Hex.walk(pos, face, c))
					if o != null and o.i != f.i and (not ln.get("retro", false) or Hex.walk(o.pos, o.face, "3") == pos):
						return true
				return false
			"ifs":
				return false
			"move":
				if not f.no_move and _kamae_ok(f, ln) and focus >= int(ln.get("f", 0)):
					var r := _stati(pos, face, ln.parts, f.i)
					for s in r.ok:
						if _puo_colpire(f, s[0], s[1], lines, i + 1, focus - int(ln.get("f", 0))):
							return true
					if not ln.has("f"):
						return false
			"or":
				for o in _opzioni_or(f, ln, focus):
					var resto: Array = _senza_porta(o) + lines.slice(i + 1)
					if _puo_colpire(f, pos, face, resto, 0, focus - int(o[0].get("f", 0))):
						return true
				return _opzioni_or(f, ln, focus).is_empty() and _puo_colpire(f, pos, face, lines, i + 1, focus)
		i += 1
	return false


## Vero se la carta (dal primo segmento) può colpire da dove si trova ora il combattente.
func carta_puo_colpire(f: Dictionary, id: int) -> bool:
	var c := Carte.carta(id)
	for s in c.segs:
		if _puo_colpire(f, f.pos, f.face, s.lines, 0, f.focus - int(c.focus)):
			return true
	return false


func _collisione(f: Dictionary, celle: Array, ctx: Dictionary) -> void:
	ctx.abort = true
	var keep: Array = []
	for en in queue:
		if en.p != f.i:
			keep.append(en)
	queue = keep
	if celle.is_empty():
		return
	var opts: Array = []
	for c in celle:
		opts.append({"pos": c, "face": f.face})
	var idx := await _ask(f.i, "hex", "%s: mossa obbligatoria impossibile — scegli dove avviene la collisione" % f.name, opts)
	await _urta(f, opts[idx].pos)
	_log("La carta di %s non viene risolta oltre." % f.name)


## Effetto di una collisione di `f` contro la cella `c` (f non si muove).
func _urta(f: Dictionary, c: Vector2i) -> void:
	fonte = {}
	var o = _in_cella(c)
	if o != null and o.i != f.i:
		_log("[b]Collisione[/b]: %s urta %s." % [f.name, o.name])
		await _scarta(f, 1)
		_stordisci(f)
		_stordisci(o)
	else:
		_log("[b]Collisione[/b]: %s finirebbe fuori dal campo." % f.name)
		_stordisci(f)


# ─────────────────────────── Attacchi e blocchi ───────────────────────────

func _attacco(f: Dictionary, ln: Dictionary, lines: Array, i: int, ctx: Dictionary) -> void:
	var imbloccabile: bool = ctx.card.type != "attack"   # i blocchi fermano solo le carte Attacco
	for l in lines:
		if l.t == "unblockable":
			imbloccabile = true
	var celle: Array = []
	var bersagli: Array = []
	for c in ln.cells:
		var cell := Hex.walk(f.pos, f.face, c)
		celle.append(cell)
		var o = _in_cella(cell)
		if o != null and o.i != f.i:
			if ln.get("retro", false) and Hex.walk(o.pos, o.face, "3") != f.pos:
				continue
			bersagli.append({"o": o, "eff": ln.cells[c]})
	_ev({"t": "attack", "p": f.i, "cells": celle})
	await _pausa("attack")
	# Righe che modificano l'attacco (asterisco, ferite sanguinanti): si pagano ora.
	var ast: Array = []
	var sangue := false
	var j := i + 1
	while j < lines.size() and (lines[j].t == "ast" or lines[j].t == "mod"):
		var m: Dictionary = lines[j]
		var serve := false
		for b in bersagli:
			if m.t == "mod" or str(b.eff).ends_with("a"):
				serve = true
		if serve and await _porta(f, m, ctx, lines, j):
			if m.t == "ast":
				ast.append_array(m.fx)
			else:
				sangue = true
		j += 1
	var veri: Array = []
	for b in bersagli:
		if str(b.eff) == "a" and ast.is_empty():
			continue
		veri.append(b)
	if veri.is_empty():
		ctx.success = false
		_log("L'attacco di %s va a vuoto." % f.name)
		return
	var colpiti: Array = []
	var parati: Array = []
	for b in veri:
		var bl = null if imbloccabile else _trova_blocco(f, b.o)
		if bl != null:
			bl.ok = true
			parati.append(bl)
			_log("[b]%s blocca[/b] l'attacco di %s." % [b.o.name, f.name])
			_ev({"t": "blocked", "p": b.o.i})
		else:
			colpiti.append(b)
	ctx.hit = []
	for b in colpiti:
		ctx.hit.append(b.o.i)
		await _colpisci(f, b, ast, sangue, ctx)
	ctx.success = not colpiti.is_empty()
	for b in colpiti:
		await _reazione_colpito(b.o)
		_verifica_morte(b.o)
	if ctx.success:
		_svela(f)
		if ctx.card.rank == "Gold" and ctx.card.type == "attack":
			_contratto(f, "vedere")
	await _pausa("hit")
	for bl in parati:
		await _blocco_riuscito(bl, f)
	if ctx.success and ctx.main and not over:
		await _istantanea(f, "atk_ok", ctx)


func _colpisci(f: Dictionary, b: Dictionary, ast: Array, sangue: bool, ctx: Dictionary) -> void:
	var o: Dictionary = b.o
	autore = f.i
	var eff: String = b.eff
	var con_ast := eff.ends_with("a")
	var base := eff.trim_suffix("a")
	if base == "x":
		o.dead = true
		_log("[b]ESECUZIONE![/b] %s è sconfitto." % o.name)
		_ev({"t": "damage", "p": o.i})
		_fine()
		return
	var w := 0
	var bl := 0
	if base == "w1":
		w = 1
	elif base == "w2":
		w = 2
	elif base == "b":
		bl = 1
	elif base == "p":
		await _fx_bersaglio(f, o, {"v": "t_poison"}, 1)
	if con_ast:
		for e in ast:
			if e.v == "add_wound":
				w += int(e.n)
			elif e.v == "add_bleed":
				bl += int(e.get("n", 1))
	if w > 0 and ctx.main:
		w += int(f.play.get("bonus_w", 0))
	if sangue:
		bl += w
		w = 0
	_danno(o, w, bl, true)
	if con_ast and not o.dead:
		var sub := ctx.duplicate()
		sub.hit = [o.i]
		for e in ast:
			if e.v != "add_wound" and e.v != "add_bleed":
				await _fx(f, e, sub)


func _salvezza(o: Dictionary) -> bool:
	return not o.ai and not o.instant_used and o.hand.has(263) and o.focus >= 2


func _verifica_morte(o: Dictionary) -> void:
	if not o.dead and o.wounds + o.bleeds >= int(o.lim):
		o.dead = true
		_log("[b]%s è sconfitto.[/b]" % o.name)
	_fine()


func _danno(o: Dictionary, w: int, bl: int, rinvia: bool = false) -> void:
	if w + bl <= 0 or o.dead:
		return
	_svela(o)
	if o.armour and w + bl >= 2:
		if w > 0:
			w -= 1
		else:
			bl -= 1
		_log("L'Armatura Pesante di %s riduce il danno di 1." % o.name)
		if o.kamae == "determination":
			_focus(o, 1)
		o.hobbles.append(0)
		_log("%s prende 1 azzoppamento." % o.name)
	o.wounds += w
	o.bleeds += bl
	o.turn_w += w
	o.turn_tot += w + bl
	if autore >= 0 and autore != o.i:
		if not primo_sangue:
			_contratto(F[autore], "sangue")
		if o.turn_tot >= 2:
			_contratto(F[autore], "furore")
		if bl > 0:
			_attrezzo(o, "sangue")
	primo_sangue = true
	var t: Array = []
	if w > 0:
		t.append("%d ferita/e" % w)
	if bl > 0:
		t.append("%d ferita/e sanguinante/i" % bl)
	_log("[color=#a01010]%s subisce %s.[/color]" % [o.name, " e ".join(t)])
	_ev({"t": "damage", "p": o.i})
	if rinvia and _salvezza(o):
		return
	_verifica_morte(o)


func _trova_blocco(att: Dictionary, dif: Dictionary):
	return _blocco_da(att.pos, dif)


func _blocco_da(da: Vector2i, dif: Dictionary):
	for b in blocks:
		if b.p != dif.i or b.init != cur_init:
			continue
		if b.cells.has(da) or Hex.percorsi_bloccati(da, dif.pos, b.cells):
			return b
	return null


# ─────────────────────────── Avversario Solo ───────────────────────────

## Tutte le combinazioni delle righe di movimento consecutive a partire da `i`.
## Ritorna {"vie": [{"st": [[pos, face], ...]}], "next": indice della riga successiva}.
func _percorsi_ia(f: Dictionary, lines: Array, i: int) -> Dictionary:
	var fronte: Array = [{"st": [], "pos": f.pos, "face": f.face}]
	var j := i
	while j < lines.size() and lines[j].t == "move":
		var nuovo: Array = []
		var visti := {}
		for fr in fronte:
			for s in _stati(fr.pos, fr.face, lines[j].parts, f.i).ok:
				if visti.has(s):
					continue
				visti[s] = true
				nuovo.append({"st": fr.st + [s], "pos": s[0], "face": s[1]})
		fronte = nuovo
		j += 1
	return {"vie": fronte, "next": j}


## Voto di una posizione per muoversi (più basso = migliore): distanza preferita,
## fronte verso il giocatore, lato indicato dal Comportamento.
func _voto_pos(f: Dictionary, pos: Vector2i, face: int) -> float:
	var pl := _umano(f)
	if pl.is_empty():
		return 0.0
	var v := absf(Hex.dist(pos, pl.pos) - float(f.raggio)) * 10.0
	var d: int = absi(face - Hex.verso(pos, pl.pos))
	v += minf(d, 6 - d) * 4.0
	v += _lato(f, pl, pos) * 1.5
	if pos != f.pos:
		v += 0.05
	return v


func _lato(f: Dictionary, pl: Dictionary, pos: Vector2i) -> float:
	var rel: int = (Hex.verso(pl.pos, pos) - int(pl.face) + 6) % 6
	var voluti: Array = [[4, 5], [0], [1, 2]][int(f.comp)]
	var m := 9
	for w in voluti:
		var dd: int = absi(rel - int(w))
		m = mini(m, mini(dd, 6 - dd))
	return float(m)


## Voto di una posizione da cui attaccare (più alto = migliore; "colpisce" falso se a vuoto).
func _voto_att(f: Dictionary, pos: Vector2i, face: int, griglia: Dictionary) -> Dictionary:
	var pl := _umano(f)
	var out := {"v": -1.0, "colpisce": false, "rischio": false}
	if pl.is_empty():
		return out
	var eff := ""
	for c in griglia.cells:
		if Hex.walk(pos, face, c) == pl.pos:
			eff = griglia.cells[c]
	if eff == "":
		return out
	var w := 1.0
	if eff.begins_with("x"):
		w = 5.0
	elif eff.begins_with("w2"):
		w = 2.0
	var v := w * 100.0
	if (Hex.verso(pl.pos, pos) - int(pl.face) + 6) % 6 == 3:
		v += 60.0
	var bloccato: bool = _blocco_da(pos, pl) != null
	var esposto := false
	for en in queue:
		if en.p != pl.i:
			continue
		for l in Carte.carta(pl.play.id).segs[en.s].lines:
			if l.t == "grid" and l.mode == "atk":
				for c in l.cells:
					if Hex.walk(pl.pos, pl.face, c) == pos:
						esposto = true
	if bloccato:
		v -= 45.0
	if esposto:
		v -= 35.0
	v -= _lato(f, pl, pos)
	if pos != f.pos or face != f.face:
		v -= 0.5
	out.v = v
	out.colpisce = true
	out.rischio = bloccato or esposto
	return out


func _pianifica(f: Dictionary, lines: Array, i: int, cerca_attacco: bool) -> Array:
	var r := _percorsi_ia(f, lines, i)
	var nx: int = r.next
	var griglia = null
	if cerca_attacco and nx < lines.size() and lines[nx].t == "grid" and lines[nx].mode == "atk":
		griglia = lines[nx]
	var meglio: Array = []
	var bv := -1e9
	for via in r.vie:
		var v := -_voto_pos(f, via.pos, via.face)
		if griglia != null:
			var a := _voto_att(f, via.pos, via.face, griglia)
			if a.colpisce:
				v = 1000.0 + a.v
		if v > bv:
			bv = v
			meglio = via.st
	return meglio.duplicate()


## Carta Solo con "OPPURE": la parte alta si usa solo se permette di attaccare.
func _decidi_or(f: Dictionary, lines: Array) -> Dictionary:
	var m := 0
	while m < lines.size() and lines[m].t != "move" and lines[m].t != "grid":
		m += 1
	var vie: Array = [{"st": [], "pos": f.pos, "face": f.face}]
	var gi := m
	if m < lines.size() and lines[m].t == "move" and not f.no_move:
		var r := _percorsi_ia(f, lines, m)
		vie = r.vie
		gi = r.next
	else:
		while gi < lines.size() and lines[gi].t != "grid":
			gi += 1
	if gi >= lines.size() or lines[gi].t != "grid":
		return {"attacca": false, "piano": []}
	var meglio = null
	var bv := -1e9
	var rischio := false
	for via in vie:
		var a := _voto_att(f, via.pos, via.face, lines[gi])
		if a.colpisce and a.v > bv:
			bv = a.v
			meglio = via.st
			rischio = a.rischio
	if meglio == null:
		return {"attacca": false, "piano": []}
	# Atteggiamento Difensivo: rinuncia se l'attacco verrebbe parato o se resterebbe esposto.
	if f.post == "def" and rischio:
		return {"attacca": false, "piano": []}
	return {"attacca": true, "piano": meglio.duplicate()}


func _seg_attacca(en: Dictionary) -> bool:
	var c := Carte.carta(F[en.p].play.id)
	for l in c.segs[en.s].lines:
		if l.t == "grid" and l.mode == "atk":
			return true
	return false


## Registra il blocco. Ritorna true se il resto della carta è rimandato a dopo
## l'attacco avversario alla stessa iniziativa.
func _blocco(f: Dictionary, ln: Dictionary, lines: Array, i: int, ctx: Dictionary) -> bool:
	var cs: Array = []
	for c in ln.cells:
		if ln.cells[c] == "sa" and ln.get("ak", "") != f.kamae:
			continue
		cs.append(Hex.walk(f.pos, f.face, c))
	var b := {"p": f.i, "init": cur_init, "cells": cs, "ok": false, "done": false,
		"lines": lines, "next": i + 1, "ctx": ctx}
	blocks.append(b)
	_ev({"t": "block", "p": f.i, "cells": cs})
	for en in queue:
		if en.init == cur_init and en.p != f.i and _seg_attacca(en):
			return true
	b.done = true
	ctx.success = false
	return false


func _blocco_riuscito(b: Dictionary, att: Dictionary) -> void:
	if b.done:
		return
	b.done = true
	var d: Dictionary = F[b.p]
	var ctx: Dictionary = b.ctx
	_svela(d)
	if ctx.card.rank == "Gold":
		_contratto(d, "vedere")
	var cl: int = b.next
	while not d.ai and cl < b.lines.size() and b.lines[cl].t == "counter":
		var vl: Array = []
		for v in b.lines[cl].v:
			vl.append(int(v))
		if _kamae_ok(d, b.lines[cl]) and vl.has(cur_init) and not d.dead and not att.dead:
			await _contrattacco(d, cur_init)
			break
		cl += 1
	if d.ai and b.next < b.lines.size() and b.lines[b.next].t == "counter":
		# Contrattacco Solo: si scarta la prima carta del mazzo; se ha un attacco, 1 ferita.
		var vv: Array = []
		for v in b.lines[b.next].v:
			vv.append(int(v))
		if vv.has(cur_init) and not d.deck.is_empty() and not att.dead:
			var top: int = d.deck.pop_back()
			d.discard.append(top)
			var attacca := false
			if top >= 0:
				for sg in Carte.carta(top).segs:
					for l in sg.lines:
						if l.t == "grid" and l.mode == "atk":
							attacca = true
			_log("Contrattacco di %s: scarta «%s» dal mazzo." % [d.name, Carte.nome(top)])
			if attacca:
				_danno(att, 1, 0)
	# Contrattacco: se l'iniziativa dell'attacco parato coincide, si può giocare subito
	# una carta Attacco non speciale di iniziativa uguale o inferiore.
	if false:
		var vel: Array = []
		for v in b.lines[b.next].v:
			vel.append(int(v))
		if vel.has(cur_init) and not d.dead and not att.dead:
			await _contrattacco(d, cur_init)
	if over or d.dead:
		return
	ctx.success = true
	ctx.hit = [att.i]
	await _istantanea(d, "block_ok", ctx)
	if over or d.dead:
		return
	await _righe(d, b.lines, b.next, ctx)
	await _fine_segmento(d, ctx)


func _contrattacco(d: Dictionary, vel: int) -> void:
	var opts: Array = [{"label": "Nessun contrattacco"}]
	var visti := {}
	for h in d.hand:
		if h < 0 or visti.has(h):
			continue
		var c := Carte.carta(h)
		if c.type != "attack" or c.init is Array or c.init is String:
			continue
		if c.get("core", false) and not c.get("counter_ok", false):
			continue
		if int(c.init) > vel or int(c.focus) > d.focus:
			continue
		if not _req_ok(d, c):
			continue
		visti[h] = true
		opts.append({"label": "Contrattacca con «%s»" % c.name, "card": h})
	if opts.size() == 1:
		return
	var idx := await _ask(d.i, "counter", "%s: blocco riuscito! Vuoi contrattaccare?" % d.name, opts)
	if idx == 0:
		return
	var id: int = opts[idx].card
	var c2 := Carte.carta(id)
	_spendi(d, int(c2.focus))
	d.hand.erase(id)
	_log("[b]%s contrattacca[/b] con %s." % [d.name, c2.name])
	d.reaz = true
	_ev({"t": "resolve", "p": d.i, "card": id, "init": cur_init})
	await _pausa("resolve")
	var ctx := {"card": c2, "success": null, "hit": [], "abort": false, "main": false, "en": {"s": 0}}
	for s in c2.segs:
		await _righe(d, s.lines, 0, ctx)
		ctx.success = null
	if c2.get("core", false):
		d.hand.append(id)
	else:
		d.discard.append(id)


## Chiude i blocchi rimasti in attesa quando non ci sono più attacchi a quella iniziativa.
func _chiudi_blocchi() -> void:
	for b in blocks:
		if b.done:
			continue
		var attesa := false
		for en in queue:
			if en.init == b.init and en.p != b.p and _seg_attacca(en):
				attesa = true
		if attesa:
			continue
		b.done = true
		b.ctx.success = false
		var d: Dictionary = F[b.p]
		await _righe(d, b.lines, b.next, b.ctx)
		await _fine_segmento(d, b.ctx)


# ─────────────────────────── Carte istantanee ───────────────────────────

## Istantanee «gioca se l'attacco dell'avversario è riuscito» (Corpo Illuminato).
func _reazione_colpito(o: Dictionary) -> void:
	if o.ai or o.instant_used:
		return
	for h in o.hand.duplicate():
		if h < 0:
			continue
		var c := Carte.carta(h)
		if c.get("when", "") != "hit_me" or int(c.focus) > o.focus:
			continue
		var idx := await _ask(o.i, "instant", "%s: sei stato colpito. Giochi «%s»?" % [o.name, c.name],
			[{"label": "Non giocare nulla"}, {"label": "Gioca «%s»" % c.name, "card": h}])
		if idx == 1:
			o.focus -= int(c.focus)
			o.hand.erase(h)
			o.instant_used = true
			_log("%s gioca l'istantanea [b]%s[/b]." % [o.name, c.name])
			var sub := {"card": c, "success": true, "hit": [], "abort": false, "main": false, "en": {"s": 0}}
			await _righe(o, c.segs[0].lines, 0, sub)
		return


func _istantanea(f: Dictionary, quando: String, ctx: Dictionary) -> void:
	if f.instant_used or f.dead or f.play.get("id", -1) < 0:
		return
	var princ := Carte.carta(f.play.id)
	if princ.get("core", false):
		return
	var opts: Array = [{"label": "Non giocare nulla"}]
	var visti := {}
	for h in f.hand:
		if h < 0 or visti.has(h):
			continue
		var c := Carte.carta(h)
		if (c.get("instant", "") != "add" and quando != "contract") or not c.get("when", "").split("|").has(quando) or c.type == princ.type:
			continue
		if int(c.focus) > f.focus or (not _req_ok(f, c)):
			continue
		visti[h] = true
		opts.append({"label": "Gioca «%s»" % c.name, "card": h})
	if opts.size() == 1:
		return
	var testo := "%s: carta risolta. Giochi un'Aggiunta istantanea?"
	if quando == "contract":
		testo = "%s: contratto completato! Giochi un'istantanea?"
	if quando == "atk_ok":
		testo = "%s: attacco riuscito! Giochi un'Aggiunta istantanea?"
	elif quando == "block_ok":
		testo = "%s: blocco riuscito! Giochi un'Aggiunta istantanea?"
	var idx := await _ask(f.i, "instant", testo % f.name, opts)
	if idx == 0:
		return
	var id: int = opts[idx].card
	var c2 := Carte.carta(id)
	_spendi(f, int(c2.focus))
	f.hand.erase(id)
	f.instant_used = true
	_log("%s gioca l'istantanea [b]%s[/b]." % [f.name, c2.name])
	_ev({"t": "resolve", "p": f.i, "card": id, "init": cur_init})
	await _pausa("resolve")
	var sub := {"card": c2, "success": true, "hit": ctx.hit.duplicate(), "abort": false, "main": false, "en": {"s": 0}}
	await _righe(f, c2.segs[0].lines, 0, sub)
	if not c2.get("stays", false) and not f.illum.has(id):
		f.discard.append(id)


# ─────────────────────────── Effetti ───────────────────────────

func _bersagli(f: Dictionary, ctx: Dictionary) -> Array:
	var out: Array = []
	if not ctx.hit.is_empty():
		for i in ctx.hit:
			if not F[i].dead:
				out.append(F[i])
		return out
	var raggio: int = int(ctx.card.get("range", 99))
	if ctx.card.get("range_contr", false):
		raggio += contratti_fatti(f)
	for o in _avversari(f):
		if Hex.dist(f.pos, o.pos) <= raggio:
			out.append(o)
	return out


func _fx(f: Dictionary, e: Dictionary, ctx: Dictionary) -> void:
	if over:
		return
	fonte = ctx.card
	autore = f.i
	var n := int(e.get("n", 1))
	match e.v:
		"discard":
			await _scarta(f, n)
		"draw":
			await _pesca_fino(f, n)
		"draw_exact":
			_pesca(f, n)
		"focus":
			_focus(f, n)
		"lose_focus_all":
			f.focus = 0
			_log("%s scarta tutto il focus." % f.name)
		"lose_focus_all_but":
			f.focus = mini(f.focus, n)
		"switch":
			await _passa_a(f, e.to)
		"change":
			await _cambia_kamae(f, n)
		"self_stun":
			_stordisci(f)
		"self_hobble":
			f.hobbles.append(0)
			_log("%s prende 1 azzoppamento." % f.name)
		"search":
			await _cerca(f, e.rank, e.get("type", ""), f.deck, true, e.get("pers", ""))
		"search_discard":
			await _cerca(f, e.rank, e.get("type", ""), f.discard, false)
		"search_top":
			var cima: Array = []
			for _k in mini(n, f.deck.size()):
				cima.append(f.deck.pop_back())
			if not cima.is_empty():
				var oo: Array = []
				for cid in cima:
					oo.append({"card": cid, "label": Carte.nome(cid)})
				var ix := await _ask(f.i, "card", "%s: scegli una delle prime carte del mazzo" % f.name, oo, {"mostra": true, "dal_mazzo": true})
				f.hand.append(oo[ix].card)
				cima.erase(oo[ix].card)
				f.deck.append_array(cima)
				_mischia(f.deck)
				_log("%s guarda le prime carte del mazzo e ne prende una." % f.name)
		"discard_stun":
			var tolti := 0
			while tolti < n and f.hand.has(-1):
				f.hand.erase(-1)
				tolti += 1
			if tolti > 0:
				_log("%s scarta %d stordimento/i." % [f.name, tolti])
		"bleed_to_wound":
			if f.bleeds > 0:
				f.wounds += f.bleeds
				f.bleeds = 0
				_log("%s fascia le ferite: non sanguina più." % f.name)
		"trade":
			var giu: Array = []
			var vv := {}
			for h in f.hand:
				if h >= 0 and not vv.has(h) and Carte.carta(h).rank == e.drop and not Carte.carta(h).get("core", false):
					vv[h] = true
					giu.append({"card": h, "label": Carte.nome(h)})
			if giu.is_empty():
				_log("%s non ha carte del rango richiesto da scartare." % f.name)
			else:
				var ig := await _ask(f.i, "card", "%s: scegli la carta da scartare" % f.name, giu, {"mostra": true, "scarto": true})
				f.hand.erase(giu[ig].card)
				await _cerca(f, e.rank, "", f.discard, false)
				f.discard.append(giu[ig].card)
		"illum_search":
			var ii := await _ask(f.i, "yesno", "%s: prendi 1 stordimento per cercare una carta Illuminata nel mazzo?" % f.name, [{"label": "Sì"}, {"label": "No"}])
			if ii == 0:
				_stordisci(f)
				if not f.dead:
					await _cerca_illum(f, f.deck, true)
		"search_illum":
			await _cerca_illum(f, f.discard if e.get("scarti", false) else f.deck, not e.get("scarti", false))
		"illumina":
			if not f.illum.has(int(ctx.card.id)):
				f.illum.append(int(ctx.card.id))
				match e.get("bonus", ""):
					"wounds": f.lim = int(f.lim) + 1
					"hand": f.mano = int(f.mano) + 1
					"focus": f.maxfocus = int(f.maxfocus) + 1
				_log("%s resta in gioco: carte Illuminate %d." % [ctx.card.name, f.illum.size()])
		"wounds_to_stun":
			var q3: int = mini(int(f.turn_w), f.wounds)
			f.wounds -= q3
			f.turn_w = 0
			_log("%s trasforma %d ferite di questo turno in stordimenti." % [f.name, q3])
			for _k in q3:
				_stordisci(f)
		"reveal_take":
			var presi := 0
			var resto: Array = []
			for _k in mini(n, f.deck.size()):
				var cid: int = f.deck.pop_back()
				if cid >= 0 and Carte.carta(cid).get("pers", "") == e.pers:
					f.hand.append(cid)
					presi += 1
				else:
					resto.append(cid)
			f.deck.append_array(resto)
			_mischia(f.deck)
			_log("%s rivela le prime %d carte del mazzo e ne prende %d." % [f.name, n, presi])
		"search_stun":
			var so2: Array = []
			var sv2 := {}
			for cid in f.deck:
				if cid >= 0 and not sv2.has(cid) and Carte.carta(cid).type == "attack" and JSON.stringify(Carte.carta(cid).segs).contains("t_stun"):
					sv2[cid] = true
					so2.append({"card": cid, "label": Carte.nome(cid)})
			if not so2.is_empty():
				var is2 := await _ask(f.i, "card", "%s: scegli un Attacco che infligge stordimento" % f.name, so2, {"mostra": true, "dal_mazzo": true})
				f.deck.erase(so2[is2].card)
				f.hand.append(so2[is2].card)
			_mischia(f.deck)
		"contract_back":
			var cb: Array = []
			for k in f.contr:
				if f.contr[k].via:
					cb.append({"label": CONTRATTI[k], "k": k})
			if cb.is_empty():
				_log("%s non ha contratti scartati da rimettere in gioco." % f.name)
			else:
				var ib := await _ask(f.i, "choice", "%s: quale contratto rimetti in gioco?" % f.name, cb)
				var kk: String = cb[ib].k
				f.contr[kk].via = false
				f.contr[kk].done = false
				f.contr[kk].rot = 0
				f.contr[kk].visti = []
				_log("%s rimette in gioco il contratto «%s»." % [f.name, CONTRATTI[kk]])
		"lavoro_finito":
			var nl := contratti_fatti(f)
			for _k in nl:
				_focus(f, 1)
				_pesca(f, 1)
				var lo: Array = []
				var lv := {}
				for cid in f.discard:
					if cid >= 0 and not lv.has(cid) and Carte.carta(cid).rank == "Wood":
						lv[cid] = true
						lo.append({"card": cid, "label": Carte.nome(cid)})
				if not lo.is_empty():
					var il := await _ask(f.i, "card", "%s: scegli una carta Legno dagli scarti da rimescolare nel mazzo" % f.name, lo, {"mostra": true, "dal_mazzo": true})
					f.discard.erase(lo[il].card)
					f.deck.append(lo[il].card)
					_mischia(f.deck)
			for k in f.contr:
				f.contr[k].via = true
			_log("%s scarta tutti i suoi contratti." % f.name)
		"discard_hobble":
			if not f.hobbles.is_empty():
				f.hobbles.pop_back()
				_log("%s scarta 1 azzoppamento." % f.name)
		"conceal":
			if not f.occ:
				f.occ = true
				_log("%s entra in [b]Occultamento[/b]." % f.name)
		"all_draw":
			for x in F:
				if not x.ai and not x.dead:
					_pesca(x, n)
			_log("Tutti i giocatori pescano %d carte." % n)
		"counter_now":
			var cv: Array = []
			for v in e.v2:
				cv.append(int(v))
			if cv.has(cur_init):
				await _contrattacco(f, cur_init)
		"nota":
			_log("(%s: «%s» va applicato a mano.)" % [f.name, e.get("txt", "")])
		"reshuffle":
			var tieni: Array = []
			for h in f.hand:
				if h < 0 or Carte.carta(h).get("core", false):
					tieni.append(h)
				else:
					f.deck.append(h)
			f.hand = tieni
			f.deck.append_array(f.discard)
			f.discard = []
			_mischia(f.deck)
			_log("%s rimescola nel mazzo tutte le sue carte." % f.name)
		"advantage":
			adv.erase(f.i)
			adv.push_front(f.i)
			_log("%s ottiene il [b]Vantaggio[/b]." % f.name)
		"armour":
			f.armour = true
			_log("L'Armatura Pesante di %s rimane in gioco." % f.name)
		"ai_change":
			f.comp = (int(f.comp) + 1) % 3
			_log("%s cambia Comportamento: [b]%s[/b]." % [f.name, Carte.COMPORTAMENTI[f.comp]])
		"ai_reset":
			f.reset = true
		"ai_recycle":
			for k in range(f.discard.size() - 1, -1, -1):
				var cid: int = f.discard[k]
				if cid >= 0 and Carte.carta(cid).type == "attack":
					f.discard.remove_at(k)
					f.deck.append(cid)
					_mischia(f.deck)
					_log("%s rimescola nel mazzo «%s»." % [f.name, Carte.nome(cid)])
					break
		_:
			for o in _bersagli(f, ctx):
				await _fx_bersaglio(f, o, e, n)
	_ev({"t": "state"})


func _fx_bersaglio(f: Dictionary, o: Dictionary, e: Dictionary, n: int) -> void:
	if o.ai and ["t_lose_focus", "t_switch", "t_discard_type", "t_discard", "t_discard_rand", "t_shuffle_type", "t_draw", "t_give_top"].has(e.v):
		return
	match e.v:
		"t_discard":
			await _scarta(o, n)
		"t_poison":
			_svela(o)
			_attrezzo(o, "veleno")
			var pp: int = maxi(0, o.deck.size() - rng.randi_range(0, mini(4, o.deck.size())))
			o.deck.insert(pp, -2)
			_log("%s è [b]avvelenato[/b]: il Veleno Debilitante finisce fra le prime 5 carte del suo mazzo." % o.name)
		"t_shuffle_type":
			var so: Array = []
			var sv := {}
			for h in o.hand:
				if h >= 0 and not sv.has(h) and Carte.carta(h).type == e.type and not Carte.carta(h).get("core", false):
					sv[h] = true
					so.append({"card": h, "label": Carte.nome(h)})
			if not so.is_empty():
				var si := await _ask(o.i, "card", "%s: scegli una carta %s da rimescolare nel mazzo" % [o.name, Carte.TIPI[e.type]], so, {"mostra": true, "scarto": true})
				o.hand.erase(so[si].card)
				o.deck.append(so[si].card)
				_mischia(o.deck)
				_log("%s rimescola una carta nel mazzo." % o.name)
		"t_draw":
			_pesca(o, n)
			_log("%s pesca %d carte." % [o.name, n])
		"t_give_top":
			var tc: Array = []
			for _k in mini(n, o.deck.size()):
				var x: int = o.deck.pop_back()
				if x >= 0:
					tc.append(x)
				else:
					o.deck.push_front(x)
			if not tc.is_empty():
				var to: Array = []
				for cid in tc:
					to.append({"card": cid, "label": Carte.nome(cid)})
				var ti := await _ask(f.i, "card", "%s: scegli la carta che %s deve prendere in mano" % [f.name, o.name], to, {"mostra": true, "dal_mazzo": true})
				o.hand.append(to[ti].card)
				tc.erase(to[ti].card)
				o.deck.append_array(tc)
				_mischia(o.deck)
				_log("%s sceglie una carta dal mazzo di %s, che la prende in mano." % [f.name, o.name])
		"t_mill_wounds":
			var q2: int = mini(o.wounds + o.bleeds + 1, o.deck.size())
			for _k in q2:
				o.discard.append(o.deck.pop_back())
			_log("%s scarta %d carte dalla cima del mazzo." % [o.name, q2])
		"t_discard_rand":
			var pr: Array = []
			for h in o.hand:
				if h >= 0 and not Carte.carta(h).get("core", false):
					pr.append(h)
			if not pr.is_empty():
				var hr: int = pr[rng.randi_range(0, pr.size() - 1)]
				o.hand.erase(hr)
				o.discard.append(hr)
				_log("%s scarta una carta a caso." % o.name)
		"t_stun_per_step":
			for _k in int(f.passi):
				_stordisci(o)
		"push_steps":
			await _spingi(f, o, 1 + (int(f.passi) if Carte.carta(f.play.id).type == "attack" else 0))
		"cancel_rot":
			o.no_rot = true
			_log("La rotazione attiva di %s è cancellata." % o.name)
		"pull_or_push":
			var pi := await _ask(f.i, "choice", "%s: tiri o spingi %s?" % [f.name, o.name], [{"label": "Spingi"}, {"label": "Tira"}])
			await _spingi(f, o, n, pi == 1)
		"view_hand":
			var viste: Array = o.hand.duplicate()
			if o.ai:
				viste = o.deck.slice(maxi(0, o.deck.size() - 2))
			_log("%s guarda la mano di %s." % [f.name, o.name])
			_ev({"t": "view", "p": f.i, "cards": viste})
		"steal_focus":
			if not o.ai:
				var q: int = mini(n, o.focus)
				o.focus -= q
				_focus(f, q)
				_log("%s ruba %d focus a %s." % [f.name, q, o.name])
		"swap":
			var tmp: Vector2i = f.pos
			f.pos = o.pos
			o.pos = tmp
			_log("%s e %s si scambiano di posto." % [f.name, o.name])
			_ev({"t": "move", "p": f.i})
			_ev({"t": "move", "p": o.i})
			await _pausa("move")
		"t_step":
			for _k in n:
				var dst: Vector2i = o.pos + Hex.DIRS[(int(o.face) + int(e.get("dir", 0))) % 6]
				if _libera(dst, o.i):
					o.pos = dst
					_log("%s viene spostato." % o.name)
					_ev({"t": "move", "p": o.i})
					await _pausa("move")
				else:
					await _urta(o, dst)
					break
		"push":
			await _spingi(f, o, n)
		"t_stun", "each_stun":
			_stordisci(o)
		"t_hobble":
			o.hobbles.append(0)
			_svela(o)
			_attrezzo(o, "azzoppato")
			_log("%s viene azzoppato." % o.name)
		"t_rot":
			var idx := await _ask(f.i, "choice", "%s: ruota %s di %d — in che verso?" % [f.name, o.name, n],
				[{"label": "In senso orario"}, {"label": "In senso antiorario"}])
			o.face = (o.face + (n if idx == 0 else -n) + 12) % 6
			_log("%s viene ruotato." % o.name)
			_ev({"t": "move", "p": o.i})
		"t_lose_focus":
			o.focus = maxi(0, o.focus - n)
			_log("%s scarta %d focus." % [o.name, n])
		"t_switch":
			var dove: String = e.to
			if dove == "any":
				var ko: Array = []
				for k in ["aggression", "balance", "determination"]:
					ko.append({"label": Carte.KAMAE[k], "to": k, "focus": 0})
				dove = ko[await _ask(f.i, "choice", "%s: in quale Kamae fai passare %s?" % [f.name, o.name], ko)].to
			o.kamae = dove
			_log("%s passa a %s." % [o.name, Carte.KAMAE[dove]])
			_ev({"t": "kamae", "p": o.i})
		"t_discard_type":
			for _k in n:
				var opts: Array = []
				var visti := {}
				for h in o.hand:
					if h >= 0 and not visti.has(h) and Carte.carta(h).type == e.type and not Carte.carta(h).get("core", false):
						visti[h] = true
						opts.append({"card": h, "label": Carte.nome(h)})
				if opts.is_empty():
					break
				var i2 := await _ask(o.i, "card", "%s: scarta una carta %s" % [o.name, Carte.TIPI[e.type]], opts, {"mostra": true})
				o.hand.erase(opts[i2].card)
				o.discard.append(opts[i2].card)
				_log("%s scarta una carta." % o.name)
		"t_wound":
			_danno(o, n, 0)
		"t_wound_to_bleed":
			if o.wounds > 0:
				o.wounds -= 1
				o.bleeds += 1
				_log("Una ferita di %s diventa sanguinante." % o.name)
		"cancel_cards":
			var keep: Array = []
			for en in queue:
				if en.p != o.i:
					keep.append(en)
			if keep.size() != queue.size():
				_log("Le carte attive di %s sono cancellate." % o.name)
			queue = keep
		"cancel_move":
			o.no_move = true
			_log("Il movimento attivo di %s è cancellato." % o.name)


func _spendi(f: Dictionary, n: int) -> void:
	if n <= 0:
		return
	f.focus -= n
	_ruota_contratto(f, "concentrazione")


func contratti_fatti(f: Dictionary) -> int:
	var n := 0
	for k in f.contr:
		if f.contr[k].done and not f.contr[k].via:
			n += 1
	return n


func _ruota_contratto(f: Dictionary, k: String) -> void:
	if not f.contr.has(k) or f.contr[k].done or f.contr[k].via:
		return
	f.contr[k].rot += 1
	if f.contr[k].rot >= 4:
		_contratto(f, k)


func _contratto(f: Dictionary, k: String) -> void:
	if not f.contr.has(k) or f.contr[k].done or f.contr[k].via:
		return
	f.contr[k].done = true
	f.contr[k].mai = true
	f.contr_nuovo = true
	_log("[b]%s completa il contratto «%s».[/b]" % [f.name, CONTRATTI[k]])
	var tot := 0
	for x in f.contr:
		if f.contr[x].mai:
			tot += 1
	if tot >= 5 and not over:
		_log("[b]%s ha completato cinque contratti e vince la partita![/b]" % f.name)
		over = true
		winner = f.i
		queue.clear()


func _attrezzo(o: Dictionary, tipo: String) -> void:
	if autore < 0 or autore == o.i:
		return
	var a: Dictionary = F[autore]
	if a.contr.has("attrezzi") and not a.contr.attrezzi.visti.has(tipo):
		a.contr.attrezzi.visti.append(tipo)
		_ruota_contratto(a, "attrezzi")


func _focus(f: Dictionary, n: int) -> void:
	if f.ai:
		return
	var prima: int = f.focus
	f.focus = mini(int(f.maxfocus), f.focus + n)
	if f.focus > prima:
		_log("%s ottiene %d focus." % [f.name, f.focus - prima])


func _stordisci(o: Dictionary) -> void:
	if o.dead:
		return
	_svela(o)
	_attrezzo(o, "stordimento")
	if o.ai:
		o.deck.insert(rng.randi_range(0, o.deck.size()), -1)
		_log("Uno [b]stordimento[/b] viene mischiato nel mazzo di %s." % o.name)
		_ev({"t": "damage", "p": o.i})
		return
	o.hand.append(-1)
	_log("%s prende 1 [b]stordimento[/b]." % o.name)
	if conta_stun(o) >= int(o.mano):
		o.dead = true
		_log("[b]%s è sconfitto[/b]: troppi stordimenti in mano." % o.name)
	_ev({"t": "damage", "p": o.i})
	_fine()


func _pesca(f: Dictionary, n: int) -> void:
	for _k in n:
		if f.dead:
			return
		if f.deck.is_empty():
			_log("%s non ha più carte da pescare." % f.name)
			_danno(f, 1, 0)
		else:
			f.hand.append(f.deck.pop_back())
	_ev({"t": "state"})


func _pesca_fino(f: Dictionary, n: int) -> void:
	var opts: Array = []
	for k in range(n, -1, -1):
		opts.append({"label": "Pesca %d" % k, "v": k})
	var idx := await _ask(f.i, "draw", "%s: quante carte peschi? (mazzo: %d)" % [f.name, f.deck.size()], opts)
	var q: int = opts[idx].v
	if q > 0:
		_pesca(f, q)
		_log("%s pesca %d carta/e." % [f.name, q])


func _scartabili(f: Dictionary) -> Array:
	var opts: Array = []
	var visti := {}
	for h in f.hand:
		if h < 0 or visti.has(h) or Carte.carta(h).get("core", false):
			continue
		visti[h] = true
		opts.append({"card": h, "label": Carte.nome(h)})
	return opts


func _scarta(f: Dictionary, n: int) -> void:
	for _k in n:
		var opts := _scartabili(f)
		if opts.is_empty():
			return
		var idx := await _ask(f.i, "card", "%s: scegli una carta da scartare" % f.name, opts, {"mostra": true, "scarto": true})
		f.hand.erase(opts[idx].card)
		f.discard.append(opts[idx].card)
		_log("%s scarta una carta." % f.name)
		await _mente_illuminata(f, int(opts[idx].card))
		_ev({"t": "state"})


## Mente Illuminata: scartata per un effetto non del Monaco, entra in gioco pagando 1 focus.
func _mente_illuminata(f: Dictionary, id: int) -> void:
	if not Carte.carta(id).get("no_play", false) or fonte.is_empty() or fonte.get("pers", "") == "Monk":
		return
	if f.focus < 1:
		return
	var idx := await _ask(f.i, "yesno", "%s: spendi 1 focus per mettere in gioco «%s»?" % [f.name, Carte.nome(id)], [{"label": "Sì"}, {"label": "No"}], {"card": id})
	if idx != 0:
		return
	_spendi(f, 1)
	f.discard.erase(id)
	var c := Carte.carta(id)
	_log("%s mette in gioco [b]%s[/b]." % [f.name, c.name])
	var sub := {"card": c, "success": true, "hit": [], "abort": false, "main": false, "en": {"s": 0}}
	await _righe(f, c.segs[0].lines, 0, sub)


func _passa_a(f: Dictionary, to: String) -> void:
	var dest := to
	if to == "any":
		var opts: Array = []
		for k in ["aggression", "balance", "determination"]:
			opts.append({"label": Carte.KAMAE[k], "to": k, "focus": 0})
		var idx := await _ask(f.i, "kamae", "%s: passa a quale Kamae?" % f.name, opts)
		dest = opts[idx].to
	if f.kamae != dest:
		f.kamae = dest
		_log("%s passa a [b]%s[/b]." % [f.name, Carte.KAMAE[dest]])
		_ev({"t": "kamae", "p": f.i})


func _vicini_kamae(f: Dictionary, nodo: String) -> Array:
	var out: Array = []
	for ed in f.cd.kamae.edges:
		if ed[0] == nodo:
			out.append(ed[1])
		elif ed[1] == nodo and int(ed[2]) == 2:
			out.append(ed[0])
	return out


func _esiti_kamae(f: Dictionary, start: String, cur: String, rimasti: int, foc: int, res: Dictionary) -> void:
	res[cur] = maxi(int(res.get(cur, -1)), foc)
	if rimasti <= 0:
		return
	for nb in _vicini_kamae(f, cur):
		if nb == "focus":
			# Punto Focus: +1 focus, poi si prosegue (gratis) verso una Kamae diversa da
			# quella di partenza; se non è possibile si torna dov'era l'anello.
			var uscite: Array = []
			for z in _vicini_kamae(f, "focus"):
				if z != start:
					uscite.append(z)
			if uscite.is_empty():
				_esiti_kamae(f, start, start, rimasti - 1, foc + 1, res)
			else:
				for z in uscite:
					_esiti_kamae(f, start, z, rimasti - 1, foc + 1, res)
		else:
			_esiti_kamae(f, start, nb, rimasti - 1, foc, res)


func _cambia_kamae(f: Dictionary, n: int) -> void:
	var res := {}
	_esiti_kamae(f, f.kamae, f.kamae, n, 0, res)
	var opts: Array = []
	for k in res:
		var foc: int = res[k]
		var lab: String = ("Resta in %s" if k == f.kamae else "Vai a %s") % Carte.KAMAE[k]
		if foc > 0:
			lab += " (+%d focus)" % foc
		opts.append({"label": lab, "to": k, "focus": foc})
	var idx := await _ask(f.i, "kamae", "%s: cambia Kamae fino a %d ramo/i" % [f.name, n], opts)
	var sc: Dictionary = opts[idx]
	if sc.focus > 0:
		_focus(f, sc.focus)
	if sc.to != f.kamae:
		f.kamae = sc.to
		_log("%s cambia Kamae: [b]%s[/b]." % [f.name, Carte.KAMAE[sc.to]])
	_ev({"t": "kamae", "p": f.i})


func _cerca(f: Dictionary, rango, tipo: String, pila: Array, mischia: bool, pers: String = "") -> void:
	var ranghi: Array = rango if rango is Array else [rango]
	var opts: Array = []
	var visti := {}
	for id in pila:
		if id < 0:
			continue
		var c := Carte.carta(id)
		if not visti.has(id) and ranghi.has(c.rank) and (tipo == "" or c.type == tipo) and (pers == "" or c.get("pers", "") == pers):
			visti[id] = true
			opts.append({"card": id, "label": c.name})
	var dove := "nel mazzo" if mischia else "negli scarti"
	if opts.is_empty():
		_log("%s cerca %s ma non trova nulla." % [f.name, dove])
	else:
		var idx := await _ask(f.i, "card", "%s: scegli la carta da prendere" % f.name, opts, {"mostra": true, "dal_mazzo": true})
		pila.erase(opts[idx].card)
		f.hand.append(opts[idx].card)
		_log("%s cerca %s e prende una carta." % [f.name, dove])
	if mischia:
		_mischia(pila)


func _cerca_illum(f: Dictionary, pila: Array, mischia: bool) -> void:
	var opts: Array = []
	var visti := {}
	for id in pila:
		if id >= 0 and not visti.has(id) and Carte.carta(id).get("illum", false):
			visti[id] = true
			opts.append({"card": id, "label": Carte.nome(id)})
	if opts.is_empty():
		_log("%s cerca una carta Illuminata ma non ne trova." % f.name)
	else:
		var idx := await _ask(f.i, "card", "%s: scegli la carta Illuminata da prendere" % f.name, opts, {"mostra": true, "dal_mazzo": true})
		pila.erase(opts[idx].card)
		f.hand.append(opts[idx].card)
		_log("%s prende una carta Illuminata." % f.name)
	if mischia:
		_mischia(pila)


func _spingi(f: Dictionary, o: Dictionary, n: int, tira: bool = false) -> void:
	for _k in n:
		if o.dead or over:
			return
		var best: Array = []
		var bd := -1.0
		for d in 6:
			var c: Vector2i = o.pos + Hex.DIRS[d]
			var dd := Hex.euclid(f.pos, c) * (-1.0 if tira else 1.0)
			if bd == -1.0 and best.is_empty():
				best = [c]
				bd = dd
			elif dd > bd + 0.01:
				best = [c]
				bd = dd
			elif absf(dd - bd) <= 0.01:
				best.append(c)
		var dest: Vector2i = best[0]
		if best.size() > 1:
			var opts: Array = []
			for c in best:
				opts.append({"pos": c, "face": o.face})
			dest = opts[await _ask(f.i, "hex", "%s: dove spingi %s?" % [f.name, o.name], opts)].pos
		if _libera(dest, o.i):
			o.pos = dest
			_log("%s viene %s." % [o.name, "tirato" if tira else "spinto"])
			_ev({"t": "move", "p": o.i})
			await _pausa("move")
		else:
			await _urta(o, dest)
			return


# ─────────────────────────── Fine turno ───────────────────────────

func _fine_turno() -> void:
	fase = "scarto"
	fonte = {}
	autore = -1
	for f in F:
		if f.reaz:
			_contratto(f, "reazione")
	if over:
		return
	await _pausa("end")
	for f in F:
		var id: int = f.play.get("id", -1)
		if id >= 0:
			if Carte.carta(id).get("core", false):
				f.hand.append(id)
			elif not f.illum.has(id):
				f.discard.append(id)
		f.play = {}
		var nuovi: Array = []
		for h in f.hobbles:
			if h + 1 < 4:
				nuovi.append(h + 1)
		f.hobbles = nuovi
		if f.ai and f.reset:
			f.reset = false
			f.deck.append_array(f.discard)
			f.discard = []
			_mischia(f.deck)
			_log("%s ricompone il mazzo." % f.name)
	for f in F:
		while not f.dead and conta_mano(f) > int(f.mano):
			var opts := _scartabili(f)
			if opts.is_empty():
				break
			var idx := await _ask(f.i, "card", "%s: limite di mano superato — scarta una carta" % f.name, opts, {"mostra": true, "scarto": true})
			f.hand.erase(opts[idx].card)
			f.discard.append(opts[idx].card)
	_ev({"t": "state"})


func _fine() -> bool:
	if over:
		return true
	var vivi: Array = []
	for f in F:
		if not f.dead:
			vivi.append(f.i)
	if vivi.size() <= 1:
		over = true
		winner = vivi[0] if vivi.size() == 1 else -1
		queue.clear()
	return over
