extends Control
## Menu hry: hlavná obrazovka (výber postavičky), svety a levely na hranie,
## a správa svetov a levelov pre editor (vytvoriť svet, nový level, upraviť, zmazať).

const UI := preload("res://scripts/ui_theme.gd")
const Catalog := preload("res://scripts/catalog.gd")
const Validator := preload("res://scripts/level_validator.gd")
const BACKGROUND := preload("res://scripts/background.gd")
const VISUAL := preload("res://scripts/player_visual.gd")
const TILE := "res://assets/npp/tiles/%s.png"
const CONTROL := "res://assets/controls/%s.png"
const STAR_DIM := Color(0.15, 0.2, 0.3, 0.45)

## Stránka, ktorá sa otvorí po návrate z editora (nastaví editor).
static var return_page := ""
static var return_world_id := ""

var _page: Control
var _preview: Node2D
var _lives_label: Label
var _timer_label: Label
var _world: Dictionary
var _form := {}


func _ready() -> void:
	theme = UI.make()
	GameState.test_level = {}
	add_child(BACKGROUND.new())
	_page = Control.new()
	_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_page)
	GameState.play_music(GameState.MENU_PLAYLIST)
	GameState.lives_changed.connect(_on_lives_changed)
	if return_page != "":
		_world = Content.get_world(return_world_id)
		var page := return_page
		return_page = ""
		if page == "editor_levels" and not _world.is_empty():
			show_editor_levels(_world)
			return
	show_main()


func _process(delta: float) -> void:
	if _timer_label and is_instance_valid(_timer_label):
		var seconds := GameState.seconds_to_next_life()
		_timer_label.text = "ďalší o " + GameState.format_time(seconds) if seconds > 0 else ""
	if _preview and is_instance_valid(_preview):
		_preview.update_visual(delta, Vector2(sin(Time.get_ticks_msec() / 700.0) * 60.0, 0), 1.0, "walk")


func _on_lives_changed(_lives: int) -> void:
	if _lives_label and is_instance_valid(_lives_label):
		_lives_label.text = "× %d" % GameState.lives


# --- Hlavná obrazovka ----------------------------------------------------------

func show_main() -> void:
	var column := _new_page("Rolly")
	_top_right_buttons()

	# Výber postavičky
	var picker := HBoxContainer.new()
	picker.alignment = BoxContainer.ALIGNMENT_CENTER
	picker.add_theme_constant_override("separation", 16)
	column.add_child(picker)
	picker.add_child(_picker_column("Farba", Catalog.CHARACTER_COLORS, 0))
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(150, 130)
	_preview = VISUAL.new()
	_preview.position = Vector2(75, 70)
	_preview.scale = Vector2(1.6, 1.6)
	holder.add_child(_preview)
	picker.add_child(holder)
	picker.add_child(_picker_column("Tvar", Catalog.CHARACTER_SHAPES, 1))
	_refresh_preview()

	var lives := HBoxContainer.new()
	lives.alignment = BoxContainer.ALIGNMENT_CENTER
	lives.add_theme_constant_override("separation", 10)
	lives.add_child(_icon(TILE % "hud_heart", 40))
	_lives_label = Label.new()
	_lives_label.text = "× %d" % GameState.lives
	lives.add_child(_lives_label)
	_timer_label = _small_label("")
	lives.add_child(_timer_label)
	lives.add_child(_icon(TILE % "hud_coin", 40))
	lives.add_child(_small_label(str(GameState.coins)))
	column.add_child(lives)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	var play := UI.primary_button("Hrať")
	play.custom_minimum_size = Vector2(220, 70)
	play.pressed.connect(show_worlds)
	buttons.add_child(play)
	var editor := _button("Editor levelov", show_editor_worlds)
	editor.custom_minimum_size = Vector2(240, 70)
	buttons.add_child(editor)
	column.add_child(buttons)
	if GameState.lives < GameState.MAX_LIVES:
		column.add_child(_button("+1 život (reklama)", func(): GameState.show_rewarded_ad(GameState.add_life)))


func _picker_column(title: String, options: Dictionary, part: int) -> Control:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(_small_label(title))
	var row := HBoxContainer.new()
	row.add_child(_arrow("direction_left", func(): _cycle(options, part, -1)))
	var name_label := Label.new()
	name_label.name = "Value"
	name_label.custom_minimum_size = Vector2(170, 0)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 24)
	row.add_child(name_label)
	row.add_child(_arrow("direction_right", func(): _cycle(options, part, 1)))
	box.add_child(row)
	box.set_meta("options", options)
	box.set_meta("part", part)
	box.add_to_group("picker")
	return box


func _cycle(options: Dictionary, part: int, step: int) -> void:
	var parts := GameState.character.split("_")
	var keys := options.keys()
	var index := (keys.find(parts[part]) + step + keys.size()) % keys.size()
	parts[part] = keys[index]
	GameState.set_character("_".join(parts))
	_refresh_preview()


func _refresh_preview() -> void:
	var parts := GameState.character.split("_")
	_preview.setup(parts[0], parts[1])
	for picker in get_tree().get_nodes_in_group("picker"):
		var options: Dictionary = picker.get_meta("options")
		var label: Label = picker.find_child("Value", true, false)
		label.text = options.get(parts[picker.get_meta("part")], "")


# --- Hranie: svety a levely ---------------------------------------------------

func show_worlds() -> void:
	var column := _new_page("Svety", show_main)
	var list := _scroll_list(column)
	var any := false
	for world in Content.worlds:
		var playable := _playable_levels(world)
		if playable.is_empty():
			continue
		any = true
		var stars := 0
		for level in playable:
			stars += GameState.stars_for(world["id"], level["id"])
		var card := _card(TILE % ("terrain_%s_block_top" % world["terrain"]), world["name"],
				"%d levelov   hviezdy %d / %d" % [playable.size(), stars, playable.size() * 3])
		card.pressed.connect(show_levels.bind(world))
		list.add_child(card)
	if not any:
		list.add_child(_small_label("Zatiaľ tu nie je žiadny svet. Vytvor ho v editore."))


func show_levels(world: Dictionary) -> void:
	_world = world
	var column := _new_page(world["name"], show_worlds)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(980, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(grid)
	column.add_child(scroll)
	var playable := _playable_levels(world)
	for i in playable.size():
		grid.add_child(_level_button(world, playable, i))
	var message := _small_label("")
	message.name = "Message"
	column.add_child(message)


func _level_button(world: Dictionary, levels: Array, index: int) -> Control:
	var level: Dictionary = levels[index]
	var unlocked := index == 0 or GameState.is_completed(world["id"], levels[index - 1]["id"])
	var button := Button.new()
	button.custom_minimum_size = Vector2(150, 140)
	button.disabled = not unlocked
	button.tooltip_text = level["name"]
	button.pressed.connect(_play_level.bind(world, level))
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(box)
	var number := Label.new()
	number.text = str(index + 1)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.add_theme_font_size_override("font_size", 40)
	box.add_child(number)
	var stars := HBoxContainer.new()
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var best := GameState.stars_for(world["id"], level["id"])
	for i in 3:
		var star := _icon(TILE % "star", 32)
		if i >= best:
			star.self_modulate = STAR_DIM
		stars.add_child(star)
	box.add_child(stars)
	if not unlocked:
		box.modulate.a = 0.4
	return button


func _play_level(world: Dictionary, level: Dictionary) -> void:
	if GameState.lives <= 0:
		var message: Label = _page.find_child("Message", true, false)
		if message:
			message.text = "Nemáš životy. Počkaj na nový alebo si pozri reklamu."
		return
	GameState.current_world_id = world["id"]
	GameState.current_level_id = level["id"]
	get_tree().change_scene_to_file("res://scenes/game.tscn")


## Levely, ktoré sa dajú hrať (nie rozpracované s chybami).
func _playable_levels(world: Dictionary) -> Array:
	return world.get("levels", []).filter(func(l): return not l.get("draft", false))


# --- Editor: svety ------------------------------------------------------------

func show_editor_worlds() -> void:
	var column := _new_page("Editor – svety", show_main)
	var list := _scroll_list(column)
	for world in Content.worlds:
		var editable := Content.is_editable(world)
		var card := _card(TILE % ("terrain_%s_block_top" % world["terrain"]), world["name"],
				"%d levelov · %s · %s%s" % [world["levels"].size(), Catalog.TERRAINS.get(world["terrain"], ""),
				Catalog.BACKGROUNDS.get(world["background"], ""), "" if editable else " · len na hranie"])
		card.disabled = not editable
		card.pressed.connect(show_editor_levels.bind(world))
		list.add_child(card)
	var create := UI.primary_button("+ Nový svet")
	create.pressed.connect(show_world_form.bind({}))
	column.add_child(create)


## Formulár sveta: názov, štýl terénu, pozadie, hudba. Prázdny svet = vytvorenie nového.
func show_world_form(world: Dictionary) -> void:
	var is_new := world.is_empty()
	var column := _new_page("Nový svet" if is_new else "Nastavenia sveta",
			show_editor_worlds if is_new else show_editor_levels.bind(world))
	_form = {
		"terrain": world.get("terrain", "grass"),
		"background": world.get("background", "hills"),
		"music": world.get("music", ""),
	}
	var name_edit := LineEdit.new()
	name_edit.text = world.get("name", "Môj svet")
	name_edit.custom_minimum_size = Vector2(500, 50)
	name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(name_edit)

	column.add_child(_small_label("Štýl blokov"))
	column.add_child(_choice_row("terrain", Catalog.TERRAINS, func(key): return TILE % ("terrain_%s_block_top" % key)))
	column.add_child(_small_label("Pozadie"))
	column.add_child(_choice_row("background", Catalog.BACKGROUNDS, func(key): return "res://assets/npp/backgrounds/background_color_%s.png" % key))
	column.add_child(_small_label("Hudba"))
	var music := OptionButton.new()
	for key in GameState.TRACK_NAMES:
		music.add_item(GameState.TRACK_NAMES[key])
		music.set_item_metadata(music.item_count - 1, key)
		if key == _form["music"]:
			music.select(music.item_count - 1)
	music.item_selected.connect(func(i): _form["music"] = music.get_item_metadata(i))
	column.add_child(music)

	var save := UI.primary_button("Vytvoriť svet" if is_new else "Uložiť")
	save.pressed.connect(func():
		var world_name := name_edit.text.strip_edges()
		if world_name == "":
			world_name = "Môj svet"
		if is_new:
			var created := Content.new_world(world_name, _form["terrain"], _form["background"], _form["music"])
			show_editor_levels(created)
		else:
			world["name"] = world_name
			world["terrain"] = _form["terrain"]
			world["background"] = _form["background"]
			world["music"] = _form["music"]
			Content.save_world(world)
			show_editor_levels(world))
	column.add_child(save)


func _choice_row(key: String, options: Dictionary, icon_for: Callable) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var group := ButtonGroup.new()
	for option in options:
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = option == _form[key]
		button.icon = load(icon_for.call(option))
		button.expand_icon = true
		button.custom_minimum_size = Vector2(112, 84)
		button.text = options[option]
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_theme_font_size_override("font_size", 16)
		button.add_theme_constant_override("icon_max_width", 44)
		button.pressed.connect(func(): _form[key] = option)
		row.add_child(button)
	return row


# --- Editor: levely sveta -------------------------------------------------------

func show_editor_levels(world: Dictionary) -> void:
	_world = world
	var column := _new_page(world["name"], show_editor_worlds)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 12)
	top.add_child(_button("Nastavenia sveta", show_world_form.bind(world)))
	var create := UI.primary_button("+ Nový level")
	create.pressed.connect(func():
		var level := Content.new_level(world)
		Content.save_world(world)
		_open_editor(world, level))
	top.add_child(create)
	top.add_child(_button("Zmazať svet", _confirm.bind("Naozaj zmazať celý svet „%s“?" % world["name"], func():
		Content.delete_world(world)
		show_editor_worlds())))
	column.add_child(top)

	var list := _scroll_list(column)
	var levels: Array = world["levels"]
	if levels.is_empty():
		list.add_child(_small_label("Svet zatiaľ nemá levely. Vytvor prvý."))
	for i in levels.size():
		var level: Dictionary = levels[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var problems := Validator.check(level)
		var title := Label.new()
		title.text = "%d. %s" % [i + 1, level["name"]]
		title.custom_minimum_size = Vector2(380, 0)
		title.clip_text = true
		row.add_child(title)
		var status := _small_label("hotový" if problems.is_empty() else "rozpracovaný (%d)" % problems.size())
		status.custom_minimum_size = Vector2(190, 0)
		status.add_theme_color_override("font_color", Color("2e7d32") if problems.is_empty() else Color("b23b1e"))
		row.add_child(status)
		row.add_child(_button("Upraviť", _open_editor.bind(world, level)))
		row.add_child(_button("Hore", _move_level.bind(world, i, -1)))
		row.add_child(_button("Dole", _move_level.bind(world, i, 1)))
		row.add_child(_button("Zmazať", _confirm.bind("Zmazať level „%s“?" % level["name"], func():
			Content.delete_level(world, level["id"])
			show_editor_levels(world))))
		list.add_child(row)


func _move_level(world: Dictionary, index: int, step: int) -> void:
	var levels: Array = world["levels"]
	var target := index + step
	if target < 0 or target >= levels.size():
		return
	var level = levels[index]
	levels[index] = levels[target]
	levels[target] = level
	Content.save_world(world)
	show_editor_levels(world)


func _open_editor(world: Dictionary, level: Dictionary) -> void:
	GameState.editor_world_id = world["id"]
	GameState.editor_level_id = level["id"]
	GameState.editor_draft = {}
	get_tree().change_scene_to_file("res://scenes/editor.tscn")


# --- Pomocné ---------------------------------------------------------------------

## Vyčistí stránku a vráti stĺpec na obsah. back = funkcia tlačidla Späť.
func _new_page(title: String, back := Callable()) -> VBoxContainer:
	for child in _page.get_children():
		child.queue_free()
	_preview = null
	_timer_label = null
	_lives_label = null
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_page.add_child(center)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", -18)
	center.add_child(outer)
	var banner := UI.banner(title)
	banner.z_index = 1
	outer.add_child(banner)
	var panel := PanelContainer.new()
	outer.add_child(panel)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	column.add_child(Control.new())
	if back.is_valid():
		var back_button := TextureButton.new()
		back_button.texture_normal = load(CONTROL % "direction_left")
		back_button.ignore_texture_size = true
		back_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		back_button.custom_minimum_size = Vector2(72, 72)
		back_button.position = Vector2(24, 24)
		back_button.pressed.connect(back)
		back_button.z_index = 5
		_page.add_child(back_button)
	return column


func _top_right_buttons() -> void:
	var toggle := TextureButton.new()
	toggle.texture_normal = load(CONTROL % "button_square")
	toggle.ignore_texture_size = true
	toggle.stretch_mode = TextureButton.STRETCH_SCALE
	toggle.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	toggle.offset_left = -96
	toggle.offset_right = -24
	toggle.offset_top = 24
	toggle.offset_bottom = 96
	var icon := _icon(CONTROL % ("icons/icon_music" if GameState.music_enabled else "icons/icon_music_disabled"), 40)
	icon.position = Vector2(16, 16)
	toggle.add_child(icon)
	toggle.pressed.connect(func():
		GameState.set_music_enabled(not GameState.music_enabled)
		icon.texture = load(CONTROL % ("icons/icon_music" if GameState.music_enabled else "icons/icon_music_disabled")))
	_page.add_child(toggle)


func _scroll_list(column: VBoxContainer) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(980, 340)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	column.add_child(scroll)
	return list


func _card(icon_path: String, title: String, subtitle: String) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(940, 90)
	card.icon = load(icon_path)
	card.expand_icon = false
	card.text = "  %s\n  %s" % [title, subtitle]
	card.alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.add_theme_font_size_override("font_size", 24)
	return card


func _confirm(text: String, action: Callable) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	row.add_child(_button("Nie", dim.queue_free))
	var yes := UI.primary_button("Áno, zmazať")
	yes.pressed.connect(func():
		dim.queue_free()
		action.call())
	row.add_child(yes)
	box.add_child(row)


func _arrow(texture: String, action: Callable) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = load(CONTROL % texture)
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.custom_minimum_size = Vector2(56, 56)
	button.pressed.connect(action)
	return button


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(action)
	return button


func _small_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	return label


func _icon(path: String, size: int) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = load(path)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(size, size)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect
