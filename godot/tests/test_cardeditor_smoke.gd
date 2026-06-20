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

	# Seleziona la prima carta e verifica che il form editabile si costruisca.
	editor._on_item_selected(0)
	await get_tree().process_frame
	_check(editor._current_id > 0, "carta selezionata id=%d" % editor._current_id)
	_check(editor._form.get_child_count() > 1, "form di dettaglio costruito")
	_check(editor._orig_preview.get_child_count() == 1, "colonna originale popolata")
	_check(editor._geom_editor._widgets.size() >= 1, "editor geometria a widget popolato")
	_check(editor._w.has("name") and editor._w.has("keywords"), "widget editabili presenti")

	# Ricalcolo automatico di type dai keywords.
	editor._w["keywords"].text = "Defence"
	editor._recalc_type()
	_check(editor._collect_fields().get("type", "") == "defence", "type ricalcolato da keywords")

	# Undo/redo: una modifica alla geometria si annulla e si ripristina.
	editor._on_item_selected(0)
	await get_tree().process_frame
	var base_atk: int = editor._geom_editor.to_geometry().get("attack", {}).get("cells", []).size()
	_check(editor._btn_undo.disabled, "Undo disabilitato al caricamento")
	editor._geom_editor.set_attack_cell(0, 1, 2)
	_check(editor._geom_editor.to_geometry().get("attack", {}).get("cells", []).size() == base_atk + 1, "cella aggiunta")
	_check(not editor._btn_undo.disabled, "Undo abilitato dopo una modifica")
	editor._undo()
	await get_tree().process_frame
	_check(editor._geom_editor.to_geometry().get("attack", {}).get("cells", []).size() == base_atk, "Undo ripristina lo stato precedente")
	editor._redo()
	await get_tree().process_frame
	_check(editor._geom_editor.to_geometry().get("attack", {}).get("cells", []).size() == base_atk + 1, "Redo riapplica la modifica")

	# «Nuova» crea una carta-utente non salvata con id >= 10000.
	editor._on_new()
	await get_tree().process_frame
	_check(editor._current_id >= 10000 and editor._pending_new, "Nuova: id-utente pending #%d" % editor._current_id)
	_check(editor._btn_remove.disabled, "Rimuovi-override disabilitato su carta nuova")
	_check(not editor._btn_save.disabled, "Salva abilitato su carta nuova")

	# «Duplica» richiede una carta esistente: riselezioniamo e duplichiamo.
	editor._on_item_selected(0)
	var base_id: int = editor._current_id
	editor._on_duplicate()
	await get_tree().process_frame
	_check(editor._current_id >= 10000 and editor._pending_new, "Duplica: nuova carta-utente pending")
	_check(editor._current_id != base_id, "duplicato ha un id diverso dall'originale #%d" % base_id)
	_check(editor._collect_fields().get("name", "").ends_with("(copia)"), "duplicato marcato (copia)")

	# «Annulla» su carta nuova la scarta senza crash.
	editor._on_cancel()
	_check(editor._current_id == -1 and not editor._pending_new, "Annulla scarta la carta nuova")

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
