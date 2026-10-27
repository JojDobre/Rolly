extends Area2D
## Bomba: po dotyku hráča sa zapáli, bliká a po 2 s vybuchne.
## Výbuch zničí moby, tehly, krabice a zraní hráča v okruhu "radius" dlaždíc.

var radius := 2
var _lit := false


func _ready() -> void:
	collision_layer = 1 << 4
	collision_mask = 1 << 2
	body_entered.connect(_on_body_entered)
	add_to_group("bomb")


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		ignite()


func ignite(fuse := 2.0) -> void:
	if _lit:
		return
	_lit = true
	var sprite: Sprite2D = get_node("Sprite")
	sprite.texture = load("res://assets/npp/tiles/bomb_active.png")
	GameState.play_sfx("impact/impactTin_medium_000", -6.0)
	var tween := create_tween().set_loops(int(fuse / 0.2))
	tween.tween_property(sprite, "modulate", Color(1, 0.4, 0.4), 0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	get_tree().create_timer(fuse).timeout.connect(_explode)


func _explode() -> void:
	var game = get_tree().get_first_node_in_group("game")
	if game:
		game.explode(global_position, radius)
	queue_free()
