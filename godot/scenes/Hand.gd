## Mano del giocatore — Senjutsu
##
## Control che dispone le carte a ventaglio in basso e gestisce la selezione.
## Riceve una lista di carte ({file, ...}) e crea un CardView per ciascuna.
extends Control

signal card_played(card_data: Dictionary)
signal card_selected(card_data: Dictionary)

const CardView := preload("res://scenes/CardView.gd")
const FAN_SPREAD := 0.10     ## rotazione massima (rad) ai bordi del ventaglio
const CARD_GAP := 96.0       ## spaziatura orizzontale tra le carte

var _cards: Array = []       ## CardView
var _selected: Object = null


func set_hand(entries: Array) -> void:
	for c in _cards:
		c.queue_free()
	_cards.clear()
	_selected = null
	for e in entries:
		var cv = CardView.new()
		add_child(cv)
		cv.setup(e)
		cv.clicked.connect(_on_card_clicked)
		_cards.append(cv)
	_layout()


func _layout() -> void:
	var n := _cards.size()
	if n == 0:
		return
	await get_tree().process_frame
	var center_x: float = size.x * 0.5
	var base_y: float = size.y - 150.0
	for i in range(n):
		var cv = _cards[i]
		var off: float = i - (n - 1) * 0.5
		var cw: float = cv.size.x
		var x: float = center_x + off * CARD_GAP - cw * 0.5
		var rot: float = off * FAN_SPREAD / max(1.0, (n - 1) * 0.5)
		var y: float = base_y + abs(off) * 8.0    ## leggera curvatura del ventaglio
		cv.place(Vector2(x, y), rot)
		cv.z_index = i


func _on_card_clicked(cv) -> void:
	if _selected == cv:
		# Secondo click = conferma giocata.
		card_played.emit(cv.card_data)
		cv.queue_free()
		_cards.erase(cv)
		_selected = null
		_layout()
		return
	if _selected:
		_selected.set_selected(false)
	_selected = cv
	cv.set_selected(true)
	card_selected.emit(cv.card_data)
