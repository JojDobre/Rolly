extends Control
## Hlavné menu: výber levelu, životy a odpočet do ďalšieho života.

const UI := preload("res://scripts/ui_theme.gd")
const BACKGROUND := preload("res://scripts/background.gd")
const TEX_STAR := preload("res://assets/objects/star.png")
const TEX_LIFE := preload("res://assets/objects/hud_heart.png")
const TEX_BUTTON_SQUARE := preload("res://assets/controls/button_square.png")
const TEX_MUSIC_ON := preload("res://assets/controls/icon_music.png")
const TEX_MUSIC_OFF := preload("res://assets/controls/icon_music_disabled.png")
const STAR_DIM := Color(0.15, 0.2, 0.3, 0.45)

var _lives_label: Label
var _timer_label: Label
var _ad_button: Button
var _message: Label


func _ready() -> void:
	theme = UI.make()
	add_child(BACKGROUND.new())

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", -18)
	center.add_child(column)
	var banner := UI.banner("Gulička")
	banner.z_index = 1
	column.add_child(banner)

	var panel := PanelContainer.new()
	column.add_child(panel)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 20)
	panel.add_child(inner)
	inner.add_child(Control.new())

	var lives_row := HBoxContainer.new()
	lives_row.alignment = BoxContainer.ALIGNMENT_CENTER
	lives_row.add_theme_constant_override("separation", 12)
	lives_row.add_child(_icon(TEX_LIFE, 44))
	_lives_label = Label.new()
	lives_row.add_child(_lives_label)
	_timer_label = Label.new()
	_timer_label.add_theme_font_size_override("font_size", 22)
	lives_row.add_child(_timer_label)
	_ad_button = Button.new()
	_ad_button.text = "+1 (reklama)"
	_ad_button.add_theme_font_size_override("font_size", 22)
	_ad_button.pressed.connect(func(): GameState.show_rewarded_ad(GameState.add_life))
	lives_row.add_child(_ad_button)
	inner.add_child(lives_row)

	var world_label := Label.new()
	world_label.text = "Svet 1: Zelené kopce"
	world_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(world_label)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	inner.add_child(grid)
	for level in range(1, GameState.LEVEL_COUNT + 1):
		grid.add_child(_level_button(level))

	_message = Label.new()
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override("font_size", 22)
	_message.add_theme_color_override("font_color", Color("a51d16"))
	inner.add_child(_message)

	_build_music_toggle()
	GameState.lives_changed.connect(_on_lives_changed)
	GameState.play_music(GameState.MENU_PLAYLIST)
	_refresh()


## Tlačidlo vpravo hore na zapnutie a vypnutie hudby.
func _build_music_toggle() -> void:
	var toggle := TextureButton.new()
	toggle.texture_normal = TEX_BUTTON_SQUARE
	toggle.ignore_texture_size = true
	toggle.stretch_mode = TextureButton.STRETCH_SCALE
	toggle.custom_minimum_size = Vector2(72, 72)
	toggle.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	toggle.offset_left = -96
	toggle.offset_right = -24
	toggle.offset_top = 24
	toggle.offset_bottom = 96
	var icon := _icon(TEX_MUSIC_ON if GameState.music_enabled else TEX_MUSIC_OFF, 40)
	icon.position = Vector2(16, 16)
	toggle.add_child(icon)
	toggle.pressed.connect(func():
		GameState.set_music_enabled(not GameState.music_enabled)
		icon.texture = TEX_MUSIC_ON if GameState.music_enabled else TEX_MUSIC_OFF)
	add_child(toggle)


func _process(_delta: float) -> void:
	var seconds := GameState.seconds_to_next_life()
	_timer_label.text = "ďalší o " + GameState.format_time(seconds) if seconds > 0 else ""


func _on_lives_changed(_lives: int) -> void:
	_refresh()


func _refresh() -> void:
	_lives_label.text = "× %d" % GameState.lives
	_ad_button.visible = GameState.lives < GameState.MAX_LIVES


func _level_button(level: int) -> Control:
	var button := Button.new()
	button.custom_minimum_size = Vector2(140, 130)
	button.disabled = not GameState.is_unlocked(level)
	button.pressed.connect(_start_level.bind(level))

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(box)
	var number := Label.new()
	number.text = str(level)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.add_theme_font_size_override("font_size", 44)
	box.add_child(number)
	var stars := HBoxContainer.new()
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var best := int(GameState.best_stars.get(level, 0))
	for i in 3:
		var star := _icon(TEX_STAR, 34)
		if i >= best:
			star.self_modulate = STAR_DIM
		stars.add_child(star)
	box.add_child(stars)
	if button.disabled:
		box.modulate.a = 0.4
	return button


func _start_level(level: int) -> void:
	if GameState.lives <= 0:
		_message.text = "Nemáš životy. Počkaj na nový alebo si pozri reklamu."
		return
	GameState.current_level = level
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _icon(texture: Texture2D, size: int) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(size, size)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect
