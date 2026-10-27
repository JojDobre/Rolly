extends RefCounted
## Postaví level z dát (JSON z editora) do scény: terén, bloky, predmety, moby.
## Fyzikálne vrstvy: 1 svet, 2 plošiny (zospodu priechodné), 3 hráč, 4 moby, 5 predmety.

const T := 64
const Catalog := preload("res://scripts/catalog.gd")
const E := "res://scripts/entities/%s.gd"

const SOLID_KINDS := ["ground", "solid"]
const ONEWAY_TOPS := {"platform": 0.0, "block_plank": 0.0, "bridge_logs": 0.0}

var level: Dictionary
var terrain := "grass"
var cells := {}  # Vector2i -> Dictionary
var width := 0
var height := 0
var root: Node2D

## Výsledok pre hru.
var start := Vector2(T * 2, T * 2)
var water := {}
var lava := {}
var ladders := {}
var star_count := 0

var _textures := {}
var _terrain_body: StaticBody2D
var _oneway_body: StaticBody2D


func build(level_data: Dictionary, world: Dictionary, target: Node2D) -> void:
	level = level_data
	terrain = world.get("terrain", "grass")
	root = target
	width = int(level.get("width", 40))
	height = int(level.get("height", 14))
	for key in level.get("cells", {}):
		var parts: PackedStringArray = String(key).split(",")
		cells[Vector2i(int(parts[0]), int(parts[1]))] = level["cells"][key]

	_terrain_body = _static_body("Terrain", 1)
	_oneway_body = _static_body("Platforms", 2)

	for pos in cells:
		_build_cell(pos, cells[pos])
	_add_merged_solids()


# --- Bunky -------------------------------------------------------------------

func _build_cell(pos: Vector2i, cell: Dictionary) -> void:
	var id: String = cell.get("t", "")
	var item := Catalog.get_item(id)
	if item.is_empty():
		push_warning("Neznámy predmet '%s' na %s" % [id, pos])
		return
	var params: Dictionary = item["params"].duplicate()
	for k in cell:
		if k != "t":
			params[k] = cell[k]
	var center := Vector2(pos.x * T + T / 2.0, pos.y * T + T / 2.0)
	match item["kind"]:
		"ground":
			_sprite(_terrain_body, _terrain_tex(_ground_tile(pos)), center)
		"solid":
			_sprite(_terrain_body, _tex(id), center)
		"platform":
			_sprite(_oneway_body, _terrain_tex(_platform_tile(pos)), center)
			_oneway(pos, 0.0, 52.0)
		"oneway":
			_sprite(_oneway_body, _tex(id), center)
			_oneway(pos, 0.0, 24.0)
		"slope":
			_slope(pos, center)
		"breakable":
			_body(StaticBody2D.new(), "breakable", center, _tex(id), Vector2(T, T), Vector2.ZERO,
					{"particle": "brickGrey" if id == "brick_grey" else "brickBrown"})
		"item_block":
			_body(StaticBody2D.new(), "item_block", center, _tex(id), Vector2(T, T), Vector2.ZERO, {
				"item_id": id, "content": params.get("content", "coin_gold"),
				"mob": params.get("mob", "slime_normal"), "hits": int(params.get("hits", 1))})
		"falling":
			_body(AnimatableBody2D.new(), "falling_block", center, _tex(id), Vector2(T, T), Vector2.ZERO, {},
					_sensor(Vector2(T - 8, 12), Vector2(0, -T / 2.0 - 4)))
		"vanishing":
			var bridge = _body(StaticBody2D.new(), "vanishing", center, _tex(id), Vector2(T, 30), Vector2(0, -T / 2.0 + 15), {},
					_sensor(Vector2(T - 8, 12), Vector2(0, -T / 2.0 - 4)))
			bridge.collision_layer = 2
			bridge.get_child(1).one_way_collision = true
		"crate":
			_crate(center, id)
		"coin", "star", "powerup", "key":
			spawn_pickup(id, center, false)
			if item["kind"] == "star":
				star_count += 1
		"lock":
			var lock = _body(StaticBody2D.new(), "", center, _tex(id), Vector2(T, T))
			lock.add_to_group("lock_" + String(params["color"]))
		"switch":
			_area("switch", center, _tex(id), Vector2(T - 12, 20), Vector2(0, 20),
					{"color": params["color"], "time": float(params.get("time", 5))})
		"color_block":
			_body(StaticBody2D.new(), "color_block", center, _tex(id), Vector2(T, T), Vector2.ZERO,
					{"color": params["color"], "solid_by_default": bool(params.get("solid", true))})
		"lever":
			var lever_color: String = params.get("color", "red")
			_area("lever", center, _tex("lever_left"), Vector2(T, T), Vector2.ZERO, {"color": lever_color},
					_color_marker(lever_color, Vector2(0, -36)))
		"lift":
			var lift_color: String = params.get("color", "red")
			_body(AnimatableBody2D.new(), "lift", center, _terrain_tex("horizontal_middle"), Vector2(T, T), Vector2.ZERO, {
				"color": lift_color, "direction": params.get("direction", "up"), "distance": int(params.get("distance", 3))},
					_color_marker(lift_color, Vector2.ZERO))
		"spring":
			_area("spring", center, _tex(id), Vector2(T - 16, 30), Vector2(0, 14))
		"conveyor":
			var belt = _body(StaticBody2D.new(), "", center, _tex(id), Vector2(T, T))
			var left: bool = params.get("direction", "right") == "left"
			belt.constant_linear_velocity = Vector2(-130.0 if left else 130.0, 0.0)
			belt.get_node("Sprite").flip_h = left
		"ladder":
			ladders[pos] = true
			_ladder(pos, center, id)
		"bomb":
			_area("bomb", center, _tex(id), Vector2(48, 48), Vector2(0, 6), {"radius": int(params.get("radius", 2))})
		"hazard":
			_hazard(id, center)
		"spike_block":
			var spiky = _body(StaticBody2D.new(), "", center, _tex(id), Vector2(T, T))
			spiky.add_to_group("hurts_on_touch")
		"lava":
			lava[pos] = true
			_sprite(root, _tex("lava_top" if not _is(pos + Vector2i.UP, "lava") else "lava"), center).z_index = 2
		"water":
			water[pos] = true
			var wave := _sprite(root, _tex("water_top" if not _is(pos + Vector2i.UP, "water") else "water"), center)
			wave.z_index = 6
			wave.modulate.a = 0.7
		"fireball":
			var fire = _area("fireball", center, _tex(id), Vector2(30, 30), Vector2.ZERO, {"height": int(params.get("height", 3))})
			fire.z_index = 3
		"weight":
			_weight(center)
		"mob":
			spawn_mob(id, center, params)
		"deco":
			var deco := _sprite(root, _tex(id) if not item["icon"].begins_with("terrain:") else _terrain_tex(item["icon"].substr(8)), center)
			deco.z_index = -1
		"torch":
			var torch := AnimatedSprite2D.new()
			torch.sprite_frames = _frames({"down": ["torch_on_a", "torch_on_b"]}, 6.0)
			torch.position = center
			torch.z_index = -1
			torch.play("down")
			root.add_child(torch)
		"start":
			start = center + Vector2(0, 2)
		"exit":
			var door := _trigger("exit", center, {"down": ["door_closed"], "up": ["door_open"]})
			var top := AnimatedSprite2D.new()
			top.sprite_frames = _frames({"down": ["door_closed_top"], "up": ["door_open_top"]}, 1.0)
			top.animation = "down"
			top.position = Vector2(0, -T)
			door.add_child(top)
		"exit_flag":
			_trigger("exit", center, {"down": ["flag_red_a", "flag_red_b"], "up": ["flag_red_a", "flag_red_b"]})
		"checkpoint":
			_trigger("checkpoint", center, {"down": ["flag_off"], "up": ["flag_green_a", "flag_green_b"]})


# --- Spawnovanie (používa aj hra počas hrania) ------------------------------

func spawn_pickup(id: String, center: Vector2, popped: bool) -> Node:
	var pickup: Area2D = load(E % "pickup").new()
	pickup.item_id = id
	pickup.kind = Catalog.get_item(id).get("kind", "coin")
	pickup.popped = popped
	pickup.position = center
	pickup.z_index = 1
	root.add_child(pickup)
	return pickup


func spawn_mob(id: String, center: Vector2, params := {}) -> Node:
	var item := Catalog.get_item(id)
	var p: Dictionary = item.get("params", {}).duplicate()
	p.merge(params, true)
	var enemy: CharacterBody2D = load(E % "enemy").new()
	enemy.item_id = id
	enemy.behavior = p.get("behavior", "walker")
	enemy.stompable = p.get("stomp", true)
	enemy.speed = float(p.get("speed", 60))
	enemy.move_range = int(p.get("range", 3))
	enemy.frames_spec = p.get("frames", {})
	enemy.sprite_prefix = p.get("sprite", "")
	enemy.position = center
	enemy.z_index = 2
	root.add_child(enemy)
	return enemy


# --- Stavebné kamene ----------------------------------------------------------

func _static_body(node_name: String, layer: int) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = node_name
	body.collision_layer = layer
	body.collision_mask = 0
	root.add_child(body)
	return body


## Vytvorí teleso so sprite a kolíziou. Vlastnosti z props sa nastavia ešte pred _ready().
func _body(body: PhysicsBody2D, script: String, center: Vector2, texture: Texture2D, size: Vector2,
		shape_offset := Vector2.ZERO, props := {}, extra: Node = null) -> Node:
	if script != "":
		body.set_script(load(E % script))
	body.position = center
	body.collision_layer = 1
	body.collision_mask = 0
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = texture
	body.add_child(sprite)
	body.add_child(_rect(size, shape_offset))
	if extra:
		body.add_child(extra)
	for key in props:
		body.set(key, props[key])
	root.add_child(body)
	return body


func _area(script: String, center: Vector2, texture: Texture2D, size: Vector2, shape_offset: Vector2,
		props := {}, extra: Node = null) -> Node:
	var area := Area2D.new()
	area.set_script(load(E % script))
	area.position = center
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = texture
	area.add_child(sprite)
	area.add_child(_rect(size, shape_offset))
	if extra:
		area.add_child(extra)
	for key in props:
		area.set(key, props[key])
	root.add_child(area)
	return area


func _sensor(size: Vector2, offset: Vector2) -> Area2D:
	var sensor := Area2D.new()
	sensor.name = "Sensor"
	sensor.collision_layer = 0
	sensor.collision_mask = 1 << 2
	sensor.add_child(_rect(size, offset))
	return sensor


func _trigger(kind: String, center: Vector2, anims: Dictionary) -> Area2D:
	var area := Area2D.new()
	area.set_script(load(E % "trigger"))
	area.kind = kind
	area.position = center
	var sprite := AnimatedSprite2D.new()
	sprite.name = "Sprite"
	sprite.sprite_frames = _frames(anims, 5.0)
	sprite.play("down")
	area.add_child(sprite)
	area.add_child(_rect(Vector2(40, 60), Vector2(0, 2)))
	area.z_index = -1
	root.add_child(area)
	return area


func _crate(center: Vector2, id: String) -> void:
	var crate := RigidBody2D.new()
	crate.position = center
	crate.collision_layer = 1
	crate.collision_mask = 1 | 2
	crate.mass = 1.0
	crate.lock_rotation = true
	crate.linear_damp = 1.0
	crate.add_to_group("bomb_breakable")
	var material := PhysicsMaterial.new()
	material.friction = 0.6
	crate.physics_material_override = material
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = _tex(id)
	crate.add_child(sprite)
	crate.add_child(_rect(Vector2(T - 2, T - 2), Vector2.ZERO))
	root.add_child(crate)


func _hazard(id: String, center: Vector2) -> void:
	var sizes := {
		"spikes": [Vector2(56, 26), Vector2(0, 19)],
		"cactus": [Vector2(40, 56), Vector2(0, 4)],
		"mushroom_red": [Vector2(26, 22), Vector2(0, 21)],
		"mushroom_brown": [Vector2(26, 26), Vector2(0, 19)],
		"saw": [Vector2(52, 52), Vector2.ZERO],
	}
	var spec: Array = sizes.get(id, [Vector2(48, 48), Vector2.ZERO])
	_area("hazard", center, _tex(id), spec[0], spec[1], {"spin": 8.0 if id == "saw" else 0.0})


func _weight(center: Vector2) -> void:
	var danger: Area2D = load(E % "hazard").new()
	danger.add_child(_rect(Vector2(56, 16), Vector2(0, 30)))
	_body(AnimatableBody2D.new(), "weight", center, _tex("weight"), Vector2(60, 60), Vector2.ZERO, {}, danger)


func _ladder(pos: Vector2i, center: Vector2, id: String) -> void:
	var above := _is_any(pos + Vector2i.UP, ["ladder", "rope"])
	var below := _is_any(pos + Vector2i.DOWN, ["ladder", "rope"])
	var texture := id
	if id == "ladder":
		texture = "ladder_middle" if above and below else ("ladder_top" if not above else "ladder_bottom")
		if not above and not below:
			texture = "ladder_top"
	elif not above:
		texture = "rop_attached"
	var sprite := _sprite(root, _tex(texture), center)
	sprite.z_index = -1
	if not above:
		# Na vrchu rebríka sa dá stáť (v úrovni hornej hrany jeho najvyššej bunky).
		_oneway(pos, 0.0, 12.0)


func _slope(pos: Vector2i, center: Vector2) -> void:
	var rising := _is(pos + Vector2i.RIGHT, "ground") or not _is_any(pos + Vector2i.LEFT, ["ground", "slope"])
	var sprite := _sprite(_terrain_body, _terrain_tex("ramp_short_b"), center)
	sprite.flip_h = rising
	var points := PackedVector2Array([Vector2(-32, 32), Vector2(32, -32), Vector2(32, 32)]) if rising \
			else PackedVector2Array([Vector2(-32, -32), Vector2(32, 32), Vector2(-32, 32)])
	var triangle := ConvexPolygonShape2D.new()
	triangle.points = points
	var shape := CollisionShape2D.new()
	shape.shape = triangle
	shape.position = center
	_terrain_body.add_child(shape)


func _oneway(pos: Vector2i, top: float, thickness: float) -> void:
	var shape := _rect(Vector2(T, thickness), Vector2(pos.x * T + T / 2.0, pos.y * T + top + thickness / 2.0))
	shape.one_way_collision = true
	_oneway_body.add_child(shape)


## Spojí susedné pevné bloky do obdĺžnikov, aby sa postavička nezasekávala na hranách.
func _add_merged_solids() -> void:
	var solid := {}
	for pos in cells:
		if Catalog.get_item(cells[pos].get("t", "")).get("kind", "") in SOLID_KINDS:
			solid[pos] = true
	var used := {}
	for y in height:
		var x := 0
		while x < width:
			var p := Vector2i(x, y)
			if not solid.has(p) or used.has(p):
				x += 1
				continue
			var x_end := x
			while solid.has(Vector2i(x_end + 1, y)) and not used.has(Vector2i(x_end + 1, y)):
				x_end += 1
			var y_end := y
			while true:
				var row_ok := true
				for xx in range(x, x_end + 1):
					if not solid.has(Vector2i(xx, y_end + 1)) or used.has(Vector2i(xx, y_end + 1)):
						row_ok = false
						break
				if not row_ok:
					break
				y_end += 1
			for yy in range(y, y_end + 1):
				for xx in range(x, x_end + 1):
					used[Vector2i(xx, yy)] = true
			var size := Vector2((x_end - x + 1) * T, (y_end - y + 1) * T)
			_terrain_body.add_child(_rect(size, Vector2(x * T, y * T) + size / 2.0))
			x = x_end + 1


func _ground_tile(pos: Vector2i) -> String:
	var up := _ground_at(pos + Vector2i.UP, false)
	var down := _ground_at(pos + Vector2i.DOWN, true)
	var left := _ground_at(pos + Vector2i.LEFT, true)
	var right := _ground_at(pos + Vector2i.RIGHT, true)
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


func _platform_tile(pos: Vector2i) -> String:
	var left := _is(pos + Vector2i.LEFT, "platform")
	var right := _is(pos + Vector2i.RIGHT, "platform")
	if left and right:
		return "cloud_middle"
	if right:
		return "cloud_left"
	return "cloud_right" if left else "cloud"


func _ground_at(pos: Vector2i, edge_is_ground: bool) -> bool:
	if pos.x < 0 or pos.x >= width or pos.y >= height:
		return edge_is_ground
	if pos.y < 0:
		return false
	return _is_any(pos, ["ground", "slope"])


func _is(pos: Vector2i, id: String) -> bool:
	return cells.has(pos) and cells[pos].get("t", "") == id


func _is_any(pos: Vector2i, ids: Array) -> bool:
	return cells.has(pos) and ids.has(cells[pos].get("t", ""))


func _rect(size: Vector2, offset: Vector2) -> CollisionShape2D:
	var rect := RectangleShape2D.new()
	rect.size = size
	var shape := CollisionShape2D.new()
	shape.shape = rect
	shape.position = offset
	return shape


func _sprite(parent: Node, texture: Texture2D, pos: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = pos
	parent.add_child(sprite)
	return sprite


## Malý drahokam farby páčky/výťahu, aby bolo vidieť, čo k čomu patrí.
func _color_marker(color: String, offset: Vector2) -> Sprite2D:
	var marker := Sprite2D.new()
	marker.name = "Color"
	marker.texture = _tex("gem_" + color)
	marker.scale = Vector2(0.45, 0.45)
	marker.position = offset
	return marker


func _frames(anims: Dictionary, fps: float) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim in anims:
		frames.add_animation(anim)
		frames.set_animation_speed(anim, fps)
		for name in anims[anim]:
			frames.add_frame(anim, _tex(name))
	return frames


func _tex(name: String) -> Texture2D:
	var path := Catalog.TILES % name
	if not _textures.has(path):
		_textures[path] = load(path)
	return _textures[path]


func _terrain_tex(name: String) -> Texture2D:
	return _tex("terrain_%s_%s" % [terrain, name])
