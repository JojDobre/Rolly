extends CanvasLayer
## Pozadie v štýle Red Ball: nebo s prechodom, oblaky a dve vrstvy kopcov.
## Vrstvy sa posúvajú pomalšie ako kamera (paralaxa), oblaky sa pomaly hýbu samy.

const TEX_CLOUDS := preload("res://assets/world/clouds.png")
const TEX_HILLS_FAR := preload("res://assets/world/hills_far.png")
const TEX_HILLS_NEAR := preload("res://assets/world/hills_near.png")
const SKY_TOP := Color("78c8f0")
const SKY_BOTTOM := Color("d7f0fa")
const DESIGN_HEIGHT := 720.0
const CLOUD_DRIFT := 12.0

var camera: Camera2D  ## ak je prázdne, pozadie sa hýbe len samé (menu)

var _layers := []  # [Sprite2D, paralaxa, posun, oblaky?]
var _time := 0.0


func _ready() -> void:
	layer = -10
	var sky := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, SKY_TOP)
	gradient.set_color(1, SKY_BOTTOM)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	texture.width = 4
	texture.height = 256
	sky.texture = texture
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(sky)

	_add_layer(TEX_CLOUDS, 0.05, 30.0, true)
	_add_layer(TEX_HILLS_FAR, 0.15, 0.0, false)
	_add_layer(TEX_HILLS_NEAR, 0.35, -60.0, false)


## shift: pri oblakoch odstup od vrchu, pri kopcoch o koľko vytŕčajú nad spodok.
func _add_layer(texture: Texture2D, parallax: float, shift: float, is_clouds: bool) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.region_enabled = true
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_child(sprite)
	_layers.append([sprite, parallax, shift, is_clouds])


func _process(delta: float) -> void:
	_time += delta
	var view := get_viewport().get_visible_rect().size
	var k := view.y / DESIGN_HEIGHT
	var camera_x := camera.get_screen_center_position().x if camera else 0.0
	for entry in _layers:
		var sprite: Sprite2D = entry[0]
		var parallax: float = entry[1]
		var shift: float = entry[2]
		var is_clouds: bool = entry[3]
		var height := sprite.texture.get_height()
		sprite.scale = Vector2(k, k)
		var scroll := camera_x * parallax
		if is_clouds:
			scroll += _time * CLOUD_DRIFT
			sprite.position = Vector2(0, shift * k)
		else:
			sprite.position = Vector2(0, view.y - (height + shift) * k)
		sprite.region_rect = Rect2(scroll / k, 0, view.x / k + 2.0, height)
