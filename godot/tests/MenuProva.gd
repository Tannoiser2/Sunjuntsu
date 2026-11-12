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
	get_tree().quit()
