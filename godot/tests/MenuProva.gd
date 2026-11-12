extends Node
func _ready() -> void:
	var cart := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			cart = a.substr(4)
	add_child(load("res://scenes/Menu.tscn").instantiate())
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(cart + "/menu.png")
	print("schermata menu")
	get_child(0).queue_free()
	Sessione.setup = {"io": "student", "avv": "ronin", "modo": "duello"}
	var pt: Node = load("res://scenes/Partita.tscn").instantiate()
	add_child(pt)
	await get_tree().create_timer(0.6).timeout
	pt.g.F[0].pos = Hex.da_offset(2, 0)
	pt.g.F[0].face = 2
	pt._muovi_pedina(0, false)
	pt._aggiorna()
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(cart + "/allievo.png")
	print("schermata allievo")
	get_tree().quit()
