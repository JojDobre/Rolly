extends Node2D
## Jeden level: postaví ho z dát, riadi hráča, zbieranie, mechanizmy, výbuchy, smrť a cieľ.
## Ak je GameState.test_level nastavený, hrá sa testovacia verzia z editora.

const Catalog := preload("res://scripts/catalog.gd")
const Loader := preload("res://scripts/level_loader.gd")
const HUD := preload("res://scripts/hud.gd")
const BACKGROUND := preload("res://scripts/background.gd")
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const T := 64
const FALL_MARGIN := 300.0
const LOOK_AHEAD := 90.0

var world: Dictionary
var level: Dictionary
var test_mode := false
var player: CharacterBody2D

var stars_total := 0
var stars_collected := 0
var coins := 0
var keys := {}  # farba -> true
var elapsed := 0.0
var running := true

var _loader: Loader
var _hud: HUD
var _respawn_point := Vector2.ZERO
var _level_size := Vector2.ZERO
var _levers := {}       # farba -> bool
var _switch_until := {} # farba -> čas konca v sekundách
var _shake := 0.0

@onready var camera: Camera2D = $Camera2D
@onready var level_root: Node2D = $World


func _ready() -> void:
	add_to_group("game")
	test_mode = not GameState.test_level.is_empty()
	if test_mode:
		world = GameState.test_world
		level = GameState.test_level
	else:
		world = Content.get_world(GameState.current_world_id)
		level = Content.get_level(GameState.current_world_id, GameState.current_level_id)
	if level.is_empty():
		push_error("Level sa nenašiel: %s / %s" % [GameState.current_world_id, GameState.current_level_id])
		get_tree().change_scene_to_file.call_deferred("res://scenes/menu.tscn")
		return

	_loader = Loader.new()
	_loader.build(level, world, level_root)
	_level_size = Vector2(_loader.width * T, _loader.height * T)
	stars_total = _loader.star_count
	_respawn_point = _loader.start

	player = PLAYER_SCENE.instantiate()
	player.game = self
	player.position = _loader.start
	player.z_index = 5
	level_root.add_child(player)
	player.set_character(GameState.character)
	player.died.connect(_on_player_died)

	camera.limit_left = 0
	camera.limit_top = -T * 4
	camera.limit_right = int(_level_size.x)
	camera.limit_bottom = int(_level_size.y)
	camera.global_position = player.global_position
	camera.reset_smoothing()

	var background = BACKGROUND.new()
	background.camera = camera
	background.style = world.get("background", "hills")
	add_child(background)

	_hud = HUD.new()
	_hud.game = self
	add_child(_hud)
	_hud.bind_player(player)
	_hud.set_level_title(level.get("name", ""))
	_hud.update_stars(stars_collected, stars_total)
	_hud.update_coins(coins)
	GameState.play_music(GameState.playlist_for(world))


func _process(delta: float) -> void:
	if player == null:
		return
	if running and not player.dead:
		elapsed += delta
		_hud.update_time(elapsed)
		var look := Vector2(clampf(player.velocity.x * 0.3, -LOOK_AHEAD, LOOK_AHEAD), 0.0)
		camera.global_position = player.global_position + look
		if player.global_position.y > _level_size.y + FALL_MARGIN:
			player.die()

	_shake = move_toward(_shake, 0.0, 50.0 * delta)
	camera.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))

	var now := Time.get_ticks_msec() / 1000.0
	for color in _switch_until.keys():
		if now >= _switch_until[color]:
			_switch_until.erase(color)
			_update_channel(color)


# --- Mriežka (voda, láva, rebríky) ------------------------------------------

func is_water(cell: Vector2i) -> bool:
	return _loader != null and _loader.water.has(cell)


func is_lava(cell: Vector2i) -> bool:
	return _loader != null and _loader.lava.has(cell)


func is_ladder(cell: Vector2i) -> bool:
	return _loader != null and _loader.ladders.has(cell)


# --- Zbieranie ---------------------------------------------------------------

func collect(item_id: String, kind: String, pos: Vector2) -> void:
	match kind:
		"coin":
			var value: int = Catalog.COIN_VALUES.get(item_id, 1)
			coins += value
			_hud.update_coins(coins)
			if not test_mode:
				GameState.add_coins(value)
			GameState.play_sfx("impact/impactGlass_light_002", -6.0, 1.6)
		"star":
			stars_collected += 1
			_hud.update_stars(stars_collected, stars_total)
			GameState.play_sfx("impact/impactBell_heavy_000", -6.0, 1.5)
			Input.vibrate_handheld(25)
		"powerup":
			player.apply_powerup(item_id)
			GameState.play_sfx("impact/impactBell_heavy_001", -4.0, 1.2)
		"key":
			var color: String = Catalog.get_item(item_id)["params"]["color"]
			keys[color] = true
			_hud.update_keys(keys)
			unlock(color)
	_sparkle(pos)


func spawn_pickup(id: String, block_center: Vector2, popped: bool) -> void:
	_loader.spawn_pickup(id, block_center, popped)


func spawn_mob(id: String, pos: Vector2) -> void:
	_loader.spawn_mob(id, pos)


func unlock(color: String) -> void:
	GameState.play_jingle(GameState.JINGLE_KEY)
	for lock in get_tree().get_nodes_in_group("lock_" + color):
		for shape in lock.find_children("*", "CollisionShape2D", false, false):
			shape.set_deferred("disabled", true)
		var tween: Tween = lock.create_tween()
		tween.tween_property(lock, "scale", Vector2(1.2, 1.2), 0.12)
		tween.tween_property(lock, "scale", Vector2.ZERO, 0.2)
		tween.tween_callback(lock.queue_free)


# --- Mechanizmy ---------------------------------------------------------------

## Prechod dverami k druhým dverám rovnakej farby (napr. do podzemia a späť).
func warp(door: Node2D) -> void:
	var target: Node2D = door.partner()
	if target == null or not running or player.dead or not player.input_enabled:
		return
	player.input_enabled = false
	player.velocity = Vector2.ZERO
	door.flash_open()
	GameState.play_sfx("impact/impactWood_medium_002", -4.0, 0.9)
	var tween := create_tween()
	tween.tween_property(player, "modulate:a", 0.0, 0.2)
	await tween.finished
	player.global_position = target.global_position + Vector2(0, 2)
	player.velocity = Vector2.ZERO
	camera.global_position = player.global_position
	camera.reset_smoothing()
	target.flash_open()
	var back := create_tween()
	back.tween_property(player, "modulate:a", 1.0, 0.2)
	await back.finished
	if not player.dead:
		player.input_enabled = true


func press_switch(color: String, seconds: float) -> void:
	_switch_until[color] = Time.get_ticks_msec() / 1000.0 + seconds
	_update_channel(color)


func toggle_lever(color: String) -> void:
	_levers[color] = not _levers.get(color, false)
	_update_channel(color)


func _update_channel(color: String) -> void:
	var switched: bool = _levers.get(color, false) != _switch_until.has(color)
	for node in get_tree().get_nodes_in_group("channel_" + color):
		node.set_switched(switched)


## Výbuch bomby: zničí moby a rozbitné bloky, zapáli iné bomby a zabije hráča v okruhu.
func explode(pos: Vector2, radius: int) -> void:
	var reach := radius * T + T / 2.0
	GameState.play_sfx("impact/impactPunch_heavy_001", 0.0, 0.7)
	GameState.play_sfx("impact/impactMetal_heavy_002", -4.0, 0.6)
	Input.vibrate_handheld(120)
	_shake = 14.0
	_explosion_effect(pos, reach)
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.global_position.distance_to(pos) <= reach:
			enemy.kill()
	for node in get_tree().get_nodes_in_group("bomb_breakable"):
		if node.global_position.distance_to(pos) <= reach:
			if node.has_method("explode"):
				node.explode()
			else:
				break_effect(node.global_position, "brickBrown")
				node.queue_free()
	for bomb in get_tree().get_nodes_in_group("bomb"):
		if bomb.global_position.distance_to(pos) <= reach:
			bomb.ignite(0.3)
	if player.global_position.distance_to(pos) <= reach and player.shield <= 0.0:
		player.die()


func break_effect(pos: Vector2, particle: String) -> void:
	var particles := CPUParticles2D.new()
	particles.texture = load("res://assets/remastered/%s.png" % particle)
	particles.position = pos
	particles.one_shot = true
	particles.amount = 6
	particles.lifetime = 0.9
	particles.explosiveness = 1.0
	particles.direction = Vector2.UP
	particles.spread = 70.0
	particles.gravity = Vector2(0, 1400)
	particles.initial_velocity_min = 250.0
	particles.initial_velocity_max = 420.0
	particles.angular_velocity_min = -360.0
	particles.angular_velocity_max = 360.0
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 0.8
	particles.z_index = 4
	level_root.add_child(particles)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)


func _explosion_effect(pos: Vector2, reach: float) -> void:
	var particles := CPUParticles2D.new()
	particles.texture = load(Catalog.TILES % "fireball")
	particles.position = pos
	particles.one_shot = true
	particles.amount = 24
	particles.lifetime = 0.5
	particles.explosiveness = 1.0
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = reach * 1.2
	particles.initial_velocity_max = reach * 2.0
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.2
	particles.color = Color(1, 0.85, 0.6)
	particles.z_index = 4
	level_root.add_child(particles)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)


func _sparkle(pos: Vector2) -> void:
	var particles := CPUParticles2D.new()
	particles.position = pos
	particles.one_shot = true
	particles.amount = 10
	particles.lifetime = 0.4
	particles.explosiveness = 1.0
	particles.spread = 180.0
	particles.gravity = Vector2(0, 300)
	particles.initial_velocity_min = 100.0
	particles.initial_velocity_max = 200.0
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 5.0
	particles.color = Color("ffd23f")
	particles.z_index = 4
	level_root.add_child(particles)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)


# --- Checkpoint, cieľ, smrť ---------------------------------------------------

func reach_checkpoint(pos: Vector2) -> void:
	_respawn_point = pos
	GameState.play_jingle(GameState.JINGLE_CHECKPOINT)


func reach_exit(exit_node: Node2D) -> void:
	if not running or player.dead:
		return
	running = false
	player.input_enabled = false
	player.velocity = Vector2.ZERO
	player.celebrate()
	var tween := create_tween()
	tween.tween_property(player, "global_position:x", exit_node.global_position.x, 0.25)
	tween.tween_property(player, "modulate:a", 0.0, 0.4)
	GameState.stop_music()
	GameState.play_jingle(GameState.JINGLE_COMPLETE)
	if not test_mode:
		GameState.record_stars(world["id"], level["id"], stars_collected)
	await get_tree().create_timer(1.0).timeout
	var next := {} if test_mode else Content.next_level(world["id"], level["id"])
	if not test_mode:
		GameState.maybe_show_interstitial()
	_hud.show_level_complete(stars_collected, stars_total, coins, elapsed, not next.is_empty(), test_mode)


func _on_player_died() -> void:
	GameState.play_jingle(GameState.JINGLE_DEATH)
	_shake = 10.0
	if not test_mode:
		GameState.lose_life()
	await get_tree().create_timer(1.2).timeout
	if test_mode or GameState.lives > 0:
		_respawn()
	else:
		_hud.show_out_of_lives()


func _respawn() -> void:
	player.modulate.a = 1.0
	player.respawn(_respawn_point)
	camera.global_position = _respawn_point
	camera.reset_smoothing()


## Volá HUD po reklame za život.
func continue_after_ad() -> void:
	_respawn()


func restart_level() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func next_level() -> void:
	get_tree().paused = false
	var next := Content.next_level(world["id"], level["id"])
	if next.is_empty():
		go_to_menu()
		return
	GameState.current_level_id = next["id"]
	get_tree().reload_current_scene()


func go_to_menu() -> void:
	get_tree().paused = false
	GameState.stop_music()
	if test_mode:
		get_tree().change_scene_to_file("res://scenes/editor.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
