extends AnimatableBody2D
## Padajúci blok: keď naň hráč stúpi, zatrasie sa, spadne a po chvíli sa vráti.

var _start := Vector2.ZERO
var _busy := false


func _ready() -> void:
	_start = position
	add_to_group("bomb_breakable")
	var sensor: Area2D = get_node("Sensor")
	sensor.body_entered.connect(_on_sensor)


func _on_sensor(body: Node) -> void:
	if _busy or not body.is_in_group("player"):
		return
	_busy = true
	var sprite: Node2D = get_node("Sprite")
	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	for i in 4:
		tween.tween_property(sprite, "position:x", 3.0, 0.05)
		tween.tween_property(sprite, "position:x", -3.0, 0.05)
	tween.tween_property(sprite, "position:x", 0.0, 0.05)
	tween.tween_property(self, "position:y", _start.y + 900.0, 1.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(func(): visible = false)
	tween.tween_interval(2.5)
	tween.tween_callback(_reset)


func _reset() -> void:
	position = _start
	visible = true
	_busy = false


func explode() -> void:
	var game = get_tree().get_first_node_in_group("game")
	if game:
		game.break_effect(global_position, "brickGrey")
	queue_free()
