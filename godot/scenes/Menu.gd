## Menu principale — Senjutsu
extends Control


func _ready() -> void:
	$VBox/SoloButton.pressed.connect(_on_solo)
	$VBox/VersusButton.pressed.connect(_on_versus)
	$VBox/QuitButton.pressed.connect(func(): get_tree().quit())

	var version: String = str(ProjectSettings.get_setting("application/config/version", "?"))
	$Version.text = "v%s" % version
	$Changes.text = "Novità v%s:\n• Animazioni di combattimento: affondo, impatto, parata, contrattacco, urti\n• Carte ISTANTANEE: sostituzione + aggiuntive; GUI con focus ◈ e frecce ⟲⟳\n• 1v1 locale, ferite come carte, sequenza di risoluzione chiara\nVedi REGOLAMENTO_FEDELTA.md e CHANGELOG.md" % version


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
