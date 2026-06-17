## Menu principale — Senjutsu
extends Control


func _ready() -> void:
	$VBox/SoloButton.pressed.connect(_on_solo)
	$VBox/VersusButton.pressed.connect(_on_versus)
	$VBox/QuitButton.pressed.connect(func(): get_tree().quit())


func _on_solo() -> void:
	# Per ora entrambe le modalità aprono la stessa arena scaffold.
	get_tree().change_scene_to_file("res://scenes/Arena.tscn")


func _on_versus() -> void:
	# Multiplayer 1v1: da implementare (vedi DESIGN.md, sezione Rete).
	get_tree().change_scene_to_file("res://scenes/Arena.tscn")
