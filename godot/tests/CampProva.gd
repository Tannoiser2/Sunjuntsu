extends Node
func _ready() -> void:
	var cart := "/tmp"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			cart = a.substr(4)
	var m = load("res://scenes/CampagnaMenu.tscn").instantiate()
	add_child(m)
	await _foto(cart + "/campagna.png")
	m._mostra("furia")
	await _foto(cart + "/campagna_furia.png")
	m._fumetto(["p08", "p09"], Callable())
	await _foto(cart + "/fumetto.png")
	m.get_child(m.get_child_count() - 1).queue_free()
	m._scelta_dopo("occhio")
	await _foto(cart + "/scelta.png")
	print("schermata campagna")
	get_tree().quit()


func _foto(f: String) -> void:
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(f)
