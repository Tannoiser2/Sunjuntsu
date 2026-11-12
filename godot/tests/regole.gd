extends SceneTree
## Test delle regole: scenari costruiti a mano con decisioni pilotate.

var g: Game
var piano: Array = [{}, {}]
var falliti := 0
var registro: Array = []


func _decidi(gg: Game, req: Dictionary) -> int:
	var pl: Dictionary = piano[req.p]
	var k: String = req.kind
	if k == "card" and not req.get("scarto", false) and pl.has("carta") and req.text.contains("coperta"):
		for i in req.opts.size():
			if req.opts[i].card == pl.carta:
				return i
		push_error("carta %d non giocabile" % pl.carta)
	if k == "speed" and pl.has("vel"):
		for i in req.opts.size():
			if req.opts[i].v == pl.vel:
				return i
	if k == "move" and pl.has("mossa"):
		var m: Array = pl.mossa.pop_front() if pl.mossa.size() > 0 else []
		if m.size() == 2:
			for i in req.opts.size():
				if req.opts[i].pos == m[0] and req.opts[i].face == m[1]:
					return i
			push_error("mossa %s non disponibile fra %s" % [m, req.opts])
		pl["ultime_mosse"] = req.opts
	if k == "move":
		pl["ultime_mosse"] = req.opts
		for i in req.opts.size():
			if req.opts[i].pos == gg.F[req.p].pos and req.opts[i].face == gg.F[req.p].face:
				return i
	if pl.has(k):
		var v = pl[k]
		if v is Array:
			return v.pop_front() if v.size() > 0 else 0
		return int(v)
	return 0


func nuovo(c0 := "warrior", c1 := "ronin") -> void:
	g = Game.new()
	g.deciders = [_decidi, _decidi]
	registro = []
	g.logged.connect(func(t): registro.append(t))
	g.prepara({"seed": 3, "players": [{"char": c0}, {"char": c1}]})
	piano = [{}, {}]
	# posizioni di base: uno di fronte all'altro, adiacenti, al centro
	metti(0, Vector2i(3, -2), 2)
	metti(1, Vector2i(4, -2), 5)


func metti(p: int, pos: Vector2i, face: int) -> void:
	g.F[p].pos = pos
	g.F[p].face = face


func mano(p: int, ids: Array) -> void:
	var f: Dictionary = g.F[p]
	for id in ids:
		if not f.hand.has(id):
			f.deck.erase(id)
			f.hand.append(id)


func ok(cond: bool, nome: String) -> void:
	if cond:
		print("  ok  ", nome)
	else:
		falliti += 1
		printerr("  FALLITO  ", nome)
		for r in registro:
			printerr("      | ", r)


func turno(c0: int, c1: int) -> void:
	piano[0]["carta"] = c0
	piano[1]["carta"] = c1
	mano(0, [c0])
	mano(1, [c1])
	await g._turno()


func _initialize() -> void:
	var W := 0
	var R := 1

	print("Griglia: fronte e celle a distanza 2")
	ok(Hex.walk(Vector2i(3, -2), 2, "0") == Vector2i(4, -2), "la cella di fronte (orientamento 2) è a sud-est")
	ok(Hex.dist(Vector2i(0, 0), Hex.walk(Vector2i(0, 0), 0, "01")) == 2, "\"01\" è a distanza 2")
	ok(Hex.percorsi_bloccati(Vector2i(0, 0), Vector2i(0, -2), [Vector2i(0, -1)]), "percorso unico bloccato")
	ok(not Hex.percorsi_bloccati(Vector2i(0, 0), Vector2i(1, -2), [Vector2i(0, -1)]), "due percorsi: uno solo bloccato non basta")
	ok(not Hex.percorsi_bloccati(Vector2i(0, 0), Vector2i(0, -1), []), "adiacenti: nessun percorso da bloccare")

	print("Attacco semplice e ordine d'iniziativa")
	nuovo()
	ok(not g.giocabile(g.F[W], 119), "senza focus il Fendente Selvaggio non è giocabile")
	ok(not g.giocabile(g.F[W], 55) and not g.giocabile(g.F[W], 54), "carte con Kamae richiesta o solo istantanee non si scelgono")
	g.F[W].focus = 1
	await turno(119, 127)
	ok(g.F[R].wounds == 2, "Fendente Selvaggio: 2 ferite sul fronte")
	ok(g.F[W].focus == 0 and g.F[W].kamae == "neutral", "Fendente: focus speso, torna Neutrale")
	ok(g.F[W].pos != Vector2i(3, -2) or g.conta_stun(g.F[W]) == 1, "Spinta Indietro: il Guerriero è spinto di 2 (o urta il bordo)")

	print("Blocco alla stessa iniziativa e 'se riuscito'")
	nuovo()
	piano[R]["vel"] = 5
	await turno(126, 123)   # il Guerriero non ha Colpo d'Elsa: uso Ronin attaccante
	nuovo("ronin", "warrior")
	piano[1]["vel"] = 5
	await turno(126, 123)   # Colpo d'Elsa (5) contro Respinta a 5
	ok(g.F[1].wounds == 0, "Respinta a 5 blocca Colpo d'Elsa a 5")
	ok(g.F[0].pos != Vector2i(3, -2) or g.conta_stun(g.F[0]) > 0, "blocco riuscito: l'attaccante viene spinto")
	nuovo("ronin", "warrior")
	piano[1]["vel"] = 4
	await turno(126, 123)
	ok(g.F[1].wounds == 1, "Respinta a 4 NON blocca un attacco a 5")
	ok(g.conta_stun(g.F[1]) == 1, "Colpo d'Elsa riuscito: bersaglio stordito")

	print("Blocco fuori arco")
	nuovo("ronin", "warrior")
	metti(1, Vector2i(4, -2), 2)   # il difensore dà le spalle
	piano[1]["vel"] = 5
	await turno(126, 123)
	ok(g.F[1].wounds == 1, "il blocco frontale non ferma un attacco alle spalle")

	print("Contrattacco (1a edizione): si gioca una carta Attacco")
	nuovo("ronin", "warrior")
	piano[1]["vel"] = 8
	piano[1]["counter"] = 1
	g.F[0].kamae = "determination"   # Falciata Montante: iniziativa alternativa 8
	mano(1, [64])
	mano(0, [60])
	g.F[0].deck.append(60)
	# Ronin non ha la 60: uso il Guerriero come attaccante contro un Guerriero
	nuovo("warrior", "warrior")
	g.F[0].kamae = "determination"
	piano[1]["vel"] = 8
	piano[1]["counter"] = 1
	mano(1, [64])
	await turno(60, 63)   # Falciata Montante a 8 contro Blocco Cinereo a 8 (contrattacco 8)
	ok(g.F[1].wounds == 0, "Blocco Cinereo blocca a 8")
	ok(g.F[0].wounds == 1, "contrattacco con Testata: 1 ferita all'attaccante")
	ok(g.F[1].discard.has(64), "la carta del contrattacco va negli scarti")

	print("Commit To Hit")
	nuovo()
	metti(1, Vector2i(5, -3), 5)    # avversario a distanza 2 in linea retta
	mano(0, [64])
	piano[0]["carta"] = 64
	piano[1]["carta"] = 23
	await g._turno()
	var mosse: Array = piano[0].get("ultime_mosse", [])
	ok(g.F[1].wounds == 1, "Testata: il passo facoltativo diventa obbligato per colpire")

	print("Kamae: Punto Focus")
	nuovo()
	g.F[W].kamae = "aggression"
	var res := {}
	g._esiti_kamae(g.F[W], "aggression", "aggression", 1, 0, res)
	ok(res.get("balance", -1) == 1 and res.get("determination", -1) == 1, "Guerriero da Aggressione: 1 ramo porta a Equilibrio o Determinazione con +1 focus")
	ok(res.has("neutral") and res.neutral == 0, "Guerriero da Aggressione: può tornare Neutrale")
	res = {}
	g._esiti_kamae(g.F[W], "balance", "balance", 1, 0, res)
	ok(res.keys().size() == 2 and res.has("determination"), "Guerriero da Equilibrio: solo Determinazione")
	res = {}
	g._esiti_kamae(g.F[R], "aggression", "aggression", 1, 0, res)
	ok(res.get("aggression", -1) == 1 and res.size() == 1, "Ronin da Aggressione: tocca il Punto Focus e torna (+1 focus)")
	res = {}
	g._esiti_kamae(g.F[R], "neutral", "neutral", 2, 0, res)
	ok(res.get("aggression", -1) == 1 and res.has("determination"), "Ronin da Neutrale con 2 rami")

	print("Azzoppamento")
	nuovo()
	g.F[W].hobbles = [1]
	await turno(116, 23)
	ok(registro.any(func(t): return t.contains("Guerriero: iniziativa [b]5")), "azzoppato: Mente Rapida passa da 6 a 5")

	print("Iniziativa divisa")
	nuovo("ronin", "warrior")
	metti(1, Vector2i(5, -2), 5)   # a distanza 2 davanti al Ronin
	await turno(29, 116)           # Spazzata Feroce 6 / parte 2 a 1
	ok(g.F[1].wounds == 1, "Spazzata Feroce colpisce a distanza 2")
	var i6 := -1
	var i1 := -1
	for k in registro.size():
		if registro[k].contains("Spazzata Feroce[/b] (parte 1)"):
			i6 = k
		if registro[k].contains("Spazzata Feroce[/b] (parte 2)"):
			i1 = k
	ok(i6 >= 0 and i1 > i6, "la seconda parte si risolve dopo, a iniziativa 1")

	print("Collisione da mossa obbligatoria")
	nuovo("ronin", "warrior")
	metti(0, Vector2i(0, 0), 5)    # Carica: passo avanti obbligatorio fuori dal campo
	g.F[0].kamae = "aggression"
	g.F[0].focus = 2
	await turno(26, 116)
	ok(g.conta_stun(g.F[0]) == 1, "passo obbligatorio fuori campo: 1 stordimento")
	ok(g.F[0].pos == Vector2i(0, 0), "chi collide non si muove")

	print("Sanguinamento e mazzo vuoto")
	nuovo()
	g.F[W].bleeds = 1
	var prima: int = g.F[W].deck.size()
	await turno(53, 23)
	ok(registro.any(func(t): return t.contains("sanguina")), "ferita sanguinante: scarta la cima del mazzo prima della pesca")
	nuovo()
	g.F[R].discard.append_array(g.F[R].deck)
	g.F[R].deck.clear()
	await turno(53, 23)
	ok(g.F[R].wounds >= 1, "mazzo vuoto: pescare costa una ferita")

	print("Tutte le carte hanno un testo")
	for c in Carte.db().cards.values():
		if Carte.testo(c).contains("?"):
			ok(false, "testo incompleto: " + c.name)
	print("FALLITI: %d" % falliti)
	quit(1 if falliti > 0 else 0)
