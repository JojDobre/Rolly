extends CanvasLayer
## Pozadie z Kenney New Platformer Pack: nebo, pás oblakov a pás kopcov/stromov/púšte/húb.
## Vrstvy sa posúvajú pomalšie ako kamera (paralaxa), oblaky sa pomaly hýbu samy.

const TEX_SKY := preload("res://assets/npp/backgrounds/background_solid_sky.png")
const TEX_CLOUDS := preload("res://assets/npp/backgrounds/background_clouds.png")
const BAND := "res://assets/npp/backgrounds/background_fade_%s.png"
const DESIGN_HEIGHT := 720.0
const BAND_HEIGHT := 300.0  ## výška pásu oblakov a kopcov pri výške obrazovky 720
const CLOUDS_TOP := 60.0
const CLOUD_DRIFT := 10.0
const CLOUD_PARALLAX := 0.05
const HILLS_PARALLAX := 0.2

var camera: Camera2D  ## ak je prázdne, pozadie sa hýbe len samé (menu)
var style := "hills"  ## hills, trees, desert, mushrooms

var _sky: TextureRect
var _clouds: Sprite2D
var _hills: Sprite2D
var _time := 0.0


func _ready() -> void:
	layer = -10
	_sky = TextureRect.new()
	_sky.texture = TEX_SKY
	_sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sky.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(_sky)
	_clouds = _band(TEX_CLOUDS)
	_hills = _band(load(BAND % style))


func _band(texture: Texture2D) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.region_enabled = true
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_child(sprite)
	return sprite


func _process(delta: float) -> void:
	_time += delta
	var view := get_viewport().get_visible_rect().size
	var band := BAND_HEIGHT * view.y / DESIGN_HEIGHT
	var camera_x := camera.get_screen_center_position().x if camera else 0.0
	var top := CLOUDS_TOP * view.y / DESIGN_HEIGHT
	_place(_clouds, top, band, camera_x * CLOUD_PARALLAX + _time * CLOUD_DRIFT, view.x)
	_place(_hills, top + band, band, camera_x * HILLS_PARALLAX, view.x)


func _place(sprite: Sprite2D, y: float, height: float, scroll: float, width: float) -> void:
	var k := height / sprite.texture.get_height()
	sprite.scale = Vector2(k, k)
	sprite.position = Vector2(0, y)
	sprite.region_rect = Rect2(scroll / k, 0, width / k + 2.0, sprite.texture.get_height())
