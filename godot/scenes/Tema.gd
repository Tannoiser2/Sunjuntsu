class_name Tema
extends RefCounted
## Tema a carta washi e inchiostro: font, colori e riquadri creati da codice.

const CARTA := Color("efe6d3")
const CARTA_SCURA := Color("d9cdb2")
const INCHIOSTRO := Color("1c1815")
const VERMIGLIO := Color("b3261e")
const INDACO := Color("27456b")
const ORO := Color("c9a227")
const GIOCATORI := [Color("b3261e"), Color("27456b")]

static var _tema: Theme
static var titolo: FontFile
static var testo: FontFile
static var grassetto: FontFile


static func tema() -> Theme:
	if _tema != null:
		return _tema
	titolo = load("res://assets/fonts/Shojumaru-Regular.ttf")
	testo = load("res://assets/fonts/AlegreyaSans-Medium.ttf")
	grassetto = load("res://assets/fonts/AlegreyaSans-Bold.ttf")
	var t := Theme.new()
	t.default_font = testo
	t.default_font_size = 20
	t.set_stylebox("panel", "PanelContainer", riquadro(CARTA, INCHIOSTRO, 2, 8))
	t.set_stylebox("panel", "Panel", riquadro(CARTA, INCHIOSTRO, 2, 8))
	t.set_color("font_color", "Label", INCHIOSTRO)
	t.set_color("default_color", "RichTextLabel", INCHIOSTRO)
	t.set_font("bold_font", "RichTextLabel", grassetto)
	t.set_font_size("normal_font_size", "RichTextLabel", 18)
	t.set_font_size("bold_font_size", "RichTextLabel", 18)
	t.set_font("font", "Button", grassetto)
	t.set_font_size("font_size", "Button", 20)
	t.set_color("font_color", "Button", CARTA)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", CARTA)
	t.set_color("font_disabled_color", "Button", Color(0.75, 0.72, 0.65))
	t.set_stylebox("normal", "Button", riquadro(INCHIOSTRO, INCHIOSTRO, 2, 6, 14, 9))
	t.set_stylebox("hover", "Button", riquadro(VERMIGLIO, INCHIOSTRO, 2, 6, 14, 9))
	t.set_stylebox("pressed", "Button", riquadro(VERMIGLIO.darkened(0.25), INCHIOSTRO, 2, 6, 14, 9))
	t.set_stylebox("disabled", "Button", riquadro(Color(0.35, 0.33, 0.3), INCHIOSTRO, 2, 6, 14, 9))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "LineEdit", INCHIOSTRO)
	t.set_stylebox("normal", "LineEdit", riquadro(Color.WHITE, INCHIOSTRO, 1, 4, 8, 6))
	t.set_color("font_color", "OptionButton", CARTA)
	t.set_color("font_color", "SpinBox", INCHIOSTRO)
	t.set_color("font_color", "PopupMenu", CARTA)
	t.set_color("font_hover_color", "PopupMenu", ORO)
	t.set_color("font_color", "CheckBox", INCHIOSTRO)
	t.set_color("font_hover_color", "CheckBox", VERMIGLIO)
	t.set_color("font_pressed_color", "CheckBox", INCHIOSTRO)
	t.set_stylebox("panel", "PopupMenu", riquadro(INCHIOSTRO, ORO, 1, 4, 6, 6))
	t.set_font_size("font_size", "PopupMenu", 20)
	_tema = t
	return t


static func riquadro(sfondo: Color, bordo: Color, spess: int = 2, raggio: int = 8, mx: int = 12, my: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = sfondo
	s.border_color = bordo
	s.set_border_width_all(spess)
	s.set_corner_radius_all(raggio)
	s.content_margin_left = mx
	s.content_margin_right = mx
	s.content_margin_top = my
	s.content_margin_bottom = my
	return s


static func etichetta(t: String, dim: int = 20, col: Color = INCHIOSTRO, tit: bool = false) -> Label:
	tema()
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", dim)
	l.add_theme_color_override("font_color", col)
	if tit:
		l.add_theme_font_override("font", titolo)
	return l


static func bottone(t: String, larg: int = 150) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(larg, 46)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b
