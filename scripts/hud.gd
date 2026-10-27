extends CanvasLayer
## Herné rozhranie: hviezdy, čas, životy, pauza, dotykové ovládanie a panely po leveli.

const UI := preload("res://scripts/ui_theme.gd")
const TEX_STAR := preload("res://assets/items/starGold.png")
const TEX_STAR_EMPTY := preload("res://assets/items/starSilver.png")
const TEX_LIFE := preload("res://assets/ui/ball_icon.png")
const TEX_LEFT := preload("res://assets/ui/touch_left.png")
const TEX_RIGHT := preload("res://assets/ui/touch_right.png")
const TEX_JUMP := preload("res://assets/ui/touch_jump.png")

var game  # game.gd

var _root: Control
var _stars_box: HBoxContainer
var _time_label: Label
var _lives_label: Label
var _title_label: Label
var _overlay: Control
var _countdown_label: Label
var _touch_buttons := []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UI.make()
	add_child(_root)
	_build_top_bar()
	_build_touch_controls()
	GameState.lives_changed.connect(_on_lives_changed)
	_on_lives_changed(GameState.lives)


func _process(_delta: float) -> void:
	if _countdown_label:
		if GameState.lives > 0:
			_close_overlay()
			game.continue_after_ad()
		else:
			_countdown_label.text = "Ďalší život o " + GameState.format_time(GameState.seconds_to_next_life())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and game.running:
		toggle_pause()


# --- Horná lišta ----------------------------------------------------------

func _build_top_bar() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	_root.add_child(margin)

	var bar := HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_constant_override("separation", 18)
	margin.add_child(bar)

	_stars_box = HBoxContainer.new()
	bar.add_child(_stars_box)
	_time_label = _hud_label("0:00", 30)
	bar.add_child(_time_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(spacer)

	bar.add_child(_icon(TEX_LIFE, 44))
	_lives_label = _hud_label("× 10", 34)
	bar.add_child(_lives_label)

	var pause := Button.new()
	pause.text = "II"
	pause.custom_minimum_size = Vector2(72, 64)
	pause.pressed.connect(toggle_pause)
	bar.add_child(pause)

	_title_label = _hud_label("", 44)
	_title_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_title_label.position.y = 110
	_root.add_child(_title_label)


func set_level_title(level: int, title: String) -> void:
	_title_label.text = "Level %d: %s" % [level, title]
	var tween := create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(_title_label, "modulate:a", 0.0, 0.6)


func update_stars(collected: int, total: int) -> void:
	if _stars_box.get_child_count() != total:
		for child in _stars_box.get_children():
			_stars_box.remove_child(child)
			child.queue_free()
		for i in total:
			_stars_box.add_child(_icon(TEX_STAR_EMPTY, 46))
	for i in total:
		var icon: TextureRect = _stars_box.get_child(i)
		var lit := i < collected
		if lit and icon.texture != TEX_STAR:
			icon.pivot_offset = Vector2(23, 23)
			icon.scale = Vector2(1.6, 1.6)
			create_tween().tween_property(icon, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)
		icon.texture = TEX_STAR if lit else TEX_STAR_EMPTY


func update_time(seconds: float) -> void:
	_time_label.text = GameState.format_time(int(seconds))


func _on_lives_changed(lives: int) -> void:
	_lives_label.text = "× %d" % lives


# --- Dotykové ovládanie ---------------------------------------------------

func _build_touch_controls() -> void:
	for spec in [[TEX_LEFT, "move_left"], [TEX_RIGHT, "move_right"], [TEX_JUMP, "jump"]]:
		var button := TouchScreenButton.new()
		button.texture_normal = spec[0]
		button.action = spec[1]
		button.passby_press = true
		button.visibility_mode = TouchScreenButton.VISIBILITY_TOUCHSCREEN_ONLY
		var circle := CircleShape2D.new()
		circle.radius = 70.0
		button.shape = circle
		button.shape_centered = true
		button.pressed.connect(func(): button.modulate = Color(1, 1, 1, 0.6))
		button.released.connect(func(): button.modulate = Color.WHITE)
		add_child(button)
		_touch_buttons.append(button)
	get_viewport().size_changed.connect(_place_touch_controls)
	_place_touch_controls()


func _place_touch_controls() -> void:
	var size := get_viewport().get_visible_rect().size
	_touch_buttons[0].position = Vector2(40, size.y - 170)
	_touch_buttons[1].position = Vector2(200, size.y - 170)
	_touch_buttons[2].position = Vector2(size.x - 170, size.y - 170)


func _set_touch_visible(on: bool) -> void:
	for button in _touch_buttons:
		button.visible = on


# --- Panely ---------------------------------------------------------------

func toggle_pause() -> void:
	if _overlay and not get_tree().paused:
		return  # iný panel (koniec levelu) je už otvorený
	if get_tree().paused:
		_close_overlay()
		get_tree().paused = false
		return
	get_tree().paused = true
	var resume := UI.primary_button("Pokračovať")
	resume.pressed.connect(toggle_pause)
	_show_panel("Pauza", [], [_button("Menu", Callable(game, "go_to_menu")), _button("Reštart", Callable(game, "restart_level")), resume])


func show_level_complete(stars: int, total: int, seconds: float, has_next: bool) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	var icons := []
	for i in total:
		var icon := _icon(TEX_STAR_EMPTY, 84)
		row.add_child(icon)
		icons.append(icon)
	var time_label := Label.new()
	time_label.text = "Čas: " + GameState.format_time(int(seconds))
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var buttons := [_button("Menu", Callable(game, "go_to_menu")), _button("Znova", Callable(game, "restart_level"))]
	if has_next:
		var next := UI.primary_button("Ďalej")
		next.pressed.connect(Callable(game, "next_level"))
		buttons.append(next)
	_show_panel("Level dokončený!", [row, time_label], buttons)

	# Hviezdy sa rozsvietia jedna po druhej.
	var tween := create_tween()
	for i in stars:
		var icon: TextureRect = icons[i]
		tween.tween_interval(0.25)
		tween.tween_callback(func():
			icon.texture = TEX_STAR
			icon.pivot_offset = icon.size / 2.0
			icon.scale = Vector2(1.5, 1.5)
			create_tween().tween_property(icon, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)
			GameState.play_sfx("impactGlass_light_000", 0.0, 1.0 + i * 0.15))


func show_out_of_lives() -> void:
	_countdown_label = Label.new()
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var info := Label.new()
	info.text = "Pozri si krátku reklamu a hraj hneď,\nalebo počkaj na nový život."
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 24)
	var ad := UI.primary_button("+1 život (reklama)")
	ad.pressed.connect(func(): GameState.show_rewarded_ad(GameState.add_life))
	_show_panel("Došli životy", [info, _countdown_label], [_button("Menu", Callable(game, "go_to_menu")), ad])


func _show_panel(title: String, content: Array, buttons: Array) -> void:
	_close_overlay()
	_set_touch_visible(false)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.08, 0.12, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay = dim
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", -18)
	center.add_child(column)
	var banner := UI.banner(title)
	banner.z_index = 1
	column.add_child(banner)

	var panel := PanelContainer.new()
	column.add_child(panel)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 22)
	panel.add_child(inner)
	inner.add_child(Control.new())  # miesto pod transparentom
	for node in content:
		inner.add_child(node)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	for button in buttons:
		row.add_child(button)
	inner.add_child(row)

	dim.modulate.a = 0.0
	create_tween().tween_property(dim, "modulate:a", 1.0, 0.2)


func _close_overlay() -> void:
	if _overlay:
		_overlay.queue_free()
		_overlay = null
	_countdown_label = null
	_set_touch_visible(true)


# --- Pomocné --------------------------------------------------------------

func _hud_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color("2b3a4a"))
	label.add_theme_constant_override("outline_size", 10)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _icon(texture: Texture2D, size: int) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(size, size)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	return button
