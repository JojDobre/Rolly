extends RefCounted
## Kontrola levelu: povinné prvky a páry (kľúč ↔ zámok, tlačidlo ↔ farebné bloky, páčka ↔ výťah...).
## Vracia zoznam problémov. Každý problém môže mať "need" – predmet, ktorý editor ponúkne položiť.

const Catalog := preload("res://scripts/catalog.gd")

## Parametre predmetov, ktoré sa dajú meniť v editore (v tomto poradí).
const EDITABLE := ["color", "content", "mob", "direction", "distance", "radius", "time", "height", "hits", "solid"]


## Vráti [{ "text": String, "need": id alebo "", "params": {} }]
static func check(level: Dictionary) -> Array:
	var problems := []
	var count := {}
	var lever_colors := {}
	var lift_colors := {}
	var cells: Dictionary = level.get("cells", {})
	for key in cells:
		var cell: Dictionary = cells[key]
		var id: String = cell.get("t", "")
		count[id] = count.get(id, 0) + 1
		if id == "lever":
			lever_colors[cell.get("color", "red")] = true
		elif id == "lift":
			lift_colors[cell.get("color", "red")] = true
		elif id == "door_exit":
			var pos := _pos(key)
			var above: Dictionary = cells.get("%d,%d" % [pos.x, pos.y - 1], {})
			if not above.is_empty():
				problems.append(_problem("Nad dverami musí byť voľné miesto (dvere sú 2 dlaždice vysoké)."))

	var starts: int = count.get("start", 0)
	if starts == 0:
		problems.append(_problem("Chýba štart.", "start"))
	elif starts > 1:
		problems.append(_problem("V leveli môže byť len jeden štart (teraz %d)." % starts))
	if count.get("door_exit", 0) + count.get("flag_exit", 0) == 0:
		problems.append(_problem("Chýba cieľ (dvere alebo vlajka).", "door_exit"))
	var stars: int = count.get("star", 0)
	if stars != 3:
		problems.append(_problem("Level musí mať presne 3 hviezdy (teraz %d)." % stars, "star" if stars < 3 else ""))

	for color in Catalog.COLORS:
		var cname: String = Catalog.COLOR_NAMES[color]
		var keys: int = count.get("key_" + color, 0)
		var locks: int = count.get("lock_" + color, 0)
		if keys > 0 and locks == 0:
			problems.append(_problem("Kľúč (%s) nemá žiadny zámok." % cname, "lock_" + color))
		if locks > 0 and keys == 0:
			problems.append(_problem("Zámok (%s) sa nedá odomknúť – chýba kľúč." % cname, "key_" + color))
		if keys > 1:
			problems.append(_problem("Kľúč (%s) je v leveli viackrát, stačí jeden." % cname))

		var switches: int = count.get("switch_" + color, 0)
		var blocks: int = count.get("block_" + color, 0)
		if switches > 0 and blocks == 0:
			problems.append(_problem("Tlačidlo (%s) nemá čo prepnúť – pridaj farebné bloky." % cname, "block_" + color))
		if blocks > 0 and switches == 0 and not lever_colors.has(color):
			problems.append(_problem("Farebné bloky (%s) nič neprepína – pridaj tlačidlo alebo páčku." % cname, "switch_" + color))

		if lever_colors.has(color) and blocks == 0 and not lift_colors.has(color):
			problems.append(_problem("Páčka (%s) nemá čo ovládať – pridaj výťah alebo farebné bloky." % cname, "lift", {"color": color}))
		if lift_colors.has(color) and not lever_colors.has(color):
			problems.append(_problem("Výťah (%s) nemá páčku." % cname, "lever", {"color": color}))
	return problems


## Krátka nápoveda po položení predmetu (čo k nemu treba pridať).
static func hint_for(id: String, params: Dictionary) -> String:
	var color: String = params.get("color", "")
	if color == "" and id.contains("_"):
		color = id.substr(id.rfind("_") + 1)
	var cname: String = Catalog.COLOR_NAMES.get(color, "")
	if id.begins_with("key_"):
		return "Teraz polož zámok (%s), ktorý kľúč odomkne." % cname
	if id.begins_with("lock_"):
		return "Teraz polož kľúč (%s)." % cname
	if id.begins_with("switch_"):
		return "Teraz polož farebné bloky (%s), ktoré tlačidlo prepne." % cname
	if id.begins_with("block_") and Catalog.COLORS.has(id.substr(6)):
		return "Bloky sa prepínajú tlačidlom alebo páčkou rovnakej farby."
	if id == "lever":
		return "Páčka (%s) ovláda výťahy a farebné bloky svojej farby." % cname
	if id == "lift":
		return "Výťah (%s) potrebuje páčku rovnakej farby." % cname
	if Catalog.get_item(id).get("kind", "") == "mob":
		return "Cestu moba nastavíš: Upraviť → ťukni na moba → Nastaviť cestu."
	if id == "door_exit":
		return "Dvere sú 2 dlaždice vysoké – nad nimi nechaj voľné miesto."
	return ""


static func _problem(text: String, need := "", params := {}) -> Dictionary:
	return {"text": text, "need": need, "params": params}


static func _pos(key: String) -> Vector2i:
	var parts := key.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))
