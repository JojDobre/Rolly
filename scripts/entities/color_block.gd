extends StaticBody2D
## Farebný blok. Tlačidlo (na chvíľu) alebo páčka (natrvalo) rovnakej farby ho prepne:
## pevný blok sa stane priehľadným a priechodným a naopak.

var color := "red"
var solid_by_default := true


func _ready() -> void:
	add_to_group("channel_" + color)
	set_switched(false)


func set_switched(switched: bool) -> void:
	var solid := solid_by_default != switched
	for shape in find_children("*", "CollisionShape2D", false, false):
		shape.set_deferred("disabled", not solid)
	get_node("Sprite").modulate.a = 1.0 if solid else 0.3
