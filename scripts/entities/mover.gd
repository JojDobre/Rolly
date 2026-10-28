extends AnimatableBody2D
## Pohyblivá plošina: plynulo jazdí tam a späť o "distance" dlaždíc (vodorovne alebo zvisle).

const SPEED := 110.0  ## px/s v strede dráhy

var vertical := false
var distance := 3

var _start := Vector2.ZERO
var _time := 0.0


func _ready() -> void:
	_start = position
	sync_to_physics = true


func _physics_process(delta: float) -> void:
	_time += delta
	var length := distance * 64.0
	var period := maxf(1.0, length * 2.0 / SPEED * 1.4)
	# 0 → 1 → 0 so spomalením na koncoch
	var phase := 0.5 - 0.5 * cos(TAU * _time / period)
	var offset := length * phase
	position = _start + (Vector2(0, -offset) if vertical else Vector2(offset, 0))
