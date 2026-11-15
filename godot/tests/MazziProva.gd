extends Node
func _ready() -> void:
	var cart := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			cart = a.substr(4)
	Sessione.setup["io"] = "onna"
	var ed: Control = load("res://scenes/EditorMazzi.tscn").instantiate()
	add_child(ed)
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(cart + "/mazzi.png")
	print("errori base: ", Mazzi.errori("onna", ed.mazzo))
	ed._cambia(Mazzi.disponibili("onna")[0], -1)
	ed.f_rango.select(3)
	ed._riempi_griglia()
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(cart + "/mazzi2.png")
	print("dopo -1: ", Mazzi.errori("onna", ed.mazzo))
	ed._ingrandisci(Mazzi.disponibili("onna")[0])
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(cart + "/mazzi3.png")
	# mazzo personale usato in partita
	var m: Dictionary = Mazzi.base("onna")
	m.deck = {}
	for id in Mazzi.disponibili("onna"):
		if Mazzi.conta(m.deck) >= 30:
			break
		var c := Carte.carta(id)
		if c.rank == "Gold" or c.rank == "Jade":
			continue
		m.deck[str(id)] = mini(int(Mazzi.COPIE[c.rank]), 30 - Mazzi.conta(m.deck))
	m.armi = [Mazzi.armi("onna")[0]]
	m["attivo"] = true
	print("personale: ", Mazzi.errori("onna", m), " armi ", Mazzi.armi("onna"))
	var g := Game.new()
	g.prepara({"seed": 5, "players": [{"char": "onna", "mazzo": Mazzi.per_partita("onna", m)}, {"char": "ronin"}]})
	print("mazzo in partita: ", g.F[0].deck.size(), " mano ", g.F[0].hand)
	get_tree().quit()
