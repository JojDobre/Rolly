extends Node2D
## Vzhľad guličky: kreslí ju kód, takže je to naša vlastná postava.
## Oči sa nekrútia s guličkou, pozerajú sa tam, kam letí, a občas žmurknú.

const RADIUS := 28.0
const OUTLINE := Color("8c1612")
const BODY := Color("e2392f")
const STRIPE := Color("f26a5f")
const SHINE := Color(1, 0.75, 0.7, 0.9)
const EYE := Color.WHITE
const PUPIL := Color("1e1e28")

var _look := Vector2.ZERO
var _blink := 0.0
var _next_blink := 2.5
var _scared := 0.0
var _squash_tween: Tween
var _drop := 0.0  # posun nadol pri sploštení, aby gulička sedela na zemi

@onready var _body := get_parent() as RigidBody2D


func _process(delta: float) -> void:
	global_rotation = 0.0
	global_position = _body.global_position + Vector2(0, _drop)
	var velocity := _body.linear_velocity
	_look = _look.lerp(velocity.limit_length(450.0) / 450.0, minf(1.0, 10.0 * delta))
	_scared = move_toward(_scared, 1.0 if velocity.y > 900.0 else 0.0, 4.0 * delta)

	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink = 0.12
		_next_blink = randf_range(2.0, 5.0)
	_blink = maxf(0.0, _blink - delta)
	queue_redraw()


## Sploštenie pri dopade. strength 0..1
func squash(strength: float) -> void:
	if _squash_tween:
		_squash_tween.kill()
	var amount := clampf(strength, 0.0, 1.0) * 0.35
	scale = Vector2(1.0 + amount, 1.0 - amount)
	_drop = RADIUS * amount
	_squash_tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_squash_tween.tween_property(self, "scale", Vector2.ONE, 0.45)
	_squash_tween.parallel().tween_property(self, "_drop", 0.0, 0.3)


## Natiahnutie pri výskoku.
func stretch() -> void:
	if _squash_tween:
		_squash_tween.kill()
	scale = Vector2(0.82, 1.18)
	_squash_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_squash_tween.tween_property(self, "scale", Vector2.ONE, 0.3)


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, OUTLINE)
	draw_circle(Vector2.ZERO, RADIUS - 3.0, BODY)
	# Oblúk, na ktorom vidno, ako sa gulička kotúľa.
	var roll := _body.rotation
	draw_arc(Vector2.ZERO, RADIUS - 9.0, roll, roll + 1.3, 12, STRIPE, 4.0, true)
	draw_arc(Vector2.ZERO, RADIUS - 9.0, roll + PI, roll + PI + 1.3, 12, STRIPE, 4.0, true)
	draw_circle(Vector2(-10, -12), 5.5, SHINE)

	var eye_open := 0.12 if _blink > 0.0 else 1.0
	var eye_size := 1.0 + _scared * 0.35
	var pupil_size := 1.0 - _scared * 0.4
	for side: float in [-1.0, 1.0]:
		var eye_pos := Vector2(side * 8.5, -5.0) + _look * 5.0
		_draw_oval(eye_pos, Vector2(6.0, 8.0 * eye_open) * eye_size, EYE)
		if eye_open > 0.5:
			_draw_oval(eye_pos + _look * 2.5 + Vector2(0, 1), Vector2(3.0, 4.0) * pupil_size, PUPIL)

	var mouth := Vector2(0, 9) + _look * 4.0
	if _scared > 0.5:
		_draw_oval(mouth, Vector2(4, 5), OUTLINE)
	else:
		draw_arc(mouth, 6.0, 0.25 * PI, 0.75 * PI, 8, OUTLINE, 2.5, true)


func _draw_oval(center: Vector2, radii: Vector2, color: Color) -> void:
	draw_set_transform(center, 0.0, Vector2(radii.x / radii.y, 1.0))
	draw_circle(Vector2.ZERO, radii.y, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
