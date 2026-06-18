## Menu principale — Senjutsu
extends Control


func _ready() -> void:
	$VBox/SoloButton.pressed.connect(_on_solo)
	$VBox/VersusButton.pressed.connect(_on_versus)
	$VBox/QuitButton.pressed.connect(func(): get_tree().quit())

	var version: String = str(ProjectSettings.get_setting("application/config/version", "?"))
	$Version.text = "v%s" % version
	$Changes.text = "Novità v%s:\n• Le FERITE sono carte (arte reale): ferite, stordimento, azzoppamenti, veleni\n• Stordimento occupa la mano e non si scarta; striscia stati visibile in partita\n• 1v1 LOCALE (hot-seat); suggerimento leggibile; Solo vs IA invariato\nVedi REGOLAMENTO_FEDELTA.md e CHANGELOG.md" % version


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
