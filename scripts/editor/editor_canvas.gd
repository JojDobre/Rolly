extends Node2D
## Vykreslenie levelu v editore: dlaždice podľa štýlu sveta, mriežka, kurzor a značky parametrov.

const Catalog := preload("res://scripts/catalog.gd")
const Loader := preload("res://scripts/level_loader.gd")
const T := 64

var level: Dictionary
var terrain := "grass"
var hover := Vector2i(-1, -1)
var selected := Vector2i(-1, -1)
var problem_cells := {}  ## bunky, ktoré treba opraviť (zvýraznené)
var path_preview: Array = []  ## body cesty, ktorú používateľ práve zadáva

var _textures := {}
var _loader := Loader.new()


func refresh() -> void:
	_loader.width = int(level["width"])
	_loader.height = int(level["height"])
	_loader.terrain = terrain
	_loader.cells.clear()
	for key in level["cells"]:
		_loader.cells[_pos(key)] = level["cells"][key]
	queue_redraw()


func _draw() -> void:
	if level.is_empty():
		return
	var w := int(level["width"])
	var h := int(level["height"])
	draw_rect(Rect2(0, 0, w * T, h * T), Color(0.76, 0.89, 1.0, 0.55))
	for pos in _loader.cells:
		_draw_cell(pos, _loader.cells[pos])
	var grid := Color(0.1, 0.2, 0.35, 0.18)
	for x in w + 1:
		draw_line(Vector2(x * T, 0), Vector2(x * T, h * T), grid, 1.0)
	for y in h + 1:
		draw_line(Vector2(0, y * T), Vector2(w * T, y * T), grid, 1.0)
	draw_rect(Rect2(0, 0, w * T, h * T), Color(0.1, 0.2, 0.35, 0.8), false, 3.0)
	for pos in _loader.cells:
		var path: Array = _loader.cells[pos].get("path", [])
		if path.size() == 4:
			_draw_path(pos, Vector2i(path[0], path[1]), Vector2i(path[2], path[3]))
	for point in path_preview:
		draw_circle(Vector2(point * T) + Vector2(T, T) / 2.0, 14.0, Color(1, 0.6, 0.1, 0.9))
	for pos in problem_cells:
		draw_rect(Rect2(pos * T, Vector2(T, T)), Color(1, 0.2, 0.1, 0.9), false, 4.0)
	if selected.x >= 0:
		draw_rect(Rect2(selected * T, Vector2(T, T)), Color(1, 0.85, 0.1), false, 4.0)
	if hover.x >= 0 and hover.x < w and hover.y >= 0 and hover.y < h:
		draw_rect(Rect2(hover * T, Vector2(T, T)), Color(1, 1, 1, 0.9), false, 3.0)


func _draw_cell(pos: Vector2i, cell: Dictionary) -> void:
	var id: String = cell.get("t", "")
	var item := Catalog.get_item(id)
	if item.is_empty():
		return
	var rect := Rect2(pos * T, Vector2(T, T))
	if cell.get("bg", "") == "secret_wall":
		draw_texture_rect(_terrain(_loader._ground_tile(pos)), rect, false, Color(1, 1, 1, 0.55))
		draw_rect(rect.grow(-6), Color(0.55, 0.2, 0.9, 0.9), false, 3.0)
	elif cell.has("bg"):
		var bg_icon: String = Catalog.get_item(cell["bg"]).get("icon", "terrain:block_center")
		var bg: Texture2D = _terrain("block_center") if bg_icon.begins_with("terrain:") else _tile(bg_icon)
		draw_texture_rect(bg, rect, false, Loader.BACKWALL_TINT)
	if id == "fireball" and _loader.in_lava(pos):
		draw_texture_rect(_tile("lava" if _loader.in_lava(pos + Vector2i.UP) else "lava_top"), rect, false)
	if _loader.submerged(pos):
		var surface: bool = not (_loader._is(pos + Vector2i.UP, "water") or _loader.submerged(pos + Vector2i.UP))
		draw_texture_rect(_tile("water_top" if surface else "water"), rect, false, Color(1, 1, 1, 0.8))
	match item["kind"]:
		"ground":
			_draw_flipped(_terrain(_loader._ground_tile(pos)), rect, _loader.under_rising_slope(pos))
		"platform":
			draw_texture_rect(_terrain(_loader._platform_tile(pos)), rect, false)
		"slope":
			var rising: bool = _loader.slope_rising(pos)
			_draw_flipped(_terrain("ramp_short_b"), rect, rising)
		"ladder":
			var above: bool = _loader._is_any(pos + Vector2i.UP, ["ladder", "rope"])
			var below: bool = _loader._is_any(pos + Vector2i.DOWN, ["ladder", "rope"])
			var name := id
			if id == "ladder":
				name = "ladder_middle" if above and below else ("ladder_top" if not above else "ladder_bottom")
			elif not above:
				name = "rop_attached"
			draw_texture_rect(_tile(name), rect, false)
		"water", "lava":
			var top: bool = not _loader._is(pos + Vector2i.UP, id) and not (id == "water" and _loader.submerged(pos + Vector2i.UP)) \
					and not (id == "lava" and _loader.in_lava(pos + Vector2i.UP))
			draw_texture_rect(_tile(id + ("_top" if top else "")), rect, false, Color(1, 1, 1, 0.8 if id == "water" else 1.0))
		"secret":
			_draw_flipped(_terrain(_loader._ground_tile(pos)), rect, _loader.under_rising_slope(pos))
			draw_rect(rect.grow(-6), Color(0.55, 0.2, 0.9, 0.9), false, 3.0)
			draw_rect(rect, Color(0.55, 0.2, 0.9, 0.18))
		"backwall":
			var wall: Texture2D = _terrain("block_center") if item["icon"].begins_with("terrain:") else _tile(item["icon"])
			draw_texture_rect(wall, rect, false, Loader.BACKWALL_TINT)
			return
		"hidden_block":
			draw_texture_rect(_tile("block_empty"), rect, false, Color(1, 1, 1, 0.35))
			draw_rect(rect.grow(-4), Color(1, 1, 1, 0.9), false, 2.0)
		"mover":
			draw_texture_rect(_terrain("horizontal_middle"), rect, false)
		"warp":
			draw_texture_rect(_tile("door_closed"), rect, false)
			draw_texture_rect(_tile("door_closed_top"), Rect2(rect.position - Vector2(0, T), rect.size), false)
		"exit":
			draw_texture_rect(_tile("door_closed"), rect, false)
			draw_texture_rect(_tile("door_closed_top"), Rect2(rect.position - Vector2(0, T), rect.size), false)
		"lift":
			draw_texture_rect(_terrain("horizontal_middle"), rect, false)
		"conveyor":
			_draw_flipped(_tile("conveyor"), rect, cell.get("direction", "right") == "left")
		"lever":
			draw_texture_rect(_tile("lever_left"), rect, false)
		"solid":
			draw_texture_rect(_tex(Catalog.icon_path(id, terrain)), rect, false, Catalog.WALL_TINT if id.begins_with("bricks_") else Color.WHITE)
		_:
			_draw_fitted(_tex(Catalog.icon_path(id, terrain)), rect)
	_draw_markers(pos, cell, item)


## Malé značky: farba páčky/výťahu, obsah bloku, smer výťahu.
func _draw_markers(pos: Vector2i, cell: Dictionary, item: Dictionary) -> void:
	var corner := Vector2(pos * T) + Vector2(T - 26, 2)
	var params: Dictionary = item["params"]
	if params.has("color") and item["kind"] in ["lever", "lift", "warp"]:
		draw_texture_rect(_tile("gem_" + cell.get("color", params["color"])), Rect2(corner, Vector2(24, 24)), false)
	if item["kind"] == "item_block":
		var content: String = cell.get("content", params.get("content", ""))
		var icon := Catalog.icon_path(cell.get("mob", params.get("mob", "slime_normal"))) if content == "mob" else Catalog.icon_path(content)
		if icon != "":
			draw_texture_rect(_tex(icon), Rect2(corner, Vector2(24, 24)), false)
	if item["kind"] == "mover":
		var vertical: bool = cell.get("direction", params["direction"]) == "vertical"
		var reach := int(cell.get("distance", params["distance"]))
		var from := Vector2(pos * T) + Vector2(T / 2.0, T / 2.0)
		var to := from + (Vector2(0, -T * reach) if vertical else Vector2(T * reach, 0))
		draw_dashed_line(from, to, Color(0.1, 0.6, 0.3, 0.9), 3.0, 8.0)
		draw_rect(Rect2(to - Vector2(T / 2.0, T / 2.0), Vector2(T, T)), Color(0.1, 0.6, 0.3, 0.6), false, 2.0)
	if item["kind"] == "lift":
		var up: bool = cell.get("direction", params["direction"]) == "up"
		var distance := int(cell.get("distance", params["distance"]))
		var start := Vector2(pos * T) + Vector2(T / 2.0, T / 2.0)
		var end := start + Vector2(0, -T * distance if up else T * distance)
		draw_dashed_line(start, end, Color(0.1, 0.3, 0.9, 0.8), 3.0, 8.0)
		draw_rect(Rect2(end - Vector2(T / 2.0, T / 2.0), Vector2(T, T)), Color(0.1, 0.3, 0.9, 0.6), false, 2.0)


## Cesta moba: oranžová prerušovaná čiara medzi začiatkom a koncom, tenká čiara k mobovi.
func _draw_path(mob: Vector2i, a: Vector2i, b: Vector2i) -> void:
	var half := Vector2(T, T) / 2.0
	var pa := Vector2(a * T) + half
	var pb := Vector2(b * T) + half
	var color := Color(1, 0.55, 0.1, 0.95)
	draw_dashed_line(pa, pb, color, 5.0, 12.0)
	for p in [pa, pb]:
		draw_circle(p, 12.0, color)
		draw_circle(p, 6.0, Color.WHITE)
	draw_line(Vector2(mob * T) + half, pa.lerp(pb, 0.5), Color(1, 0.55, 0.1, 0.4), 2.0)


func _draw_fitted(texture: Texture2D, rect: Rect2) -> void:
	if texture == null:
		return
	var size := texture.get_size()
	var k := minf(rect.size.x / size.x, rect.size.y / size.y)
	var drawn := size * minf(k, 1.0) if size.x <= T * 1.2 and size.y <= T * 1.2 else size * k
	draw_texture_rect(texture, Rect2(rect.position + Vector2((rect.size.x - drawn.x) / 2.0, rect.size.y - drawn.y), drawn), false)


func _draw_flipped(texture: Texture2D, rect: Rect2, flip: bool) -> void:
	if flip:
		draw_set_transform(rect.position + Vector2(rect.size.x, 0), 0.0, Vector2(-1, 1))
		draw_texture_rect(texture, Rect2(Vector2.ZERO, rect.size), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_texture_rect(texture, rect, false)


func _tile(name: String) -> Texture2D:
	return _tex(Catalog.TILES % name)


func _terrain(name: String) -> Texture2D:
	return _tex(Catalog.TILES % ("terrain_%s_%s" % [terrain, name]))


func _tex(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path)
	return _textures[path]


static func _pos(key: String) -> Vector2i:
	var parts := key.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))
