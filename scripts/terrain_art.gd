extends Node2D
## Vykreslí terén z mapy v štýle Red Ball: hlina s kamienkami, tráva navrchu,
## tmavý obrys a zaoblené konce trávy. Kolízie rieši level_builder.gd.

const T := 64
const TEX_SIZE := 256.0
const GRASS_RISE := 12.0  ## koľko trávy trčí nad hranu
const DIRT := preload("res://assets/world/dirt.png")
const GRASS := preload("res://assets/world/grass_top.png")
const OUTLINE := Color("263e14")
const GRASS_COLOR := Color("7ec636")
const EDGE := 5.0
const PLATFORM_HEIGHT := 50.0

var map: Array = []
var cols := 0


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	queue_redraw()


func _draw() -> void:
	# 1. hlina a obrysy
	for y in map.size():
		for x in cols:
			match _cell(x, y):
				"#":
					_draw_dirt(Rect2(x * T, y * T, T, T))
					_draw_block_outline(x, y, T)
				"=":
					_draw_dirt(Rect2(x * T, y * T, T, PLATFORM_HEIGHT))
					_draw_platform_outline(x, y)
				"/":
					_draw_slope_dirt(x, y)
	# 2. tráva navrch (cez susedné bunky, aby steblá prekrývali hranu)
	for y in map.size():
		for x in cols:
			var c := _cell(x, y)
			if (c == "#" and not _solid(x, y - 1)) or (c == "=" and _cell(x, y - 1) != "="):
				_draw_grass_strip(Vector2(x * T, y * T), T, 0.0)
				var flat := "=" if c == "=" else "#/"
				if not flat.contains(_cell(x - 1, y)) or _cell(x - 1, y) == "":
					_draw_cap(Vector2(x * T, y * T))
				if not flat.contains(_cell(x + 1, y)) or _cell(x + 1, y) == "":
					_draw_cap(Vector2((x + 1) * T, y * T))
			elif c == "/":
				if _rising(x, y):
					_draw_grass_strip(Vector2(x * T, (y + 1) * T), T * sqrt(2.0), -PI / 4.0)
					if not _solid(x - 1, y + 1) and not _solid(x - 1, y):
						_draw_cap(Vector2(x * T, (y + 1) * T))
				else:
					_draw_grass_strip(Vector2(x * T, y * T), T * sqrt(2.0), PI / 4.0)
					if not _solid(x + 1, y + 1) and not _solid(x + 1, y):
						_draw_cap(Vector2((x + 1) * T, (y + 1) * T))


func _draw_dirt(rect: Rect2) -> void:
	var src := Rect2(fposmod(rect.position.x, TEX_SIZE), fposmod(rect.position.y, TEX_SIZE), rect.size.x, rect.size.y)
	draw_texture_rect_region(DIRT, rect, src)


func _draw_slope_dirt(x: int, y: int) -> void:
	var points: PackedVector2Array
	if _rising(x, y):
		points = PackedVector2Array([Vector2(x * T, (y + 1) * T), Vector2((x + 1) * T, y * T), Vector2((x + 1) * T, (y + 1) * T)])
	else:
		points = PackedVector2Array([Vector2(x * T, y * T), Vector2((x + 1) * T, (y + 1) * T), Vector2(x * T, (y + 1) * T)])
	var uvs := PackedVector2Array()
	for p in points:
		uvs.append(p / TEX_SIZE)
	draw_colored_polygon(points, Color.WHITE, uvs, DIRT)
	if not _solid(x, y + 1):
		draw_line(Vector2(x * T, (y + 1) * T), Vector2((x + 1) * T, (y + 1) * T), OUTLINE, EDGE)


func _draw_block_outline(x: int, y: int, h: float) -> void:
	var left := x * T
	var right := (x + 1) * T
	var top := y * T
	if not _solid(x - 1, y):
		draw_line(Vector2(left, top), Vector2(left, top + h), OUTLINE, EDGE)
	if not _solid(x + 1, y):
		draw_line(Vector2(right, top), Vector2(right, top + h), OUTLINE, EDGE)
	if not _solid(x, y + 1):
		draw_line(Vector2(left - EDGE / 2.0, top + h), Vector2(right + EDGE / 2.0, top + h), OUTLINE, EDGE)


func _draw_platform_outline(x: int, y: int) -> void:
	var left := x * T
	var right := (x + 1) * T
	var top := y * T
	var bottom := top + PLATFORM_HEIGHT
	if _cell(x - 1, y) != "=":
		draw_line(Vector2(left, top), Vector2(left, bottom), OUTLINE, EDGE)
	if _cell(x + 1, y) != "=":
		draw_line(Vector2(right, top), Vector2(right, bottom), OUTLINE, EDGE)
	draw_line(Vector2(left - EDGE / 2.0, bottom), Vector2(right + EDGE / 2.0, bottom), OUTLINE, EDGE)


## Pás trávy od bodu start v danom smere (uhol 0 = vodorovne doprava).
func _draw_grass_strip(start: Vector2, length: float, angle: float) -> void:
	draw_set_transform(start, angle, Vector2.ONE)
	var src := Rect2(fposmod(start.x, TEX_SIZE), 0.0, length, GRASS.get_height())
	draw_texture_rect_region(GRASS, Rect2(0.0, -GRASS_RISE, length, GRASS.get_height()), src)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Zaoblený koniec trávy na okraji.
func _draw_cap(at: Vector2) -> void:
	draw_circle(at + Vector2(0, 8), 15.0, OUTLINE)
	draw_circle(at + Vector2(0, 8), 11.0, GRASS_COLOR)


func _rising(x: int, y: int) -> bool:
	return _cell(x + 1, y) == "#" or not _solid(x - 1, y)


func _solid(x: int, y: int) -> bool:
	var c := _cell(x, y)
	return c == "#" or c == "/"


func _cell(x: int, y: int) -> String:
	if y < 0 or y >= map.size():
		return ""
	var line := String(map[y])
	if x < 0 or x >= line.length():
		return ""
	return line[x]
