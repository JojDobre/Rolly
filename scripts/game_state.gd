extends Node
## Globálny stav hry (autoload "GameState"): životy, najlepšie hviezdy, ukladanie, zvuky.

signal lives_changed(lives: int)

const MAX_LIVES := 10
const LIFE_REGEN_SECONDS := 30 * 60
const SAVE_PATH := "user://save.cfg"
const LEVEL_COUNT := 3

var lives := MAX_LIVES
var best_stars := {}  # číslo levelu -> najviac zozbieraných hviezd (0 – 3)
var current_level := 1

## Unix čas, od ktorého sa odpočítava ďalší život. Platí len keď lives < MAX_LIVES.
var _regen_start := 0
var _sfx_cache := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_load()
	_update_regen()
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_update_regen)
	add_child(timer)


# --- Životy ---------------------------------------------------------------

func lose_life() -> void:
	if lives <= 0:
		return
	if lives == MAX_LIVES:
		_regen_start = _now()
	lives -= 1
	_save()
	lives_changed.emit(lives)


func add_life() -> void:
	lives = mini(MAX_LIVES, lives + 1)
	_save()
	lives_changed.emit(lives)


## Koľko sekúnd zostáva do ďalšieho života (0 = životy sú plné).
func seconds_to_next_life() -> int:
	if lives >= MAX_LIVES:
		return 0
	return maxi(0, LIFE_REGEN_SECONDS - (_now() - _regen_start))


func _update_regen() -> void:
	if lives >= MAX_LIVES:
		return
	var gained := floori(float(_now() - _regen_start) / LIFE_REGEN_SECONDS)
	if gained <= 0:
		return
	lives = mini(MAX_LIVES, lives + gained)
	_regen_start += gained * LIFE_REGEN_SECONDS
	_save()
	lives_changed.emit(lives)


static func format_time(seconds: int) -> String:
	return "%d:%02d" % [seconds / 60, seconds % 60]


# --- Levely ---------------------------------------------------------------

func record_stars(level: int, stars: int) -> void:
	best_stars[level] = maxi(stars, int(best_stars.get(level, 0)))
	_save()


func is_unlocked(level: int) -> bool:
	return level == 1 or best_stars.has(level - 1)


func has_level(level: int) -> bool:
	return level >= 1 and level <= LEVEL_COUNT


# --- Reklamy (zatiaľ len atrapa) -----------------------------------------

## Reklama, ktorú si hráč spustí sám (napr. +1 život).
## TODO: napojiť na AdMob. Zatiaľ odmenu dá hneď.
func show_rewarded_ad(on_reward: Callable) -> void:
	print("[reklama] tu sa zobrazí reklama s odmenou")
	on_reward.call()


## Reklama po dokončení levelu, ktorá sa dá hneď zavrieť.
## TODO: napojiť na AdMob a zobrazovať napríklad každý 3. level.
func maybe_show_interstitial() -> void:
	pass


# --- Zvuky ----------------------------------------------------------------

func play_sfx(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not _sfx_cache.has(sound):
		_sfx_cache[sound] = load("res://assets/sfx/%s.ogg" % sound)
	var player := AudioStreamPlayer.new()
	player.stream = _sfx_cache[sound]
	player.volume_db = volume_db
	player.pitch_scale = pitch
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


# --- Ovládanie ------------------------------------------------------------

func _setup_input() -> void:
	_add_action("move_left", [KEY_LEFT, KEY_A])
	_add_action("move_right", [KEY_RIGHT, KEY_D])
	_add_action("jump", [KEY_SPACE, KEY_UP, KEY_W])
	_add_action("pause", [KEY_ESCAPE, KEY_P])


func _add_action(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)


# --- Ukladanie ------------------------------------------------------------

func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("player", "lives", lives)
	config.set_value("player", "regen_start", _regen_start)
	config.set_value("player", "best_stars", best_stars)
	config.save(SAVE_PATH)


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	lives = config.get_value("player", "lives", MAX_LIVES)
	_regen_start = config.get_value("player", "regen_start", _now())
	best_stars = config.get_value("player", "best_stars", {})


func _now() -> int:
	return int(Time.get_unix_time_from_system())
