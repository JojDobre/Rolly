extends Control
## Menu hry: hlavná obrazovka (výber postavičky), svety a levely na hranie,
## a správa svetov a levelov pre editor (vytvoriť svet, nový level, upraviť, zmazať).
## Vzhľad: Kenney UI Pack + font Baloo 2 (ui_theme.gd), pozadie a tráva z New Platformer Pack.

const UI := preload("res://scripts/ui_theme.gd")
const Catalog := preload("res://scripts/catalog.gd")
const Validator := preload("res://scripts/level_validator.gd")
const BACKGROUND := preload("res://scripts/background.gd")
const VISUAL := preload("res://scripts/player_visual.gd")
const TILE := "res://assets/npp/tiles/%s.png"
const ICON := "res://assets/controls/icons/%s.png"
const UI_TEX := "res://assets/ui/%s.png"
const STAR_DIM := Color(0.15, 0.2, 0.3, 0.35)
const GROUND_HEIGHT := 96.0

## Stránka, ktorá sa otvorí po návrate z editora (nastaví editor).
static var return_page := ""
static var return_world_id := ""

var _page: Control
var _preview: Node2D
var _lives_label: Label
var _timer_label: Label
var _coins_label: Label
var _world: Dictionary
var _form := {}


func _ready() -> void:
	theme = UI.make()
	GameState.test_level = {}
	add_child(BACKGROUND.new())
	_build_ground()
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
		_timer_label.text = GameState.format_time(seconds) if seconds > 0 else ""
		_timer_label.visible = seconds > 0
	if _preview and is_instance_valid(_preview):
		_preview.update_visual(delta, Vector2.ZERO, 1.0, "idle")


func _on_lives_changed(_lives: int) -> void:
	if _lives_label and is_instance_valid(_lives_label):
		_lives_label.text = str(GameState.lives)


## Pás trávy dole na všetkých obrazovkách menu.
func _build_ground() -> void:
	var ground := TextureRect.new()
	ground.texture = load(TILE % "terrain_grass_block_top")
	ground.stretch_mode = TextureRect.STRETCH_TILE
	ground.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ground.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	ground.offset_top = -GROUND_HEIGHT
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)


# --- Hlavná obrazovka ----------------------------------------------------------

func show_main() -> void:
	_clear()
	_stats_pill()
	_music_button()

	var logo := UI.title("Rolly", 150)
	logo.set_anchors_preset(Control.PRESET_CENTER_TOP)
	logo.grow_horizontal = Control.GROW_DIRECTION_BOTH
	logo.position.y = 10
	_page.add_child(logo)

	# Postavička v strede, vedľa nej výber farby a tvaru.
	var stage := Control.new()
	stage.set_anchors_preset(Control.PRESET_CENTER)
	stage.position = Vector2(0, -20)
	_page.add_child(stage)
	_preview = VISUAL.new()
	_preview.scale = Vector2(2.6, 2.6)
	_preview.position = Vector2(0, 20)
	stage.add_child(_preview)

	var color_row := _picker_row("Farba", Catalog.CHARACTER_COLORS, 0)
	color_row.position = Vector2(-460, -50)
	stage.add_child(color_row)
	var shape_row := _picker_row("Tvar", Catalog.CHARACTER_SHAPES, 1)
	shape_row.position = Vector2(150, -50)
	stage.add_child(shape_row)
	_refresh_preview.call_deferred()

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 24)
	buttons.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	buttons.grow_horizontal = Control.GROW_DIRECTION_BOTH
	buttons.grow_vertical = Control.GROW_DIRECTION_BEGIN
	buttons.offset_bottom = -GROUND_HEIGHT - 20
	var play := UI.primary_button("Hrať")
	play.custom_minimum_size = Vector2(300, 96)
	play.add_theme_font_size_override("font_size", 44)
	play.pressed.connect(show_worlds)
	buttons.add_child(play)
	var editor := UI.colored_button("Editor", "yellow")
	editor.custom_minimum_size = Vector2(240, 96)
	editor.add_theme_font_size_override("font_size", 36)
	editor.pressed.connect(show_editor_worlds)
	buttons.add_child(editor)
	_page.add_child(buttons)


func _picker_row(label_text: String, options: Dictionary, part: int) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.add_child(_label(label_text, 22, UI.INK_SOFT))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.add_child(_arrow_button("w", func(): _cycle(options, part, -1)))
	var value := _label("", 26)
	value.name = "Value"
	value.custom_minimum_size = Vector2(170, 0)
	row.add_child(value)
	row.add_child(_arrow_button("e", func(): _cycle(options, part, 1)))
	box.add_child(row)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.card(12))
	panel.add_child(box)
	panel.set_meta("options", options)
	panel.set_meta("part", part)
	panel.add_to_group("picker")
	return panel


func _cycle(options: Dictionary, part: int, step: int) -> void:
	var parts := GameState.character.split("_")
	var keys := options.keys()
	var index := (keys.find(parts[part]) + step + keys.size()) % keys.size()
	parts[part] = keys[index]
	GameState.set_character("_".join(parts))
	_refresh_preview()
	_preview.squash(0.6)


func _refresh_preview() -> void:
	var parts := GameState.character.split("_")
	_preview.setup(parts[0], parts[1])
	for picker in get_tree().get_nodes_in_group("picker"):
		var options: Dictionary = picker.get_meta("options")
		var label: Label = picker.find_child("Value", true, false)
		label.text = options.get(parts[picker.get_meta("part")], "")


func _stats_pill() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.card(12))
	panel.position = Vector2(20, 20)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_icon(TILE % "hud_heart", 40))
	_lives_label = _label(str(GameState.lives), 30)
	row.add_child(_lives_label)
	_timer_label = _label("", 20, UI.INK_SOFT)
	row.add_child(_timer_label)
	row.add_child(VSeparator.new())
	row.add_child(_icon(TILE % "hud_coin", 40))
	_coins_label = _label(str(GameState.coins), 30)
	row.add_child(_coins_label)
	if GameState.lives < GameState.MAX_LIVES:
		var ad := UI.colored_button("+1", "green")
		ad.tooltip_text = "+1 život za reklamu"
		ad.add_theme_font_size_override("font_size", 22)
		ad.pressed.connect(func(): GameState.show_rewarded_ad(GameState.add_life))
		row.add_child(ad)
	panel.add_child(row)
	_page.add_child(panel)


func _music_button() -> void:
	var button := UI.icon_button(load(ICON % ("icon_music" if GameState.music_enabled else "icon_music_disabled")), "blue", 76)
	button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	button.offset_left = -96
	button.offset_right = -20
	button.offset_top = 20
	button.offset_bottom = 96
	button.pressed.connect(func():
		GameState.set_music_enabled(not GameState.music_enabled)
		button.icon = load(ICON % ("icon_music" if GameState.music_enabled else "icon_music_disabled")))
	_page.add_child(button)


# --- Hranie: svety a levely ---------------------------------------------------

func show_worlds() -> void:
	var content := _new_page("Svety", show_main)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1160, 390)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var center := CenterContainer.new()
	center.custom_minimum_size = Vector2(1160, 380)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	center.add_child(row)
	scroll.add_child(center)
	content.add_child(scroll)
	var any := false
	for world in Content.worlds:
		var playable := _playable_levels(world)
		if playable.is_empty():
			continue
		any = true
		row.add_child(_world_card(world, playable))
	if not any:
		content.add_child(_note("Zatiaľ tu nie je žiadny svet. Vytvor ho v editore."))


func _world_card(world: Dictionary, levels: Array) -> Control:
	var stars := 0
	var done := 0
	for level in levels:
		stars += GameState.stars_for(world["id"], level["id"])
		done += 1 if GameState.is_completed(world["id"], level["id"]) else 0
	var card := Button.new()
	card.custom_minimum_size = Vector2(300, 370)
	for state in ["normal", "hover", "pressed", "focus"]:
		card.add_theme_stylebox_override(state, UI.card(20))
	card.pressed.connect(show_levels.bind(world))
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 22
	box.offset_right = -22
	box.offset_top = 22
	box.offset_bottom = -22
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	var preview := TextureRect.new()
	preview.texture = load("res://assets/npp/backgrounds/background_color_%s.png" % world.get("background", "hills"))
	preview.clip_contents = true
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	preview.custom_minimum_size = Vector2(256, 140)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(preview)
	var ground := TextureRect.new()
	ground.texture = load(TILE % ("terrain_%s_block_top" % world["terrain"]))
	ground.stretch_mode = TextureRect.STRETCH_TILE
	ground.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ground.custom_minimum_size = Vector2(256, 40)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(ground)
	var name_label := _label(world["name"], 32)
	name_label.add_theme_font_override("font", UI.font(800))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(name_label)
	box.add_child(_label("%d / %d levelov" % [done, levels.size()], 22, UI.INK_SOFT))
	var star_row := HBoxContainer.new()
	star_row.alignment = BoxContainer.ALIGNMENT_CENTER
	star_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star_row.add_child(_icon(TILE % "star", 40))
	star_row.add_child(_label("%d / %d" % [stars, levels.size() * 3], 26))
	box.add_child(star_row)
	return card


func show_levels(world: Dictionary) -> void:
	_world = world
	var content := _new_page(world["name"], show_worlds)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 14)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1080, 410)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var center := CenterContainer.new()
	center.custom_minimum_size = Vector2(1060, 0)
	center.add_child(grid)
	scroll.add_child(center)
	content.add_child(scroll)
	var playable := _playable_levels(world)
	for i in playable.size():
		grid.add_child(_level_button(world, playable, i))
	var message := _note("")
	message.name = "Message"
	content.add_child(message)


func _level_button(world: Dictionary, levels: Array, index: int) -> Control:
	var level: Dictionary = levels[index]
	var unlocked := index == 0 or GameState.is_completed(world["id"], levels[index - 1]["id"])
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var button := Button.new()
	var color := "blue" if unlocked else "grey"
	if unlocked and GameState.is_completed(world["id"], level["id"]):
		color = "green"
	var styles := UI._styles(color, 8, 8, 28)
	for state in styles:
		button.add_theme_stylebox_override(state, styles[state])
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.custom_minimum_size = Vector2(140, 140)
	button.tooltip_text = level["name"]
	if unlocked:
		button.text = str(index + 1)
		button.add_theme_font_override("font", UI.font(800))
		button.add_theme_font_size_override("font_size", 60)
		button.pressed.connect(_play_level.bind(world, level))
	else:
		button.icon = load(TILE % "lock_yellow")
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.disabled = true
	box.add_child(button)
	var stars := HBoxContainer.new()
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	stars.add_theme_constant_override("separation", 0)
	var best := GameState.stars_for(world["id"], level["id"])
	for i in 3:
		var star := _icon(TILE % "star", 42)
		if i >= best:
			star.self_modulate = STAR_DIM
		stars.add_child(star)
	box.add_child(stars)
	return box


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
	var content := _new_page("Editor", show_main)
	var list := _scroll_list(content, 360)
	for world in Content.worlds:
		var editable := Content.is_editable(world)
		var row := _row_card()
		var hbox: HBoxContainer = row.get_child(0)
		hbox.add_child(_icon(TILE % ("terrain_%s_block_top" % world["terrain"]), 56))
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_theme_constant_override("separation", -4)
		var name_label := _label(world["name"], 28, UI.INK, HORIZONTAL_ALIGNMENT_LEFT)
		name_label.add_theme_font_override("font", UI.font(800))
		texts.add_child(name_label)
		texts.add_child(_label("%d levelov · %s · %s" % [world["levels"].size(), Catalog.TERRAINS.get(world["terrain"], ""),
				Catalog.BACKGROUNDS.get(world["background"], "")], 20, UI.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT))
		hbox.add_child(texts)
		if editable:
			var open := UI.colored_button("Otvoriť", "blue")
			open.pressed.connect(show_editor_levels.bind(world))
			hbox.add_child(open)
		else:
			hbox.add_child(_label("len na hranie", 20, UI.INK_SOFT))
		list.add_child(row)
	var create := UI.primary_button("+ Nový svet")
	create.custom_minimum_size = Vector2(320, 76)
	create.pressed.connect(show_world_form.bind({}))
	content.add_child(create)


## Formulár sveta: názov, štýl terénu, pozadie, hudba. Prázdny svet = vytvorenie nového.
func show_world_form(world: Dictionary) -> void:
	var is_new := world.is_empty()
	var content := _new_page("Nový svet" if is_new else "Nastavenia sveta",
			show_editor_worlds if is_new else show_editor_levels.bind(world))
	_form = {
		"terrain": world.get("terrain", "grass"),
		"background": world.get("background", "hills"),
		"music": world.get("music", ""),
	}
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.card(22))
	content.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	card.add_child(column)

	var name_edit := LineEdit.new()
	name_edit.text = world.get("name", "Môj svet")
	name_edit.placeholder_text = "Názov sveta"
	name_edit.custom_minimum_size = Vector2(760, 56)
	name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(name_edit)
	column.add_child(_label("Štýl blokov", 22, UI.INK_SOFT))
	column.add_child(_choice_row("terrain", Catalog.TERRAINS, func(key): return TILE % ("terrain_%s_block_top" % key)))
	column.add_child(_label("Pozadie", 22, UI.INK_SOFT))
	column.add_child(_choice_row("background", Catalog.BACKGROUNDS, func(key): return "res://assets/npp/backgrounds/background_color_%s.png" % key))
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_child(_label("Hudba", 22, UI.INK_SOFT))
	var music := OptionButton.new()
	music.custom_minimum_size = Vector2(320, 0)
	for key in GameState.TRACK_NAMES:
		music.add_item(GameState.TRACK_NAMES[key])
		music.set_item_metadata(music.item_count - 1, key)
		if key == _form["music"]:
			music.select(music.item_count - 1)
	music.item_selected.connect(func(i): _form["music"] = music.get_item_metadata(i))
	bottom.add_child(music)
	var save := UI.primary_button("Vytvoriť svet" if is_new else "Uložiť")
	save.custom_minimum_size = Vector2(260, 0)
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
	bottom.add_child(save)
	column.add_child(bottom)


func _choice_row(key: String, options: Dictionary, icon_for: Callable) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var buttons := []
	for option in options:
		var button := Button.new()
		button.icon = load(icon_for.call(option))
		button.expand_icon = true
		button.custom_minimum_size = Vector2(118, 100)
		button.text = options[option]
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_theme_font_size_override("font_size", 18)
		button.add_theme_constant_override("icon_max_width", 48)
		buttons.append([button, option])
		row.add_child(button)
	var refresh := func():
		for entry in buttons:
			var selected: bool = entry[1] == _form[key]
			var styles := UI._styles("yellow" if selected else "grey", 10, 8)
			for state in styles:
				entry[0].add_theme_stylebox_override(state, styles[state])
			for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
				entry[0].add_theme_color_override(state, UI.INK)
			entry[0].add_theme_constant_override("outline_size", 0)
	for entry in buttons:
		entry[0].pressed.connect(func():
			_form[key] = entry[1]
			refresh.call())
	refresh.call()
	return row


# --- Editor: levely sveta -------------------------------------------------------

func show_editor_levels(world: Dictionary) -> void:
	_world = world
	var content := _new_page(world["name"], show_editor_worlds)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 14)
	var create := UI.primary_button("+ Nový level")
	create.pressed.connect(func():
		var level := Content.new_level(world)
		Content.save_world(world)
		_open_editor(world, level))
	top.add_child(create)
	var settings := UI.colored_button("Nastavenia sveta", "yellow")
	settings.pressed.connect(show_world_form.bind(world))
	top.add_child(settings)
	var remove := UI.colored_button("Zmazať svet", "red")
	remove.pressed.connect(_confirm.bind("Naozaj zmazať celý svet „%s“?" % world["name"], func():
		Content.delete_world(world)
		show_editor_worlds()))
	top.add_child(remove)
	content.add_child(top)

	var list := _scroll_list(content, 340)
	var levels: Array = world["levels"]
	if levels.is_empty():
		list.add_child(_note("Svet zatiaľ nemá levely. Vytvor prvý."))
	for i in levels.size():
		var level: Dictionary = levels[i]
		var problems := Validator.check(level)
		var row := _row_card()
		var hbox: HBoxContainer = row.get_child(0)
		var number := _label(str(i + 1), 34)
		number.add_theme_font_override("font", UI.font(800))
		number.custom_minimum_size = Vector2(48, 0)
		hbox.add_child(number)
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_theme_constant_override("separation", -4)
		texts.add_child(_label(level["name"], 26, UI.INK, HORIZONTAL_ALIGNMENT_LEFT))
		var status := _label("hotový – dá sa hrať" if problems.is_empty() else "rozpracovaný – chýba %d vec(í)" % problems.size(),
				18, Color("2e7d32") if problems.is_empty() else Color("c0392b"), HORIZONTAL_ALIGNMENT_LEFT)
		texts.add_child(status)
		hbox.add_child(texts)
		var edit := UI.colored_button("Upraviť", "blue")
		edit.pressed.connect(_open_editor.bind(world, level))
		hbox.add_child(edit)
		var up := UI.icon_button(load(UI_TEX % "extra_icon_arrow_up_dark"), "grey", 56, false)
		up.pressed.connect(_move_level.bind(world, i, -1))
		hbox.add_child(up)
		var down := UI.icon_button(load(UI_TEX % "extra_icon_arrow_down_dark"), "grey", 56, false)
		down.pressed.connect(_move_level.bind(world, i, 1))
		hbox.add_child(down)
		var delete := UI.icon_button(load(UI_TEX % "grey_icon_cross"), "red", 56, false)
		delete.pressed.connect(_confirm.bind("Zmazať level „%s“?" % level["name"], func():
			Content.delete_level(world, level["id"])
			show_editor_levels(world)))
		hbox.add_child(delete)
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

func _clear() -> void:
	for child in _page.get_children():
		child.queue_free()
	_preview = null
	_timer_label = null
	_lives_label = null


## Vyčistí stránku: nadpis hore, tlačidlo späť vľavo, vráti stĺpec na obsah.
func _new_page(title_text: String, back := Callable()) -> VBoxContainer:
	_clear()
	var heading := UI.title(title_text, 72)
	heading.set_anchors_preset(Control.PRESET_CENTER_TOP)
	heading.grow_horizontal = Control.GROW_DIRECTION_BOTH
	heading.position.y = 8
	_page.add_child(heading)
	if back.is_valid():
		var back_button := UI.icon_button(load(UI_TEX % "grey_arrow_basic_w"), "blue", 76)
		back_button.position = Vector2(20, 20)
		back_button.pressed.connect(back)
		_page.add_child(back_button)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 110
	center.offset_bottom = -GROUND_HEIGHT + 30
	_page.add_child(center)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 18)
	center.add_child(column)
	return column


func _scroll_list(column: VBoxContainer, height: float) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1000, height)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)
	column.add_child(scroll)
	return list


func _row_card() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.card(14))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(hbox)
	return panel


func _confirm(text: String, action: Callable) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.08, 0.15, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	panel.add_child(box)
	box.add_child(_label(text, 28))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	var no := UI.colored_button("Nie", "grey")
	no.pressed.connect(dim.queue_free)
	row.add_child(no)
	var yes := UI.colored_button("Áno, zmazať", "red")
	yes.pressed.connect(func():
		dim.queue_free()
		action.call())
	row.add_child(yes)
	box.add_child(row)


func _arrow_button(direction: String, action: Callable) -> Button:
	var button := UI.icon_button(load(UI_TEX % ("grey_arrow_basic_" + direction)), "blue", 56)
	button.pressed.connect(action)
	return button


func _label(text: String, size: int, color := UI.INK, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


## Text priamo na pozadí (biely s obrysom, aby bol čitateľný na nebi).
func _note(text: String) -> Label:
	var label := _label(text, 26, Color.WHITE)
	label.add_theme_color_override("font_outline_color", UI.OUTLINE)
	label.add_theme_constant_override("outline_size", 8)
	return label


func _icon(path: String, size: int) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = load(path)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(size, size)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect
