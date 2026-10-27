extends RefCounted
## Vzhľad menu a panelov postavený z Kenney UI Pack Adventure.

const TEX_PANEL := preload("res://assets/ui/panel_brown.png")
const TEX_BUTTON := preload("res://assets/ui/button_brown.png")
const TEX_BUTTON_RED := preload("res://assets/ui/button_red.png")
const TEX_BANNER := preload("res://assets/ui/banner_hanging.png")

const TEXT_DARK := Color("4a2c14")
const TEXT_LIGHT := Color("fff6e3")


static func make() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 30

	theme.set_stylebox("panel", "PanelContainer", _box(TEX_PANEL, 20, 36))

	var normal := _box(TEX_BUTTON, 14, 18)
	var pressed := _box(TEX_BUTTON, 14, 18)
	pressed.modulate_color = Color(0.85, 0.8, 0.75)
	var disabled := _box(TEX_BUTTON, 14, 18)
	disabled.modulate_color = Color(1, 1, 1, 0.45)
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", normal)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("disabled", "Button", disabled)
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(state, "Button", TEXT_DARK)
	theme.set_color("font_disabled_color", "Button", Color(TEXT_DARK, 0.5))

	theme.set_color("font_color", "Label", TEXT_DARK)
	return theme


## Červené tlačidlo pre hlavnú akciu (Ďalej, Hrať).
static func primary_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	var box := _box(TEX_BUTTON_RED, 14, 18)
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", box)
	var pressed := _box(TEX_BUTTON_RED, 14, 18)
	pressed.modulate_color = Color(0.85, 0.8, 0.8)
	button.add_theme_stylebox_override("pressed", pressed)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, TEXT_LIGHT)
	return button


## Nadpis na zavesenom transparente.
static func banner(text: String) -> Control:
	var holder := MarginContainer.new()
	holder.custom_minimum_size = Vector2(520, 130)
	var bg := NinePatchRect.new()
	bg.texture = TEX_BANNER
	bg.patch_margin_left = 40
	bg.patch_margin_right = 40
	bg.patch_margin_top = 30
	bg.patch_margin_bottom = 30
	holder.add_child(bg)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", TEXT_LIGHT)
	label.add_theme_color_override("font_outline_color", Color("8c1612"))
	label.add_theme_constant_override("outline_size", 8)
	holder.add_child(label)
	return holder


static func _box(texture: Texture2D, margin: int, padding: int) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = texture
	box.texture_margin_left = margin
	box.texture_margin_right = margin
	box.texture_margin_top = margin
	box.texture_margin_bottom = margin
	box.content_margin_left = padding * 1.6
	box.content_margin_right = padding * 1.6
	box.content_margin_top = padding
	box.content_margin_bottom = padding
	return box
