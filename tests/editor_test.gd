extends SceneTree
## Test editora: svet → level → kľúč a zámok cez nápovedu → uloženie → skúšanie → návrat.
##   godot --headless --path . --script res://tests/editor_test.gd

var failures := 0
var passed := 0


func _initialize() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail := "") -> void:
	if ok:
		passed += 1
		print("  OK   ", name)
	else:
		failures += 1
		print("  CHYBA ", name, "  ", detail)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var content = root.get_node("Content")
	var gs = root.get_node("GameState")
	var Validator = load("res://scripts/level_validator.gd")

	var world: Dictionary = content.new_world("Test svet", "snow", "trees", "")
	var level: Dictionary = content.new_level(world)
	content.save_world(world)
	check("nový svet má štýl snehu", world["terrain"] == "snow")
	var problems: Array = Validator.check(level)
	check("nový level hlási chýbajúce hviezdy", problems.any(func(p): return p["text"].contains("hviezdy")))

	gs.editor_world_id = world["id"]
	gs.editor_level_id = level["id"]
	change_scene_to_file("res://scenes/editor.tscn")
	await _frames(5)
	var editor = current_scene
	check("editor sa otvoril", editor != null and editor.has_method("save"))

	editor._select_item("key_blue")
	editor._apply_tool(Vector2i(8, 11))
	problems = Validator.check(editor.level)
	var lock_problem = problems.filter(func(p): return p["need"] == "lock_blue")
	check("po kľúči editor žiada modrý zámok", lock_problem.size() == 1, str(problems))
	editor._select_item(lock_problem[0]["need"], lock_problem[0]["params"])
	editor._apply_tool(Vector2i(12, 11))
	problems = Validator.check(editor.level)
	check("po zámku je pár kompletný", not problems.any(func(p): return p["text"].contains("Kľúč") or p["text"].contains("Zámok")))

	editor._select_item("lever")
	editor.tool_params["color"] = "green"
	editor._apply_tool(Vector2i(5, 11))
	problems = Validator.check(editor.level)
	var lift_need = problems.filter(func(p): return p["need"] == "lift")
	check("páčka bez výťahu ponúkne zelený výťah", lift_need.size() == 1 and lift_need[0]["params"].get("color") == "green", str(problems))
	editor._select_item("lift", lift_need[0]["params"])
	check("výťah prevzal zelenú farbu", editor.tool_params.get("color") == "green")
	editor._apply_tool(Vector2i(15, 10))

	editor._select_item("slime_normal")
	editor._apply_tool(Vector2i(20, 11))
	editor._set_tool("edit")
	editor._apply_tool(Vector2i(20, 11))
	check("mob ponúka nastavenie cesty", editor._has_path_option("slime_normal"))
	editor.tool = "path"
	editor._apply_tool(Vector2i(17, 11))
	editor._apply_tool(Vector2i(25, 11))
	check("cesta moba sa uložila do bunky", editor.level["cells"]["20,11"].get("path") == [17, 11, 25, 11], str(editor.level["cells"]["20,11"]))
	check("po zadaní cesty je nástroj znova Upraviť", editor.tool == "edit")
	editor._set_tool("paint")

	for x in [3, 4, 6]:
		editor._select_item("star")
		editor._apply_tool(Vector2i(x, 9))
	problems = Validator.check(editor.level)
	check("level je kompletný", problems.is_empty(), str(problems))

	editor._name_edit.text = "Testovací level"
	editor.save()
	content.reload()
	var saved: Dictionary = content.get_level(world["id"], level["id"])
	check("uložený level má názov", saved.get("name") == "Testovací level")
	check("uložený level nie je rozpracovaný", saved.get("draft") == false)
	check("uložený level obsahuje zámok", saved["cells"].values().any(func(c): return c["t"] == "lock_blue"))

	editor.resize(8, 2)
	check("zmena veľkosti", int(editor.level["width"]) == 48 and int(editor.level["height"]) == 16)
	editor.undo()
	check("krok späť vráti bunky", editor.level["cells"].size() == saved["cells"].size())

	editor.test_level()
	await _frames(10)
	var game = current_scene
	check("skúšanie spustí hru v testovacom režime", game.has_method("collect") and game.test_mode)
	game.go_to_menu()
	await _frames(10)
	check("návrat z hry otvorí editor", current_scene.has_method("save"))
	check("editor si pamätá rozpracovaný level", current_scene.level["cells"].size() > 0)

	content.delete_world(world)
	content.reload()
	check("svet sa zmazal", content.get_world(world["id"]).is_empty())
	print("\nVÝSLEDOK: %d testov prešlo, %d zlyhalo" % [passed, failures])
	quit(1 if failures > 0 else 0)
