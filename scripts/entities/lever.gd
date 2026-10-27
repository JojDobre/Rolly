extends Area2D
## Páčka: hráč pri nej stlačí šípku hore a natrvalo prepne farebné bloky a výťahy svojej farby.

var color := "red"
var on := false

var _sprite: Sprite2D
var _player_near := false


func _ready() -> void:
	collision_layer = 1 << 4
	collision_mask = 1 << 2
	_sprite = get_node("Sprite")
	body_entered.connect(_on_body.bind(true))
	body_exited.connect(_on_body.bind(false))


func _on_body(body: Node, near: bool) -> void:
	if body.is_in_group("player"):
		_player_near = near


func _process(_delta: float) -> void:
	if _player_near and Input.is_action_just_pressed("move_up"):
		toggle()


func toggle() -> void:
	on = not on
	_sprite.texture = load("res://assets/npp/tiles/%s.png" % ("lever_right" if on else "lever_left"))
	GameState.play_sfx("impact/impactMetal_medium_000", -4.0)
	var game = get_tree().get_first_node_in_group("game")
	if game:
		game.toggle_lever(color)
