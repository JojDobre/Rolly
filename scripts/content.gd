extends Node
## Úložisko svetov a levelov (autoload "Content").
##
## Každý svet je jeden JSON súbor so svojimi levelmi:
##   res://data/worlds/*.json  – svety dodávané s hrou
##   user://worlds/*.json      – svety vytvorené v editore na telefóne
## Keď hru spustíš z Godot editora na počítači, editor ukladá priamo do res://data/worlds,
## takže nové levely môžeš commitnúť do repa a budú súčasťou hry.

const BUILTIN_DIR := "res://data/worlds"
const USER_DIR := "user://worlds"
const FORMAT_VERSION := 1

var worlds: Array = []  # zoradené: vstavané, potom vlastné


func _ready() -> void:
	reload()


func reload() -> void:
	worlds.clear()
	for dir in [BUILTIN_DIR, USER_DIR]:
		for world in _read_dir(dir):
			world["_dir"] = dir
			worlds.append(world)
	worlds.sort_custom(_world_before)


func _world_before(a: Dictionary, b: Dictionary) -> bool:
	var a_custom: bool = a["_dir"] != BUILTIN_DIR
	var b_custom: bool = b["_dir"] != BUILTIN_DIR
	if a_custom != b_custom:
		return b_custom
	if a.get("order", 0) != b.get("order", 0):
		return a.get("order", 0) < b.get("order", 0)
	return String(a["name"]) < String(b["name"])


func get_world(world_id: String) -> Dictionary:
	for world in worlds:
		if world["id"] == world_id:
			return world
	return {}


func get_level(world_id: String, level_id: String) -> Dictionary:
	var world := get_world(world_id)
	for level in world.get("levels", []):
		if level["id"] == level_id:
			return level
	return {}


## Level, ktorý nasleduje po danom (alebo {}).
func next_level(world_id: String, level_id: String) -> Dictionary:
	var levels: Array = get_world(world_id).get("levels", [])
	for i in levels.size() - 1:
		if levels[i]["id"] == level_id:
			return levels[i + 1]
	return {}


func is_editable(world: Dictionary) -> bool:
	return world.get("_dir", USER_DIR) == USER_DIR or OS.has_feature("editor")


# --- Vytváranie -----------------------------------------------------------

func new_world(world_name: String, terrain: String, background: String, music: String) -> Dictionary:
	var world := {
		"version": FORMAT_VERSION,
		"id": "w%d" % Time.get_unix_time_from_system(),
		"name": world_name,
		"terrain": terrain,
		"background": background,
		"music": music,
		"order": 100,
		"levels": [],
		"_dir": BUILTIN_DIR if OS.has_feature("editor") else USER_DIR,
	}
	worlds.append(world)
	save_world(world)
	return world


## Nový level so zemou dole, štartom a cieľom, aby sa dal hneď skúsiť.
func new_level(world: Dictionary) -> Dictionary:
	var width := 40
	var height := 14
	var cells := {}
	for x in width:
		for y in [height - 2, height - 1]:
			cells["%d,%d" % [x, y]] = {"t": "ground"}
	cells["2,%d" % (height - 3)] = {"t": "start"}
	cells["%d,%d" % [width - 3, height - 3]] = {"t": "door_exit"}
	var level := {
		"id": "l%d" % Time.get_ticks_usec(),
		"name": "Level %d" % (world["levels"].size() + 1),
		"width": width,
		"height": height,
		"cells": cells,
	}
	world["levels"].append(level)
	return level


func delete_level(world: Dictionary, level_id: String) -> void:
	world["levels"] = world["levels"].filter(func(l): return l["id"] != level_id)
	save_world(world)


func delete_world(world: Dictionary) -> void:
	worlds.erase(world)
	var path := _path(world)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path if path.begins_with("user://") else ProjectSettings.globalize_path(path))


# --- Ukladanie ------------------------------------------------------------

func save_world(world: Dictionary) -> bool:
	var dir: String = world.get("_dir", USER_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var data := world.duplicate(true)
	data.erase("_dir")
	data["version"] = FORMAT_VERSION
	var file := FileAccess.open(_path(world), FileAccess.WRITE)
	if file == null:
		push_error("Svet sa nepodarilo uložiť: %s" % _path(world))
		return false
	file.store_string(JSON.stringify(data, "\t"))
	return true


func _path(world: Dictionary) -> String:
	return "%s/%s.json" % [world.get("_dir", USER_DIR), world["id"]]


func _read_dir(dir: String) -> Array:
	var result := []
	var access := DirAccess.open(dir)
	if access == null:
		return result
	for file_name in access.get_files():
		# Po exporte môžu mať súbory príponu .json.remap – tie preskočíme.
		if not file_name.ends_with(".json"):
			continue
		var text := FileAccess.get_file_as_string("%s/%s" % [dir, file_name])
		var data = JSON.parse_string(text)
		if data is Dictionary and data.has("id") and data.has("levels"):
			result.append(data)
		else:
			push_warning("Neplatný súbor sveta: %s/%s" % [dir, file_name])
	return result
