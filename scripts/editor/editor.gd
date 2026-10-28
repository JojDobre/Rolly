extends Node2D
## Editor levelu. Paleta obsahuje len predmety (terén sa kreslí v štýle sveta),
## kontrola párov hneď ukáže, čo v leveli chýba (kľúč → zámok, tlačidlo → bloky...),
## a level sa dá okamžite vyskúšať.
##
## Ovládanie: prst/ľavé tlačidlo = nástroj, dva prsty / pravé tlačidlo = posun, koliesko/štipnutie = zoom.

const Catalog := preload("res://scripts/catalog.gd")
const Validator := preload("res://scripts/level_validator.gd")
const UI := preload("res://scripts/ui_theme.gd")
const MENU := preload("res://scripts/menu.gd")
const ENEMY := preload("res://scripts/entities/enemy.gd")
const T := 64
const MIN_ZOOM := 0.25
const MAX_ZOOM := 2.0
const UNDO_LIMIT := 60

var world: Dictionary
var level: Dictionary
var tool := "paint"           ## paint, erase, pan, edit
var item := "ground"          ## vybraný predmet na kreslenie
var tool_params := {}         ## parametre pre nové predmety (farba, obsah...)
var dirty := false

var _undo: Array = []
var _stroke_saved := false
var _painting := false
var _touches := {}            ## index prsta -> pozícia
var _pinch_distance := 0.0
var _edit_cell := Vector2i(-1, -1)
var _category := "teren"

@onready var canvas = $Canvas
@onready var camera: Camera2D = $Camera2D

# UI
var _ui: Control
var _name_edit: LineEdit
var _size_label: Label
var _palette: HBoxContainer
var _tool_buttons := {}
var _item_label: Label
var _side: PanelContainer
var _props_box: VBoxContainer
var _problems_box: VBoxContainer
var _check_button: Button
var _toast: Label
var _toast_tween: Tween
var _ui_panels: Array = []
var _path_points: Array = []  ## body cesty moba počas jej zadávania    ## panely rozhrania – dotyk na nich nekreslí do levelu


func _ready() -> void:
	GameState.test_level = {}
	world = Content.get_world(GameState.editor_world_id)
	if world.is_empty():
		get_tree().change_scene_to_file.call_deferred("res://scenes/menu.tscn")
		return
	if not GameState.editor_draft.is_empty():
		level = GameState.editor_draft
		dirty = GameState.editor_draft.get("_dirty", false)
		level.erase("_dirty")
	else:
		level = Content.get_level(world["id"], GameState.editor_level_id).duplicate(true)
	GameState.editor_draft = {}
	canvas.level = level
	canvas.terrain = world.get("terrain", "grass")
	canvas.refresh()
	_build_ui()
	_select_item("ground")
	_set_tool("paint")
	_refresh_problems()
	camera.zoom = Vector2(0.75, 0.75)
	camera.position = Vector2(12 * T, (int(level["height"]) - 5) * T)
	GameState.stop_music()


# --- Vstup --------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch and event.pressed) and _over_ui(event.position):
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		if _touches.size() >= 2:
			_end_stroke()
			_pinch_distance = _pinch()
		elif event.index == 0:
			if event.pressed:
				_begin_stroke(event.position)
			else:
				_end_stroke()
	elif event is InputEventScreenDrag:
		var previous: Vector2 = _touches.get(event.index, event.position)
		_touches[event.index] = event.position
		if _touches.size() >= 2:
			# Dva prsty: posun a štipnutie
			camera.position -= event.relative / camera.zoom.x / _touches.size()
			var distance := _pinch()
			if _pinch_distance > 0.0 and distance > 0.0:
				_zoom_by(distance / _pinch_distance)
			_pinch_distance = distance
		elif event.index == 0:
			if tool == "pan":
				camera.position -= (event.position - previous) / camera.zoom.x
			elif _painting:
				_apply_tool(_cell_at(event.position))
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_by(1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_by(1.0 / 1.1)
	elif event is InputEventMouseMotion:
		canvas.hover = _cell_at(event.position)
		canvas.queue_redraw()
		if event.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE):
			camera.position -= event.relative / camera.zoom.x
	elif event is InputEventKey and event.pressed and event.ctrl_pressed and event.keycode == KEY_Z:
		undo()


func _over_ui(screen_pos: Vector2) -> bool:
	for panel in _ui_panels:
		if panel.visible and panel.get_global_rect().has_point(screen_pos):
			return true
	return false


func _pinch() -> float:
	if _touches.size() < 2:
		return 0.0
	var points := _touches.values()
	return (points[0] as Vector2).distance_to(points[1])


func _zoom_by(factor: float) -> void:
	var z := clampf(camera.zoom.x * factor, MIN_ZOOM, MAX_ZOOM)
	camera.zoom = Vector2(z, z)


func _cell_at(screen_pos: Vector2) -> Vector2i:
	var world_pos: Vector2 = get_canvas_transform().affine_inverse() * screen_pos
	return Vector2i(floori(world_pos.x / T), floori(world_pos.y / T))


func _begin_stroke(screen_pos: Vector2) -> void:
	if tool == "pan":
		return
	_painting = true
	_stroke_saved = false
	var was_tool := tool
	_apply_tool(_cell_at(screen_pos))
	if was_tool == "edit" or was_tool == "path":
		_painting = false


func _end_stroke() -> void:
	if _painting and _stroke_saved:
		_refresh_problems()
	_painting = false


# --- Nástroje -------------------------------------------------------------------

func _apply_tool(cell: Vector2i) -> void:
	if cell.x < 0 or cell.y < 0 or cell.x >= int(level["width"]) or cell.y >= int(level["height"]):
		return
	var key := "%d,%d" % [cell.x, cell.y]
	var cells: Dictionary = level["cells"]
	match tool:
		"paint":
			var new_cell := {"t": item}
			for k in tool_params:
				new_cell[k] = tool_params[k]
			# Stena podzemia a tajná stena sú vrstva: predmet v bunke zostane (pred stenou podzemia,
			# za tajnou stenou).
			var old_cell: Dictionary = cells.get(key, {})
			var old_kind: String = Catalog.get_item(old_cell.get("t", "")).get("kind", "")
			var new_kind: String = Catalog.get_item(item).get("kind", "")
			var layers := ["backwall", "secret"]
			if new_kind in layers and not old_cell.is_empty() and not old_kind in layers:
				if not Catalog.is_solid_kind(old_kind):
					new_cell = old_cell.duplicate()
					new_cell["bg"] = item
			elif not new_kind in layers and not Catalog.is_solid_kind(new_kind):
				if old_kind in layers:
					new_cell["bg"] = old_cell["t"]
				elif old_cell.has("bg"):
					new_cell["bg"] = old_cell["bg"]
			if old_cell == new_cell:
				return
			var first_in_stroke := not _stroke_saved
			_save_undo()
			if item == "start":
				for other in cells.keys():
					if cells[other].get("t", "") == "start":
						cells.erase(other)
			cells[key] = new_cell
			var hint := Validator.hint_for(item, tool_params)
			if hint != "" and first_in_stroke:
				_show_toast(hint)
		"erase":
			if not cells.has(key):
				return
			_save_undo()
			# najprv zmizne predmet, stena podzemia za ním zostane
			if cells[key].has("bg"):
				cells[key] = {"t": cells[key]["bg"]}
			else:
				cells.erase(key)
		"edit":
			_edit_cell = cell
			canvas.selected = cell
			_show_properties()
			canvas.queue_redraw()
			return
		"path":
			_path_points.append(cell)
			canvas.path_preview = _path_points.duplicate()
			if _path_points.size() == 1:
				_show_toast("Teraz ťukni na KONIEC cesty.")
				canvas.queue_redraw()
				return
			var mob_key := "%d,%d" % [_edit_cell.x, _edit_cell.y]
			if cells.has(mob_key):
				_save_undo()
				var a: Vector2i = _path_points[0]
				var b: Vector2i = _path_points[1]
				cells[mob_key]["path"] = [a.x, a.y, b.x, b.y]
				_show_toast("Cesta je nastavená.")
			_path_points.clear()
			canvas.path_preview = []
			tool = "edit"
			canvas.refresh()
			_show_properties()
			dirty = true
			return
	dirty = true
	canvas.refresh()
	if not _painting:
		_refresh_problems()


func _save_undo() -> void:
	if _painting and _stroke_saved:
		return
	_undo.append(level["cells"].duplicate(true))
	if _undo.size() > UNDO_LIMIT:
		_undo.pop_front()
	_stroke_saved = true


func undo() -> void:
	if _undo.is_empty():
		_show_toast("Nie je čo vrátiť.")
		return
	level["cells"] = _undo.pop_back()
	canvas.level = level
	canvas.refresh()
	dirty = true
	_refresh_problems()


func _set_tool(new_tool: String) -> void:
	tool = new_tool
	for key in _tool_buttons:
		_tool_buttons[key].button_pressed = key == tool
	if tool != "edit":
		_edit_cell = Vector2i(-1, -1)
		canvas.selected = _edit_cell
		canvas.queue_redraw()
	_show_properties()


func _select_item(id: String, params := {}) -> void:
	item = id
	tool_params = {}
	var defaults: Dictionary = Catalog.get_item(id)["params"]
	var kind: String = Catalog.get_item(id)["kind"]
	for key in Validator.EDITABLE:
		if defaults.has(key) and not (key == "color" and not kind in ["lever", "lift", "warp"]):
			tool_params[key] = params.get(key, defaults[key])
	var cat: String = Catalog.get_item(id)["cat"]
	if cat != _category:
		_show_category(cat)
	for button in _palette.get_children():
		button.button_pressed = button.get_meta("id") == id
	var info: String = Catalog.get_item(id).get("info", "")
	_item_label.text = Catalog.get_item(id)["name"] + ("  –  " + info if info != "" else "")
	if tool != "paint":
		_set_tool("paint")
	else:
		_show_properties()


# --- Ukladanie a testovanie -------------------------------------------------------

func save() -> void:
	level["name"] = _name_edit.text.strip_edges() if _name_edit.text.strip_edges() != "" else level["name"]
	var problems := Validator.check(level)
	level["draft"] = not problems.is_empty()
	var levels: Array = world["levels"]
	var replaced := false
	for i in levels.size():
		if levels[i]["id"] == level["id"]:
			levels[i] = level.duplicate(true)
			replaced = true
	if not replaced:
		levels.append(level.duplicate(true))
	if Content.save_world(world):
		dirty = false
		if problems.is_empty():
			_show_toast("Uložené. Level je hotový a dá sa hrať.")
		else:
			_show_toast("Uložené ako rozpracované – v hre sa objaví, keď opravíš %d problém(y)." % problems.size())
		_open_side(not problems.is_empty())


func test_level() -> void:
	var cells: Dictionary = level["cells"]
	var has_start := cells.values().any(func(c): return c.get("t", "") == "start")
	if not has_start:
		_show_toast("Na skúšanie treba položiť štart.")
		return
	level["name"] = _name_edit.text
	GameState.test_world = world
	GameState.test_level = level.duplicate(true)
	var draft := level.duplicate(true)
	draft["_dirty"] = dirty
	GameState.editor_draft = draft
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func go_back() -> void:
	if dirty:
		_ask_save()
		return
	MENU.return_page = "editor_levels"
	MENU.return_world_id = world["id"]
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func resize(dw: int, dh: int) -> void:
	var w := clampi(int(level["width"]) + dw, 16, 400)
	var h := clampi(int(level["height"]) + dh, 10, 60)
	_save_undo()
	_stroke_saved = false
	var cells: Dictionary = level["cells"]
	# Pri zmene výšky posunieme obsah, aby zem zostala dole.
	var shift := h - int(level["height"])
	var moved := {}
	for key in cells:
		var p := Vector2i(int(key.split(",")[0]), int(key.split(",")[1]) + shift)
		if p.x >= 0 and p.y >= 0 and p.x < w and p.y < h:
			moved["%d,%d" % [p.x, p.y]] = cells[key]
	level["cells"] = moved
	level["width"] = w
	level["height"] = h
	_size_label.text = "%d × %d" % [w, h]
	dirty = true
	canvas.refresh()
	_refresh_problems()


# --- Rozhranie ----------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.theme = UI.make_compact()
	layer.add_child(_ui)

	# Horná lišta
	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_ui.add_child(top)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	top.add_child(bar)
	bar.add_child(_button("Späť", go_back))
	_name_edit = LineEdit.new()
	_name_edit.text = level["name"]
	_name_edit.custom_minimum_size = Vector2(240, 0)
	_name_edit.text_changed.connect(func(_t): dirty = true)
	bar.add_child(_name_edit)
	bar.add_child(_small("Šírka"))
	bar.add_child(_button("−", resize.bind(-4, 0)))
	bar.add_child(_button("+", resize.bind(4, 0)))
	bar.add_child(_small("Výška"))
	bar.add_child(_button("−", resize.bind(0, -1)))
	bar.add_child(_button("+", resize.bind(0, 1)))
	_size_label = _small("%d × %d" % [int(level["width"]), int(level["height"])])
	bar.add_child(_size_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	bar.add_child(_button("Vrátiť", undo))
	_check_button = _button("Kontrola", func(): _open_side(not _side.visible))
	bar.add_child(_check_button)
	bar.add_child(_button("Skúsiť", test_level))
	var save_button := UI.primary_button("Uložiť")
	save_button.pressed.connect(save)
	bar.add_child(save_button)

	# Nástroje vľavo
	var tools := VBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	tools.position = Vector2(8, 66)
	_ui.add_child(tools)
	for spec in [["paint", "Kresliť"], ["erase", "Guma"], ["pan", "Posun"], ["edit", "Upraviť"]]:
		var b := Button.new()
		b.text = spec[1]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(104, 44)
		UI.style_toggle(b)
		b.pressed.connect(_set_tool.bind(spec[0]))
		tools.add_child(b)
		_tool_buttons[spec[0]] = b
	var zoom_row := HBoxContainer.new()
	zoom_row.add_child(_button("+", _zoom_by.bind(1.25)))
	zoom_row.add_child(_button("−", _zoom_by.bind(0.8)))
	tools.add_child(zoom_row)

	# Paleta dole
	var bottom := PanelContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_ui.add_child(bottom)
	var bottom_box := VBoxContainer.new()
	bottom.add_child(bottom_box)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	for cat in Catalog.CATEGORIES:
		var tab := _button(cat[1], _show_category.bind(cat[0]))
		tab.toggle_mode = true
		UI.style_toggle(tab)
		tab.set_meta("cat", cat[0])
		tab.add_to_group("editor_tab")
		tabs.add_child(tab)
	bottom_box.add_child(tabs)
	_item_label = _small("")
	_item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_item_label.clip_text = true
	_item_label.custom_minimum_size = Vector2(900, 0)
	bottom_box.add_child(_item_label)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 76)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_palette = HBoxContainer.new()
	_palette.add_theme_constant_override("separation", 6)
	scroll.add_child(_palette)
	bottom_box.add_child(scroll)

	# Bočný panel: vlastnosti a kontrola
	_side = PanelContainer.new()
	_side.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_side.offset_left = -330
	_side.offset_top = 62
	_side.offset_bottom = -152
	_ui.add_child(_side)
	var side_scroll := ScrollContainer.new()
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_side.add_child(side_scroll)
	var side_box := VBoxContainer.new()
	side_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_box.add_theme_constant_override("separation", 10)
	side_scroll.add_child(side_box)
	_props_box = VBoxContainer.new()
	side_box.add_child(_props_box)
	side_box.add_child(HSeparator.new())
	_problems_box = VBoxContainer.new()
	side_box.add_child(_problems_box)
	_side.visible = false

	_ui_panels = [top, tools, bottom, _side]
	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.position.y = 70
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_color_override("font_color", Color.WHITE)
	_toast.add_theme_color_override("font_outline_color", Color("1d2b3a"))
	_toast.add_theme_constant_override("outline_size", 10)
	_toast.add_theme_font_size_override("font_size", 26)
	_toast.modulate.a = 0.0
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_toast)


func _show_category(cat: String) -> void:
	_category = cat
	for tab in get_tree().get_nodes_in_group("editor_tab"):
		tab.button_pressed = tab.get_meta("cat") == cat
	for child in _palette.get_children():
		_palette.remove_child(child)
		child.queue_free()
	for id in Catalog.in_category(cat):
		var b := Button.new()
		b.toggle_mode = true
		b.icon = load(Catalog.icon_path(id, world.get("terrain", "grass")))
		b.expand_icon = true
		b.custom_minimum_size = Vector2(68, 68)
		UI.style_toggle(b, 6, 4)
		b.tooltip_text = Catalog.get_item(id)["name"]
		b.set_meta("id", id)
		b.button_pressed = id == item
		b.pressed.connect(_select_item.bind(id))
		_palette.add_child(b)


func _open_side(open: bool) -> void:
	_side.visible = open


## Vlastnosti: pri kreslení pre nové predmety, pri úprave pre vybranú bunku.
func _show_properties() -> void:
	if _props_box == null:
		return
	for child in _props_box.get_children():
		child.queue_free()
	var target: Dictionary
	var id := item
	if tool == "edit":
		var key := "%d,%d" % [_edit_cell.x, _edit_cell.y]
		target = level["cells"].get(key, {})
		if target.is_empty():
			_props_box.add_child(_small("Ťukni na predmet v leveli, ktorý chceš upraviť."))
			_open_side(true)
			return
		id = target["t"]
	else:
		target = tool_params
	var defaults: Dictionary = Catalog.get_item(id)["params"]
	var title := _small(Catalog.get_item(id)["name"])
	title.add_theme_font_size_override("font_size", 26)
	_props_box.add_child(title)
	var any := false
	var kind: String = Catalog.get_item(id)["kind"]
	for key in Validator.EDITABLE:
		if not defaults.has(key) or (key == "color" and not kind in ["lever", "lift", "warp"]):
			continue
		any = true
		_props_box.add_child(_property_editor(key, target, defaults))
	if _has_path_option(id):
		any = true
		_props_box.add_child(_path_editor(target))
	if not any:
		_props_box.add_child(_small("Tento predmet nemá nastavenia."))
	elif tool == "edit" or tool == "paint":
		_open_side(true)


func _has_path_option(id: String) -> bool:
	var item_def := Catalog.get_item(id)
	return item_def.get("kind", "") == "mob" and ENEMY.PATH_BEHAVIORS.has(item_def["params"].get("behavior", ""))


## Cesta moba: začiatok a koniec (nastavuje sa ťuknutím v leveli).
func _path_editor(target: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var path: Array = target.get("path", [])
	var caption := "Cesta: nenastavená (mob chodí sám)" if path.size() != 4 \
			else "Cesta: z [%d, %d] do [%d, %d]" % [path[0], path[1], path[2], path[3]]
	var label := _small(caption)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(label)
	if tool == "edit":
		var row := HBoxContainer.new()
		var set_path := UI.colored_button("Nastaviť cestu", "green")
		set_path.pressed.connect(func():
			tool = "path"
			_path_points.clear()
			for key in _tool_buttons:
				_tool_buttons[key].button_pressed = false
			_show_toast("Ťukni na ZAČIATOK cesty."))
		row.add_child(set_path)
		if path.size() == 4:
			var clear := UI.colored_button("Zrušiť", "red")
			clear.pressed.connect(func():
				target.erase("path")
				dirty = true
				canvas.refresh()
				_show_properties())
			row.add_child(clear)
		box.add_child(row)
	else:
		var hint := _small("Cestu nastavíš: Upraviť → ťukni na moba → Nastaviť cestu.")
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.add_theme_color_override("font_color", UI.INK_SOFT)
		box.add_child(hint)
	return box


func _property_editor(key: String, target: Dictionary, defaults: Dictionary) -> Control:
	var box := VBoxContainer.new()
	var value = target.get(key, defaults[key])
	var on_change := func(v):
		target[key] = v
		dirty = true
		canvas.refresh()
		_refresh_problems()
	match key:
		"color":
			box.add_child(_small("Farba"))
			var row := HBoxContainer.new()
			for color in Catalog.COLORS:
				var b := Button.new()
				b.icon = load(Catalog.TILES % ("gem_" + color))
				b.expand_icon = true
				b.toggle_mode = true
				b.button_pressed = color == value
				b.custom_minimum_size = Vector2(64, 52)
				UI.style_toggle(b, 6, 4)
				b.pressed.connect(func():
					on_change.call(color)
					_show_properties())
				row.add_child(b)
			box.add_child(row)
		"content", "mob", "direction":
			var options := {}
			if key == "content":
				options = Catalog.CONTENTS
			elif key == "mob":
				for id in Catalog.in_category("moby"):
					options[id] = Catalog.get_item(id)["name"]
			elif defaults.get("direction", "") in ["up", "down"]:
				options = {"up": "Hore", "down": "Dole"}
			elif defaults.get("direction", "") in ["horizontal", "vertical"]:
				options = {"horizontal": "Vodorovne (doprava a späť)", "vertical": "Zvisle (hore a späť)"}
			else:
				options = {"left": "Doľava", "right": "Doprava"}
			box.add_child(_small({"content": "Obsah", "mob": "Mob", "direction": "Smer"}[key]))
			var option := OptionButton.new()
			for k in options:
				option.add_item(options[k])
				option.set_item_metadata(option.item_count - 1, k)
				if k == value:
					option.select(option.item_count - 1)
			option.item_selected.connect(func(i): on_change.call(option.get_item_metadata(i)))
			box.add_child(option)
		"distance", "radius", "time", "height", "hits":
			var labels := {"distance": "Vzdialenosť (dlaždice)", "radius": "Dosah výbuchu (dlaždice)",
				"time": "Čas otvorenia (s)", "height": "Výška skoku (dlaždice)", "hits": "Počet úderov"}
			var limits := {"distance": [1, 12], "radius": [1, 5], "time": [2, 30], "height": [1, 8], "hits": [1, 10]}
			box.add_child(_small(labels[key]))
			var spin := SpinBox.new()
			spin.min_value = limits[key][0]
			spin.max_value = limits[key][1]
			spin.value = int(value)
			spin.value_changed.connect(func(v): on_change.call(int(v)))
			box.add_child(spin)
		"solid":
			var check := CheckBox.new()
			check.text = "Na začiatku pevný"
			check.button_pressed = bool(value)
			check.toggled.connect(func(v): on_change.call(v))
			box.add_child(check)
	return box


func _refresh_problems() -> void:
	if _problems_box == null:
		return
	for child in _problems_box.get_children():
		child.queue_free()
	var problems := Validator.check(level)
	_check_button.text = "Kontrola" if problems.is_empty() else "Kontrola (%d)" % problems.size()
	var check_styles := UI._styles("blue" if problems.is_empty() else "red", 12, 5)
	for state in check_styles:
		_check_button.add_theme_stylebox_override(state, check_styles[state])
	var header := _small("Level je v poriadku." if problems.is_empty() else "Čo ešte chýba:")
	header.add_theme_font_size_override("font_size", 24)
	_problems_box.add_child(header)
	for problem in problems:
		var label := Label.new()
		label.text = "• " + problem["text"]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(300, 0)
		label.add_theme_font_size_override("font_size", 18)
		_problems_box.add_child(label)
		if problem["need"] != "":
			var need: String = problem["need"]
			var params: Dictionary = problem["params"]
			var add := _button("Položiť: " + Catalog.get_item(need)["name"], func(): _select_item(need, params))
			_problems_box.add_child(add)


func _ask_save() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	box.add_child(_small("Level má neuložené zmeny."))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(_button("Zrušiť", dim.queue_free))
	row.add_child(_button("Zahodiť", func():
		dirty = false
		go_back()))
	var save_button := UI.primary_button("Uložiť a odísť")
	save_button.pressed.connect(func():
		save()
		go_back())
	row.add_child(save_button)
	box.add_child(row)


func _show_toast(text: String) -> void:
	_toast.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(3.0)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	return button


func _small(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	return label
