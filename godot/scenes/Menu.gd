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
	$Changes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$Changes.text = _latest_changes(version)


## Ricava le "Novità" dall'ultima voce del CHANGELOG.md (titolo + primi punti),
## così lo splash resta sempre allineato. Fallback se il file non è leggibile
## (es. build esportata in cui non è impacchettato).
func _latest_changes(version: String) -> String:
	var path := ProjectSettings.globalize_path("res://").path_join("../CHANGELOG.md")
	if not FileAccess.file_exists(path):
		return "Novità v%s — vedi CHANGELOG.md" % version
	var lines := FileAccess.get_file_as_string(path).split("\n")
	var out: Array = []
	var started := false
	var bullets := 0
	for raw in lines:
		var line := str(raw)
		if line.begins_with("## ["):
			if started:
				break
			started = true
			# "## [0.62.0] — 2026-06-21" → "Novità v0.62.0 — 2026-06-21"
			out.append("Novità v" + line.substr(4).replace("] —", " —").replace("]", "").strip_edges())
		elif started and line.begins_with("### "):
			out.append(_clean_md(line.substr(4)))
		elif started and line.strip_edges().begins_with("- ") and bullets < 3:
			out.append("• " + _trunc(_clean_md(line.strip_edges().substr(2)), 92))
			bullets += 1
	if out.is_empty():
		return "Novità v%s — vedi CHANGELOG.md" % version
	return "\n".join(out)


func _clean_md(s: String) -> String:
	return s.replace("**", "").replace("`", "").strip_edges()


func _trunc(s: String, n: int) -> String:
	return s if s.length() <= n else s.substr(0, n - 1).strip_edges() + "…"


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
