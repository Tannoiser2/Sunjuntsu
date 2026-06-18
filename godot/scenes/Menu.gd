## Menu principale — Senjutsu
extends Control


func _ready() -> void:
	$VBox/SoloButton.pressed.connect(_on_solo)
	$VBox/VersusButton.pressed.connect(_on_versus)
	$VBox/QuitButton.pressed.connect(func(): get_tree().quit())

	var version: String = str(ProjectSettings.get_setting("application/config/version", "?"))
	$Version.text = "v%s" % version
	$Changes.text = "Novità v%s:\n• Collisioni (spinte): fuori arena/contro nemico/terreno + Commit To Hit\n• Blocchi fedeli 1.5 e IA solo che rivela la cima del mazzo\n• Turno fedele e movimento obbligatorio/opzionale dalle carte\nVedi REGOLAMENTO_FEDELTA.md e CHANGELOG.md" % version


func _on_solo() -> void:
	# Per ora entrambe le modalità aprono la stessa arena scaffold.
	get_tree().change_scene_to_file("res://scenes/Arena.tscn")


func _on_versus() -> void:
	# Multiplayer 1v1: da implementare (vedi DESIGN.md, sezione Rete).
	get_tree().change_scene_to_file("res://scenes/Arena.tscn")
