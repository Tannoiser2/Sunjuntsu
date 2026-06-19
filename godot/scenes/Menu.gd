## Menu principale — Senjutsu
extends Control


func _ready() -> void:
	$VBox/SoloButton.pressed.connect(_on_solo)
	$VBox/VersusButton.pressed.connect(_on_versus)
	$VBox/OnlineButton.pressed.connect(_on_online)
	$VBox/QuitButton.pressed.connect(func(): get_tree().quit())

	var version: String = str(ProjectSettings.get_setting("application/config/version", "?"))
	$Version.text = "v%s" % version
	$Changes.text = "Novità v%s:\n• ONLINE companion: tavolo 3D + telefoni (codice stanza); serve il relay WebSocket\n• Animazioni di combattimento; carte ISTANTANEE (sostituzione + aggiuntive)\n• 1v1 locale, ferite come carte, focus ◈ e rotazione con frecce ⟲⟳\nVedi docs/MULTIPLAYER_PLAN.md e CHANGELOG.md" % version


func _on_solo() -> void:
	# Solo: giocatore (pedina 0) contro l'IA solitaria (pedina 1).
	Domain.game_mode = "solo"
	get_tree().change_scene_to_file("res://scenes/Arena.tscn")


func _on_versus() -> void:
	# 1v1 locale (hot-seat): due giocatori umani sullo stesso dispositivo, con
	# TUTTA la logica del duello (programmazione coperta a turno, rivelazione,
	# risoluzione per iniziativa). Si passano il dispositivo tra le fasi.
	Domain.game_mode = "versus"
	get_tree().change_scene_to_file("res://scenes/Arena.tscn")


func _on_online() -> void:
	# Tavolo ONLINE companion: questo schermo mostra la board e il codice stanza;
	# i due giocatori si collegano col telefono (pagina phone/). Serve il relay
	# (server/server.js) in ascolto su Domain.ws_url.
	get_tree().change_scene_to_file("res://scenes/TableOnline.tscn")
