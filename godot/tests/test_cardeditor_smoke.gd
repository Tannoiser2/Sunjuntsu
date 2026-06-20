## Smoke test headless dell'editor di carte: istanzia la scena, verifica che
## l'elenco si popoli e che selezionare una carta costruisca il dettaglio senza
## errori a runtime. Non scrive nulla (Fase 1 è sola lettura).
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
	var scene: PackedScene = load("res://scenes/CardEditor.tscn")
	_check(scene != null, "CardEditor.tscn caricabile")
	var editor := scene.instantiate()
	add_child(editor)
	await get_tree().process_frame

	var list: ItemList = editor._list
	_check(list != null and list.item_count > 0, "elenco popolato (%d carte)" % (list.item_count if list else -1))

	# Seleziona la prima carta e verifica che il dettaglio si costruisca.
	editor._on_item_selected(0)
	await get_tree().process_frame
	_check(editor._selected_id > 0, "carta selezionata id=%d" % editor._selected_id)
	_check(editor._detail.get_child_count() > 1, "pannello dettaglio costruito")
	_check(editor._preview_holder.get_child_count() == 1, "anteprima CardView creata")

	# Un filtro testuale assurdo deve svuotare l'elenco senza crash.
	editor._search.text = "zzz_nessuna_carta_zzz"
	editor._refresh_list()
	_check(list.item_count == 0, "filtro senza risultati svuota l'elenco")

	editor.queue_free()
	if _failures == 0:
		print("CARDEDITOR SMOKE DONE ok")
		get_tree().quit(0)
	else:
		print("CARDEDITOR SMOKE DONE failures=", _failures)
		get_tree().quit(1)
