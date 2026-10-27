extends Area2D
## Predmet na zbieranie: minca, hviezda, srdce, drahokam, kľúč.
## Pri dotyku hráča ho hra započíta (game.collect).

var item_id := ""
var kind := ""  ## coin, star, powerup, key
var popped := false  ## vyskočil z bloku – chvíľu sa nedá zobrať

var _time := randf() * TAU
var _taken := false
var _sprite: Sprite2D


func _ready() -> void:
	collision_layer = 1 << 4
	collision_mask = 1 << 2
	_sprite = Sprite2D.new()
	_sprite.texture = load(preload("res://scripts/catalog.gd").icon_path(item_id))
	add_child(_sprite)
	var circle := CircleShape2D.new()
	circle.radius = 22.0
	var shape := CollisionShape2D.new()
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	if popped:
		monitoring = false
		var start := position
		var tween := create_tween()
		tween.tween_property(self, "position:y", start.y - 72.0, 0.25).set_ease(Tween.EASE_OUT)
		if kind == "coin":
			# Minca z bloku sa započíta hneď.
			tween.tween_callback(func(): _collect(get_tree().get_first_node_in_group("player")))
		else:
			tween.tween_property(self, "position:y", start.y - 64.0, 0.15)
			tween.tween_callback(func(): monitoring = true)


func _process(delta: float) -> void:
	if _taken or popped:
		return
	_time += delta
	_sprite.position.y = sin(_time * 2.6) * 4.0
	if kind == "coin":
		_sprite.scale.x = absf(cos(_time * 2.0)) * 0.6 + 0.4


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_collect(body)


func _collect(player: Node) -> void:
	if _taken or player == null:
		return
	_taken = true
	set_deferred("monitoring", false)
	var game = get_tree().get_first_node_in_group("game")
	if game:
		game.collect(item_id, kind, global_position)
	var tween := create_tween().set_parallel()
	tween.tween_property(_sprite, "position:y", _sprite.position.y - 30.0, 0.25)
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(queue_free)
