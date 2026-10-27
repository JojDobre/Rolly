extends RefCounted
## Moderný plochý vzhľad menu, panelov a editora: zaoblené rohy, jemné tiene,
## farebné tlačidlá s hrubším spodným okrajom a font Baloo 2.
## Ikony sú z Kenney UI Pack a Mobile Controls.

const UI := "res://assets/ui/%s.png"
const FONT_PATH := "res://assets/fonts/Baloo2.ttf"

const INK := Color("24304a")        ## tmavý text
const INK_SOFT := Color("67748e")   ## popisky
const WHITE := Color("ffffff")
const OUTLINE := Color("1d2a45")    ## obrys veľkých nadpisov
const CARD := Color(1, 1, 1, 0.96)
const RADIUS := 20

## Farba plochy a spodného okraja (tieňa) tlačidiel podľa významu.
const COLORS := {
	"blue": [Color("3b8df0"), Color("2a63b8")],
	"green": [Color("37c76b"), Color("259450")],
	"yellow": [Color("ffc83d"), Color("d79a12")],
	"red": [Color("ff5d63"), Color("c63d44")],
	"grey": [Color("eef1f7"), Color("c4cbdb")],
	"dark": [Color("2c3a57"), Color("1b253b")],
}

static var _fonts := {}


## Font Baloo 2 v danej hrúbke (400 – 800).
static func font(weight := 600) -> Font:
	if not _fonts.has(weight):
		var variation := FontVariation.new()
		variation.base_font = load(FONT_PATH)
		variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		_fonts[weight] = variation
	return _fonts[weight]


static func make() -> Theme:
	var theme := Theme.new()
	theme.default_font = font(600)
	theme.default_font_size = 26

	theme.set_stylebox("panel", "PanelContainer", card(26))
	theme.set_stylebox("panel", "Panel", card(26))
	_button_styles(theme, "Button", "blue", 22, 10)
	_button_colors(theme, "Button", WHITE)
	theme.set_font("font", "Button", font(700))

	theme.set_color("font_color", "Label", INK)
	theme.set_font("font", "Label", font(600))

	var input := _flat(Color("f1f4f9"), 14, 18, 10)
	input.border_color = Color("d5dbe7")
	input.set_border_width_all(2)
	var focus := input.duplicate()
	focus.border_color = COLORS["blue"][0]
	theme.set_stylebox("normal", "LineEdit", input)
	theme.set_stylebox("focus", "LineEdit", focus)
	theme.set_stylebox("read_only", "LineEdit", input)
	theme.set_color("font_color", "LineEdit", INK)
	theme.set_color("font_placeholder_color", "LineEdit", INK_SOFT)
	theme.set_color("caret_color", "LineEdit", INK)

	_button_styles(theme, "OptionButton", "grey", 18, 10)
	_button_colors(theme, "OptionButton", INK)
	theme.set_font("font", "OptionButton", font(700))

	theme.set_icon("checked", "CheckBox", load(UI % "grey_check_square_color_checkmark"))
	theme.set_icon("unchecked", "CheckBox", load(UI % "grey_check_square_grey"))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		theme.set_color(state, "CheckBox", INK)

	var popup := card(10)
	theme.set_stylebox("panel", "PopupMenu", popup)
	theme.set_stylebox("hover", "PopupMenu", _flat(Color("e7eefb"), 10, 8, 4))
	theme.set_color("font_color", "PopupMenu", INK)
	theme.set_color("font_hover_color", "PopupMenu", INK)
	theme.set_stylebox("panel", "TooltipPanel", card(10))
	theme.set_color("font_color", "TooltipLabel", INK)

	var separator := StyleBoxLine.new()
	separator.color = Color("dfe4ee")
	separator.thickness = 2
	theme.set_stylebox("separator", "HSeparator", separator)
	var vseparator := separator.duplicate()
	vseparator.vertical = true
	theme.set_stylebox("separator", "VSeparator", vseparator)

	var scroll := _flat(Color(0, 0, 0, 0.12), 6, 0, 0)
	var grabber := _flat(Color(0.15, 0.2, 0.3, 0.45), 6, 0, 0)
	for type in ["HScrollBar", "VScrollBar"]:
		theme.set_stylebox("scroll", type, scroll)
		theme.set_stylebox("grabber", type, grabber)
		theme.set_stylebox("grabber_highlight", type, grabber)
		theme.set_stylebox("grabber_pressed", type, grabber)
	return theme


## Menší vzhľad pre editor, aby sa zmestil na mobil.
static func make_compact() -> Theme:
	var theme := make()
	theme.default_font_size = 20
	theme.set_stylebox("panel", "PanelContainer", card(10))
	_button_styles(theme, "Button", "blue", 12, 5)
	_button_styles(theme, "OptionButton", "grey", 12, 5)
	return theme


## Tlačidlo v danej farbe: blue, green, yellow, red, grey, dark.
static func colored_button(text: String, color := "blue") -> Button:
	var button := Button.new()
	button.text = text
	var styles := _styles(color, 22, 10)
	for state in styles:
		button.add_theme_stylebox_override(state, styles[state])
	var ink := INK if color in ["grey", "yellow"] else WHITE
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, ink)
	return button


## Zelené tlačidlo pre hlavnú akciu (Hrať, Ďalej, Uložiť).
static func primary_button(text: String) -> Button:
	return colored_button(text, "green")


## Prepínacie tlačidlo: sivé, keď je vypnuté, žlté, keď je vybrané (nástroje, paleta, karty).
static func style_toggle(button: Button, h_pad := 10, v_pad := 6) -> void:
	var off := _styles("grey", h_pad, v_pad)
	var on := _styles("yellow", h_pad, v_pad)
	button.add_theme_stylebox_override("normal", off["normal"])
	button.add_theme_stylebox_override("hover", off["hover"])
	button.add_theme_stylebox_override("pressed", on["normal"])
	button.add_theme_stylebox_override("hover_pressed", on["hover"])
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, INK)


## Okrúhle (alebo zaoblené štvorcové) tlačidlo s ikonou.
static func icon_button(icon: Texture2D, color := "blue", size := 72.0, rounded := true) -> Button:
	var button := Button.new()
	var radius := int(size / 2.0) if rounded else 16
	var pad := int(size * 0.22)
	var styles := _styles(color, pad, pad, radius)
	for state in styles:
		button.add_theme_stylebox_override(state, styles[state])
	button.icon = icon
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = Vector2(size, size)
	return button


## Veľký biely nadpis s jemným obrysom a tieňom.
static func title(text: String, size := 64) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font(800))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", WHITE)
	label.add_theme_color_override("font_outline_color", OUTLINE)
	label.add_theme_constant_override("outline_size", maxi(6, size / 9))
	label.add_theme_color_override("font_shadow_color", Color(0.05, 0.1, 0.25, 0.35))
	label.add_theme_constant_override("shadow_offset_y", maxi(3, size / 14))
	label.add_theme_constant_override("shadow_offset_x", 0)
	return label


## Nadpis panelu (pauza, koniec levelu…).
static func banner(text: String) -> Control:
	return title(text, 56)


## Biela karta so zaoblenými rohmi a jemným tieňom.
static func card(padding := 26) -> StyleBoxFlat:
	var box := _flat(CARD, RADIUS, padding, padding)
	box.shadow_color = Color(0.05, 0.1, 0.25, 0.18)
	box.shadow_size = 14
	box.shadow_offset = Vector2(0, 5)
	return box


## Štýly tlačidla: plocha + hrubší spodný okraj; pri stlačení sa „zatlačí“ dole.
static func _styles(color: String, h_pad: int, v_pad: int, radius := 16) -> Dictionary:
	var face: Color = COLORS[color][0]
	var edge: Color = COLORS[color][1]
	var normal := _flat(face, radius, h_pad, v_pad)
	normal.border_color = edge
	normal.border_width_bottom = 6
	normal.content_margin_bottom = v_pad + 6
	var hover := normal.duplicate()
	hover.bg_color = face.lightened(0.08)
	var pressed := normal.duplicate()
	pressed.bg_color = face.darkened(0.06)
	pressed.border_width_bottom = 2
	pressed.content_margin_top = v_pad + 4
	pressed.content_margin_bottom = v_pad + 2
	pressed.expand_margin_top = -4
	var disabled := _flat(Color("dfe3eb"), radius, h_pad, v_pad)
	disabled.border_color = Color("c9cfdb")
	disabled.border_width_bottom = 6
	disabled.content_margin_bottom = v_pad + 6
	return {"normal": normal, "hover": hover, "pressed": pressed, "hover_pressed": pressed,
		"disabled": disabled, "focus": StyleBoxEmpty.new()}


static func _button_styles(theme: Theme, type: String, color: String, h_pad: int, v_pad: int) -> void:
	var styles := _styles(color, h_pad, v_pad)
	for state in styles:
		theme.set_stylebox(state, type, styles[state])


static func _button_colors(theme: Theme, type: String, ink: Color) -> void:
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		theme.set_color(state, type, ink)
	theme.set_color("font_disabled_color", type, Color(INK, 0.45))


static func _flat(color: Color, radius: int, h_pad: int, v_pad: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.corner_detail = 8
	box.anti_aliasing = true
	box.content_margin_left = h_pad
	box.content_margin_right = h_pad
	box.content_margin_top = v_pad
	box.content_margin_bottom = v_pad
	return box
