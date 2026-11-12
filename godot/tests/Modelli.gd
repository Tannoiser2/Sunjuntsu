extends Node
func _ready() -> void:
	var cart := "user://"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			cart = a.substr(4)
	var p: Node = load("res://scenes/Partita.tscn").instantiate()
	add_child(p)
	await get_tree().create_timer(0.5).timeout
	p.g.F[0].pos = Hex.da_offset(2, 1)
	p.g.F[0].face = 3
	p.g.F[1].pos = Hex.da_offset(4, 1)
	p.g.F[1].face = 3
	for i in 2:
		p._muovi_pedina(i, false)
		var m: Node3D = p.pedine[i].get_node("Modello").get_child(0)
		print(i, " aabb ", p._aabb(m, Transform3D.IDENTITY), " scale ", m.scale)
	p.hud.visible = false
	p.perno.position = Vector3(4.5, 0.6, 2.6)
	p.dist = 6.5
	p.pitch = 0.5
	p._aggiorna_cam()
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(cart + "/modelli.png")
	print("schermata modelli")
	get_tree().quit()
