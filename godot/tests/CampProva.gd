extends Node
func _ready() -> void:
	var cart := "/tmp"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			cart = a.substr(4)
	add_child(load("res://scenes/CampagnaMenu.tscn").instantiate())
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(cart + "/campagna.png")
	print("schermata campagna")
	get_tree().quit()
