extends StaticBody2D
## Rozbitná tehla: rozbije sa úderom hlavy zospodu alebo bombou.

var particle := "brickBrown"


func _ready() -> void:
	add_to_group("bomb_breakable")


func hit_from_below(_player: Node) -> void:
	explode()


func explode() -> void:
	var game = get_tree().get_first_node_in_group("game")
	if game:
		game.break_effect(global_position, particle)
	GameState.play_sfx("impact/impactMining_000", -2.0)
	queue_free()
