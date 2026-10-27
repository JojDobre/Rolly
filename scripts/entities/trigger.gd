extends Area2D
## Checkpoint alebo cieľ (dvere, vlajka): pri dotyku hráča zavolá hru.

var kind := "checkpoint"  ## checkpoint, exit
var _done := false


func _ready() -> void:
	collision_layer = 1 << 4
	collision_mask = 1 << 2
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if _done or not body.is_in_group("player"):
		return
	var game = get_tree().get_first_node_in_group("game")
	if game == null:
		return
	_done = true
	var sprite = get_node("Sprite")
	if sprite is AnimatedSprite2D:
		sprite.play("up")
	if kind == "checkpoint":
		game.reach_checkpoint(global_position + Vector2(0, -40))
	else:
		game.reach_exit(self)
