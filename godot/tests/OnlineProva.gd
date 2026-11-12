extends Node
## Due giocatori finti giocano online attraverso il finto Firebase (tests/firebase_mock.py).

func _ready() -> void:
	var a := await _giocatore("user://prova_a.cfg")
	var b := await _giocatore("user://prova_b.cfg")
	var codice: String = await a.create_room("Anna", {"pers": "warrior"})
	assert(codice != "", "stanza non creata: " + a.last_error)
	var posto: int = await b.join_room(codice, "Bruno", 2)
	print("stanza ", codice, " posto ospite ", posto)
	var partita := {"seed": 77, "pers": ["warrior", "ronin"]}
	assert(await a.start_room(codice, partita))
	var stanza: Dictionary = await b.room(codice)
	var letta: Dictionary = JSON.parse_string(stanza.game)
	var g0 := await _tavolo(a, codice, 0, letta, 11)
	var g1 := await _tavolo(b, codice, 1, letta, 12)
	_gioca(g0)
	_gioca(g1)
	var t := 0.0
	while not (g0.over and g1.over) and t < 150.0:
		await get_tree().create_timer(0.25).timeout
		t += 0.25
	var uguali: bool = g0.journal == g1.journal and g0.winner == g1.winner
	print("online: finite=%s vincitore %d/%d decisioni %d/%d uguali=%s" % [g0.over and g1.over, g0.winner, g1.winner, g0.journal.size(), g1.journal.size(), uguali])
	var ok: bool = g0.over and g1.over and uguali
	if ok:
		# un terzo dispositivo rientra al posto 1 e rigioca tutto il registro
		var g2 := await _tavolo(b, codice, 1, letta, 13)
		_gioca(g2)
		var t2 := 0.0
		while not g2.over and t2 < 30.0:
			await get_tree().create_timer(0.25).timeout
			t2 += 0.25
		print("rientro: finita=%s vincitore %d" % [g2.over, g2.winner])
		ok = g2.over and g2.winner == g0.winner
	get_tree().quit(0 if ok else 1)


func _giocatore(file: String) -> Rete:
	var r := Rete.new()
	r.file_sessione = file
	if FileAccess.file_exists(file):
		DirAccess.remove_absolute(file)
	add_child(r)
	return r


func _tavolo(r: Rete, codice: String, posto: int, partita: Dictionary, seme: int) -> Game:
	var g := Game.new()
	g.prepara({"seed": int(partita.seed), "players": [{"char": partita.pers[0]}, {"char": partita.pers[1]}]})
	var s := Sincro.new()
	s.rete = r
	s.codice = codice
	s.posto = posto
	add_child(s)
	await s.avvia(g)
	var bot := Bot.new(posto, seme)
	s.tocca_a_me.connect(func(req): s.rispondi(bot.decidi(g, req)))
	return g


func _gioca(g: Game) -> void:
	await g._piazzamento()
	await g._preparazione()
	while not g.over:
		await g._turno()
