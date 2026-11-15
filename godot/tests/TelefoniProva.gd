extends Node
## Partita con gli smartphone: il tavolo crea la stanza; i telefoni (pagina web vera, pilotata da
## tests/telefoni_e2e.py) entrano e giocano.
func _ready() -> void:
	var cart := "/tmp"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			cart = a.substr(4)
	Sessione.setup = {"io": "sailor", "avv": "ninja", "modo": "telefoni", "tel_solo": false, "terreno": "casuale", "segui": true}
	var p: Node = load("res://scenes/Partita.tscn").instantiate()
	add_child(p)
	while p.tel == null or p.tel.codice == "":
		await get_tree().create_timer(0.3).timeout
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(cart + "/tv_qr.png")
	print("CODICE ", p.tel.codice)
	var t := 0.0
	var fatta := false
	while t < 400.0:
		await get_tree().create_timer(1.0).timeout
		t += 1.0
		if p.g != null and p.g.turn >= 2 and not fatta:
			fatta = true
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(cart + "/tv_partita.png")
			print("schermata tv")
		if p.g != null and int(t) % 20 == 0:
			print("TURNO ", p.g.turn, " fase ", p.g.fase)
		if p.g != null and p.g.over:
			print("FINE vincitore ", p.g.winner, " turni ", p.g.turn)
			break
	await get_tree().create_timer(3.0).timeout
	get_tree().quit()
