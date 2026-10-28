extends Node2D
## Tajná stena: vyzerá ako zem, ale dá sa cez ňu prejsť. Keď je v nej hráč, spriehľadní sa.

const HIDDEN_ALPHA := 0.35

var _inside := 0
var _tween: Tween


func _ready() -> void:
	var area: Area2D = get_child(0)
	area.body_entered.connect(func(body: Node): _change(body, 1))
	area.body_exited.connect(func(body: Node): _change(body, -1))


func _change(body: Node, step: int) -> void:
	if not body.is_in_group("player"):
		return
	var was_inside := _inside > 0
	_inside = maxi(0, _inside + step)
	if was_inside == (_inside > 0):
		return
	if _inside > 0 and not was_inside:
		GameState.play_sfx("impact/impactSoft_heavy_001", -10.0, 1.6)
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", HIDDEN_ALPHA if _inside > 0 else 1.0, 0.25)
