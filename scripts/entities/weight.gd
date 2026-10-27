extends AnimatableBody2D
## Závažie: visí, kým hráč nepríde pod neho. Potom spadne, chvíľu leží a vráti sa hore.

var _start := Vector2.ZERO
var _busy := false


func _ready() -> void:
	_start = position
	sync_to_physics = false


func _physics_process(_delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if _busy or player == null or player.dead:
		return
	var dx := absf(player.global_position.x - global_position.x)
	var dy: float = player.global_position.y - global_position.y
	if dx < 48.0 and dy > 0.0 and dy < 64.0 * 8:
		_drop()


func _drop() -> void:
	_busy = true
	var floor_y := _find_floor()
	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(self, "position:y", floor_y, 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(func(): GameState.play_sfx("impact/impactMetal_heavy_000", -2.0))
	tween.tween_interval(1.0)
	tween.tween_property(self, "position:y", _start.y, 1.5)
	tween.tween_callback(func(): _busy = false)


func _find_floor() -> float:
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, 33), global_position + Vector2(0, 64 * 12), 1)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return _start.y + 64 * 6
	return position.y + (hit["position"].y - global_position.y) - 32.0
