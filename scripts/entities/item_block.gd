extends StaticBody2D
## Blok s otáznikom/výkričníkom/mincou: úder hlavou zospodu vyhodí obsah.

var item_id := ""
var content := "coin_gold"
var mob := "slime_normal"
var hits := 1

var _sprite: Sprite2D
var _active_texture: Texture2D


func _ready() -> void:
	_sprite = get_node("Sprite")
	var active_path := "res://assets/npp/tiles/%s_active.png" % item_id
	if ResourceLoader.exists(active_path):
		_active_texture = load(active_path)
	if not item_id.begins_with("block_strong"):
		add_to_group("bomb_breakable")


func hit_from_below(_player: Node) -> void:
	var tween := create_tween()
	tween.tween_property(_sprite, "position:y", -10.0, 0.07)
	tween.tween_property(_sprite, "position:y", 0.0, 0.1)
	if hits <= 0:
		GameState.play_sfx("impact/impactPlank_medium_000", -6.0)
		return
	hits -= 1
	var game = get_tree().get_first_node_in_group("game")
	if game:
		if content == "mob":
			game.spawn_mob(mob, global_position + Vector2(0, -64))
		else:
			game.spawn_pickup(content, global_position, true)
	GameState.play_sfx("impact/impactGlass_light_001", -2.0, 1.3)
	if hits <= 0 and _active_texture:
		_sprite.texture = _active_texture


func explode() -> void:
	var game = get_tree().get_first_node_in_group("game")
	if game:
		game.break_effect(global_position, "brickBrown")
	queue_free()
