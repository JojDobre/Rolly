extends AnimatableBody2D
## Výťah: keď sa prepne páčka jeho farby, posunie sa hore alebo dole o "distance" dlaždíc.

var color := "red"
var direction := "up"
var distance := 3

var _start := Vector2.ZERO
var _tween: Tween


func _ready() -> void:
	_start = position
	add_to_group("channel_" + color)


func set_switched(switched: bool) -> void:
	var offset := Vector2(0, -64 * distance if direction == "up" else 64 * distance)
	var target := _start + offset if switched else _start
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.tween_property(self, "position", target, 0.6 * distance)
