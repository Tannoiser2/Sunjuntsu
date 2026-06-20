## Test headless della logica immagini (Fase 6): scansione, naming, slug e
## crop+save webp. Scrive un file temporaneo e lo ripulisce; non tocca i dati.
extends Node

var _failures: int = 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok: ", msg)
	else:
		_failures += 1
		push_error("FAIL: " + msg)
		print("  FAIL: ", msg)


func _ready() -> void:
	# Scansione.
	var imgs := CardStore.list_card_images()
	_check(imgs.size() > 0, "trovate %d immagini" % imgs.size())
	_check("warrior/warrior_01.webp" in imgs, "immagine nota presente nello scan")

	# Slug personaggio.
	_check(CardStore.char_slug("Warrior") == "warrior", "char_slug semplice")
	_check(CardStore.char_slug("Gen. Ability") == "gen_ability", "char_slug normalizza punti/spazi")

	# Nome libero per import.
	var nn := CardStore.next_image_name("warrior")
	_check(not (nn in imgs), "next_image_name è libero: %s" % nn)

	# Crop + save webp su un'immagine fittizia.
	var src := Image.create(800, 1000, false, Image.FORMAT_RGBA8)
	src.fill(Color(0.2, 0.4, 0.8))
	var dest := "_tmp_test/crop.webp"
	var abs_path := "res://assets/cards/" + dest
	var res := CardStore.crop_and_save_webp(src, Rect2i(100, 100, 400, 558), dest)
	_check(res.get("ok", false), "crop_and_save_webp ok")
	_check(FileAccess.file_exists(abs_path), "file webp creato")
	var rl := Image.new()
	var loaded := FileAccess.file_exists(abs_path) and rl.load(abs_path) == OK
	_check(loaded and rl.get_width() == 463 and rl.get_height() == 645,
		"ridimensionato al formato carta 463x645 (%dx%d)" % [rl.get_width() if loaded else -1, rl.get_height() if loaded else -1])

	# Regione vuota -> errore pulito.
	var bad := CardStore.crop_and_save_webp(src, Rect2i(0, 0, 0, 0), "_tmp_test/bad.webp")
	_check(not bad.get("ok", true), "regione vuota -> errore")

	# Pulizia.
	DirAccess.remove_absolute(abs_path)
	DirAccess.remove_absolute("res://assets/cards/_tmp_test")

	if _failures == 0:
		print("CARDIMAGES DONE ok")
		get_tree().quit(0)
	else:
		print("CARDIMAGES DONE failures=", _failures)
		get_tree().quit(1)
