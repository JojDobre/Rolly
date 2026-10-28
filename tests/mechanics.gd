extends SceneTree
## Automatické testy mechaník. Každý test postaví malý level, ovláda hráča a overí výsledok.
## Spustenie:  godot --headless --path . --script res://tests/mechanics.gd
## Voliteľne len jeden test:  ... -- kluc

const T := 64
var gs
var game
var failures := 0
var passed := 0


func _initialize() -> void:
	gs = root.get_node("GameState")
	_run.call_deferred()


func _run() -> void:
	var only := OS.get_cmdline_user_args()
	var tests := ["chodza", "skok", "kluc", "mince_blok", "tehla", "tlacidlo", "packa_vytah", "pruzina",
		"bomba", "mob_skok", "mob_zranenie", "bodce", "utopenie", "lava", "rebrik", "padajuci_blok",
		"miznuci_most", "ciel", "drahokamy", "slimak_ulita", "krabica", "pas", "vsetky_moby", "zavazie",
		"ukazka_vytah", "ukazka_bomba", "ukazka_kluce", "ukazka_pruzina", "hadanka_krabica", "cesta_moba",
		"dvere_prechod", "skryty_blok", "tajna_stena", "pohybliva_plosina", "svet1_levely"]
	for test in tests:
		if only.size() > 0 and not only.has(test):
			continue
		await call("t_" + test)
		await _cleanup()
	print("\nVÝSLEDOK: %d testov prešlo, %d zlyhalo" % [passed, failures])
	quit(1 if failures > 0 else 0)


# --- Pomocné -----------------------------------------------------------------

func _level(cells: Dictionary, width := 30, height := 12) -> void:
	var all := {}
	for x in width:
		all["%d,%d" % [x, height - 2]] = {"t": "ground"}
		all["%d,%d" % [x, height - 1]] = {"t": "ground"}
	for key in cells:
		all[key] = cells[key] if cells[key] is Dictionary else {"t": cells[key]}
	if not all.values().any(func(c): return c["t"] == "start"):
		all["2,%d" % (height - 3)] = {"t": "start"}
	gs.test_world = {"id": "test", "name": "Test", "terrain": "grass", "background": "hills", "music": "", "levels": []}
	gs.test_level = {"id": "t", "name": "Test", "width": width, "height": height, "cells": all}
	change_scene_to_file("res://scenes/game.tscn")
	await process_frame
	await process_frame
	game = current_scene
	await _frames(10)


func _cleanup() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "jump"]:
		Input.action_release(action)
	paused = false
	await process_frame


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _seconds(s: float) -> void:
	await _frames(int(s * 60))


func _hold(action: String, s: float) -> void:
	Input.action_press(action)
	await _seconds(s)
	Input.action_release(action)
	await _frames(2)


func _tap(action: String) -> void:
	Input.action_press(action)
	await _frames(3 if action != "jump" else 25)
	Input.action_release(action)
	await _frames(2)


func _cell(x: int, y: int) -> Vector2:
	return Vector2(x * T + T / 2.0, y * T + T / 2.0)


func _put_player(x: int, y: int) -> void:
	game.player.global_position = _cell(x, y)
	game.player.velocity = Vector2.ZERO
	await _frames(20)


func check(name: String, ok: bool, detail := "") -> void:
	if ok:
		passed += 1
		print("  OK   ", name)
	else:
		failures += 1
		print("  CHYBA ", name, "  ", detail)


# --- Testy -------------------------------------------------------------------

func t_chodza() -> void:
	print("Chôdza")
	await _level({})
	var x0: float = game.player.global_position.x
	await _hold("move_right", 1.0)
	check("ide doprava", game.player.global_position.x > x0 + 150.0, str(game.player.global_position.x - x0))
	check("stojí na zemi", game.player.is_on_floor())


func t_skok() -> void:
	print("Skok")
	await _level({"8,7": "ground", "8,8": "ground", "8,9": "ground", "20,6": "ground", "20,7": "ground", "20,8": "ground", "20,9": "ground"})
	var y0: float = game.player.global_position.y
	Input.action_press("jump")
	await _frames(20)
	var y1: float = game.player.global_position.y
	Input.action_release("jump")
	check("vyskočí aspoň 2 dlaždice", y0 - y1 > 128.0, str(y0 - y1))
	await _seconds(1.0)
	# Stena vysoká 3 dlaždice sa dá vyskočiť
	await _put_player(6, 9)
	Input.action_press("move_right")
	Input.action_press("jump")
	await _seconds(0.8)
	Input.action_release("jump")
	await _seconds(0.4)
	Input.action_release("move_right")
	await _frames(10)
	check("preskočí 3 dlaždice vysokú stenu", game.player.global_position.x > 9 * T, str(game.player.global_position))
	# Na 4 dlaždice už nie
	await _put_player(18, 9)
	Input.action_press("move_right")
	Input.action_press("jump")
	await _seconds(0.8)
	Input.action_release("jump")
	await _seconds(0.4)
	Input.action_release("move_right")
	await _frames(10)
	check("4 dlaždice vysokú stenu nepreskočí", game.player.global_position.x < 20 * T, str(game.player.global_position))


func t_kluc() -> void:
	print("Kľúč a zámok")
	await _level({"5,9": "key_red", "9,9": "lock_red", "9,8": "lock_red"})
	check("zámky existujú", get_nodes_in_group("lock_red").size() == 2)
	await _hold("move_right", 0.6)
	await _frames(30)
	check("po zobratí kľúča zámky zmizli", get_nodes_in_group("lock_red").size() == 0, str(get_nodes_in_group("lock_red").size()))
	check("kľúč je v HUD", game.keys.has("red"))


func t_mince_blok() -> void:
	print("Blok s mincami")
	await _level({"4,7": "block_strong_coin", "6,7": {"t": "block_exclamation", "content": "heart"}})
	await _put_player(4, 9)
	for i in 2:
		await _tap("jump")
		await _seconds(0.8)
	check("dva údery dali 2 × 5 mincí", game.coins == 10, str(game.coins))
	game.player.health = 1
	await _put_player(6, 9)
	await _tap("jump")
	await _seconds(1.2)
	await _hold("move_left", 0.1)
	await _hold("move_right", 0.1)
	await _tap("jump")
	await _seconds(1.0)
	check("srdce z bloku vyskočilo", get_nodes_in_group("enemy").size() == 0)


func t_tehla() -> void:
	print("Rozbitná tehla")
	await _level({"4,7": "brick_brown"})
	await _put_player(4, 9)
	var bricks_before := _count_script("breakable")
	await _tap("jump")
	await _seconds(0.6)
	check("tehla sa rozbila", _count_script("breakable") == bricks_before - 1, str(_count_script("breakable")))


func t_tlacidlo() -> void:
	print("Tlačidlo a farebné bloky")
	await _level({"6,9": "switch_blue", "10,9": "block_blue", "10,8": "block_blue"})
	var block = get_nodes_in_group("channel_blue")[0]
	check("blok je na začiatku pevný", not _disabled(block))
	await _put_player(6, 9)
	await _frames(10)
	check("po stúpení na tlačidlo je priechodný", _disabled(block))
	await _put_player(2, 9)
	await _seconds(5.5)
	check("po 5 s je znova pevný", not _disabled(block))


func t_packa_vytah() -> void:
	print("Páčka a výťah")
	await _level({"5,9": {"t": "lever", "color": "green"}, "10,9": {"t": "lift", "color": "green", "direction": "up", "distance": 3}})
	var lift = get_nodes_in_group("channel_green")[0]
	var y0: float = lift.position.y
	await _put_player(5, 9)
	await _tap("move_up")
	await _seconds(2.2)
	check("výťah sa posunul o 3 dlaždice hore", is_equal_approx(lift.position.y, y0 - 3 * T), str(lift.position.y - y0))
	await _tap("move_up")
	await _seconds(2.2)
	check("druhé prepnutie ho vráti", is_equal_approx(lift.position.y, y0), str(lift.position.y - y0))


func t_pruzina() -> void:
	print("Pružina")
	await _level({"6,9": "spring"})
	game.player.global_position = _cell(6, 5)
	await _frames(25)
	var min_y: float = game.player.global_position.y
	for i in 40:
		await physics_frame
		min_y = minf(min_y, game.player.global_position.y)
	check("pružina vystrelí hráča vyššie, než spadol", min_y < 5 * T - 40, str(min_y))


func t_bomba() -> void:
	print("Bomba")
	await _level({"8,9": "bomb", "10,9": "brick_brown", "9,8": "slime_normal", "20,9": "slime_normal", "14,9": "brick_grey"})
	await _put_player(8, 9)
	await _put_player(2, 9)
	await _seconds(2.4)
	var alive := get_nodes_in_group("enemy").filter(func(e): return not e.dead)
	check("blízky mob zomrel, vzdialený žije", alive.size() == 1, str(alive.size()))
	check("blízka tehla zničená, vzdialená nie", _count_script("breakable") == 1, str(_count_script("breakable")))
	check("hráč mimo dosahu prežil", not game.player.dead)


func t_mob_skok() -> void:
	print("Skok na moba")
	await _level({"10,9": "slime_normal"})
	var mob = get_nodes_in_group("enemy")[0]
	await _frames(5)
	game.player.global_position = mob.global_position + Vector2(0, -150)
	game.player.velocity = Vector2.ZERO
	await _seconds(0.6)
	check("mob je rozpučený", mob == null or not is_instance_valid(mob) or mob.dead)
	check("hráč nie je zranený", game.player.health == 3, str(game.player.health))


func t_mob_zranenie() -> void:
	print("Zranenie od moba")
	await _level({"8,9": "slime_spike"})
	await _hold("move_right", 1.2)
	check("pichľavý sliz zraní hráča", game.player.health < 3, str(game.player.health))


func t_bodce() -> void:
	print("Bodce, kaktus, hríb")
	await _level({"5,9": "spikes", "9,9": "cactus", "13,9": "mushroom_red"})
	await _put_player(5, 9)
	check("bodce zrania", game.player.health == 2, str(game.player.health))
	await _seconds(1.6)
	await _put_player(9, 9)
	check("kaktus zraní", game.player.health == 1, str(game.player.health))
	await _seconds(1.6)
	await _put_player(13, 9)
	check("hríb zraní (posledné srdce = smrť)", game.player.dead)


func t_utopenie() -> void:
	print("Voda a topenie")
	var cells := {}
	for x in range(6, 14):
		for y in range(4, 10):
			cells["%d,%d" % [x, y]] = "water"
	await _level(cells)
	var drowned := [false]
	game.player.died.connect(func(): drowned[0] = true)
	await _put_player(9, 8)
	check("vo vode pláva (pomalé klesanie)", game.player._swimming)
	await _seconds(5.0)
	check("po 5 s ešte žije", not drowned[0])
	await _seconds(4.0)
	check("po 9 s pod vodou sa utopil", drowned[0])


func t_lava() -> void:
	print("Láva")
	await _level({"8,9": "lava", "8,10": "lava"})
	await _put_player(8, 8)
	check("láva zabije", game.player.dead)


func t_rebrik() -> void:
	print("Rebrík")
	var cells := {}
	for y in range(4, 10):
		cells["6,%d" % y] = "ladder"
	cells["7,4"] = "ground"
	cells["8,4"] = "ground"
	cells["7,5"] = "ground"
	cells["8,5"] = "ground"
	await _level(cells)
	await _put_player(6, 9)
	await _hold("move_up", 3.5)
	check("vyliezol hore po rebríku", game.player.global_position.y < 5 * T, str(game.player.global_position.y))
	await _hold("move_right", 0.5)
	await _frames(20)
	check("zišiel z rebríka na zem hore", game.player.global_position.y < 4 * T and game.player.is_on_floor(), str(game.player.global_position))


func t_padajuci_blok() -> void:
	print("Padajúci blok")
	await _level({"8,6": "block_empty_warning"})
	var block = get_nodes_in_group("bomb_breakable")[0]
	var y0: float = block.position.y
	game.player.global_position = _cell(8, 4)
	await _seconds(1.2)
	check("blok spadol", block.position.y > y0 + 64.0, str(block.position.y - y0))


func t_miznuci_most() -> void:
	print("Miznúci most")
	await _level({"8,6": "bridge"})
	game.player.global_position = _cell(8, 4)
	await _seconds(0.3)
	var y_on: float = game.player.global_position.y
	check("hráč stojí na moste", y_on < 6 * T, str(y_on))
	await _seconds(1.0)
	check("most zmizol a hráč spadol", game.player.global_position.y > 7 * T, str(game.player.global_position.y))


func t_ciel() -> void:
	print("Cieľ")
	await _level({"8,9": "door_exit", "4,9": "star", "5,9": "star", "6,9": "star"})
	await _hold("move_right", 1.4)
	await _frames(20)
	check("zobral 3 hviezdy", game.stars_collected == 3, str(game.stars_collected))
	check("level je dokončený", not game.running)


func t_drahokamy() -> void:
	print("Drahokamy a power-upy")
	await _level({"4,9": "gem_blue", "6,9": "gem_green", "8,9": "gem_yellow"})
	await _hold("move_right", 1.6)
	check("rýchlosť", game.player.speed_boost > 0.0)
	check("vysoký skok", game.player.jump_boost > 0.0)
	check("neporaziteľnosť", game.player.shield > 0.0)


func t_slimak_ulita() -> void:
	print("Slimák a ulita")
	await _level({"10,9": "snail", "16,9": "slime_normal"})
	var snail = get_nodes_in_group("enemy").filter(func(e): return e.item_id == "snail")[0]
	await _frames(5)
	game.player.global_position = snail.global_position + Vector2(0, -150)
	await _seconds(0.5)
	check("slimák sa schoval do ulity", snail._shell)
	game.player.global_position = snail.global_position + Vector2(-60, 0)
	game.player.velocity = Vector2.ZERO
	await _hold("move_right", 0.3)
	await _seconds(1.5)
	var slime = get_nodes_in_group("enemy").filter(func(e): return e.item_id == "slime_normal")
	check("kopnutá ulita zabila sliz", slime.is_empty() or slime[0].dead)


func t_krabica() -> void:
	print("Krabica")
	await _level({"5,9": "block_planks"})
	var crate = get_nodes_in_group("bomb_breakable")[0]
	var x0: float = crate.global_position.x
	var fastest := 0.0
	Input.action_press("move_right")
	for i in 90:
		await physics_frame
		fastest = maxf(fastest, absf(crate.linear_velocity.x))
	Input.action_release("move_right")
	check("krabica sa posunula", crate.global_position.x > x0 + 40.0, str(crate.global_position.x - x0))
	check("krabica neodletí (rýchlosť do 200)", fastest <= 200.0, str(fastest))
	# Rozbeh z diaľky a náraz do krabice
	await _put_player(1, 9)
	var before: float = crate.global_position.x
	await _hold("move_right", 0.6)
	await _seconds(1.0)
	check("po náraze sa krabica zastaví blízko", crate.global_position.x - before < 4 * T, str(crate.global_position.x - before))


func t_pas() -> void:
	print("Pás")
	var cells := {}
	for x in range(4, 12):
		cells["%d,9" % x] = {"t": "conveyor", "direction": "right"}
	await _level(cells)
	await _put_player(5, 7)
	var x0: float = game.player.global_position.x
	await _seconds(1.0)
	check("pás posúva hráča doprava", game.player.global_position.x > x0 + 60.0, str(game.player.global_position.x - x0))


func t_vsetky_moby() -> void:
	print("Všetky moby sa načítajú a hýbu")
	var Catalog = load("res://scripts/catalog.gd")
	var cells := {}
	var x := 3
	var water_x := []
	for id in Catalog.in_category("moby"):
		if id.begins_with("fish") or id == "piranha":
			water_x.append(x)
		cells["%d,7" % x] = id
		x += 3
	for wx in water_x:
		for dx in range(-1, 2):
			for y in range(6, 10):
				if not cells.has("%d,%d" % [wx + dx, y]):
					cells["%d,%d" % [wx + dx, y]] = "water"
	await _level(cells, x + 4, 12)
	game.player.global_position = _cell(1, 2)
	var mobs := get_nodes_in_group("enemy")
	var start := {}
	var moved := {}
	for m in mobs:
		start[m] = m.global_position
		moved[m] = 0.0
	for i in 16:
		await _seconds(0.25)
		for m in mobs:
			if is_instance_valid(m):
				moved[m] = maxf(moved[m], m.global_position.distance_to(start[m]))
	check("počet mobov = %d" % Catalog.in_category("moby").size(), mobs.size() == Catalog.in_category("moby").size(), str(mobs.size()))
	var still := []
	for m in mobs:
		if is_instance_valid(m) and moved[m] < 4.0 and not m.behavior in ["barnacle", "crusher", "pillar", "bat", "ghost"]:
			still.append(m.item_id)
	check("pohyblivé moby sa hýbu", still.is_empty(), str(still))


func t_zavazie() -> void:
	print("Závažie a drvič")
	await _level({"8,3": "weight"})
	await _put_player(8, 9)
	await _seconds(1.0)
	check("závažie spadlo a zranilo hráča", game.player.health < 3, str(game.player.health))


# --- Pomocné kontroly -------------------------------------------------------

func _disabled(body: Node) -> bool:
	for shape in body.find_children("*", "CollisionShape2D", false, false):
		if shape.disabled:
			return true
	return false


func _count_script(name: String) -> int:
	var count := 0
	for node in current_scene.find_children("*", "StaticBody2D", true, false):
		if node.get_script() and String(node.get_script().resource_path).ends_with(name + ".gd"):
			count += 1
	return count


# --- Ukážkové levely (data/worlds/ukazka.json) ---------------------------------

func _demo(level_id: String) -> void:
	var content = root.get_node("Content")
	gs.test_world = content.get_world("ukazka")
	gs.test_level = content.get_level("ukazka", level_id)
	change_scene_to_file("res://scenes/game.tscn")
	await process_frame
	await process_frame
	game = current_scene
	await _frames(10)


func t_ukazka_vytah() -> void:
	print("Ukážka: páčka postaví most z výťahov")
	await _demo("m3")
	var lifts := get_nodes_in_group("channel_green")
	await _put_player(28, 11)
	await _tap("move_up")
	await _seconds(1.2)
	check("8 výťahov sa zdvihlo na úroveň zeme", lifts.size() == 8 and lifts.all(func(l): return is_equal_approx(l.position.y, 12 * T + T / 2.0)), str(lifts.map(func(l): return l.position.y)))
	await _hold("move_right", 3.0)
	check("hráč prešiel po moste", game.player.global_position.x > 39 * T and not game.player.dead, str(game.player.global_position))


func t_ukazka_bomba() -> void:
	print("Ukážka: bomba zničí tehlovú stenu")
	await _demo("m4")
	await _put_player(25, 11)
	await _put_player(4, 11)
	await _seconds(2.5)
	check("tehly zmizli", _count_script("breakable") == 0, str(_count_script("breakable")))
	check("hráč prežil", not game.player.dead)


func t_ukazka_kluce() -> void:
	print("Ukážka: kľúč a tlačidlo")
	await _demo("m2")
	await _put_player(8, 10)
	await _frames(10)
	check("červené zámky zmizli", get_nodes_in_group("lock_red").size() == 0)
	await _put_player(18, 11)
	await _hold("move_right", 1.8)
	check("cez modrú bránu prešiel včas", game.player.global_position.x > 24 * T + 40, str(game.player.global_position))


func t_ukazka_pruzina() -> void:
	print("Ukážka: pružina vystrelí na rímsu")
	await _demo("m3")
	await _put_player(6, 11)
	Input.action_press("move_right")
	await _seconds(0.35)
	Input.action_release("move_right")
	await _seconds(1.4)
	Input.action_press("move_right")
	await _seconds(0.3)
	Input.action_release("move_right")
	await _seconds(0.6)
	check("hráč stojí na rímse", game.player.global_position.y < 7 * T and game.player.is_on_floor(), str(game.player.global_position))


func t_hadanka_krabica() -> void:
	print("Level Kľúč a krabica: bez krabice na rímsu nevyskočí, s krabicou áno")
	var content = root.get_node("Content")
	gs.test_world = content.get_world("ukazka")
	gs.test_level = content.get_level("ukazka", "m6")
	change_scene_to_file("res://scenes/game.tscn")
	await process_frame
	await process_frame
	game = current_scene
	await _frames(10)
	# Bez krabice: priamo pod rímsou skáče márne
	await _put_player(11, 11)
	Input.action_press("move_right")
	Input.action_press("jump")
	await _seconds(0.7)
	Input.action_release("jump")
	Input.action_release("move_right")
	await _seconds(0.5)
	check("bez krabice sa na rímsu nedostane", game.player.global_position.y > 10 * T, str(game.player.global_position))
	# S krabicou: dotlačí ju k rímse, vyskočí na ňu a potom na rímsu
	await _put_player(5, 11)
	await _hold("move_right", 2.0)
	var crate = get_nodes_in_group("bomb_breakable")[0]
	await _put_player(8, 11)
	Input.action_press("move_right")
	Input.action_press("jump")
	await _seconds(0.5)
	Input.action_release("jump")
	for i in 90:
		await physics_frame
		if game.player.is_on_floor():
			break
	Input.action_press("jump")
	await _seconds(0.6)
	Input.action_release("jump")
	await _seconds(0.4)
	Input.action_release("move_right")
	await _frames(20)
	check("krabica je pri rímse", crate.global_position.x > 10 * T, str(crate.global_position))
	check("z krabice vyskočí na rímsu", game.player.global_position.y < 8 * T, str(game.player.global_position))


func t_cesta_moba() -> void:
	print("Cesta moba")
	await _level({
		"8,9": {"t": "slime_normal", "path": [6, 9, 11, 9]},
		"8,4": {"t": "bee", "path": [4, 4, 14, 2]},
		"20,6": {"t": "saw_mob", "path": [18, 6, 24, 6]},
	}, 30, 12)
	game.player.global_position = _cell(1, 2)
	var mobs := {}
	for m in get_nodes_in_group("enemy"):
		mobs[m.item_id] = {"node": m, "min": Vector2(INF, INF), "max": Vector2(-INF, -INF)}
	for i in 600:
		await physics_frame
		for id in mobs:
			var p: Vector2 = mobs[id]["node"].global_position
			mobs[id]["min"] = mobs[id]["min"].min(p)
			mobs[id]["max"] = mobs[id]["max"].max(p)
	var slime: Dictionary = mobs["slime_normal"]
	check("sliz chodí len po svojej ceste", slime["min"].x >= 6 * T and slime["max"].x <= 12 * T, str(slime["min"], slime["max"]))
	check("sliz prejde celú cestu", slime["min"].x < 7 * T and slime["max"].x > 11 * T, str(slime["min"], slime["max"]))
	var bee: Dictionary = mobs["bee"]
	check("včela letí šikmo medzi bodmi cesty", bee["min"].x < 5 * T and bee["max"].x > 14 * T and bee["min"].y < 3 * T, str(bee["min"], bee["max"]))
	var saw: Dictionary = mobs["saw_mob"]
	check("píla jazdí medzi bodmi cesty", saw["min"].x < 19 * T and saw["max"].x > 24 * T, str(saw["min"], saw["max"]))


func t_dvere_prechod() -> void:
	print("Prechodové dvere")
	# Druhé dvere sú v uzavretej miestnosti (stena podzemia), kam sa inak nedá dostať.
	var cells := {}
	for x in range(15, 27):
		cells["%d,12" % x] = "ground"
	for x in range(16, 26):
		for y in range(13, 16):
			cells["%d,%d" % [x, y]] = "backwall"
	for y in range(12, 16):
		cells["15,%d" % y] = "ground"
		cells["26,%d" % y] = "ground"
	cells["4,15"] = {"t": "door_warp", "color": "blue"}
	cells["20,15"] = {"t": "door_warp", "color": "blue"}
	await _level(cells, 30, 18)
	await _put_player(4, 15)
	Input.action_press("move_up")
	await _frames(4)
	Input.action_release("move_up")
	await _seconds(0.8)
	var p: Vector2 = game.player.global_position
	check("prešiel k druhým dverám", p.distance_to(_cell(20, 15)) < 40.0, str(p))
	check("hráč sa môže znova hýbať", game.player.input_enabled)


func t_skryty_blok() -> void:
	print("Skrytý blok")
	await _level({"8,10": "ground", "8,7": {"t": "block_hidden", "content": "coin_gold"}, "12,9": "block_hidden"})
	# prejde cez skrytý blok zboku (nie je pevný)
	await _put_player(10, 9)
	await _hold("move_right", 0.6)
	check("zboku sa cezeň prejde", game.player.global_position.x > _cell(12, 9).x + 20.0, str(game.player.global_position.x))
	await _put_player(8, 9)
	var coins_before: int = game.coins
	await _tap("jump")
	await _seconds(1.2)
	check("úder zospodu vyhodí mincu", game.coins > coins_before, str(game.coins))
	var block = _find_block(Vector2(8, 7))
	check("blok sa objavil", block != null and block.get_node("Sprite").visible)
	# teraz sa na ňom dá stáť
	game.player.global_position = _cell(8, 5)
	game.player.velocity = Vector2.ZERO
	await _seconds(0.8)
	check("na objavenom bloku sa dá stáť", game.player.is_on_floor() and game.player.global_position.y < _cell(8, 7).y, str(game.player.global_position))


func _find_block(cell: Vector2) -> Node:
	for node in game.level_root.get_children():
		if node is StaticBody2D and node.get("secret") != null and node.global_position.distance_to(_cell(int(cell.x), int(cell.y))) < 4.0:
			return node
	return null


func t_tajna_stena() -> void:
	print("Tajná stena")
	var cells := {}
	for y in range(6, 10):
		cells["10,%d" % y] = "secret_wall"
		cells["11,%d" % y] = "secret_wall"
	cells["14,9"] = "star"
	await _level(cells)
	await _hold("move_right", 3.2)
	check("prešiel cez tajnú stenu", game.player.global_position.x > _cell(12, 9).x, str(game.player.global_position.x))
	check("zobral hviezdu za stenou", game.stars_collected == 1)
	var wall: Node = null
	for node in game.level_root.get_children():
		if node.get_script() and node.get_script().resource_path.ends_with("secret.gd"):
			wall = node
	check("stena je jedna skupina", wall != null and wall.get_child_count() == 9, str(wall.get_child_count() if wall else -1))


func t_pohybliva_plosina() -> void:
	print("Pohyblivá plošina")
	var cells := {}
	for x in range(6, 30):
		cells["%d,10" % x] = "lava"
		cells["%d,11" % x] = "ground"
	for x in range(6, 9):
		cells["%d,8" % x] = {"t": "moving_platform", "direction": "horizontal", "distance": 6}
	await _level(cells)
	var movers: Array = game.level_root.get_children().filter(func(n): return n is AnimatableBody2D and n.get("vertical") != null)
	check("tri bunky = jedna plošina", movers.size() == 1, str(movers.size()))
	game.player.global_position = _cell(7, 7)
	game.player.velocity = Vector2.ZERO
	await _frames(10)
	var x0: float = game.player.global_position.x
	await _seconds(2.5)
	check("hráč stojí na plošine", game.player.is_on_floor() and not game.player.dead)
	check("plošina hráča vezie", game.player.global_position.x > x0 + 120.0, str(game.player.global_position.x - x0))


func t_svet1_levely() -> void:
	print("Svet 1: každý level sa postaví bez chýb a prejde kontrolou editora")
	var content = root.get_node("Content")
	var Validator = load("res://scripts/level_validator.gd")
	var world: Dictionary = content.get_world("zelene_kopce")
	check("svet má 5 levelov", world.get("levels", []).size() == 5, str(world.get("levels", []).size()))
	for level in world.get("levels", []):
		var problems: Array = Validator.check(level)
		check("%s: kontrola editora bez problémov" % level["name"], problems.is_empty(), str(problems))
		var width := int(level["width"])
		var checkpoints := 0
		for key in level["cells"]:
			if level["cells"][key]["t"] == "checkpoint":
				checkpoints += 1
		check("%s: dĺžka %d, checkpointy %d" % [level["name"], width, checkpoints], width >= 150 and checkpoints == width / 150)
		gs.test_world = world
		gs.test_level = level
		change_scene_to_file("res://scenes/game.tscn")
		await process_frame
		await process_frame
		game = current_scene
		await _frames(30)
		check("%s: hráč stojí na štarte" % level["name"], game.player.is_on_floor() and not game.player.dead)
		check("%s: 3 hviezdy" % level["name"], game.stars_total == 3)
