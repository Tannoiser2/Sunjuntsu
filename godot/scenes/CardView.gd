## Singola carta nell'HUD — Senjutsu
##
## Control che mostra l'immagine ritagliata di una carta, con animazione di
## sollevamento al passaggio del mouse e selezione al click.
extends Control

signal clicked(card_view)

const CARD_H := 200.0
const CARD_RATIO := 463.0 / 646.0   ## w/h dei ritagli (180 dpi)

var card_data: Dictionary = {}      ## {file, deck, index, ...} dal manifest
var texture_path: String = ""
var base_pos := Vector2.ZERO        ## posizione "a riposo" nel ventaglio
var base_rot := 0.0
var selected := false

var _tex_rect: TextureRect


func setup(path: String, data: Dictionary) -> void:
	texture_path = path
	card_data = data
	custom_minimum_size = Vector2(CARD_H * CARD_RATIO, CARD_H)
	size = custom_minimum_size
	pivot_offset = size * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP

	_tex_rect = TextureRect.new()
	_tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tex_rect.texture = _load_texture(path)
	add_child(_tex_rect)

	# Etichetta dati (visibile solo se la carta è collegata al pool).
	if data.has("name"):
		var tip := Label.new()
		tip.text = "%s\n%s · ini %s" % [
			data.get("name", ""),
			Domain.CARD_TYPE_LABELS.get(Domain.parse_card_type(data.get("type", "")), "?"),
			str(data.get("initiative", "-"))]
		tip.add_theme_font_size_override("font_size", 11)
		tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tip.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tip.add_theme_color_override("font_outline_color", Color.BLACK)
		tip.add_theme_constant_override("outline_size", 4)
		add_child(tip)

	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	gui_input.connect(_on_gui_input)


## Carica la texture anche se la risorsa non è ancora stata importata in editor.
static func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	var img := Image.new()
	if img.load(path) == OK:
		return ImageTexture.create_from_image(img)
	return null


func place(pos: Vector2, rot: float) -> void:
	base_pos = pos
	base_rot = rot
	position = pos
	rotation = rot
	pivot_offset = size * 0.5


func _on_hover(entered: bool) -> void:
	if selected:
		return
	var tw := create_tween().set_parallel()
	if entered:
		z_index = 10
		tw.tween_property(self, "position", base_pos + Vector2(0, -50), 0.12)
		tw.tween_property(self, "rotation", 0.0, 0.12)
		tw.tween_property(self, "scale", Vector2(1.15, 1.15), 0.12)
	else:
		z_index = 0
		tw.tween_property(self, "position", base_pos, 0.12)
		tw.tween_property(self, "rotation", base_rot, 0.12)
		tw.tween_property(self, "scale", Vector2.ONE, 0.12)


func set_selected(v: bool) -> void:
	selected = v
	var tw := create_tween().set_parallel()
	z_index = 20 if v else 0
	tw.tween_property(self, "position", base_pos + Vector2(0, -70 if v else 0), 0.15)
	tw.tween_property(self, "rotation", 0.0 if v else base_rot, 0.15)
	tw.tween_property(self, "scale", Vector2(1.25, 1.25) if v else Vector2.ONE, 0.15)
	modulate = Color(1.3, 1.2, 0.7) if v else Color.WHITE


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit(self)
