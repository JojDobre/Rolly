extends Area2D
## Tlačidlo na zemi: keď naň stúpi hráč alebo krabica, prepne farebné bloky na pár sekúnd.

var color := "red"
var time := 5.0

var _sprite: Sprite2D
var _pressed_until := 0.0


func _ready() -> void:
	collision_layer = 1 << 4
	collision_mask = (1 << 2) | 1
	_sprite = get_node("Sprite")
	body_entered.connect(_on_body_entered)


func _process(_delta: float) -> void:
	if _pressed_until > 0.0 and Time.get_ticks_msec() / 1000.0 > _pressed_until:
		_pressed_until = 0.0
		_sprite.texture = load("res://assets/npp/tiles/switch_%s.png" % color)


func _on_body_entered(body: Node) -> void:
	if not (body.is_in_group("player") or body is RigidBody2D):
		return
	_sprite.texture = load("res://assets/npp/tiles/switch_%s_pressed.png" % color)
	_pressed_until = Time.get_ticks_msec() / 1000.0 + time
	GameState.play_sfx("impact/impactPlate_light_000", -4.0)
	var game = get_tree().get_first_node_in_group("game")
	if game:
		game.press_switch(color, time)
