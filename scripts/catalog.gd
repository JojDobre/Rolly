extends RefCounted
## Katalóg všetkého, čo sa dá položiť do levelu: názov, kategória, ikona, správanie a parametre.
## Používa ho editor (paleta, kontrola párov) aj hra (level_loader.gd).
##
## Ikona "terrain:xxx" znamená dlaždicu podľa štýlu sveta (napr. terrain_grass_xxx).

const TILES := "res://assets/npp/tiles/%s.png"
const ENEMIES := "res://assets/npp/enemies/%s.png"
const ENEMIES_EXT := "res://assets/enemies_ext/%s.png"
const SHAPES := "res://assets/shape/%s.png"

const COLORS := ["red", "blue", "green", "yellow"]
const COLOR_NAMES := {"red": "červená", "blue": "modrá", "green": "zelená", "yellow": "žltá"}
const COLOR_VALUES := {"red": Color("e8423f"), "blue": Color("3d8ee8"), "green": Color("3fbf5c"), "yellow": Color("f2c230")}

const TERRAINS := {"grass": "Tráva", "dirt": "Hlina", "sand": "Piesok", "snow": "Sneh", "stone": "Kameň", "purple": "Fialová"}
const BACKGROUNDS := {"hills": "Kopce", "trees": "Stromy", "desert": "Púšť", "mushrooms": "Huby"}
## Postavička z Kenney Shape Characters: farba tela a tvar.
const CHARACTER_COLORS := {"red": "Červená", "blue": "Modrá", "green": "Zelená", "pink": "Ružová", "purple": "Fialová"}
const CHARACTER_SHAPES := {"circle": "Guľa", "squircle": "Oblý štvorec", "square": "Kocka", "rhombus": "Kosoštvorec"}

const CATEGORIES := [
	["teren", "Terén"],
	["bloky", "Bloky"],
	["zbieranie", "Zbieranie"],
	["mechanizmy", "Mechanizmy"],
	["nebezpecne", "Nebezpečné"],
	["moby", "Moby"],
	["ozdoby", "Ozdoby"],
	["specialne", "Štart a cieľ"],
]

## Čo môže vypadnúť z bloku s otáznikom / výkričníkom.
const CONTENTS := {
	"coin_gold": "Zlatá minca",
	"heart": "Srdce (+1 zdravie)",
	"gem_red": "Červený drahokam (+1 život)",
	"gem_blue": "Modrý drahokam (rýchlosť)",
	"gem_green": "Zelený drahokam (vysoký skok)",
	"gem_yellow": "Žltý drahokam (neporaziteľnosť)",
	"mob": "Mob (slime)",
}

## Hodnota mincí.
const COIN_VALUES := {"coin_bronze": 1, "coin_silver": 2, "coin_gold": 5}

static var _items := {}
static var _order := []


static func items() -> Dictionary:
	if _items.is_empty():
		_build()
	return _items


static func order() -> Array:
	if _items.is_empty():
		_build()
	return _order


static func get_item(id: String) -> Dictionary:
	return items().get(id, {})


## Zoznam id predmetov v kategórii (v poradí pre paletu).
static func in_category(category: String) -> Array:
	var result := []
	for id in order():
		if _items[id]["cat"] == category:
			result.append(id)
	return result


## Cesta k ikone predmetu pre daný štýl terénu.
static func icon_path(id: String, terrain := "grass") -> String:
	var item := get_item(id)
	if item.is_empty():
		return ""
	var icon: String = item["icon"]
	if icon.begins_with("terrain:"):
		return TILES % ("terrain_%s_%s" % [terrain, icon.substr(8)])
	if icon.begins_with("enemy:"):
		return ENEMIES % icon.substr(6)
	if icon.begins_with("ext:"):
		return ENEMIES_EXT % icon.substr(4)
	return TILES % icon


static func _add(id: String, name: String, cat: String, icon: String, kind: String, params := {}, info := "") -> void:
	_items[id] = {"id": id, "name": name, "cat": cat, "icon": icon, "kind": kind, "params": params, "info": info}
	_order.append(id)


static func _build() -> void:
	# --- Terén (podľa štýlu sveta) ---
	_add("ground", "Zem", "teren", "terrain:block_top", "ground", {}, "Pevná zem. Rohy a okraje sa vyberú samé.")
	_add("platform", "Plošina", "teren", "terrain:cloud", "platform", {}, "Zospodu sa cez ňu dá vyskočiť.")
	_add("slope", "Svah", "teren", "terrain:ramp_short_b", "slope", {}, "Natočí sa sám k susednej zemi.")
	_add("bricks_brown", "Tehlová stena", "teren", "bricks_brown", "solid")
	_add("bricks_grey", "Šedá stena", "teren", "bricks_grey", "solid")
	_add("block_strong_empty", "Pevný blok", "teren", "block_strong_empty", "solid")
	_add("block_empty", "Prázdny blok", "teren", "block_empty", "solid")
	_add("block_plank", "Doska", "teren", "block_plank", "oneway", {}, "Tenká plošina, zospodu sa cez ňu dá vyskočiť.")
	_add("bridge_logs", "Drevený most", "teren", "bridge_logs", "oneway")

	# --- Bloky s funkciou ---
	_add("brick_brown", "Rozbitná tehla", "bloky", "brick_brown", "breakable", {}, "Rozbije sa úderom hlavy zospodu alebo bombou.")
	_add("brick_grey", "Rozbitný kameň", "bloky", "brick_grey", "breakable", {}, "Rozbije sa úderom hlavy zospodu alebo bombou.")
	_add("block_coin", "Blok s mincou", "bloky", "block_coin", "item_block", {"content": "coin_gold", "hits": 1}, "Úder zospodu vyhodí mincu.")
	_add("block_strong_coin", "Blok s 5 mincami", "bloky", "block_strong_coin", "item_block", {"content": "coin_gold", "hits": 5}, "Každý úder vyhodí mincu, spolu 5.")
	_add("block_exclamation", "Blok s prekvapením", "bloky", "block_exclamation", "item_block", {"content": "heart", "hits": 1}, "Úder zospodu vyhodí zvolený predmet.")
	_add("block_strong_exclamation", "Silný blok s prekvapením", "bloky", "block_strong_exclamation", "item_block", {"content": "gem_yellow", "hits": 1}, "Ako blok s prekvapením, ale nedá sa rozbiť bombou.")
	_add("block_strong_danger", "Blok s mobom", "bloky", "block_strong_danger", "item_block", {"content": "mob", "mob": "slime_normal", "hits": 1}, "Úder zospodu vypustí moba.")
	_add("block_empty_warning", "Padajúci blok", "bloky", "block_empty_warning", "falling", {}, "Keď naň stúpiš, zatrasie sa a spadne. Po chvíli sa vráti.")
	_add("bridge", "Miznúci most", "bloky", "bridge", "vanishing", {}, "Chvíľu po stúpení zmizne, potom sa objaví znova.")
	_add("block_planks", "Krabica", "bloky", "block_planks", "crate", {}, "Dá sa tlačiť a stáť na nej.")

	# --- Zbieranie ---
	_add("coin_bronze", "Bronzová minca", "zbieranie", "coin_bronze", "coin", {}, "1 minca. 100 mincí = +1 život.")
	_add("coin_silver", "Strieborná minca", "zbieranie", "coin_silver", "coin", {}, "2 mince.")
	_add("coin_gold", "Zlatá minca", "zbieranie", "coin_gold", "coin", {}, "5 mincí.")
	_add("star", "Hviezda", "zbieranie", "star", "star", {}, "V každom leveli sú presne 3. Určujú hodnotenie.")
	_add("heart", "Srdce", "zbieranie", "heart", "powerup", {}, "+1 zdravie (najviac 3).")
	_add("gem_red", "Červený drahokam", "zbieranie", "gem_red", "powerup", {}, "+1 život.")
	_add("gem_blue", "Modrý drahokam", "zbieranie", "gem_blue", "powerup", {}, "Rýchlosť na 10 sekúnd.")
	_add("gem_green", "Zelený drahokam", "zbieranie", "gem_green", "powerup", {}, "Vysoký skok na 10 sekúnd.")
	_add("gem_yellow", "Žltý drahokam", "zbieranie", "gem_yellow", "powerup", {}, "Neporaziteľnosť na 8 sekúnd.")

	# --- Mechanizmy ---
	for color in COLORS:
		var cname: String = COLOR_NAMES[color]
		_add("key_" + color, "Kľúč (%s)" % cname, "mechanizmy", "key_" + color, "key", {"color": color}, "Po zobratí zmiznú všetky zámky rovnakej farby.")
		_add("lock_" + color, "Zámok (%s)" % cname, "mechanizmy", "lock_" + color, "lock", {"color": color}, "Zmizne, keď hráč zoberie kľúč rovnakej farby.")
	for color in COLORS:
		var cname: String = COLOR_NAMES[color]
		_add("switch_" + color, "Tlačidlo (%s)" % cname, "mechanizmy", "switch_" + color, "switch", {"color": color, "time": 5}, "Po stúpení na 5 s prepne farebné bloky rovnakej farby.")
		_add("block_" + color, "Farebný blok (%s)" % cname, "mechanizmy", "block_" + color, "color_block", {"color": color, "solid": true}, "Prepína ho tlačidlo alebo páčka rovnakej farby.")
	_add("lever", "Páčka", "mechanizmy", "lever_left", "lever", {"color": "red"}, "Natrvalo prepne farebné bloky a pohne výťahmi svojej farby.")
	_add("lift", "Výťah", "mechanizmy", "terrain:horizontal_middle", "lift", {"color": "red", "direction": "up", "distance": 3}, "Po prepnutí páčky rovnakej farby sa posunie hore alebo dole.")
	_add("spring", "Pružina", "mechanizmy", "spring", "spring", {}, "Vystrelí hráča vysoko do vzduchu.")
	_add("conveyor", "Pás", "mechanizmy", "conveyor", "conveyor", {"direction": "right"}, "Posúva všetko, čo na ňom stojí.")
	_add("ladder", "Rebrík", "mechanizmy", "ladder_middle", "ladder", {}, "Lezie sa hore a dole šípkami.")
	_add("rope", "Lano", "mechanizmy", "rope", "ladder", {}, "Lezie sa ako po rebríku.")
	_add("bomb", "Bomba", "mechanizmy", "bomb", "bomb", {"radius": 2}, "Po dotyku sa zapáli a vybuchne. Zničí všetko v okruhu.")

	# --- Nebezpečné ---
	_add("spikes", "Bodce", "nebezpecne", "spikes", "hazard", {}, "Zrania hráča.")
	_add("block_spikes", "Blok s bodcami", "nebezpecne", "block_spikes", "spike_block", {}, "Pevný blok, ktorý zraní pri dotyku.")
	_add("cactus", "Kaktus", "nebezpecne", "cactus", "hazard", {}, "Pichá a zraní hráča.")
	_add("mushroom_red", "Jedovatý hríb", "nebezpecne", "mushroom_red", "hazard", {}, "Zraní hráča.")
	_add("mushroom_brown", "Hnedý hríb", "nebezpecne", "mushroom_brown", "hazard", {}, "Zraní hráča.")
	_add("saw", "Píla", "nebezpecne", "saw", "hazard", {}, "Točiaca sa píla, zraní hráča.")
	_add("lava", "Láva", "nebezpecne", "lava_top", "lava", {}, "Okamžite zabije.")
	_add("water", "Voda", "nebezpecne", "water_top", "water", {}, "Dá sa v nej plávať, ale po 8 s pod vodou sa hráč utopí.")
	_add("fireball", "Ohnivá guľa", "nebezpecne", "fireball", "fireball", {"height": 3}, "Vyskakuje hore a dole (napr. z lávy).")
	_add("weight", "Závažie", "nebezpecne", "weight", "weight", {}, "Spadne, keď je hráč pod ním. Potom sa vráti.")

	# --- Moby ---
	_add("slime_normal", "Sliz", "moby", "enemy:slime_normal_rest", "mob", {"behavior": "walker", "stomp": true, "speed": 60})
	_add("slime_fire", "Ohnivý sliz", "moby", "enemy:slime_fire_rest", "mob", {"behavior": "walker", "stomp": false, "speed": 60}, "Nedá sa naň skočiť – páli.")
	_add("slime_spike", "Pichľavý sliz", "moby", "enemy:slime_spike_rest", "mob", {"behavior": "walker", "stomp": false, "speed": 50}, "Nedá sa naň skočiť – pichá.")
	_add("slime_block", "Skákajúci sliz", "moby", "enemy:slime_block_rest", "mob", {"behavior": "hopper", "stomp": true, "speed": 80})
	_add("snail", "Slimák", "moby", "enemy:snail_rest", "mob", {"behavior": "snail", "stomp": true, "speed": 35}, "Po skoku sa schová do ulity. Ulitu sa dá kopnúť.")
	_add("worm_normal", "Červík", "moby", "enemy:worm_normal_rest", "mob", {"behavior": "walker", "stomp": true, "speed": 30})
	_add("worm_ring", "Pruhovaný červík", "moby", "enemy:worm_ring_rest", "mob", {"behavior": "walker", "stomp": true, "speed": 40})
	_add("mouse", "Myš", "moby", "enemy:mouse_rest", "mob", {"behavior": "walker", "stomp": true, "speed": 140}, "Veľmi rýchla.")
	_add("ladybug", "Lienka", "moby", "enemy:ladybug_rest", "mob", {"behavior": "ladybug", "stomp": true, "speed": 60}, "Chodí a občas vzlietne.")
	_add("frog", "Žaba", "moby", "enemy:frog_rest", "mob", {"behavior": "frog", "stomp": true, "speed": 120}, "Skáče smerom k hráčovi.")
	_add("bee", "Včela", "moby", "enemy:bee_rest", "mob", {"behavior": "flyer", "stomp": true, "speed": 70, "range": 3})
	_add("fly", "Mucha", "moby", "enemy:fly_rest", "mob", {"behavior": "flyer_vertical", "stomp": true, "speed": 60, "range": 2})
	_add("fish_blue", "Modrá ryba", "moby", "enemy:fish_blue_rest", "mob", {"behavior": "swimmer", "stomp": false, "speed": 70}, "Pláva vo vode.")
	_add("fish_yellow", "Žltá ryba", "moby", "enemy:fish_yellow_rest", "mob", {"behavior": "swimmer", "stomp": false, "speed": 100}, "Pláva vo vode.")
	_add("fish_purple", "Fialová ryba", "moby", "enemy:fish_purple_rest", "mob", {"behavior": "jumper_fish", "stomp": false, "speed": 0}, "Vyskakuje z vody.")
	_add("barnacle", "Masožravka", "moby", "enemy:barnacle_attack_rest", "mob", {"behavior": "barnacle", "stomp": false, "speed": 0}, "Stojí na mieste a hryzie, keď je hráč blízko.")
	_add("saw_mob", "Pohyblivá píla", "moby", "enemy:saw_rest", "mob", {"behavior": "saw", "stomp": false, "speed": 120, "range": 3, "sprite": "saw"}, "Jazdí tam a späť.")
	_add("block_mob", "Drvič", "moby", "enemy:block_idle", "mob", {"behavior": "crusher", "stomp": false, "speed": 0, "sprite": "block"}, "Spadne na hráča pod sebou a vráti sa hore.")

	# Moby z Kenney Platformer Art Extended Enemies (len tie, ktoré v New Platformer Pack nie sú).
	_ext("slime_green", "Zelený sliz", "slimeGreen", {"move": ["slimeGreen", "slimeGreen_walk"], "flat": ["slimeGreen_squashed"]}, {"behavior": "walker", "stomp": true, "speed": 55})
	_ext("slime_blue", "Modrý sliz", "slimeBlue", {"move": ["slimeBlue", "slimeBlue_blue"], "flat": ["slimeBlue_squashed"]}, {"behavior": "walker", "stomp": true, "speed": 70})
	_ext("slime_pink", "Ružový sliz", "slime", {"move": ["slime", "slime_walk"], "flat": ["slime_squashed"]}, {"behavior": "hopper", "stomp": true, "speed": 70})
	_ext("snake", "Had", "snake", {"move": ["snake", "snake_walk"]}, {"behavior": "walker", "stomp": true, "speed": 45})
	_ext("snake_lava", "Lávový had", "snakeLava", {"move": ["snakeLava", "snakeLava_ani"]}, {"behavior": "pillar", "stomp": false, "speed": 0}, "Vysoký had, ktorý sa kýve na mieste. Nedá sa naň skočiť.")
	_ext("snake_slime", "Slizový had", "snakeSlime", {"move": ["snakeSlime", "snakeSlime_ani"]}, {"behavior": "pillar", "stomp": false, "speed": 0}, "Vysoký had, ktorý sa kýve na mieste. Nedá sa naň skočiť.")
	_ext("spider", "Pavúk", "spider", {"move": ["spider_walk1", "spider_walk2"], "rest": ["spider"]}, {"behavior": "walker", "stomp": true, "speed": 110})
	_ext("bat", "Netopier", "bat_hang", {"move": ["bat", "bat_fly"], "rest": ["bat_hang"]}, {"behavior": "bat", "stomp": true, "speed": 110}, "Visí hore, kým hráč nepríde blízko. Potom ho prenasleduje.")
	_ext("ghost", "Duch", "ghost_normal", {"move": ["ghost_normal", "ghost"]}, {"behavior": "ghost", "stomp": false, "speed": 55}, "Prenasleduje hráča aj cez steny, keď sa hráč nedíva.")
	_ext("piranha", "Piraňa", "piranha", {"move": ["piranha"], "jump": ["piranha"], "down": ["piranha_down"]}, {"behavior": "jumper_fish", "stomp": false, "speed": 0}, "Vyskakuje z vody.")
	_ext("fish_green", "Zelená ryba", "fishGreen", {"move": ["fishGreen", "fishGreen_swim"]}, {"behavior": "swimmer", "stomp": false, "speed": 80})
	_ext("fish_pink", "Ružová ryba", "fishPink", {"move": ["fishPink", "fishPink_swim"]}, {"behavior": "swimmer", "stomp": false, "speed": 60})
	_ext("spinner", "Vrtuľa", "spinner", {"move": ["spinner", "spinner_spin"]}, {"behavior": "saw", "stomp": false, "speed": 100, "range": 2}, "Točí sa a lieta tam a späť.")
	_ext("spinner_half", "Polovičná vrtuľa", "spinnerHalf", {"move": ["spinnerHalf", "spinnerHalf_spin"]}, {"behavior": "walker", "stomp": false, "speed": 70}, "Jazdí po zemi a reže.")
	_ext("grass_block", "Trávový blok", "grassBlock", {"move": ["grassBlock"], "jump": ["grassBlock_jump"]}, {"behavior": "hopper", "stomp": true, "speed": 70})

	# --- Ozdoby (bez kolízie) ---
	for deco in ["bush", "grass", "grass_purple", "rock", "snow", "fence", "fence_broken", "window", "sign", "sign_left", "sign_right", "sign_exit", "torch_off", "hill", "hill_top", "hill_top_smile", "chain"]:
		_add(deco, _deco_name(deco), "ozdoby", deco, "deco")
	_add("torch_on", "Horiaca fakľa", "ozdoby", "torch_on_a", "torch")
	_add("cloud_background", "Oblak v pozadí", "ozdoby", "terrain:cloud_background", "deco")

	# --- Štart a cieľ ---
	_add("start", "Štart", "specialne", "flag_off", "start", {}, "Tu začína hráč. V leveli musí byť práve jeden.")
	_add("door_exit", "Cieľ – dvere", "specialne", "door_closed", "exit", {}, "Dvere sa otvoria, keď k nim hráč príde.")
	_add("flag_exit", "Cieľ – vlajka", "specialne", "flag_red_a", "exit_flag", {}, "Cieľová vlajka.")
	_add("checkpoint", "Checkpoint", "specialne", "flag_green_a", "checkpoint", {}, "Po smrti sa hráč objaví tu.")


## Mob z rozšíreného balíka: frames = {animácia: [súbory bez .png]}.
static func _ext(id: String, name: String, icon: String, frames: Dictionary, params: Dictionary, info := "") -> void:
	params["frames"] = frames
	_add(id, name, "moby", "ext:" + icon, "mob", params, info)


static func _deco_name(id: String) -> String:
	var names := {
		"bush": "Krík", "grass": "Tráva", "grass_purple": "Fialová tráva", "rock": "Kameň", "snow": "Snehová kôpka",
		"fence": "Plot", "fence_broken": "Zlomený plot", "window": "Okno", "sign": "Tabuľa", "sign_left": "Šípka vľavo",
		"sign_right": "Šípka vpravo", "sign_exit": "Tabuľa EXIT", "torch_off": "Zhasnutá fakľa", "hill": "Kopček",
		"hill_top": "Vrchol kopčeka", "hill_top_smile": "Usmiaty kopček", "chain": "Reťaz",
	}
	return names.get(id, id)
