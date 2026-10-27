extends CanvasLayer
## Herné rozhranie: srdcia, mince, hviezdy, kľúče, životy, dych, power-upy, pauza,
## dotykové ovládanie (Kenney Mobile Controls) a panely (pauza, koniec levelu, došli životy).

const UI := preload("res://scripts/ui_theme.gd")
const TILE := "res://assets/npp/tiles/%s.png"
const CONTROL := "res://assets/controls/%s.png"
const STAR_DIM := Color(0.15, 0.2, 0.3, 0.45)
const TOUCH_SIZE := 120.0

var game  # game.gd

var _root: Control
var _hearts: HBoxContainer
var _stars_box: HBoxContainer
var _keys_box: HBoxContainer
var _powerups_box: HBoxContainer
var _coins_label: Label
var _time_label: Label
var _lives_label: Label
var _title_label: Label
var _breath: ProgressBar
var _overlay: Control
var _countdown_label: Label
var _touch := {}
var _player


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


func bind_player(player) -> void:
	_player = player
	player.health_changed.connect(update_health)
	player.breath_changed.connect(_on_breath)
	player.powerups_changed.connect(_update_powerups)
	update_health(player.health)


# --- Horná lišta ----------------------------------------------------------

func _build_top_bar() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	_root.add_child(margin)

	var bar := HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_constant_override("separation", 14)
	margin.add_child(bar)

	_hearts = HBoxContainer.new()
	_hearts.add_theme_constant_override("separation", 0)
	bar.add_child(_hearts)
	bar.add_child(_icon(load(TILE % "hud_coin"), 44))
	_coins_label = _hud_label("0", 30)
	bar.add_child(_coins_label)
	_stars_box = HBoxContainer.new()
	_stars_box.add_theme_constant_override("separation", 0)
	bar.add_child(_stars_box)
	_keys_box = HBoxContainer.new()
	bar.add_child(_keys_box)
	_powerups_box = HBoxContainer.new()
	bar.add_child(_powerups_box)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(spacer)

	_time_label = _hud_label("0:00", 26)
	bar.add_child(_time_label)
	bar.add_child(_icon(load("res://assets/shape/%s_body_%s.png" % Array(GameState.character.split("_"))), 40))
	_lives_label = _hud_label("× 10", 30)
	bar.add_child(_lives_label)

	var pause := TextureButton.new()
	pause.texture_normal = load(CONTROL % "button_square")
	pause.ignore_texture_size = true
	pause.stretch_mode = TextureButton.STRETCH_SCALE
	pause.custom_minimum_size = Vector2(64, 64)
	pause.pressed.connect(toggle_pause)
	var pause_icon := _icon(load(CONTROL % "icons/icon_pause"), 36)
	pause_icon.position = Vector2(14, 14)
	pause.add_child(pause_icon)
	bar.add_child(pause)

	_breath = ProgressBar.new()
	_breath.max_value = 1.0
	_breath.step = 0.01
	_breath.value = 1.0
	_breath.show_percentage = false
	_breath.custom_minimum_size = Vector2(220, 18)
	_breath.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_breath.position = Vector2(-110, 96)
	_breath.visible = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("3d8ee8")
	fill.set_corner_radius_all(9)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.4)
	back.set_corner_radius_all(9)
	_breath.add_theme_stylebox_override("fill", fill)
	_breath.add_theme_stylebox_override("background", back)
	_root.add_child(_breath)

	_title_label = _hud_label("", 40)
	_title_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_title_label.position.y = 120
	_root.add_child(_title_label)


func set_level_title(title: String) -> void:
	_title_label.text = title
	var tween := create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(_title_label, "modulate:a", 0.0, 0.6)


func update_health(health: int) -> void:
	for child in _hearts.get_children():
		child.queue_free()
	for i in 3:
		_hearts.add_child(_icon(load(TILE % ("hud_heart" if i < health else "hud_heart_empty")), 44))


func update_coins(amount: int) -> void:
	_coins_label.text = str(amount)


func update_stars(collected: int, total: int) -> void:
	for child in _stars_box.get_children():
		child.queue_free()
	for i in total:
		var star := _icon(load(TILE % "star"), 46)
		if i >= collected:
			star.self_modulate = STAR_DIM
		_stars_box.add_child(star)


func update_keys(keys: Dictionary) -> void:
	for child in _keys_box.get_children():
		child.queue_free()
	for color in keys:
		_keys_box.add_child(_icon(load(TILE % ("hud_key_" + color)), 40))


func update_time(seconds: float) -> void:
	_time_label.text = GameState.format_time(int(seconds))


func _on_lives_changed(lives: int) -> void:
	_lives_label.text = "× %d" % lives


func _on_breath(ratio: float) -> void:
	_breath.visible = ratio < 0.999
	_breath.value = ratio
	_breath.modulate = Color.WHITE if ratio > 0.3 else Color(1, 0.5, 0.5)


func _update_powerups() -> void:
	for child in _powerups_box.get_children():
		child.queue_free()
	if _player == null:
		return
	for entry in [["gem_blue", _player.speed_boost], ["gem_green", _player.jump_boost], ["gem_yellow", _player.shield]]:
		if entry[1] > 0.0:
			var icon := _icon(load(TILE % entry[0]), 40)
			if entry[1] < 2.0:
				icon.modulate.a = 0.5 if int(entry[1] * 6.0) % 2 == 0 else 1.0
			_powerups_box.add_child(icon)


# --- Dotykové ovládanie ---------------------------------------------------

func _build_touch_controls() -> void:
	var specs := {
		"left": ["direction_left", "", "move_left"],
		"right": ["direction_right", "", "move_right"],
		"up": ["direction_right", "", "move_up"],
		"down": ["direction_right", "", "move_down"],
		"jump": ["button_circle", "icons/icon_jump", "jump"],
	}
	for key in specs:
		var spec: Array = specs[key]
		var button := TouchScreenButton.new()
		button.texture_normal = load(CONTROL % spec[0])
		button.action = spec[2]
		button.passby_press = true
		button.visibility_mode = TouchScreenButton.VISIBILITY_TOUCHSCREEN_ONLY
		var tex_size: Vector2 = button.texture_normal.get_size()
		button.scale = Vector2.ONE * (TOUCH_SIZE / maxf(tex_size.x, tex_size.y))
		var rect := RectangleShape2D.new()
		rect.size = tex_size * 1.15
		button.shape = rect
		button.shape_centered = true
		button.modulate = Color(1, 1, 1, 0.85)
		if spec[1] != "":
			var icon := Sprite2D.new()
			icon.texture = load(CONTROL % spec[1])
			icon.position = tex_size / 2.0
			icon.scale = Vector2(0.6, 0.6)
			button.add_child(icon)
		button.pressed.connect(func(): button.modulate = Color(1, 1, 1, 0.55))
		button.released.connect(func(): button.modulate = Color(1, 1, 1, 0.85))
		add_child(button)
		_touch[key] = button
	get_viewport().size_changed.connect(_place_touch_controls)
	_place_touch_controls()


func _place_touch_controls() -> void:
	var size := get_viewport().get_visible_rect().size
	var margin := 28.0
	var gap := 14.0
	var bottom := size.y - TOUCH_SIZE - margin
	_touch["left"].position = Vector2(margin, bottom)
	_touch["right"].position = Vector2(margin + TOUCH_SIZE + gap, bottom)
	_touch["jump"].position = Vector2(size.x - TOUCH_SIZE - margin, bottom)
	# Hore/dole (rebrík, páčka, zoskočenie z plošiny) – menšie, nad sebou vedľa skoku.
	var small := TOUCH_SIZE * 0.7
	var column_x := size.x - TOUCH_SIZE - margin - gap - small
	# Šípka doprava otočená hore/dole; pri otočení sa posúva aj začiatok obrázka.
	_touch["up"].rotation = -PI / 2.0
	_touch["down"].rotation = PI / 2.0
	_touch["up"].position = Vector2(column_x, size.y - small - margin - gap - small + small)
	_touch["down"].position = Vector2(column_x + small, size.y - small - margin)
	for key in ["up", "down"]:
		var tex_size: Vector2 = _touch[key].texture_normal.get_size()
		_touch[key].scale = Vector2.ONE * (small / maxf(tex_size.x, tex_size.y))


func _set_touch_visible(on: bool) -> void:
	for button in _touch.values():
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
	var menu_text := "Do editora" if game.test_mode else "Menu"
	_show_panel("Pauza", [], [_button(menu_text, Callable(game, "go_to_menu")), _button("Reštart", Callable(game, "restart_level")), resume])


func show_level_complete(stars: int, total: int, coins: int, seconds: float, has_next: bool, test_mode: bool) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	var icons := []
	for i in total:
		var icon := _icon(load(TILE % "star"), 100)
		icon.self_modulate = STAR_DIM
		row.add_child(icon)
		icons.append(icon)
	var info := Label.new()
	info.text = "Mince: %d     Čas: %s" % [coins, GameState.format_time(int(seconds))]
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var buttons := []
	if test_mode:
		buttons.append(_button("Znova", Callable(game, "restart_level")))
		var back := UI.primary_button("Späť do editora")
		back.pressed.connect(Callable(game, "go_to_menu"))
		buttons.append(back)
	else:
		buttons.append(_button("Menu", Callable(game, "go_to_menu")))
		buttons.append(_button("Znova", Callable(game, "restart_level")))
		if has_next:
			var next := UI.primary_button("Ďalej")
			next.pressed.connect(Callable(game, "next_level"))
			buttons.append(next)
	_show_panel("Level dokončený!", [row, info], buttons)

	var tween := create_tween()
	for i in mini(stars, icons.size()):
		var icon: TextureRect = icons[i]
		tween.tween_interval(0.25)
		tween.tween_callback(func():
			icon.self_modulate = Color.WHITE
			icon.pivot_offset = icon.size / 2.0
			icon.scale = Vector2(1.5, 1.5)
			create_tween().tween_property(icon, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)
			GameState.play_sfx("impact/impactGlass_light_000", 0.0, 1.0 + i * 0.15))


func show_out_of_lives() -> void:
	GameState.play_jingle(GameState.JINGLE_NO_LIVES)
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
	column.add_theme_constant_override("separation", 6)
	center.add_child(column)
	var banner := UI.banner(title)
	banner.z_index = 1
	column.add_child(banner)

	var panel := PanelContainer.new()
	column.add_child(panel)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 22)
	panel.add_child(inner)
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
