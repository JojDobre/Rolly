extends "res://scripts/entities/hazard.gd"
## Ohnivá guľa: vyskakuje do výšky "height" dlaždíc a padá späť (napr. z lávy).

var height := 3


func _ready() -> void:
	super._ready()
	var start := position
	var sprite: Sprite2D = get_node("Sprite")
	var tween := create_tween().set_loops()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_callback(func(): sprite.flip_v = false)
	tween.tween_property(self, "position:y", start.y - 64.0 * height, 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(func(): sprite.flip_v = true)
	tween.tween_property(self, "position:y", start.y, 0.7).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_interval(1.0)
