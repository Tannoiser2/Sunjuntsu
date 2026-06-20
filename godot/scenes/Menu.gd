## Menu principale — Senjutsu
extends Control


func _ready() -> void:
	$VBox/SoloButton.pressed.connect(_on_solo)
	$VBox/VersusButton.pressed.connect(_on_versus)
	$VBox/OnlineButton.pressed.connect(_on_online)
	$VBox/EditorButton.pressed.connect(_on_editor)
	$VBox/QuitButton.pressed.connect(func(): get_tree().quit())

	var version: String = str(ProjectSettings.get_setting("application/config/version", "?"))
	$Version.text = "v%s" % version
	$Changes.text = "Novità v%s:\n• Controller telefono ORIZZONTALE: barra di stato (Kamae/ferite/focus), mano scorrevole\n• Movimento GRAFICO: mappa 2D toccabile (muovi/ruota/attacca), stile giapponese\n• ONLINE companion (tavolo 3D + telefoni); animazioni; carte istantanee\nVedi docs/MULTIPLAYER_PLAN.md e CHANGELOG.md" % version


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


func _on_editor() -> void:
	# Editor di carte (Fase 1: browser & inspector). Vedi docs/CARD_EDITOR_ROADMAP.md.
	get_tree().change_scene_to_file("res://scenes/CardEditor.tscn")


func _on_online() -> void:
	# Tavolo ONLINE companion: questo schermo mostra la board e il codice stanza;
	# i due giocatori si collegano col telefono (pagina phone/). Serve il relay
	# (server/server.js) in ascolto su Domain.ws_url.
	get_tree().change_scene_to_file("res://scenes/TableOnline.tscn")
