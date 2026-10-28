extends Area2D
## Prechodové dvere: hráč pri nich stlačí hore a prejde k druhým dverám rovnakej farby.

const ARROW := preload("res://assets/controls/icons/icon_arrow.png")
const T_HALF := 32.0

var kind := "warp"
var color := "red"

var _player: Node2D
var _arrow: Sprite2D
var _time := 0.0


func _ready() -> void:
	collision_layer = 1 << 4
	collision_mask = 1 << 2
	add_to_group("warp_" + color)
	body_entered.connect(func(body: Node): if body.is_in_group("player"): _player = body)
	body_exited.connect(func(body: Node): if body == _player: _player = null)
	_arrow = Sprite2D.new()
	_arrow.texture = ARROW
	_arrow.rotation = -PI / 2.0
	_arrow.scale = Vector2(0.45, 0.45)
	_arrow.position = Vector2(0, -T_HALF * 4.4)
	_arrow.visible = false
	add_child(_arrow)



func _process(delta: float) -> void:
	_time += delta
	var near: bool = _player != null and not _player.dead and _player.input_enabled
	_arrow.visible = near
	if near:
		_arrow.position.y = -T_HALF * 4.4 + sin(_time * 6.0) * 5.0
		if Input.is_action_just_pressed("move_up"):
			var game = get_tree().get_first_node_in_group("game")
			if game:
				game.warp(self)


## Druhé dvere rovnakej farby.
func partner() -> Node2D:
	for door in get_tree().get_nodes_in_group("warp_" + color):
		if door != self:
			return door
	return null


## Krátko otvorí dvere (pri vstupe aj výstupe).
func flash_open() -> void:
	for sprite_name in ["Sprite", "Top"]:
		var sprite: AnimatedSprite2D = get_node(sprite_name)
		sprite.play("up")
	get_tree().create_timer(0.6).timeout.connect(func():
		for sprite_name in ["Sprite", "Top"]:
			var sprite: AnimatedSprite2D = get_node(sprite_name)
			sprite.play("down"))
