extends CharacterBody2D
## Mob z Kenney New Platformer Pack. Správanie určuje "behavior" z katalógu:
##   walker, hopper, snail, ladybug, frog, flyer, flyer_vertical, swimmer, jumper_fish, barnacle, saw, crusher,
##   bat, ghost, pillar (moby z Platformer Art Extended Enemies)

const T := 64
const GRAVITY := 1500.0
const SHELL_SPEED := 460.0

var item_id := "slime_normal"
var behavior := "walker"
var stompable := true
var speed := 60.0
var move_range := 3  ## dlaždice pre letcov a pílu
var frames_spec := {}
var sprite_prefix := ""
## Cesta z editora: [x1, y1, x2, y2] v bunkách. Chodci sa otáčajú na jej krajoch,
## letci, ryby a píly sa pohybujú tam a späť medzi oboma bodmi.
var path: Array = []

const PATH_BEHAVIORS := ["walker", "snail", "hopper", "ladybug", "flyer", "flyer_vertical", "swimmer", "saw"]  ## predpona obrázkov v assets/npp/enemies (ak sa líši od item_id)  ## obrázky pre moby z rozšíreného balíka: {animácia: [súbory]}

var dir := -1.0
var dead := false

var _sprite: AnimatedSprite2D
var _hurtbox: Area2D
var _start := Vector2.ZERO
var _has_path := false
var _path_a := Vector2.ZERO
var _path_b := Vector2.ZERO
var _path_t := 0.0
var _time := 0.0
var _timer := 0.0
var _shell := false
var _shell_moving := false
var _busy := false
var _kick_cooldown := 0.0


func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 1 << 3
	collision_mask = 1 | 2
	floor_snap_length = 6.0
	_start = position
	_time = randf() * TAU
	if path.size() == 4 and behavior in PATH_BEHAVIORS:
		_has_path = true
		_path_a = Vector2(path[0] * T + T / 2.0, path[1] * T + T / 2.0)
		_path_b = Vector2(path[2] * T + T / 2.0, path[3] * T + T / 2.0)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = _build_frames()
	_sprite.play("move" if _sprite.sprite_frames.has_animation("move") and behavior != "bat" else "rest")
	add_child(_sprite)
	# Spodok obrázka na spodok tela (obrázky z rozšíreného balíka nemajú 64 px).
	var tex_height: float = _sprite.sprite_frames.get_frame_texture(_sprite.animation, 0).get_height()
	if not behavior in ["flyer", "flyer_vertical", "swimmer", "bat", "ghost", "saw", "jumper_fish"]:
		_sprite.offset.y = T / 2.0 - tex_height / 2.0
	if behavior == "bat":
		_sprite.offset.y = -T / 2.0 + tex_height / 2.0  # visí zo stropu

	var body_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(44, 40)
	body_shape.shape = rect
	body_shape.position = Vector2(0, 12)
	add_child(body_shape)

	_hurtbox = Area2D.new()
	_hurtbox.collision_layer = 0
	_hurtbox.collision_mask = 1 << 2
	var hurt_shape := CollisionShape2D.new()
	var hurt_rect := RectangleShape2D.new()
	hurt_rect.size = Vector2(46, 42)
	hurt_shape.position = Vector2(0, 10)
	if behavior == "crusher":
		hurt_rect.size = Vector2(60, 64)
		hurt_shape.position = Vector2.ZERO
	elif behavior == "pillar":
		hurt_rect.size = Vector2(36, tex_height - 10)
		hurt_shape.position = Vector2(0, T / 2.0 - tex_height / 2.0)
	hurt_shape.shape = hurt_rect
	_hurtbox.add_child(hurt_shape)
	add_child(_hurtbox)

	if behavior in ["flyer", "flyer_vertical", "swimmer", "jumper_fish", "barnacle", "saw", "crusher", "bat", "ghost", "pillar"]:
		collision_mask = 0 if behavior != "swimmer" else 1
	if behavior == "jumper_fish":
		_jump_loop()
	if behavior == "pillar":
		_snap_to_floor.call_deferred()


func _build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	if not frames_spec.is_empty():
		for anim in frames_spec:
			frames.add_animation(anim)
			frames.set_animation_speed(anim, 6.0)
			for file in frames_spec[anim]:
				frames.add_frame(anim, load("res://assets/enemies_ext/%s.png" % file))
		if not frames.has_animation("rest"):
			frames.add_animation("rest")
			frames.add_frame("rest", frames.get_frame_texture("move", 0))
		return frames
	var sets := {
		"move": [["walk_a", "walk_b"], ["move_a", "move_b"], ["swim_a", "swim_b"], ["a", "b"]],
		"rest": [["rest"], ["idle"], ["attack_rest"]],
		"flat": [["flat"], ["shell"]],
		"jump": [["jump"], ["fly"], ["up"], ["fall"]],
		"down": [["down"]],
		"attack": [["attack_a", "attack_b"]],
	}
	for anim in sets:
		for names in sets[anim]:
			var paths := []
			for n in names:
				paths.append("res://assets/npp/enemies/%s_%s.png" % [sprite_prefix if sprite_prefix != "" else item_id, n])
			if paths.all(func(p): return ResourceLoader.exists(p)):
				frames.add_animation(anim)
				frames.set_animation_speed(anim, 6.0)
				for p in paths:
					frames.add_frame(anim, load(p))
				break
	if not frames.has_animation("rest"):
		frames.add_animation("rest")
		frames.add_frame("rest", frames.get_frame_texture(frames.get_animation_names()[0], 0))
	return frames


func _physics_process(delta: float) -> void:
	if dead:
		return
	_time += delta
	_kick_cooldown = maxf(0.0, _kick_cooldown - delta)
	match behavior:
		"walker":
			_walk(delta)
		"snail":
			if _shell:
				_shell_slide(delta)
			else:
				_walk(delta)
		"hopper":
			_hop(delta)
		"ladybug":
			_ladybug(delta)
		"frog":
			_frog(delta)
		"flyer":
			_fly(false)
		"flyer_vertical":
			_fly(true)
		"swimmer":
			_swim(delta)
		"barnacle":
			_barnacle()
		"saw":
			_saw()
		"crusher":
			_crusher()
		"bat":
			_bat()
		"ghost":
			_ghost(delta)
	_touch_player()


# --- Správanie ---------------------------------------------------------------

func _walk(delta: float) -> void:
	velocity.x = dir * speed
	velocity.y += GRAVITY * delta
	move_and_slide()
	if is_on_wall() or (is_on_floor() and not _ground_ahead()):
		dir = -dir
	_keep_on_path()
	_sprite.flip_h = dir > 0.0


## Chodci: na krajoch cesty sa otočia.
func _keep_on_path() -> void:
	if not _has_path:
		return
	var left := minf(_path_a.x, _path_b.x)
	var right := maxf(_path_a.x, _path_b.x)
	if dir < 0.0 and position.x <= left:
		dir = 1.0
	elif dir > 0.0 and position.x >= right:
		dir = -1.0


## Letci, ryby a píly: plynulo tam a späť medzi bodmi cesty. Vráti true, ak cestu majú.
func _follow_path(delta: float) -> bool:
	if not _has_path:
		return false
	var length := maxf(_path_a.distance_to(_path_b), 1.0)
	_path_t += delta * speed / length
	var k := pingpong(_path_t, 1.0)
	var smooth := k * k * (3.0 - 2.0 * k)
	var previous := position
	position = _path_a.lerp(_path_b, smooth)
	if absf(position.x - previous.x) > 0.01:
		_sprite.flip_h = position.x > previous.x
	return true


func _hop(delta: float) -> void:
	velocity.y += GRAVITY * delta
	if is_on_floor():
		velocity.x = 0.0
		_timer += delta
		_sprite.play("rest")
		if _timer > 1.2:
			_timer = 0.0
			if not _ground_ahead():
				dir = -dir
			velocity = Vector2(dir * speed * 2.0, -560.0)
			if _sprite.sprite_frames.has_animation("jump"):
				_sprite.play("jump")
	move_and_slide()
	if is_on_wall():
		dir = -dir
	_keep_on_path()
	_sprite.flip_h = dir > 0.0


func _ladybug(delta: float) -> void:
	_timer += delta
	if is_on_floor() and _timer > 4.0:
		_timer = 0.0
		velocity.y = -520.0
		_sprite.play("jump")
	elif is_on_floor() and _sprite.animation != "move":
		_sprite.play("move")
	_walk(delta)


func _frog(delta: float) -> void:
	velocity.y += GRAVITY * delta
	if is_on_floor():
		velocity.x = 0.0
		_timer += delta
		_sprite.play("rest")
		if _timer > 1.6:
			_timer = 0.0
			var player = get_tree().get_first_node_in_group("player")
			if player:
				dir = signf(player.global_position.x - global_position.x)
			velocity = Vector2(dir * speed, -560.0)
			_sprite.play("jump")
	move_and_slide()
	_sprite.flip_h = dir > 0.0


func _fly(vertical: bool) -> void:
	if _follow_path(get_physics_process_delta_time()):
		return
	var span := move_range * T
	var phase := _time * speed / maxf(span, 1.0)
	var offset := sin(phase) * span
	if vertical:
		position = _start + Vector2(0, offset)
	else:
		position = _start + Vector2(offset, sin(_time * 3.0) * 6.0)
		_sprite.flip_h = cos(phase) > 0.0


func _swim(_delta: float) -> void:
	if _follow_path(_delta):
		return
	var game = get_tree().get_first_node_in_group("game")
	var ahead := Vector2i(floori((global_position.x + dir * 36.0) / T), floori(global_position.y / T))
	if game and not game.is_water(ahead):
		dir = -dir
	velocity = Vector2(dir * speed, sin(_time * 2.0) * 20.0)
	move_and_slide()
	if is_on_wall():
		dir = -dir
	_sprite.flip_h = dir > 0.0


func _jump_loop() -> void:
	var tween := create_tween().set_loops()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_interval(1.2)
	tween.tween_callback(func(): _sprite.play("jump" if _sprite.sprite_frames.has_animation("jump") else "rest"))
	tween.tween_property(self, "position:y", _start.y - T * 3.0, 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(func(): _sprite.play("down" if _sprite.sprite_frames.has_animation("down") else "rest"))
	tween.tween_property(self, "position:y", _start.y, 0.7).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(func(): _sprite.play("rest"))


func _barnacle() -> void:
	var player = get_tree().get_first_node_in_group("player")
	var near: bool = player != null and player.global_position.distance_to(global_position) < 140.0
	var anim := "attack" if near and _sprite.sprite_frames.has_animation("attack") else "rest"
	if _sprite.animation != anim:
		_sprite.play(anim)


func _saw() -> void:
	_sprite.rotation += 0.25 if _has_path else 0.0
	if _follow_path(get_physics_process_delta_time()):
		return
	var span := move_range * T
	position.x = _start.x + sin(_time * speed / maxf(span, 1.0)) * span
	_sprite.rotation += 0.25


func _crusher() -> void:
	if _busy:
		return
	var player = get_tree().get_first_node_in_group("player")
	if player == null or player.dead:
		return
	var dx := absf(player.global_position.x - global_position.x)
	var dy: float = player.global_position.y - global_position.y
	if dx < 56.0 and dy > 0.0 and dy < T * 8:
		_busy = true
		_sprite.play("jump")  # block_fall
		var floor_y := _find_floor()
		var tween := create_tween()
		tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		tween.tween_property(self, "position:y", floor_y, 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tween.tween_callback(func():
			_sprite.play("rest")
			GameState.play_sfx("impact/impactMetal_heavy_001", -2.0))
		tween.tween_interval(1.0)
		tween.tween_property(self, "position:y", _start.y, 1.4)
		tween.tween_callback(func():
			_sprite.play("move" if _sprite.sprite_frames.has_animation("move") else "rest")
			_busy = false)


## Stojace moby (vysoké hady) sa po položení postavia na zem pod sebou.
func _snap_to_floor() -> void:
	position.y = _find_floor()
	_start = position


func _bat() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	if not _busy:
		if player.global_position.distance_to(global_position) < T * 5:
			_busy = true
			_sprite.play("move")
			_sprite.offset.y = 0.0
		return
	var to_player: Vector2 = player.global_position - global_position
	velocity = to_player.normalized() * speed + Vector2(0, sin(_time * 6.0) * 80.0)
	position += velocity * get_physics_process_delta_time()
	_sprite.flip_h = to_player.x > 0.0


## Duch sa hýbe k hráčovi, len keď sa naň hráč nepozerá (ako Boo).
func _ghost(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null or player.dead:
		return
	var to_player: Vector2 = player.global_position - global_position
	var watched: bool = signf(-to_player.x) == signf(player.facing)
	if watched:
		_sprite.modulate.a = move_toward(_sprite.modulate.a, 0.5, delta * 2.0)
	else:
		_sprite.modulate.a = move_toward(_sprite.modulate.a, 1.0, delta * 2.0)
		position += to_player.normalized() * speed * delta
	_sprite.flip_h = to_player.x > 0.0


func _shell_slide(delta: float) -> void:
	velocity.y += GRAVITY * delta
	velocity.x = dir * SHELL_SPEED if _shell_moving else 0.0
	move_and_slide()
	if _shell_moving and is_on_wall():
		dir = -dir
		GameState.play_sfx("impact/impactPlate_light_001", -6.0)
	if _shell_moving:
		for enemy in get_tree().get_nodes_in_group("enemy"):
			if enemy != self and not enemy.dead and enemy.global_position.distance_to(global_position) < 48.0:
				enemy.kill()


# --- Kontakt s hráčom ---------------------------------------------------------

func _touch_player() -> void:
	for body in _hurtbox.get_overlapping_bodies():
		if not body.is_in_group("player") or body.dead:
			continue
		if _shell and not _shell_moving:
			if _kick_cooldown <= 0.0:
				dir = signf(global_position.x - body.global_position.x)
				if dir == 0.0:
					dir = 1.0
				_shell_moving = true
				_kick_cooldown = 0.3
				GameState.play_sfx("impact/impactSoft_heavy_000", -4.0)
			continue
		if stompable and body.is_falling_onto(global_position.y):
			body.bounce()
			stomp()
		elif _kick_cooldown <= 0.0:
			if body.shield > 0.0:
				kill()
			else:
				body.hurt(global_position)


func stomp() -> void:
	GameState.play_sfx("impact/impactSoft_heavy_001", -2.0)
	if behavior == "snail":
		if _shell and _shell_moving:
			_shell_moving = false
		else:
			_shell = true
			_shell_moving = false
		_kick_cooldown = 0.3
		_sprite.play("flat")
		return
	dead = true
	_hurtbox.set_deferred("monitoring", false)
	set_deferred("collision_layer", 0)
	if _sprite.sprite_frames.has_animation("flat"):
		_sprite.play("flat")
	else:
		_sprite.scale.y = 0.4
		_sprite.position.y += 18.0
	var tween := create_tween()
	tween.tween_interval(0.4)
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)


## Zabitie bombou, ulitou alebo pri neporaziteľnosti: mob sa prevráti a spadne.
func kill() -> void:
	if dead:
		return
	dead = true
	_hurtbox.set_deferred("monitoring", false)
	collision_mask = 0
	collision_layer = 0
	_sprite.flip_v = true
	GameState.play_sfx("impact/impactSoft_heavy_002", -4.0)
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - 40.0, 0.2)
	tween.tween_property(self, "position:y", position.y + 800.0, 0.9).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


func explode() -> void:
	kill()


# --- Pomocné -----------------------------------------------------------------

func _ground_ahead() -> bool:
	var space := get_world_2d().direct_space_state
	var from := global_position + Vector2(dir * 26.0, 20.0)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 40), 1 | 2)
	return not space.intersect_ray(query).is_empty()


func _find_floor() -> float:
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, 33), global_position + Vector2(0, T * 12), 1 | 2)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return _start.y + T * 6
	return position.y + (hit["position"].y - global_position.y) - 32.0
