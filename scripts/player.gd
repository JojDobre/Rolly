extends CharacterBody2D
## Hráč – guľová postavička z Kenney Shape Characters (telo, tvár, ruky – pozri player_visual.gd).
## Chôdza, skok, rebrík a lano, plávanie (s dychom), zdravie, skok na moby,
## úder hlavou do blokov zospodu, tlačenie krabíc a power-upy z drahokamov.

signal died
signal health_changed(health: int)
signal breath_changed(ratio: float)  ## 1 = plné pľúca, 0 = topí sa
signal powerups_changed

const Catalog := preload("res://scripts/catalog.gd")
const T := 64
const MAX_HEALTH := 3
const RADIUS := 26.0

@export var walk_speed := 270.0
@export var acceleration := 1900.0
@export var air_acceleration := 1300.0
@export var friction := 2200.0
@export var gravity := 1500.0
@export var jump_speed := 690.0      ## ~2,5 dlaždice (stena vysoká 2 dlaždice sa dá vyskočiť)
@export var max_fall_speed := 900.0
@export var climb_speed := 170.0
@export var coyote_time := 0.1
@export var jump_buffer := 0.12
@export var push_force := 60.0
@export var breath_seconds := 8.0
@export var invulnerable_time := 1.5

var game  # game.gd – nastaví ho hra
var input_enabled := true
var health := MAX_HEALTH
var dead := false
var facing := 1.0

## Power-upy: zostávajúci čas v sekundách.
var speed_boost := 0.0
var jump_boost := 0.0
var shield := 0.0

var _climbing := false
var _swimming := false
var _breath := 1.0
var _invulnerable := 0.0
var _since_ground := 1.0
var _since_jump_press := 1.0
var _drop_through := 0.0
var _hit_cooldown := 0.0
var _won := false
var _was_on_floor := true
var _fall_speed := 0.0

@onready var visual = $Visual  # player_visual.gd


func _ready() -> void:
	add_to_group("player")
	collision_layer = 1 << 2
	collision_mask = 1 | 2
	floor_snap_length = 8.0
	floor_max_angle = deg_to_rad(50)


## Nastaví postavičku, napr. "red_circle" (farba: blue, green, pink, purple, red;
## tvar: circle, square, squircle, rhombus).
func set_character(character: String) -> void:
	var parts := character.split("_")
	var color := parts[0] if parts.size() > 0 else "red"
	var shape := parts[1] if parts.size() > 1 else "circle"
	visual.setup(color, shape)


## Radosť v cieli (palec hore).
func celebrate() -> void:
	_won = true


func _physics_process(delta: float) -> void:
	if dead:
		return
	_tick_timers(delta)

	var dir := Input.get_axis("move_left", "move_right") if input_enabled else 0.0
	var vertical := Input.get_axis("move_up", "move_down") if input_enabled else 0.0
	var jump_pressed := input_enabled and Input.is_action_just_pressed("jump")
	if jump_pressed:
		_since_jump_press = 0.0

	var center_cell := _cell_at(global_position)
	var head_cell := _cell_at(global_position + Vector2(0, -RADIUS + 6))
	var feet_cell := _cell_at(global_position + Vector2(0, RADIUS + 6))  # bunka tesne pod nohami
	var on_ladder: bool = game and (game.is_ladder(center_cell) or game.is_ladder(feet_cell))
	_swimming = game and (game.is_water(center_cell) or game.is_water(feet_cell))
	var head_under: bool = game and game.is_water(head_cell)

	if game and (game.is_lava(center_cell) or game.is_lava(feet_cell)):
		die()
		return

	# Dych pod vodou
	if head_under:
		_breath = maxf(0.0, _breath - delta / breath_seconds)
		breath_changed.emit(_breath)
		if _breath <= 0.0:
			die()
			return
	elif _breath < 1.0:
		_breath = minf(1.0, _breath + delta / 1.5)
		breath_changed.emit(_breath)

	# Rebrík: chytí sa šípkou hore/dole, pustí sa skokom alebo keď rebrík skončí
	if on_ladder and vertical != 0.0 and not _climbing:
		_climbing = true
		global_position.x = lerpf(global_position.x, (center_cell.x + 0.5) * T, 0.5)
	if _climbing and (not on_ladder or jump_pressed):
		_climbing = false
	# Na vrchu rebríka sa nedá liezť vyššie – nohy zostanú na úrovni jeho vrchu.
	var ladder_top_y := feet_cell.y * T
	var at_top: bool = _climbing and game and not game.is_ladder(Vector2i(feet_cell.x, feet_cell.y - 1)) \
			and global_position.y + RADIUS <= ladder_top_y + 2.0
	if vertical > 0.5 and is_on_floor() and not _climbing and jump_pressed:
		_drop_through = 0.25  # dole + skok = zoskočenie z plošiny
		jump_pressed = false
		_since_jump_press = 1.0
	set_collision_mask_value(2, not (_climbing or _drop_through > 0.0))

	var speed := walk_speed * (1.5 if speed_boost > 0.0 else 1.0)
	if _climbing:
		velocity = Vector2(dir * climb_speed * 0.6, vertical * climb_speed)
		if at_top and velocity.y < 0.0:
			velocity.y = 0.0
			global_position.y = ladder_top_y - RADIUS
	elif _swimming:
		velocity.x = move_toward(velocity.x, dir * speed * 0.6, acceleration * delta)
		velocity.y = minf(velocity.y + gravity * 0.25 * delta, 160.0)
		if jump_pressed:
			velocity.y = -360.0 if not head_under else -300.0
			_since_jump_press = 1.0
	else:
		var accel := acceleration if is_on_floor() else air_acceleration
		if dir != 0.0:
			velocity.x = move_toward(velocity.x, dir * speed, accel * delta)
		elif is_on_floor():
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
		if is_on_floor():
			_since_ground = 0.0
		if _since_jump_press < jump_buffer and _since_ground < coyote_time:
			velocity.y = -jump_speed * (1.3 if jump_boost > 0.0 else 1.0)
			_since_jump_press = 1.0
			_since_ground = 1.0
			GameState.play_sfx("impact/impactSoft_medium_000", -14.0, 1.4)
			visual.stretch()
		if Input.is_action_just_released("jump") and velocity.y < 0.0:
			velocity.y *= 0.5

	if dir != 0.0:
		facing = signf(dir)
	var rising := velocity.y < 0.0
	_fall_speed = velocity.y
	move_and_slide()
	_after_move(rising)
	if is_on_floor() and not _was_on_floor and _fall_speed > 300.0:
		visual.squash(inverse_lerp(300.0, 900.0, _fall_speed))
	_was_on_floor = is_on_floor()
	_animate(delta, vertical, head_under)


func _after_move(was_rising: bool) -> void:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		var normal := collision.get_normal()
		# Úder hlavou zospodu
		if was_rising and normal.y > 0.6 and _hit_cooldown <= 0.0 and collider and collider.has_method("hit_from_below"):
			collider.hit_from_below(self)
			_hit_cooldown = 0.15
		# Tlačenie krabíc
		if collider is RigidBody2D and absf(normal.x) > 0.6:
			collider.apply_central_impulse(Vector2(-normal.x * push_force, 0.0))
		# Bloky s bodcami
		if collider and collider.is_in_group("hurts_on_touch"):
			hurt(collider.global_position)


func _animate(delta: float, vertical: float, head_under: bool) -> void:
	var state := "idle"
	if dead:
		state = "dead"
	elif _won:
		state = "win"
	elif _invulnerable > invulnerable_time - 0.4:
		state = "hurt"
	elif _climbing:
		state = "climb"
	elif _swimming:
		state = "drowning" if head_under and _breath < 0.35 else "swim"
	elif not is_on_floor():
		state = "jump" if velocity.y < 200.0 else "fall"
	elif vertical > 0.5:
		state = "duck"
	elif absf(velocity.x) > 20.0:
		state = "walk"
	visual.update_visual(delta, velocity, facing, state)
	# Blikanie pri nezraniteľnosti, dúhová farba pri štíte
	if shield > 0.0:
		visual.modulate = Color.from_hsv(fmod(Time.get_ticks_msec() / 600.0, 1.0), 0.45, 1.0)
	elif _invulnerable > 0.0:
		visual.modulate.a = 0.35 if int(_invulnerable * 12.0) % 2 == 0 else 1.0
	else:
		visual.modulate = Color.WHITE


func _tick_timers(delta: float) -> void:
	_since_ground += delta
	_since_jump_press += delta
	_invulnerable = maxf(0.0, _invulnerable - delta)
	_drop_through = maxf(0.0, _drop_through - delta)
	_hit_cooldown = maxf(0.0, _hit_cooldown - delta)
	var had := speed_boost > 0.0 or jump_boost > 0.0 or shield > 0.0
	speed_boost = maxf(0.0, speed_boost - delta)
	jump_boost = maxf(0.0, jump_boost - delta)
	shield = maxf(0.0, shield - delta)
	if had:
		powerups_changed.emit()


func _cell_at(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / T), floori(point.y / T))


# --- Interakcie -------------------------------------------------------------

func is_invulnerable() -> bool:
	return _invulnerable > 0.0 or shield > 0.0 or dead


## Zranenie (bodce, mob, kaktus...). Vráti true, ak hráč naozaj dostal zásah.
func hurt(from: Vector2) -> bool:
	if is_invulnerable():
		return false
	health -= 1
	health_changed.emit(health)
	GameState.play_sfx("impact/impactPunch_medium_000", -2.0)
	Input.vibrate_handheld(40)
	if health <= 0:
		die()
		return true
	_invulnerable = invulnerable_time
	_climbing = false
	var away := signf(global_position.x - from.x)
	velocity = Vector2((away if away != 0.0 else -facing) * 260.0, -420.0)
	return true


func heal(amount := 1) -> void:
	health = mini(MAX_HEALTH, health + amount)
	health_changed.emit(health)


## Odraz po skoku na moba alebo pružinu.
func bounce(strength := 520.0) -> void:
	velocity.y = -strength
	_since_ground = 1.0
	_climbing = false


func is_falling_onto(target_y: float) -> bool:
	return velocity.y > 0.0 and global_position.y < target_y - 12.0


func apply_powerup(id: String) -> void:
	match id:
		"heart":
			heal()
		"gem_blue":
			speed_boost = 10.0
		"gem_green":
			jump_boost = 10.0
		"gem_yellow":
			shield = 8.0
		"gem_red":
			GameState.add_life()
	powerups_changed.emit()


func die() -> void:
	if dead:
		return
	dead = true
	health = 0
	health_changed.emit(health)
	velocity = Vector2.ZERO
	collision_mask = 0
	visual.update_visual(0.0, Vector2.ZERO, facing, "dead")
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - 60.0, 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", position.y + 900.0, 0.8).set_ease(Tween.EASE_IN)
	died.emit()


func respawn(at: Vector2) -> void:
	dead = false
	health = MAX_HEALTH
	health_changed.emit(health)
	_breath = 1.0
	breath_changed.emit(_breath)
	_invulnerable = 1.0
	_climbing = false
	_won = false
	velocity = Vector2.ZERO
	collision_mask = 1 | 2
	global_position = at
	input_enabled = true
