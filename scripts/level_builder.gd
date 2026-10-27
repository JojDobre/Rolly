extends RefCounted
## Postaví level z textovej mapy. Jeden znak = jedna dlaždica 64 × 64 px.
## Všetka grafika je z Kenney New Platformer Pack.
##
##   .  prázdne miesto          #  zem (rohy a okraje sa vyberú samé)
##   =  lietajúca plošina       /  svah (natočí sa sám podľa susedného bloku)
##   P  štart guličky           F  cieľ (dvere)
##   *  hviezda (v leveli 3)    C  checkpoint (vlajka)
##   ^  bodce                   B  drevená krabica (ľahká)
##   M  ťažká krabica           K  kľúč
##   L  zámok (zmizne po zobratí kľúča)
##   >  tabuľa so šípkou        g  tráva   u  krík   m  hríb   o  kameň  (ozdoby)

const T := 64
const SOLID := "#/"
const CRATE_SIZE := 68.0  ## o kúsok väčšia ako gulička (priemer 52)
const PLATFORM_HEIGHT := 52.0

const PICKUP := preload("res://scripts/pickup.gd")
const TILES := "res://assets/tiles/terrain_grass_%s.png"
const OBJECTS := "res://assets/objects/%s.png"
const DECORATIONS := {"g": "grass", "u": "bush", "m": "mushroom_red", "o": "rock", ">": "sign_right"}

var _textures := {}


func build(map: Array, world: Node2D) -> Dictionary:
	var result := {
		"start": Vector2(T * 1.5, T * 1.5),
		"size": Vector2.ZERO,
		"stars": [],
		"keys": [],
		"locks": [],
		"hazards": [],
		"checkpoints": [],
		"finish": null,
	}
	var cols := 0
	for line in map:
		cols = maxi(cols, String(line).length())
	result["size"] = Vector2(cols * T, map.size() * T)

	var terrain := StaticBody2D.new()
	terrain.name = "Terrain"
	var material := PhysicsMaterial.new()
	material.friction = 1.0
	terrain.physics_material_override = material
	world.add_child(terrain)
	for y in map.size():
		for x in cols:
			_build_cell(_cell(map, x, y), x, y, map, world, terrain, result)

	_add_merged_rects(map, cols, "#", T, terrain)
	_add_merged_rects(map, cols, "=", int(PLATFORM_HEIGHT), terrain)
	return result


func _build_cell(c: String, x: int, y: int, map: Array, world: Node2D, terrain: StaticBody2D, result: Dictionary) -> void:
	var center := Vector2(x * T + T / 2.0, y * T + T / 2.0)
	var bottom := Vector2(center.x, (y + 1) * T)
	match c:
		".", " ", "":
			pass
		"#":
			_sprite(terrain, _tex(TILES % _ground_tile(map, x, y)), center)
		"=":
			_sprite(terrain, _tex(TILES % _platform_tile(map, x, y)), center)
		"/":
			# Svah stúpa smerom k susednému bloku zeme.
			var rising := _cell(map, x + 1, y) == "#" or not SOLID.contains(_cell(map, x - 1, y)) or _cell(map, x - 1, y) == ""
			var slope := _sprite(terrain, _tex(TILES % "ramp_short_b"), center)
			slope.flip_h = rising  # obrázok v balíku klesá doprava
			var triangle := ConvexPolygonShape2D.new()
			if rising:
				triangle.points = PackedVector2Array([Vector2(-32, 32), Vector2(32, -32), Vector2(32, 32)])
			else:
				triangle.points = PackedVector2Array([Vector2(-32, -32), Vector2(32, 32), Vector2(-32, 32)])
			var shape := CollisionShape2D.new()
			shape.shape = triangle
			shape.position = center
			terrain.add_child(shape)
		"P":
			result["start"] = center
		"*":
			var star := _pickup(_tex(OBJECTS % "star"), 1.1, "impactGlass_light_000", Color("ffd23f"), center)
			world.add_child(star)
			result["stars"].append(star)
		"K":
			var key := _pickup(_tex(OBJECTS % "key_red"), 1.0, "impactBell_heavy_000", Color("e2392f"), center)
			world.add_child(key)
			result["keys"].append(key)
		"L":
			var lock := StaticBody2D.new()
			lock.position = center
			_sprite(lock, _tex(OBJECTS % "lock_red"), Vector2.ZERO)
			lock.add_child(_rect_shape(Vector2(T, T), Vector2.ZERO))
			world.add_child(lock)
			result["locks"].append(lock)
		"^":
			var spikes := Area2D.new()
			spikes.position = center
			_sprite(spikes, _tex(OBJECTS % "spikes"), Vector2.ZERO)
			spikes.add_child(_rect_shape(Vector2(54, 22), Vector2(0, 19)))
			world.add_child(spikes)
			result["hazards"].append(spikes)
		"C":
			var checkpoint := _flag(bottom)
			world.add_child(checkpoint)
			result["checkpoints"].append(checkpoint)
		"F":
			var finish := _door(bottom)
			world.add_child(finish)
			result["finish"] = finish
		"B", "M":
			world.add_child(_crate(c == "M", bottom - Vector2(0, CRATE_SIZE / 2.0)))
		"g", "u", "m", "o", ">":
			var decoration := _sprite(world, _tex(OBJECTS % DECORATIONS[c]), center)
			decoration.z_index = -1
		_:
			push_warning("Neznámy znak '%s' v mape na pozícii %d, %d" % [c, x, y])


func _cell(map: Array, x: int, y: int) -> String:
	if y < 0 or y >= map.size():
		return ""
	var line := String(map[y])
	if x < 0 or x >= line.length():
		return ""
	return line[x]


## Spojí susedné bloky rovnakého typu do väčších obdĺžnikov,
## aby sa gulička nezasekávala na hranách medzi dlaždicami.
func _add_merged_rects(map: Array, cols: int, kind: String, height: int, terrain: StaticBody2D) -> void:
	var open := {}  # "x0:x1" -> [x0, x1, y_start, y_end]
	var finished := []
	for y in map.size() + 1:
		var runs := {}
		if y < map.size():
			var x := 0
			while x < cols:
				if _cell(map, x, y) == kind:
					var x0 := x
					while x < cols and _cell(map, x, y) == kind:
						x += 1
					runs["%d:%d" % [x0, x]] = [x0, x]
				else:
					x += 1
		for key in open.keys():
			# Tenké plošiny sa zvislo nespájajú.
			if runs.has(key) and kind == "#":
				open[key][3] = y
				runs.erase(key)
			else:
				finished.append(open[key])
				open.erase(key)
		for key in runs:
			open[key] = [runs[key][0], runs[key][1], y, y]
	for r in finished:
		var w: int = (r[1] - r[0]) * T
		var h: int = (r[3] - r[2]) * T + height
		var top_left := Vector2(r[0] * T, r[2] * T)
		terrain.add_child(_rect_shape(Vector2(w, h), top_left + Vector2(w, h) / 2.0))


func _sprite(parent: Node, texture: Texture2D, pos: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = pos
	parent.add_child(sprite)
	return sprite


func _rect_shape(size: Vector2, pos: Vector2) -> CollisionShape2D:
	var rect := RectangleShape2D.new()
	rect.size = size
	var shape := CollisionShape2D.new()
	shape.shape = rect
	shape.position = pos
	return shape


func _pickup(texture: Texture2D, sprite_scale: float, sound: String, color: Color, pos: Vector2) -> Area2D:
	var pickup = PICKUP.new()
	pickup.texture = texture
	pickup.sprite_scale = sprite_scale
	pickup.sound = sound
	pickup.particle_color = color
	pickup.position = pos
	return pickup


## Checkpoint: stožiar bez vlajky, po dotyku sa vytiahne zelená vlajka.
## Animácie: "down" a "up" (game.gd zavolá play("up")).
func _flag(bottom: Vector2) -> Area2D:
	var flag := Area2D.new()
	flag.position = bottom
	var frames := SpriteFrames.new()
	frames.add_animation("down")
	frames.add_frame("down", _tex(OBJECTS % "flag_off"))
	frames.add_animation("up")
	frames.set_animation_speed("up", 5.0)
	frames.add_frame("up", _tex(OBJECTS % "flag_green_a"))
	frames.add_frame("up", _tex(OBJECTS % "flag_green_b"))
	var sprite := AnimatedSprite2D.new()
	sprite.name = "Sprite"
	sprite.sprite_frames = frames
	sprite.animation = "down"
	sprite.scale = Vector2(1.5, 1.5)
	sprite.position = Vector2(20, -48)
	flag.add_child(sprite)
	flag.add_child(_rect_shape(Vector2(48, 128), Vector2(0, -64)))
	return flag


## Cieľ: otvorené dvere (2 dlaždice vysoké).
func _door(bottom: Vector2) -> Area2D:
	var door := Area2D.new()
	door.position = bottom
	var lower := _sprite(door, _tex(OBJECTS % "door_open"), Vector2(0, -T / 2.0))
	lower.z_index = -1
	var upper := _sprite(door, _tex(OBJECTS % "door_open_top"), Vector2(0, -T * 1.5))
	upper.z_index = -1
	door.add_child(_rect_shape(Vector2(40, 100), Vector2(0, -50)))
	return door


func _crate(heavy: bool, pos: Vector2) -> RigidBody2D:
	var crate := RigidBody2D.new()
	crate.position = pos
	crate.add_to_group("pushable")
	crate.mass = 2.0 if heavy else 0.7
	crate.linear_damp = 0.5  # krabica po náraze neodletí ďaleko
	var material := PhysicsMaterial.new()
	material.friction = 0.6 if heavy else 0.45
	crate.physics_material_override = material
	var sprite := _sprite(crate, _tex(OBJECTS % ("block_strong_empty" if heavy else "block_planks")), Vector2.ZERO)
	sprite.scale = Vector2.ONE * (CRATE_SIZE / T)
	crate.add_child(_rect_shape(Vector2(CRATE_SIZE, CRATE_SIZE), Vector2.ZERO))
	return crate


## Vyberie dlaždicu zeme podľa susedov (rohy, okraje, stred).
## Okraj mapy sa berie ako zem, aby nebol vidieť spodný obrys.
func _ground_tile(map: Array, x: int, y: int) -> String:
	var up := _is_ground(map, x, y - 1, false)
	var down := _is_ground(map, x, y + 1, true)
	var left := _is_ground(map, x - 1, y, true)
	var right := _is_ground(map, x + 1, y, true)
	if not left and not right:
		if not up and not down:
			return "block"
		if not up:
			return "vertical_top"
		return "vertical_bottom" if not down else "vertical_middle"
	if not up and not down:
		if not left:
			return "horizontal_left"
		return "horizontal_right" if not right else "horizontal_middle"
	var row := "top" if not up else ("bottom" if not down else "")
	var column := "left" if not left else ("right" if not right else "")
	if row == "" and column == "":
		return "block_center"
	if row == "" or column == "":
		return "block_" + row + column
	return "block_%s_%s" % [row, column]


func _platform_tile(map: Array, x: int, y: int) -> String:
	var left := _cell(map, x - 1, y) == "="
	var right := _cell(map, x + 1, y) == "="
	if left and right:
		return "cloud_middle"
	if right:
		return "cloud_left"
	return "cloud_right" if left else "cloud"


func _is_ground(map: Array, x: int, y: int, edge_is_ground: bool) -> bool:
	var line_count := map.size()
	var width := String(map[0]).length() if line_count > 0 else 0
	if x < 0 or x >= width or y >= line_count:
		return edge_is_ground
	if y < 0:
		return false
	return SOLID.contains(_cell(map, x, y)) and _cell(map, x, y) != ""


func _tex(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path)
	return _textures[path]
