extends RefCounted
## Postaví level z textovej mapy. Jeden znak = jedna dlaždica 64 × 64 px.
##
##   .  prázdne miesto          #  zem
##   =  tenká plošina           /  svah (natočí sa sám podľa susedného bloku)
##   P  štart guličky           F  cieľ (vlajka)
##   *  hviezda (v leveli 3)    C  checkpoint
##   ^  bodce                   B  drevená krabica (ľahká)
##   M  kovová krabica (ťažká)  K  kľúč
##   L  zámok (zmizne po zobratí kľúča)
##   >  šípka (len ozdoba)

const T := 64
const SOLID := "#/"

const CRATE_SIZE := 68.0  ## o kúsok väčšia ako gulička (priemer 52)

const PICKUP := preload("res://scripts/pickup.gd")
const TERRAIN_ART := preload("res://scripts/terrain_art.gd")
const TEX_SPIKES := preload("res://assets/objects/spikesLow.png")
const TEX_STAR := preload("res://assets/items/starGold.png")
const TEX_KEY := preload("res://assets/objects/keyRed.png")
const TEX_LOCK := preload("res://assets/objects/blockRed_lock.png")
const TEX_FLAG_RED := preload("res://assets/objects/flagRed_down.png")
const TEX_FLAG_GREEN := preload("res://assets/objects/flagGreen_down.png")
const TEX_SIGN := preload("res://assets/objects/signArrow_right.png")
const TEX_CRATE_WOOD := preload("res://assets/objects/crate_wood.png")
const TEX_CRATE_METAL := preload("res://assets/objects/crate_metal.png")


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
	var art = TERRAIN_ART.new()
	art.name = "TerrainArt"
	art.map = map
	art.cols = cols
	terrain.add_child(art)

	for y in map.size():
		for x in cols:
			_build_cell(_cell(map, x, y), x, y, map, world, terrain, result)

	_add_merged_rects(map, cols, "#", T, terrain)
	_add_merged_rects(map, cols, "=", 50, terrain)
	return result


func _build_cell(c: String, x: int, y: int, map: Array, world: Node2D, terrain: StaticBody2D, result: Dictionary) -> void:
	var center := Vector2(x * T + T / 2.0, y * T + T / 2.0)
	var bottom := Vector2(center.x, (y + 1) * T)
	match c:
		".", " ", "", "#", "=":
			pass  # zem a plošiny kreslí terrain_art.gd, kolízie _add_merged_rects
		"/":
			# Svah stúpa smerom k susednému bloku zeme.
			var rising := _cell(map, x + 1, y) == "#" or not SOLID.contains(_cell(map, x - 1, y)) or _cell(map, x - 1, y) == ""
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
			var star := _pickup(TEX_STAR, 0.75, "impactGlass_light_000", Color("ffd23f"), center)
			world.add_child(star)
			result["stars"].append(star)
		"K":
			var key := _pickup(TEX_KEY, 1.5, "impactBell_heavy_000", Color("e2392f"), center)
			world.add_child(key)
			result["keys"].append(key)
		"L":
			var lock := StaticBody2D.new()
			lock.position = center
			_sprite(lock, TEX_LOCK, Vector2.ZERO)
			lock.add_child(_rect_shape(Vector2(T, T), Vector2.ZERO))
			world.add_child(lock)
			result["locks"].append(lock)
		"^":
			var spikes := Area2D.new()
			spikes.position = bottom + Vector2(0, -13)
			_sprite(spikes, TEX_SPIKES, Vector2.ZERO)
			spikes.add_child(_rect_shape(Vector2(54, 16), Vector2(0, 3)))
			world.add_child(spikes)
			result["hazards"].append(spikes)
		"C":
			var checkpoint := _flag(TEX_FLAG_GREEN, bottom)
			world.add_child(checkpoint)
			result["checkpoints"].append(checkpoint)
		"F":
			var finish := _flag(TEX_FLAG_RED, bottom)
			world.add_child(finish)
			result["finish"] = finish
		"B", "M":
			world.add_child(_crate(c == "M", bottom - Vector2(0, CRATE_SIZE / 2.0)))
		">":
			var arrow := _sprite(world, TEX_SIGN, bottom)
			arrow.offset = Vector2(0, -TEX_SIGN.get_height() / 2.0)
			arrow.z_index = -1
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


func _flag(texture: Texture2D, bottom: Vector2) -> Area2D:
	var flag := Area2D.new()
	flag.position = bottom
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = texture
	sprite.centered = false
	sprite.scale = Vector2(1.6, 1.6)
	sprite.position = Vector2(-12, -texture.get_height() * 1.6)
	flag.add_child(sprite)
	flag.add_child(_rect_shape(Vector2(48, 128), Vector2(0, -64)))
	return flag


func _crate(heavy: bool, pos: Vector2) -> RigidBody2D:
	var crate := RigidBody2D.new()
	crate.position = pos
	crate.add_to_group("pushable")
	crate.mass = 1.6 if heavy else 0.4
	var material := PhysicsMaterial.new()
	material.friction = 0.5 if heavy else 0.3
	crate.physics_material_override = material
	var sprite := _sprite(crate, TEX_CRATE_METAL if heavy else TEX_CRATE_WOOD, Vector2.ZERO)
	sprite.scale = Vector2.ONE * (CRATE_SIZE / 70.0)
	crate.add_child(_rect_shape(Vector2(CRATE_SIZE, CRATE_SIZE), Vector2.ZERO))
	return crate
