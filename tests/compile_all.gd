extends SceneTree
## Načíta všetky skripty a scény projektu, aby Godot vypísal prípadné chyby kompilácie.

func _initialize() -> void:
	var count := _walk("res://scripts") + _walk("res://scenes")
	print("načítaných súborov: ", count)
	quit()


func _walk(dir: String) -> int:
	var count := 0
	var access := DirAccess.open(dir)
	for sub in access.get_directories():
		count += _walk(dir + "/" + sub)
	for file in access.get_files():
		if file.ends_with(".gd") or file.ends_with(".tscn"):
			var res = load(dir + "/" + file)
			if res == null:
				print("NEPODARILO SA: ", dir + "/" + file)
			count += 1
	return count
