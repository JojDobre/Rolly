extends SceneTree
## Spustí level v hre bez okna a vypíše stav. Použitie:
##   godot --headless --path . --script res://tests/smoke.gd -- <svet> <level> [sekundy]

var _frames := 0
var _limit := 180
var _game


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var gs = root.get_node("GameState")
	gs.current_world_id = args[0] if args.size() > 0 else "zelene_kopce"
	gs.current_level_id = args[1] if args.size() > 1 else "l1"
	_limit = int(float(args[2]) * 60) if args.size() > 2 else 180
	change_scene_to_file("res://scenes/game.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	if _game == null:
		_game = current_scene
	if _frames == _limit:
		var p = _game.player
		print("hráč: pozícia=", p.global_position, " na zemi=", p.is_on_floor(), " zdravie=", p.health, " mŕtvy=", p.dead)
		print("mobov: ", get_nodes_in_group("enemy").size(), " hviezd: ", _game.stars_total)
		return true
	return false
