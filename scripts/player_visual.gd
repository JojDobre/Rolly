extends Node2D
## Vzhľad hráča z Kenney Shape Characters: telo (guľa alebo iný tvar), tvár a dve ruky.
## Telo sa pri pohybe kotúľa, tvár mení výraz podľa toho, čo hráč robí, ruky gestikulujú.

const DIR := "res://assets/shape/%s.png"
const BODY_SCALE := 0.36  ## 160 px obrázok → priemer ~58 px
const HAND_SCALE := 0.32
const FACE_SCALE := 0.36
const RADIUS := 26.0

## Výraz tváre pre každý stav (face_a … face_l).
const FACES := {
	"idle": "face_a", "walk": "face_f", "jump": "face_c", "fall": "face_i", "climb": "face_e",
	"swim": "face_e", "drowning": "face_i", "hurt": "face_g", "dead": "face_j", "win": "face_l",
	"duck": "face_b", "blink": "face_l",
}

var color := "red"
var shape := "circle"

var _body: Sprite2D
var _face: Sprite2D
var _hand_front: Sprite2D
var _hand_back: Sprite2D
var _shadow: Sprite2D
var _time := 0.0
var _blink := 0.0
var _next_blink := 3.0
var _squash: Tween
var _textures := {}


func setup(new_color: String, new_shape: String) -> void:
	color = new_color
	shape = new_shape
	for child in get_children():
		child.queue_free()
	_shadow = _part("shadow", 0.9)
	_shadow.position = Vector2(0, RADIUS + 2)
	_shadow.modulate.a = 0.5
	_hand_back = _part("%s_hand_open" % color, HAND_SCALE)
	_body = _part("%s_body_%s" % [color, shape], BODY_SCALE)
	_face = _part("face_a", FACE_SCALE)
	_hand_front = _part("%s_hand_open" % color, HAND_SCALE)


func _part(texture: String, part_scale: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = _tex(texture)
	sprite.scale = Vector2.ONE * part_scale
	add_child(sprite)
	return sprite


## Volá hráč každý snímok. state: idle, walk, jump, fall, climb, swim, drowning, hurt, dead, win, duck
func update_visual(delta: float, velocity: Vector2, facing: float, state: String) -> void:
	if _body == null:
		return
	_time += delta
	# Kotúľanie tela (guľa sa točí, ostatné tvary sa len nakláňajú)
	if shape == "circle":
		if state in ["walk", "jump", "fall", "idle"]:
			_body.rotation += velocity.x * delta / RADIUS
	else:
		_body.rotation = lerp_angle(_body.rotation, clampf(velocity.x * 0.0009, -0.25, 0.25), 10.0 * delta)
	_shadow.visible = state in ["idle", "walk", "duck"]

	# Žmurkanie v pokoji
	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink = 0.15
		_next_blink = randf_range(2.5, 5.0)
	_blink = maxf(0.0, _blink - delta)
	var face_state := "blink" if _blink > 0.0 and state in ["idle", "walk"] else state
	_face.texture = _tex(FACES.get(face_state, "face_a"))
	_face.position = Vector2(facing * 7.0, -4.0 + (6.0 if state == "duck" else 0.0))
	_face.flip_h = facing < 0.0

	_animate_hands(state, facing, velocity)


func _animate_hands(state: String, facing: float, velocity: Vector2) -> void:
	var front := Vector2(facing * 30.0, 8.0)
	var back := Vector2(-facing * 30.0, 8.0)
	var front_tex := "open"
	var back_tex := "open"
	var swing := sin(_time * 12.0)
	match state:
		"idle":
			front.y += sin(_time * 2.5) * 2.0
			back.y += sin(_time * 2.5 + 1.0) * 2.0
		"walk":
			front_tex = "point"
			front += Vector2(facing * 4.0, swing * 5.0)
			back += Vector2(0, -swing * 5.0)
			back_tex = "closed"
		"jump":
			front += Vector2(0, -22)
			back += Vector2(0, -22)
		"fall":
			front += Vector2(facing * 6.0, -30 + swing * 4.0)
			back += Vector2(-facing * 6.0, -30 - swing * 4.0)
		"climb":
			front_tex = "closed"
			back_tex = "closed"
			var climb := sin(_time * 8.0) * 10.0 if absf(velocity.y) > 5.0 else 0.0
			front = Vector2(18.0, -18.0 + climb)
			back = Vector2(-18.0, -18.0 - climb)
		"swim", "drowning":
			front += Vector2(swing * 6.0, -6.0)
			back += Vector2(-swing * 6.0, -6.0)
		"hurt", "dead":
			front += Vector2(facing * 8.0, -16.0)
			back += Vector2(-facing * 8.0, -16.0)
		"win":
			front_tex = "thumb"
			back_tex = "peace"
			front += Vector2(0, -26.0)
			back += Vector2(0, -26.0)
		"duck":
			front.y += 8.0
			back.y += 8.0
	_hand_front.position = front
	_hand_back.position = back
	_hand_front.texture = _tex("%s_hand_%s" % [color, front_tex])
	_hand_back.texture = _tex("%s_hand_%s" % [color, back_tex])
	_hand_front.flip_h = facing < 0.0
	_hand_back.flip_h = facing > 0.0


## Sploštenie pri dopade (strength 0..1).
func squash(strength: float) -> void:
	_kill_squash()
	var amount := clampf(strength, 0.0, 1.0) * 0.3
	scale = Vector2(1.0 + amount, 1.0 - amount)
	position.y = RADIUS * amount
	_squash = create_tween().set_parallel().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_squash.tween_property(self, "scale", Vector2.ONE, 0.45)
	_squash.tween_property(self, "position:y", 0.0, 0.3)


## Natiahnutie pri výskoku.
func stretch() -> void:
	_kill_squash()
	scale = Vector2(0.85, 1.15)
	_squash = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_squash.tween_property(self, "scale", Vector2.ONE, 0.3)


func _kill_squash() -> void:
	if _squash:
		_squash.kill()


func _tex(name: String) -> Texture2D:
	if not _textures.has(name):
		_textures[name] = load(DIR % name)
	return _textures[name]
