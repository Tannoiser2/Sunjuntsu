## Dialog di ritaglio immagine — Senjutsu (editor carte, Fase 6)
##
## Mostra un'immagine importata e un rettangolo di ritaglio bloccato sul formato
## carta (463:645). Si trascina per spostarlo, si usa la maniglia in basso a
## destra per ridimensionarlo. "Ritaglia e salva" emette la regione in pixel
## SORGENTE; se non si trascina nulla, vale il ritaglio massimo centrato.
class_name ImageCropDialog
extends Window

signal cropped(region: Rect2i)

const ASPECT := 463.0 / 645.0   ## w/h del formato carta

var _view: CropView


func setup(img: Image) -> void:
	title = "Ritaglia immagine — formato carta"
	size = Vector2i(720, 620)
	close_requested.connect(queue_free)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 8; root.offset_top = 8
	root.offset_right = -8; root.offset_bottom = -8
	add_child(root)

	var hint := Label.new()
	hint.text = "Trascina il riquadro per spostarlo · maniglia ◢ in basso a destra per ridimensionare"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.6, 0.66, 0.74))
	root.add_child(hint)

	_view = CropView.new()
	_view.setup(img)
	_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_view)

	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_END
	var cancel := Button.new()
	cancel.text = "Annulla"
	cancel.pressed.connect(queue_free)
	bar.add_child(cancel)
	var ok := Button.new()
	ok.text = "Ritaglia e salva"
	ok.pressed.connect(func():
		cropped.emit(_view.region_in_source())
		queue_free())
	bar.add_child(ok)
	root.add_child(bar)


# ─── Vista con immagine + rettangolo di ritaglio ─────────────────────────────

class CropView extends Control:
	var _img: Image
	var _tex: Texture2D
	var _disp := Rect2()    ## dove l'immagine è disegnata (fit nel controllo)
	var _crop := Rect2()    ## rettangolo di ritaglio in coordinate VISTA
	var _mode := 0          ## 0=nessuno 1=sposta 2=ridimensiona
	var _grab := Vector2.ZERO
	const HANDLE := 18.0

	func setup(img: Image) -> void:
		_img = img
		_tex = ImageTexture.create_from_image(img)
		custom_minimum_size = Vector2(680, 480)
		mouse_filter = Control.MOUSE_FILTER_STOP
		resized.connect(_relayout)

	func _ready() -> void:
		_relayout()

	## (Ri)calcola la posizione dell'immagine e il ritaglio iniziale massimo.
	func _relayout() -> void:
		if _img == null or size.x <= 0 or size.y <= 0:
			return
		var isz := Vector2(_img.get_size())
		var scale: float = minf(size.x / isz.x, size.y / isz.y)
		var dsz := isz * scale
		_disp = Rect2((size - dsz) * 0.5, dsz)
		if _crop.size == Vector2.ZERO:
			_crop = _max_centered_crop()
		else:
			_crop = _clamp_crop(_crop)
		queue_redraw()

	func _max_centered_crop() -> Rect2:
		var h: float = _disp.size.y
		var w: float = h * ASPECT
		if w > _disp.size.x:
			w = _disp.size.x
			h = w / ASPECT
		return Rect2(_disp.position + (_disp.size - Vector2(w, h)) * 0.5, Vector2(w, h))

	func _clamp_crop(c: Rect2) -> Rect2:
		c.size.x = clampf(c.size.x, 24.0, _disp.size.x)
		c.size.y = c.size.x / ASPECT
		if c.size.y > _disp.size.y:
			c.size.y = _disp.size.y
			c.size.x = c.size.y * ASPECT
		c.position.x = clampf(c.position.x, _disp.position.x, _disp.end.x - c.size.x)
		c.position.y = clampf(c.position.y, _disp.position.y, _disp.end.y - c.size.y)
		return c

	func _draw() -> void:
		if _tex != null:
			draw_texture_rect(_tex, _disp, false)
		# Oscura fuori dal ritaglio (quattro bande).
		var dim := Color(0, 0, 0, 0.5)
		draw_rect(Rect2(_disp.position, Vector2(_disp.size.x, _crop.position.y - _disp.position.y)), dim)
		draw_rect(Rect2(Vector2(_disp.position.x, _crop.end.y), Vector2(_disp.size.x, _disp.end.y - _crop.end.y)), dim)
		draw_rect(Rect2(Vector2(_disp.position.x, _crop.position.y), Vector2(_crop.position.x - _disp.position.x, _crop.size.y)), dim)
		draw_rect(Rect2(Vector2(_crop.end.x, _crop.position.y), Vector2(_disp.end.x - _crop.end.x, _crop.size.y)), dim)
		draw_rect(_crop, Color(1, 1, 1, 0.9), false, 2.0)
		var hr := Rect2(_crop.end - Vector2(HANDLE, HANDLE), Vector2(HANDLE, HANDLE))
		draw_rect(hr, Color(0.95, 0.8, 0.3, 0.95))

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var hr := Rect2(_crop.end - Vector2(HANDLE, HANDLE), Vector2(HANDLE, HANDLE))
				if hr.has_point(event.position):
					_mode = 2
				elif _crop.has_point(event.position):
					_mode = 1
					_grab = event.position - _crop.position
			else:
				_mode = 0
		elif event is InputEventMouseMotion and _mode != 0:
			if _mode == 1:
				_crop.position = event.position - _grab
			else:
				_crop.size.x = event.position.x - _crop.position.x
			_crop = _clamp_crop(_crop)
			queue_redraw()

	## Regione di ritaglio in pixel dell'immagine SORGENTE.
	func region_in_source() -> Rect2i:
		if _disp.size.x <= 0:
			return Rect2i(Vector2i.ZERO, _img.get_size())
		var scale: float = _img.get_size().x / _disp.size.x
		var pos := (_crop.position - _disp.position) * scale
		var sz := _crop.size * scale
		return Rect2i(Vector2i(roundi(pos.x), roundi(pos.y)), Vector2i(roundi(sz.x), roundi(sz.y)))
