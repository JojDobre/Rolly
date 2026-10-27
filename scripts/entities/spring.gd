extends Area2D
## Pružina: hráč, ktorý na ňu dopadne, vyletí vysoko.

const LAUNCH := 1050.0

var _sprite: Sprite2D


func _ready() -> void:
	collision_layer = 1 << 4
	collision_mask = 1 << 2
	_sprite = get_node("Sprite")
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player") or body.velocity.y < -50.0:
		return
	body.bounce(LAUNCH)
	_sprite.texture = load("res://assets/npp/tiles/spring_out.png")
	GameState.play_sfx("impact/impactMetal_light_000", -2.0, 1.3)
	get_tree().create_timer(0.35).timeout.connect(func(): _sprite.texture = load("res://assets/npp/tiles/spring.png"))
