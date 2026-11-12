extends Node
## Andata e ritorno dell'editor su tutte le carte + schermata.
func _ready() -> void:
	var cart := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			cart = a.substr(4)
	var e: Control = load("res://scenes/Editor.tscn").instantiate()
	add_child(e)
	await get_tree().process_frame
	var diversi := 0
	for id in e.ids:
		var orig: String = Carte.testo(Carte.carta(id))
		e._apri(id)
		if Carte.testo(e.cur) != orig:
			diversi += 1
			print("DIVERSA ", id, "\n", orig, "\n---\n", Carte.testo(e.cur))
	print("editor: carte diverse dopo andata e ritorno = ", diversi)
	if cart != "":
		e._apri(60)
		e.lista.select(e.ids.find(60))
		await get_tree().create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(cart + "/editor.png")
		print("schermata editor")
	get_tree().quit(1 if diversi > 0 else 0)
