extends Area2D
## Nebezpečný predmet (bodce, kaktus, hríb, píla, ohnivá guľa): zraňuje hráča, kým sa ho dotýka.

var spin := 0.0  ## otáčanie obrázka (píla)


func _ready() -> void:
	collision_layer = 1 << 4
	collision_mask = 1 << 2


func _physics_process(delta: float) -> void:
	if spin != 0.0:
		get_node("Sprite").rotation += spin * delta
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			body.hurt(global_position)
