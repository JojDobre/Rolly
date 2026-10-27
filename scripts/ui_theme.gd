extends RefCounted
## Vzhľad menu a panelov: Kenney UI Pack (lesklé farebné tlačidlá, biele karty) a font Baloo 2.

const UI := "res://assets/ui/%s.png"
const FONT_PATH := "res://assets/fonts/Baloo2.ttf"

const INK := Color("2b3a55")        ## tmavý text
const INK_SOFT := Color("5b6a85")   ## popisky
const WHITE := Color("ffffff")
const OUTLINE := Color("1f2b44")    ## obrys veľkých nadpisov

## Farby tlačidiel podľa významu.
const COLORS := {"blue": "blue", "green": "green", "yellow": "yellow", "red": "red", "grey": "grey"}

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

	theme.set_stylebox("panel", "PanelContainer", _card(28))
	theme.set_stylebox("panel", "Panel", _card(28))
	_button_styles(theme, "Button", "blue", 22, 12)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		theme.set_color(state, "Button", WHITE)
	theme.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.7))
	theme.set_color("font_outline_color", "Button", Color(0, 0, 0, 0.25))
	theme.set_constant("outline_size", "Button", 6)
	theme.set_font("font", "Button", font(700))

	theme.set_color("font_color", "Label", INK)
	theme.set_font("font", "Label", font(600))

	var input := _box("extra_input_rectangle", 22, 18, 10)
	theme.set_stylebox("normal", "LineEdit", input)
	theme.set_stylebox("focus", "LineEdit", input)
	theme.set_stylebox("read_only", "LineEdit", input)
	theme.set_color("font_color", "LineEdit", INK)
	theme.set_color("caret_color", "LineEdit", INK)

	_button_styles(theme, "OptionButton", "grey", 22, 12)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(state, "OptionButton", INK)
	theme.set_font("font", "OptionButton", font(700))

	theme.set_icon("checked", "CheckBox", load(UI % "grey_check_square_color_checkmark"))
	theme.set_icon("unchecked", "CheckBox", load(UI % "grey_check_square_grey"))
	theme.set_color("font_color", "CheckBox", INK)
	theme.set_color("font_hover_color", "CheckBox", INK)
	theme.set_color("font_pressed_color", "CheckBox", INK)

	theme.set_stylebox("panel", "PopupMenu", _card(12))
	theme.set_color("font_color", "PopupMenu", INK)
	theme.set_color("font_hover_color", "PopupMenu", INK)
	theme.set_stylebox("panel", "TooltipPanel", _card(10))
	theme.set_color("font_color", "TooltipLabel", INK)
	return theme


## Menší vzhľad pre editor, aby sa zmestil na mobil.
static func make_compact() -> Theme:
	var theme := make()
	theme.default_font_size = 20
	theme.set_stylebox("panel", "PanelContainer", _card(8))
	_button_styles(theme, "Button", "blue", 12, 6)
	_button_styles(theme, "OptionButton", "grey", 12, 6)
	return theme


## Tlačidlo v danej farbe: blue, green, yellow, red, grey.
static func colored_button(text: String, color := "blue") -> Button:
	var button := Button.new()
	button.text = text
	var styles := _styles(color, 22, 12)
	for state in styles:
		button.add_theme_stylebox_override(state, styles[state])
	if color in ["grey", "yellow"]:
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(state, INK)
		button.add_theme_constant_override("outline_size", 0)
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
	button.add_theme_constant_override("outline_size", 0)


## Okrúhle/štvorcové tlačidlo s ikonou.
static func icon_button(icon: Texture2D, color := "blue", size := 72.0, rounded := true) -> Button:
	var button := Button.new()
	var base := "%s_button_%s" % [color, "round" if rounded else "square"]
	# Celý obrázok sa roztiahne na štvorcové tlačidlo (bez 9-slice), aby kruh zostal kruhom.
	var normal := _box(base + "_depth_gloss", 0, int(size * 0.2), int(size * 0.18))
	normal.content_margin_bottom = int(size * 0.24)
	var pressed := _box(base + "_depth_flat", 0, int(size * 0.2), int(size * 0.22))
	pressed.content_margin_bottom = int(size * 0.2)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.icon = icon
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = Vector2(size, size)
	return button


## Veľký biely nadpis s tmavým obrysom.
static func title(text: String, size := 64) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font(800))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", WHITE)
	label.add_theme_color_override("font_outline_color", OUTLINE)
	label.add_theme_constant_override("outline_size", maxi(8, size / 6))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.25))
	label.add_theme_constant_override("shadow_offset_y", maxi(3, size / 16))
	return label


## Zachované kvôli starým volaniam: nadpis panelu.
static func banner(text: String) -> Control:
	return title(text, 52)


static func card(padding := 28) -> StyleBoxTexture:
	return _card(padding)


static func _card(padding: int) -> StyleBoxTexture:
	return _box("grey_button_square_flat", 24, padding, padding)


static func _button_styles(theme: Theme, type: String, color: String, h_pad: int, v_pad: int) -> void:
	var styles := _styles(color, h_pad, v_pad)
	for state in styles:
		theme.set_stylebox(state, type, styles[state])


static func _styles(color: String, h_pad: int, v_pad: int) -> Dictionary:
	var normal := _box(color + "_button_rectangle_depth_gloss", 24, h_pad, v_pad)
	normal.content_margin_bottom = v_pad + 6
	var pressed := _box(color + "_button_rectangle_depth_flat", 24, h_pad, v_pad)
	pressed.content_margin_top = v_pad + 4
	pressed.content_margin_bottom = v_pad + 2
	var hover := normal.duplicate()
	hover.modulate_color = Color(1.06, 1.06, 1.06)
	var disabled := _box("grey_button_rectangle_depth_flat", 24, h_pad, v_pad)
	disabled.modulate_color = Color(1, 1, 1, 0.6)
	return {"normal": normal, "hover": hover, "pressed": pressed, "hover_pressed": pressed,
		"disabled": disabled, "focus": StyleBoxEmpty.new()}


static func _box(texture: String, margin: int, h_pad: int, v_pad: int) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = load(UI % texture)
	box.texture_margin_left = margin
	box.texture_margin_right = margin
	box.texture_margin_top = margin
	box.texture_margin_bottom = margin
	box.content_margin_left = h_pad
	box.content_margin_right = h_pad
	box.content_margin_top = v_pad
	box.content_margin_bottom = v_pad
	return box
