## Singola carta nell'HUD — Senjutsu
##
## Mostra una carta come immagine ritagliata dal PDF (se l'entry ha "file")
## oppure come scheda generata dai dati del mazzo (se ha "name"). Animazione di
## sollevamento al passaggio del mouse e selezione al click.
extends Control

signal clicked(card_view)
signal hover_changed(card_view, entered: bool)

const CARD_H := 200.0
const CARD_RATIO := 463.0 / 646.0   ## w/h dei ritagli (180 dpi)

var card_data: Dictionary = {}
var base_pos := Vector2.ZERO
var base_rot := 0.0
var selected := false


func setup(entry: Dictionary) -> void:
	card_data = entry
	custom_minimum_size = Vector2(CARD_H * CARD_RATIO, CARD_H)
	size = custom_minimum_size
	pivot_offset = size * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	if entry.has("file"):
		_build_image(entry["file"])
	else:
		_build_data_card(entry)
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	gui_input.connect(_on_gui_input)


func _build_image(file: String) -> void:
	var tr := TextureRect.new()
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.texture = _load_texture("res://assets/cards/" + file)
	add_child(tr)


func _build_data_card(d: Dictionary) -> void:
	var rank := Domain.parse_rank(str(d.get("rank", "-")))
	var accent: Color = Domain.RANK_COLORS.get(rank, Color.GRAY)

	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.13, 0.16)
	sb.set_border_width_all(4)
	sb.border_color = accent
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 8; sb.content_margin_right = 8
	sb.content_margin_top = 6; sb.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 8; vb.offset_top = 6; vb.offset_right = -8; vb.offset_bottom = -6
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vb)

	var top := Label.new()
	top.text = "◈%s   ⚡%s" % [str(d.get("focus", 0)), str(d.get("initiative", "-"))]
	top.add_theme_font_size_override("font_size", 14)
	vb.add_child(top)

	var nm := Label.new()
	nm.text = str(d.get("name", "?"))
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nm.add_theme_font_size_override("font_size", 16)
	vb.add_child(nm)

	var typ: int = Domain.parse_card_type(str(d.get("type", "")))
	var bottom := Label.new()
	bottom.text = "%s · %s" % [
		Domain.CARD_TYPE_LABELS.get(typ, "?"), Domain.RANK_LABELS.get(rank, "—")]
	bottom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_theme_font_size_override("font_size", 12)
	bottom.add_theme_color_override("font_color", accent)
	vb.add_child(bottom)


## Carica una texture anche se la risorsa non è ancora stata importata in editor.
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
	hover_changed.emit(self, entered)   # l'arena mostra l'azione contestuale sulla mappa
	if selected:
		return
	var tw := create_tween().set_parallel()
	if entered:
		z_index = 10
		tw.tween_property(self, "position", base_pos + Vector2(0, -72), 0.12)
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
	tw.tween_property(self, "position", base_pos + Vector2(0, -96 if v else 0), 0.15)
	tw.tween_property(self, "rotation", 0.0 if v else base_rot, 0.15)
	tw.tween_property(self, "scale", Vector2(1.25, 1.25) if v else Vector2.ONE, 0.15)
	modulate = Color(1.3, 1.2, 0.7) if v else Color.WHITE


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit(self)
