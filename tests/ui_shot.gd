extends SceneTree
## Screenshot obrazovky menu alebo editora (potrebuje displej, napr. xvfb-run).
##   ... --script res://tests/ui_shot.gd -- <menu|svety|levely|editor_svety|editor_levely|novy_svet|editor> <súbor.png>

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var page: String = args[0]
	var gs = root.get_node("GameState")
	var content = root.get_node("Content")
	if page.begins_with("editor") and page != "editor_svety" and page != "editor_levely":
		gs.editor_world_id = "zelene_kopce"
		gs.editor_level_id = "l3"
		change_scene_to_file("res://scenes/editor.tscn")
	else:
		change_scene_to_file("res://scenes/menu.tscn")
	for i in 5:
		await process_frame
	var scene = current_scene
	var world = content.get_world("zelene_kopce")
	match page:
		"svety":
			scene.show_worlds()
		"levely":
			scene.show_levels(world)
		"editor_svety":
			scene.show_editor_worlds()
		"editor_levely":
			scene.show_editor_levels(world)
		"novy_svet":
			scene.show_world_form({})
		"editor_star":
			scene.camera.zoom = Vector2(2, 2)
			scene.camera.position = Vector2(9 * 64, 8 * 64)
		"editor":
			scene._select_item("key_red")
			scene._apply_tool(Vector2i(10, 9))
			scene._refresh_problems()
			scene._open_side(true)
	for i in 30:
		await process_frame
	root.get_texture().get_image().save_png(args[1])
	print("uložené ", args[1])
	quit()
