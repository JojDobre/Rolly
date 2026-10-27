extends Node2D
## Jeden level: postaví mapu, sleduje hviezdy, smrť, checkpointy a cieľ.

const BUILDER := preload("res://scripts/level_builder.gd")
const HUD := preload("res://scripts/hud.gd")
const BACKGROUND := preload("res://scripts/background.gd")
const TEX_FLAG_RED_UP := preload("res://assets/objects/flagRed_up.png")
const TEX_FLAG_GREEN_UP := preload("res://assets/objects/flagGreen_up.png")
const BALL := preload("res://scripts/ball.gd")
const FALL_MARGIN := 300.0
const T_EXTRA := 256  ## koľko je kamera ochotná ukázať nad levelom
const LOOK_AHEAD := 110.0

var level := 1
var stars_total := 0
var stars_collected := 0
var elapsed := 0.0
var running := true

var _respawn_point := Vector2.ZERO
var _level_size := Vector2.ZERO
var _dead := false
var _shake := 0.0
var _hud: HUD

@onready var ball: BALL = $Ball
@onready var camera: Camera2D = $Camera2D
@onready var world: Node2D = $World


func _ready() -> void:
	level = GameState.current_level
	var data = load("res://levels/level_%02d.gd" % level)
	var info: Dictionary = BUILDER.new().build(data.MAP, world)

	_level_size = info["size"]
	_respawn_point = info["start"]
	ball.add_to_group("player")
	ball.respawn(info["start"])
	ball.global_position = info["start"]
	ball.landed.connect(_on_ball_landed)
	ball.jumped.connect(_on_ball_jumped)

	stars_total = info["stars"].size()
	for star in info["stars"]:
		star.collected.connect(_on_star_collected)
	for key in info["keys"]:
		key.collected.connect(_on_key_collected.bind(info["locks"]))
	for hazard in info["hazards"]:
		hazard.body_entered.connect(_on_hazard_body_entered)
	for checkpoint in info["checkpoints"]:
		checkpoint.body_entered.connect(_on_checkpoint_body_entered.bind(checkpoint))
	if info["finish"]:
		info["finish"].body_entered.connect(_on_finish_body_entered.bind(info["finish"]))
	else:
		push_error("Level %d nemá cieľ (F)" % level)

	camera.limit_left = 0
	camera.limit_top = -T_EXTRA
	camera.limit_right = int(_level_size.x)
	camera.limit_bottom = int(_level_size.y)
	camera.global_position = info["start"]
	camera.reset_smoothing()

	var background = BACKGROUND.new()
	background.camera = camera
	add_child(background)
	_hud = HUD.new()
	_hud.game = self
	add_child(_hud)
	_hud.set_level_title(level, data.TITLE)
	_hud.update_stars(stars_collected, stars_total)


func _process(delta: float) -> void:
	if running and not _dead:
		elapsed += delta
		_hud.update_time(elapsed)

	if not _dead:
		var look_ahead := Vector2(clampf(ball.linear_velocity.x * 0.2, -LOOK_AHEAD, LOOK_AHEAD), 0.0)
		camera.global_position = ball.global_position + look_ahead

	_shake = move_toward(_shake, 0.0, 60.0 * delta)
	camera.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))

	if not _dead and ball.global_position.y > _level_size.y + FALL_MARGIN:
		_die()


# --- Udalosti -------------------------------------------------------------

func _on_star_collected() -> void:
	stars_collected += 1
	_hud.update_stars(stars_collected, stars_total)


func _on_key_collected(locks: Array) -> void:
	for lock in locks:
		for shape in lock.find_children("*", "CollisionShape2D", false, false):
			shape.set_deferred("disabled", true)
		var tween: Tween = lock.create_tween()
		tween.tween_property(lock, "scale", Vector2(1.2, 1.2), 0.12)
		tween.tween_property(lock, "scale", Vector2.ZERO, 0.2)
		tween.tween_callback(lock.queue_free)


func _on_hazard_body_entered(body: Node) -> void:
	if body == ball:
		_die()


func _on_checkpoint_body_entered(body: Node, checkpoint: Area2D) -> void:
	if body != ball or _respawn_point == checkpoint.global_position + Vector2(0, -40):
		return
	_respawn_point = checkpoint.global_position + Vector2(0, -40)
	var sprite: Sprite2D = checkpoint.get_node("Sprite")
	sprite.texture = TEX_FLAG_GREEN_UP
	GameState.play_sfx("impactBell_heavy_000", -8.0, 1.4)


func _on_finish_body_entered(body: Node, finish: Area2D) -> void:
	if body != ball or not running or _dead:
		return
	running = false
	ball.input_enabled = false
	var sprite: Sprite2D = finish.get_node("Sprite")
	sprite.texture = TEX_FLAG_RED_UP
	GameState.play_sfx("impactBell_heavy_000")
	GameState.record_stars(level, stars_collected)
	await get_tree().create_timer(0.8).timeout
	GameState.maybe_show_interstitial()
	_hud.show_level_complete(stars_collected, stars_total, elapsed, GameState.has_level(level + 1))


func _on_ball_landed(impact_speed: float) -> void:
	if impact_speed < 250.0:
		return
	var strength := inverse_lerp(250.0, 1400.0, impact_speed)
	ball.visual.squash(strength)
	GameState.play_sfx("impactSoft_medium_000", lerpf(-14.0, 0.0, strength), randf_range(0.9, 1.1))
	if strength > 0.55:
		_shake = 8.0 * strength
		Input.vibrate_handheld(15)


func _on_ball_jumped() -> void:
	ball.visual.stretch()


# --- Smrť a návrat --------------------------------------------------------

func _die() -> void:
	if _dead or not running:
		return
	_dead = true
	GameState.play_sfx("impactPunch_heavy_000", -4.0)
	Input.vibrate_handheld(60)
	_shake = 12.0
	ball.input_enabled = false
	ball.set_deferred("freeze", true)
	var tween := create_tween()
	tween.tween_property(ball.visual, "scale", Vector2(1.6, 0.2), 0.12)
	tween.tween_callback(func(): ball.visible = false)
	GameState.lose_life()
	await get_tree().create_timer(0.9).timeout

	if GameState.lives > 0:
		_respawn()
	else:
		_hud.show_out_of_lives()


func _respawn() -> void:
	ball.visual.scale = Vector2.ONE
	ball.global_position = _respawn_point
	ball.respawn(_respawn_point)
	camera.global_position = _respawn_point
	camera.reset_smoothing()
	_dead = false


## Volá HUD, keď si hráč pozrie reklamu a dostane život.
func continue_after_ad() -> void:
	_respawn()


func restart_level() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func next_level() -> void:
	get_tree().paused = false
	GameState.current_level = level + 1
	get_tree().reload_current_scene()


func go_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
