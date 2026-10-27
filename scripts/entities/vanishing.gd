extends StaticBody2D
## Miznúci most: chvíľu po stúpení zmizne a o pár sekúnd sa objaví znova.

var _busy := false


func _ready() -> void:
	var sensor: Area2D = get_node("Sensor")
	sensor.body_entered.connect(_on_sensor)


func _on_sensor(body: Node) -> void:
	if _busy or not body.is_in_group("player"):
		return
	_busy = true
	var sprite: CanvasItem = get_node("Sprite")
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.4, 0.5)
	tween.tween_callback(func(): _set_solid(false))
	tween.tween_property(sprite, "modulate:a", 0.0, 0.15)
	tween.tween_interval(3.0)
	tween.tween_callback(func(): _set_solid(true))
	tween.tween_property(sprite, "modulate:a", 1.0, 0.3)
	tween.tween_callback(func(): _busy = false)


func _set_solid(solid: bool) -> void:
	for shape in find_children("*", "CollisionShape2D", false, false):
		shape.set_deferred("disabled", not solid)
