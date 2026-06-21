## Smoke: lo splash legge versione + Novità dal CHANGELOG e ha lo sfondo.
extends Node
var _fail := 0
func _ck(c: bool, m: String) -> void:
	print(("  ok: " if c else "  FAIL: ") + m)
	if not c: _fail += 1
func _ready() -> void:
	var m = load("res://scenes/Menu.tscn").instantiate()
	add_child(m)
	await get_tree().process_frame
	var ver: String = m.get_node("Version").text
	var ch: String = m.get_node("Changes").text
	_ck(ver.begins_with("v0."), "versione mostrata (%s)" % ver)
	_ck(ch.begins_with("Novità v") and ch.contains("•"), "Novità dal CHANGELOG")
	_ck(not ch.contains("Controller telefono ORIZZONTALE"), "niente testo hardcoded vecchio")
	_ck(m.get_node("Background").texture != null, "immagine di sfondo presente")
	print("MENU CHANGES DONE ", "ok" if _fail == 0 else "failures=%d" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
