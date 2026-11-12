extends Node
## L'interfaccia vera in modalità online (posto 0) contro un avversario finto (posto 1).

var cart := "user://"


func _scatta(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [cart, nome])
	print("schermata ", nome)


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			cart = a.substr(4)
	var sala: Control = load("res://scenes/Online.tscn").instantiate()
	add_child(sala)
	Sessione.rete.file_sessione = "user://prova_a.cfg"
	await get_tree().create_timer(0.3).timeout
	sala._crea()
	var b := Rete.new()
	b.file_sessione = "user://prova_b.cfg"
	add_child(b)
	while sala.codice == "":
		await get_tree().create_timer(0.2).timeout
	print("posto ospite: ", await b.join_room(sala.codice, "Bruno", 2), " ", b.last_error)
	await get_tree().create_timer(2.5).timeout
	print("sala: ", sala.stato.text, " / inizia visibile: ", sala.b_inizia.visible)
	await _scatta("online_sala")
	var codice: String = sala.codice
	sala.attivo = false
	sala.queue_free()
	var partita := {"seed": 55, "pers": ["warrior", "ronin"]}
	await Sessione.rete.start_room(codice, partita)
	Sessione.setup = {"io": "warrior", "modo": "online", "codice": codice, "posto": 0, "partita": partita}
	var p: Node = load("res://scenes/Partita.tscn").instantiate()
	add_child(p)
	# avversario finto
	var g1 := Game.new()
	g1.prepara({"seed": 55, "players": [{"char": "warrior"}, {"char": "ronin"}]})
	var s := Sincro.new()
	s.rete = b
	s.codice = codice
	s.posto = 1
	add_child(s)
	await s.avvia(g1)
	var bot1 := Bot.new(1, 3)
	s.tocca_a_me.connect(func(r): s.rispondi(bot1.decidi(g1, r)))
	_gioca(g1)
	var bot0 := Bot.new(0, 4)
	var fatto := false
	var passi := 0
	while passi < 3000:
		await get_tree().create_timer(0.1).timeout
		passi += 1
		if p.g.over and g1.over:
			break
		if not p.req.is_empty():
			p._rispondi(bot0.decidi(p.g, p.req))
		elif not fatto and p.g.turn >= 2 and p.lbl_richiesta.text.begins_with("In attesa"):
			fatto = true
			await _scatta("online_attesa")
	print("online interfaccia: finite=%s uguali=%s" % [p.g.over and g1.over, p.g.journal == g1.journal])
	await get_tree().create_timer(0.5).timeout
	await _scatta("online_fine")
	get_tree().quit(0 if (p.g.over and p.g.journal == g1.journal) else 1)


func _gioca(g: Game) -> void:
	await g._piazzamento()
	await g._preparazione()
	while not g.over:
		await g._turno()
