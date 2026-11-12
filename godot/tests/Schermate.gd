extends Node
## Gioca una partita nell'interfaccia vera e salva schermate nei momenti chiave.

var p: Node
var aiuto: Bot
var fatte := {}
var cart := "user://schermate"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			cart = a.substr(4)
	DirAccess.make_dir_recursive_absolute(cart)
	p = load("res://scenes/Partita.tscn").instantiate()
	add_child(p)
	aiuto = Bot.new(0, 5)
	_gira()


func _scatta(nome: String) -> void:
	if fatte.has(nome):
		return
	fatte[nome] = true
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [cart, nome])
	print("schermata ", nome)


func _gira() -> void:
	var passi := 0
	while passi < 4000:
		await get_tree().create_timer(0.12).timeout
		passi += 1
		if p.g.over:
			await get_tree().create_timer(0.5).timeout
			await _scatta("9_fine")
			break
		if p.req.is_empty():
			if p.g.fase == "risolvi":
				await _scatta("5_risoluzione")
			continue
		var r: Dictionary = p.req
		match r.kind:
			"place":
				await _scatta("1_schieramento")
			"card":
				if r.text.contains("coperta") and p.g.turn >= 2:
					await _scatta("2_scelta_carta")
					if not fatte.has("3_anteprima"):
						p._tocco_carta_mano(int(r.opts[0].card))
						await get_tree().create_timer(0.2).timeout
						await _scatta("3_anteprima")
						p.anteprima.visible = false
			"move":
				await _scatta("4_movimento")
			"kamae", "choice", "draw", "speed", "instant", "counter", "yesno":
				await _scatta("6_richiesta_" + r.kind)
		p._rispondi(aiuto.decidi(p.g, r))
	get_tree().quit()
