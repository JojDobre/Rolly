extends SceneTree
## Urobí screenshot levelu (potrebuje displej, napr. xvfb-run).
##   xvfb-run godot --path . --script res://tests/screenshot.gd -- <svet> <level> <súbor.png> [x_dlaždica] [sekundy]

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var gs = root.get_node("GameState")
	gs.current_world_id = args[0]
	gs.current_level_id = args[1]
	if args[0] == "katalog":
		_catalog_level(gs, args[1])
	change_scene_to_file("res://scenes/game.tscn")
	await process_frame
	await process_frame
	var game = current_scene
	if args.size() > 3:
		game.player.global_position.x = float(args[3]) * 64.0 + 32.0
	var wait := float(args[4]) if args.size() > 4 else 1.5
	for i in int(wait * 60):
		await process_frame
	var image := root.get_texture().get_image()
	image.save_png(args[2])
	print("uložené: ", args[2], " ", image.get_size())
	quit()


## Testovací level so všetkými predmetmi jednej kategórie vedľa seba.
func _catalog_level(gs, category: String) -> void:
	var Catalog = load("res://scripts/catalog.gd")
	var cells := {}
	var x := 2
	for id in Catalog.in_category(category):
		cells["%d,7" % x] = {"t": id}
		x += 2
	for xx in x + 2:
		cells["%d,10" % xx] = {"t": "ground"}
		cells["%d,11" % xx] = {"t": "ground"}
	cells["0,9"] = {"t": "start"}
	gs.test_world = {"id": "t", "name": "t", "terrain": "grass", "background": "hills", "music": "", "levels": []}
	gs.test_level = {"id": "t", "name": category, "width": x + 2, "height": 12, "cells": cells}
