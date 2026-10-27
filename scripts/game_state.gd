extends Node
## Globálny stav hry (autoload "GameState"): životy, mince, najlepšie hviezdy,
## vybraná postavička, ukladanie, hudba a zvuky.

signal lives_changed(lives: int)
signal coins_changed(coins: int)

const MAX_LIVES := 10
const LIFE_REGEN_SECONDS := 30 * 60
const SAVE_PATH := "user://save.cfg"
const COINS_PER_LIFE := 100

## Krátke melódie z Kenney Music Jingles (assets/sfx/jingles). Vypočuj si ich a vymeň podľa chuti.
const JINGLE_COMPLETE := "jingles/jingles_PIZZI07"
const JINGLE_CHECKPOINT := "jingles/jingles_PIZZI01"
const JINGLE_KEY := "jingles/jingles_PIZZI03"
const JINGLE_DEATH := "jingles/jingles_PIZZI16"
const JINGLE_NO_LIVES := "jingles/jingles_PIZZI12"

## Hudba na pozadí (assets/music). Skladby sa striedajú v náhodnom poradí.
const MENU_PLAYLIST := ["musicbox2_cute_tune"]
const LEVEL_PLAYLIST := ["happy_clappy", "other_center", "swinging_sweet", "just_saying_tho", "musicbox4_happy_polka"]
## Názvy skladieb pre výber hudby sveta v editore ("" = všetky striedavo).
const TRACK_NAMES := {
	"": "Všetky striedavo",
	"happy_clappy": "Happy Clappy",
	"other_center": "Other Center",
	"swinging_sweet": "Swinging Sweet",
	"just_saying_tho": "Just Saying Tho",
	"musicbox4_happy_polka": "Happy Polka",
	"musicbox2_cute_tune": "Cute Tune",
}
const TRACK_MIN_SECONDS := 90.0  ## krátka slučka sa opakuje, kým neuplynie tento čas
const MUSIC_DB := -9.0
const SILENT_DB := -40.0

var lives := MAX_LIVES
var coins := 0
var best_stars := {}  # "svet/level" -> najviac zozbieraných hviezd (0 – 3)
var character := "red_circle"
var current_world_id := ""
var current_level_id := ""

## Testovanie z editora: level a svet, ktorý sa práve skúša (inak prázdne).
var test_level := {}
var test_world := {}
## Editor si sem odloží, čo práve upravuje, aby sa po teste vrátil na to isté miesto.
var editor_world_id := ""
var editor_level_id := ""
var editor_draft := {}

## Unix čas, od ktorého sa odpočítava ďalší život. Platí len keď lives < MAX_LIVES.
var _regen_start := 0
var _sfx_cache := {}
var music_enabled := true
var _music: AudioStreamPlayer
var _playlist: Array = []
var _track_index := 0
var _track_time := 0.0
var _switching := false
var _fade: Tween


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
	_music = AudioStreamPlayer.new()
	_music.volume_db = SILENT_DB
	add_child(_music)


func _process(delta: float) -> void:
	if not _music.playing or _switching or _playlist.size() < 2:
		return
	_track_time += delta
	if _track_time >= maxf(TRACK_MIN_SECONDS, _music.stream.get_length()):
		_switching = true
		var tween := create_tween()
		tween.tween_property(_music, "volume_db", SILENT_DB, 1.5)
		tween.tween_callback(func():
			_track_index = (_track_index + 1) % _playlist.size()
			_start_track())


# --- Hudba ----------------------------------------------------------------

func play_music(playlist: Array) -> void:
	if playlist == _playlist and _music.playing:
		return
	_playlist = playlist
	_track_index = randi() % playlist.size()
	_start_track()


func stop_music() -> void:
	_playlist = []
	_fade = create_tween()
	_fade.tween_property(_music, "volume_db", SILENT_DB, 0.6)
	_fade.tween_callback(_music.stop)


func set_music_enabled(on: bool) -> void:
	music_enabled = on
	_save()
	if on:
		_start_track()
	else:
		_music.stop()


func _start_track() -> void:
	if _fade:
		_fade.kill()
	_switching = false
	_track_time = 0.0
	if not music_enabled or _playlist.is_empty():
		_music.stop()
		return
	var stream: AudioStreamOggVorbis = load("res://assets/music/%s.ogg" % _playlist[_track_index])
	stream.loop = true
	_music.stream = stream
	_music.volume_db = SILENT_DB
	_music.play()
	_fade = create_tween()
	_fade.tween_property(_music, "volume_db", MUSIC_DB, 1.5)


func play_jingle(jingle: String) -> void:
	play_sfx(jingle, -2.0)


func playlist_for(world: Dictionary) -> Array:
	var track: String = world.get("music", "")
	return [track] if track != "" else LEVEL_PLAYLIST


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


func add_coins(amount: int) -> void:
	var before := coins / COINS_PER_LIFE
	coins += amount
	if coins / COINS_PER_LIFE > before:
		add_life()
		play_jingle(JINGLE_CHECKPOINT)
	_save()
	coins_changed.emit(coins)


static func format_time(seconds: int) -> String:
	return "%d:%02d" % [seconds / 60, seconds % 60]


# --- Levely ---------------------------------------------------------------

func record_stars(world_id: String, level_id: String, stars: int) -> void:
	var key := world_id + "/" + level_id
	best_stars[key] = maxi(stars, int(best_stars.get(key, 0)))
	_save()


func stars_for(world_id: String, level_id: String) -> int:
	return int(best_stars.get(world_id + "/" + level_id, 0))


func is_completed(world_id: String, level_id: String) -> bool:
	return best_stars.has(world_id + "/" + level_id)


## Level je odomknutý, ak je prvý vo svete alebo je predchádzajúci dokončený.
func is_unlocked(world: Dictionary, index: int) -> bool:
	if index == 0:
		return true
	var previous: Dictionary = world["levels"][index - 1]
	return is_completed(world["id"], previous["id"])


func set_character(color: String) -> void:
	character = color
	_save()


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
	_add_action("move_up", [KEY_UP, KEY_W])
	_add_action("move_down", [KEY_DOWN, KEY_S])
	_add_action("jump", [KEY_SPACE, KEY_Z, KEY_J])
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
	config.set_value("player", "coins", coins)
	config.set_value("player", "character", character)
	config.set_value("settings", "music", music_enabled)
	config.save(SAVE_PATH)


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	lives = config.get_value("player", "lives", MAX_LIVES)
	_regen_start = config.get_value("player", "regen_start", _now())
	best_stars = config.get_value("player", "best_stars", {})
	coins = config.get_value("player", "coins", 0)
	character = config.get_value("player", "character", "red_circle")
	if not String(character).contains("_"):
		character = "red_circle"
	# Staré uloženie (číslo levelu namiesto "svet/level") nepoužijeme.
	for key in best_stars.keys():
		if not String(str(key)).contains("/"):
			best_stars.erase(key)
	music_enabled = config.get_value("settings", "music", true)


func _now() -> int:
	return int(Time.get_unix_time_from_system())
