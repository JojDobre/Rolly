extends Area2D
## Predmet na zbieranie (hviezda alebo kľúč). Pri dotyku guličky zahrá efekt a zmizne.

signal collected

@export var texture: Texture2D
@export var sprite_scale := 0.75
@export var sound := "impactGlass_light_000"
@export var bob_height := 6.0
@export var particle_color := Color("ffd23f")

var _taken := false
var _time := randf() * TAU

@onready var _sprite := Sprite2D.new()


func _ready() -> void:
	_sprite.texture = texture
	_sprite.scale = Vector2.ONE * sprite_scale
	add_child(_sprite)
	var circle := CircleShape2D.new()
	circle.radius = 24.0
	var shape := CollisionShape2D.new()
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _taken:
		return
	_time += delta
	_sprite.position.y = sin(_time * 2.5) * bob_height
	_sprite.rotation = sin(_time * 1.7) * 0.12


func _on_body_entered(body: Node) -> void:
	if _taken or not body.is_in_group("player"):
		return
	_taken = true
	set_deferred("monitoring", false)
	GameState.play_sfx(sound, -2.0, randf_range(1.1, 1.3))
	Input.vibrate_handheld(25)
	_burst()
	var tween := create_tween().set_parallel()
	tween.tween_property(_sprite, "scale", _sprite.scale * 1.8, 0.25).set_ease(Tween.EASE_OUT)
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(queue_free)
	collected.emit()


func _burst() -> void:
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.emitting = false
	particles.amount = 14
	particles.lifetime = 0.5
	particles.explosiveness = 1.0
	particles.spread = 180.0
	particles.gravity = Vector2(0, 400)
	particles.initial_velocity_min = 120.0
	particles.initial_velocity_max = 260.0
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 6.0
	particles.color = particle_color
	add_child(particles)
	particles.emitting = true
