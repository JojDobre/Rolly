"""Svet 1 – Zelené kopce: vygeneruje data/worlds/zelene_kopce.json.

Levely sa skladajú z úsekov (textové mapy pásu nad zemou) a podzemných miestností.
Každý level sa po vygenerovaní overí v tools/reach.py (dajú sa zobrať všetky hviezdy
a dôjsť do cieľa). Levely sa dajú ďalej upravovať v editore v hre.

Spustenie:  python3 tools/world1.py
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(Path(__file__).resolve().parent))
import reach  # noqa: E402

BAND = 16      # výška pásu nad zemou (riadky 0 – 15), zem začína na riadku 13
GROUND_TOP = 13

LEGEND = {
    "#": {"t": "ground"}, "/": {"t": "slope"}, "=": {"t": "platform"}, "_": {"t": "bridge_logs"},
    "p": {"t": "block_plank"}, "Z": {"t": "secret_wall"}, "~": {"t": "backwall"}, "`": {"t": "backwall_bricks"},
    "x": {"t": "brick_brown"}, "X": {"t": "bricks_brown"}, "g": {"t": "bricks_grey"}, "B": {"t": "block_strong_empty"},
    "$": {"t": "block_coin"}, "%": {"t": "block_strong_coin"},
    "?": {"t": "block_exclamation", "content": "heart"},
    "!": {"t": "block_strong_exclamation", "content": "gem_red"},
    "h": {"t": "block_hidden", "content": "coin_gold"},
    "H": {"t": "block_hidden", "content": "gem_red"},
    "v": {"t": "block_empty_warning"}, "-": {"t": "bridge"}, "S": {"t": "spring"},
    "M": {"t": "moving_platform", "direction": "horizontal", "distance": 4},
    "V": {"t": "moving_platform", "direction": "vertical", "distance": 3},
    "|": {"t": "ladder"}, "R": {"t": "rope"},
    "^": {"t": "spikes"}, "T": {"t": "cactus"}, "m": {"t": "mushroom_red"}, "K": {"t": "block_spikes"},
    "W": {"t": "water"}, "L": {"t": "lava"}, "F": {"t": "fireball", "height": 4}, "w": {"t": "weight"},
    "*": {"t": "star"}, "c": {"t": "coin_gold"}, "s": {"t": "coin_silver"}, "b": {"t": "coin_bronze"},
    "e": {"t": "heart"},
    "k": {"t": "key_red"}, "l": {"t": "lock_red"}, "j": {"t": "key_blue"}, "J": {"t": "lock_blue"},
    "P": {"t": "start"}, "D": {"t": "door_exit"}, "E": {"t": "flag_exit"}, "C": {"t": "checkpoint"},
    "1": {"t": "door_warp", "color": "red"}, "2": {"t": "door_warp", "color": "blue"},
    "3": {"t": "door_warp", "color": "green"}, "4": {"t": "door_warp", "color": "yellow"},
    "z": {"t": "slime_normal"}, "n": {"t": "snail"}, "y": {"t": "bee"}, "Y": {"t": "fly"},
    "a": {"t": "frog"}, "u": {"t": "ladybug"}, "r": {"t": "mouse"}, "q": {"t": "spider"},
    "t": {"t": "bat"}, "o": {"t": "barnacle"}, "O": {"t": "block_mob"}, "G": {"t": "saw_mob"},
    "i": {"t": "spinner"}, "d": {"t": "fish_blue"}, "N": {"t": "piranha"}, "A": {"t": "slime_spike"},
    "Q": {"t": "slime_block"}, "U": {"t": "worm_normal"}, "+": {"t": "brick_grey"},
    ",": {"t": "grass"}, ";": {"t": "bush"}, ":": {"t": "rock"}, ">": {"t": "sign_right"},
    "<": {"t": "sign_left"}, "@": {"t": "sign_exit"}, "f": {"t": "fence"}, "&": {"t": "torch_on"},
    "{": {"t": "hill_top_smile"}, "}": {"t": "hill"},
}
SOLID = {"ground", "bricks_brown", "bricks_grey", "block_strong_empty", "brick_brown", "brick_grey", "secret_wall", "slope",
         "block_spikes", "lock_red", "lock_blue", "block_coin", "block_strong_coin", "block_exclamation",
         "block_strong_exclamation", "block_empty_warning"}


class Level:
    def __init__(self, level_id, name, height=BAND):
        self.id = level_id
        self.name = name
        self.h = height
        self.w = 0
        self.cells = {}

    # --- skladanie -----------------------------------------------------------

    def seg(self, rows):
        """Pridá úsek pásu nad zemou. rows sú spodné riadky pásu (doplní sa prázdne nebo)."""
        width = len(rows[0])
        assert all(len(r) == width for r in rows), (self.name, self.w, [len(r) for r in rows])
        assert len(rows) <= BAND, (self.name, len(rows))
        top = BAND - len(rows)
        for dy, row in enumerate(rows):
            for dx, ch in enumerate(row):
                if ch != ".":
                    self.put(self.w + dx, top + dy, ch)
        # zem pod pásom až na spodok mapy (diery v páse sú diery až dole)
        for dx in range(width):
            if self.cells.get((self.w + dx, BAND - 1), {}).get("t") == "ground":
                for y in range(BAND, self.h):
                    self.cells[(self.w + dx, y)] = {"t": "ground"}
        self.w += width
        return self.w - width

    def room(self, x, y, rows, fill="~"):
        """Podzemná miestnosť: '.' je vnútro (stena podzemia), ostatné znaky ako v legende."""
        for dy, row in enumerate(rows):
            for dx, ch in enumerate(row):
                pos = (x + dx, y + dy)
                if ch == ".":
                    self.cells[pos] = dict(LEGEND[fill])
                elif ch == " ":
                    continue
                else:
                    self.put(pos[0], pos[1], ch)
                    if LEGEND[ch]["t"] not in SOLID and ch not in "~`":
                        self.cells[pos]["bg"] = LEGEND[fill]["t"]

    def fill(self, x1, x2, y1, y2, ch, **params):
        """Vyplní obdĺžnik (vrátane okrajov). ch=None bunky vymaže."""
        for x in range(x1, x2 + 1):
            for y in range(y1, y2 + 1):
                if ch is None:
                    self.cells.pop((x, y), None)
                else:
                    self.put(x, y, ch, **params)

    def pillar(self, x1, x2, top, ch="#"):
        """Stĺp zeme od riadku top až na spodok mapy."""
        self.fill(x1, x2, top, self.h - 1, ch)

    def stamp(self, x, y, rows, bg=None):
        """Textová mapa na pozícii x, y. '.' bunku nemení. Predmety dostanú pozadie bg."""
        for dy, row in enumerate(rows):
            for dx, ch in enumerate(row):
                if ch == ".":
                    continue
                pos = (x + dx, y + dy)
                old_bg = self.cells.get(pos, {}).get("t") if self.cells.get(pos, {}).get("t") in ("backwall", "backwall_bricks") else None
                self.put(pos[0], pos[1], ch)
                layer = bg or old_bg
                if layer and LEGEND[ch]["t"] not in SOLID and ch not in "~`":
                    self.cells[pos]["bg"] = layer

    def put(self, x, y, ch, **params):
        assert ch in LEGEND, (self.name, ch, x, y)
        cell = dict(LEGEND[ch])
        cell.update(params)
        self.cells[(x, y)] = cell

    def set(self, x, y, **params):
        self.cells[(x, y)].update(params)

    def data(self):
        cells = {"%d,%d" % p: c for p, c in sorted(self.cells.items()) if 0 <= p[0] < self.w and 0 <= p[1] < self.h}
        return {"id": self.id, "name": self.name, "width": self.w, "height": self.h, "cells": cells}


def empty(width, ground=True):
    return ["." * width] * (BAND - GROUND_TOP) if not ground else None


# =============================================================================
# 1-1 Zelené kopce: klasický začiatok – bloky, piliere, diery, schody, tajná miestnosť pod zemou.
# =============================================================================

def level_1():
    L = Level("1-1", "Zelené kopce", height=26)
    L.seg([
        "..........................",
        ".................?........",
        "..........................",
        "..........................",
        "..........$...x$x?x.......",
        "..........................",
        "..P..>....;......z....,...",
        "##########################",
        "##########################",
        "##########################",
    ])
    x_pillars = L.seg([
        "...................1..........",
        "...........B.......B..........",
        ".....B.....B.......B..........",
        ".,...B..z..B...z.z.B....;..z..",
        "##############################",
        "##############################",
        "##############################",
    ])
    L.seg([
        "......................*...........",
        "..................................",
        "..................................",
        "...............xxxxxxxx...xxx%....",
        "..................................",
        "...H..............................",
        "............x$x......?.....x......",
        "..................................",
        "........................z.z.......",
        "######...#########...#############",
        "######...#########...#############",
        "######...#########...#############",
    ])
    L.seg([
        "............................",
        "...........%................",
        "............................",
        "............................",
        ".....$.....$.....$..........",
        "............................",
        "..C....n..;.......zz.....,..",
        "############################",
        "############################",
        "############################",
    ])
    x_return = L.seg([
        "..........................y...........",
        "......................................",
        "...........xx?xx..........#..#........",
        "..........................##..##......",
        "......2..............z...###..###.....",
        "........................####..####....",
        "##################################..##",
        "##################################..##",
        "##################################..##",
    ])
    x_end = L.seg([
        "..................................................",
        "..................................................",
        ".........y........................................",
        "......x?x.....!...................................",
        "..................................................",
        "..................................................",
        "..................................................",
        "...............z.z...n...ccc....................@.",
        "############...######..###########################",
        "############...######..###########################",
        "############...######..###########################",
    ])
    # záverečné schody (výška 1 až 8) a vlajka; spodok prvých troch schodov je tajná stena,
    # za ňou je skrytá komôrka s hviezdou
    for i in range(9):
        height = min(i + 1, 8)
        for dy in range(height):
            L.put(x_end + 30 + i, 12 - dy, "#")
    for i in range(3):
        L.put(x_end + 30 + i, 12, "Z")
    for i in range(3, 6):
        L.put(x_end + 30 + i, 12, "Z")
    L.put(x_end + 34, 12, "*", bg="secret_wall")
    L.put(x_end + 45, 12, "E")
    # tajná podzemná miestnosť (vstup cez červené dvere na pilieri, výstup modrými dverami)
    L.room(x_pillars + 6, 17, [
        "##########################",
        "#........................#",
        "#..c.c.c.c.c.c.c.c.c.c...#",
        "#........................#",
        "#..%..................*..#",
        "#....s.s.s.s.s.s.s.s.....#",
        "#1........BBB.........2..#",
        "##########################",
    ])
    # dvere v miestnosti: červená je pár k pilieru, modrá k návratu
    return L


# =============================================================================
# 1-2 Podzemná chodba: jaskyňa pod kopcom – bomba, výťahy nad priepasťou, netopiere,
# tajná cesta po strope a schovaný tunel pod zemou.
# =============================================================================

def level_2():
    W = 200
    L = Level("1-2", "Podzemná chodba")
    L.w = W
    L.fill(0, W - 1, 13, 15, "#")
    # vonku pred jaskyňou
    L.stamp(0, 9, [
        "..............",
        "..............",
        ".....;........",
        "..P..>..,.....",
    ])
    # jaskyňa: strop, vnútro so stenou podzemia, koncová stena
    L.fill(14, W - 1, 0, 3, "#")
    L.fill(14, W - 4, 4, 12, "~")
    L.fill(W - 3, W - 1, 0, 12, "#")
    L.fill(14, 15, 4, 9, "#")
    # úsek tehlového stropu – nad ním je tajná chodba pod holým nebom
    L.fill(62, 108, 0, 2, None)
    L.fill(62, 108, 3, 3, "x")

    # A: bloky, prvé moby, nízky strop, bomba pred tehlovou stenou
    L.stamp(16, 4, [
        "..............................",
        "..............................",
        "......*.......................",
        "....c.c.c.....................",
        "..............................",
        "..............................",
        "....x$x?x.....................",
        "..............................",
        "......z..............z.....U..",
    ])
    L.fill(28, 30, 4, 8, "#")
    L.fill(37, 37, 4, 9, "#")
    L.fill(37, 37, 10, 12, "x")
    L.cells[(35, 12)] = {"t": "bomb", "radius": 2, "bg": "backwall"}
    L.stamp(38, 11, ["c.c.c", "....."])

    # B: schody k stropu (horná cesta) a priepasť
    L.fill(46, 52, 13, 15, "~")
    L.stamp(42, 6, [
        "..........BBBBBBBBBBBBBBB",
        "......BB.................",
        "..........................",
        "..........................",
        "..BB......................",
        "..........................",
        "......................q...",
    ])
    # C: pod tehlovým stropom – priepasť s pohyblivou plošinou, netopiere, checkpoint
    L.fill(76, 87, 13, 15, "~")
    L.put(77, 11, "M", distance=5, bg="backwall")
    L.put(78, 11, "M", distance=5, bg="backwall")
    L.stamp(67, 4, [
        ".............................t.......t....",
        "..........................................",
        "..........................................",
        "...........Y..............................",
        "..........................................",
        "...................s.s.s..................",
        "..........................................",
        "..........................................",
        "...q....q...............C.....z...n.......",
    ])
    # tajná chodba po strope: mince, hviezda, srdce
    L.stamp(63, 1, [
        "..c.c.c.c.c.c.c.c.c.c.c.c.c.c.c.c.c.c.c.e...*..",
        "...............................................",
    ])
    # D: zvýšená podlaha so schovaným tunelom (vchod je tajná stena)
    L.stamp(110, 4, [
        "..........................................",
        "..........................................",
        ".........%......%.........................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..................q.....##################",
        "..........................................",
        "................bbb.......................",
    ])
    L.fill(134, 151, 10, 12, "#")
    L.fill(134, 143, 11, 12, "Z")
    L.cells[(142, 12)] = {"t": "star", "bg": "secret_wall"}
    L.fill(144, 151, 11, 12, "#")
    # E: drvič, slimák, masožravky a východ
    L.stamp(152, 4, [
        "......O.........O.........................",
        "..........................................",
        "..........................................",
        "...........................BBB............",
        "....................BBB...................",
        "..........................................",
        "..........................................",
        "..........................................",
        "..n.........U.....o.......o.......&.@.D...",
    ])
    return L


# =============================================================================
# 1-3 Nad oblakmi: bez zeme pod nohami – stĺpy, oblaky, pohyblivé a padajúce plošiny,
# miznúce mosty, pružiny a neviditeľné bloky.
# =============================================================================

def level_3():
    W = 180
    L = Level("1-3", "Nad oblakmi")
    L.w = W
    # štart
    L.fill(0, 8, 13, 15, "#")
    L.stamp(1, 12, ["P..>..;"])
    # 1: stĺpy a oblak
    L.pillar(12, 14, 11)
    L.pillar(18, 19, 9)
    L.fill(23, 26, 9, 9, "=")
    L.stamp(12, 6, ["..c.....c....c.c"])
    L.put(24, 8, "z")
    # 2: pohyblivá plošina, stĺp s včelou, padajúce bloky
    L.put(30, 10, "M", distance=5)
    L.put(31, 10, "M", distance=5)
    L.stamp(31, 7, ["c.c.c"])
    L.pillar(41, 43, 10)
    L.put(42, 6, "y")
    L.fill(48, 50, 9, 9, "v")
    L.pillar(55, 57, 10)
    # neviditeľné bloky nad stĺpom vedú k hviezde
    L.put(56, 8, "c")
    L.put(56, 7, "h")
    L.put(57, 4, "h")
    L.put(60, 1, "*")
    # 3: miznúci most, pružina s hviezdou nad ňou, ostrov s checkpointom
    L.fill(62, 70, 10, 10, "-")
    L.stamp(63, 8, ["s.s.s.s"])
    L.pillar(74, 75, 11)
    L.put(75, 10, "S")
    L.put(75, 5, "*")
    L.stamp(73, 3, ["..c.c."])
    L.fill(79, 89, 12, 15, "#")
    L.stamp(80, 11, ["..C..;...a"])
    # 4: zvislý výťah, vysoký oblak, padajúce bloky
    L.put(93, 12, "V", distance=4)
    L.put(94, 12, "V", distance=4)
    L.fill(99, 102, 7, 7, "=")
    L.put(101, 6, "Q")
    L.put(97, 3, "Y")
    L.fill(107, 109, 8, 8, "v")
    L.stamp(106, 5, ["c.c.c"])
    L.pillar(114, 116, 10)
    L.put(115, 9, "n")
    # 5: pohyblivá plošina, stĺp s pružinou a horná cesta k hviezde
    L.put(120, 10, "M", distance=6)
    L.put(121, 10, "M", distance=6)
    L.put(125, 6, "y")
    L.pillar(131, 133, 10)
    L.put(131, 9, "S")
    L.fill(134, 137, 5, 5, "=")
    L.fill(141, 144, 4, 4, "=")
    L.stamp(134, 3, ["c.c.....c.*"])
    L.fill(137, 138, 10, 10, "=")
    L.put(138, 7, "y")
    L.pillar(142, 144, 10)
    # 6: miznúci most a cieľ
    L.fill(148, 156, 11, 11, "-")
    L.put(152, 7, "Y")
    L.fill(160, W - 1, 13, 15, "#")
    L.stamp(161, 12, ["..z....,....;.E..."])
    return L


# =============================================================================
# 1-4 Hrad: lávové jamy s ohnivými guľami, drviče, píly, závažia, výťah ku kľúču
# a zamknutá brána pred cieľom.
# =============================================================================

def level_4():
    W = 190
    L = Level("1-4", "Hrad")
    L.w = W
    L.fill(0, W - 1, 0, 2, "g")
    L.fill(0, W - 1, 3, 12, "`")
    L.fill(0, W - 1, 13, 15, "g")
    L.fill(0, 0, 3, 12, "g")
    L.fill(W - 1, W - 1, 3, 12, "g")

    def lava(x1, x2, fire=()):
        L.fill(x1, x2, 13, 14, "L")
        for x in fire:
            L.cells[(x, 13)] = {"t": "fireball", "height": 4}

    # A: vstupná sieň so závažiami
    L.stamp(2, 10, [
        "..&......&.........&.......",
        "...........................",
        ".P..........A..............",
    ], bg="backwall_bricks")
    L.stamp(14, 3, ["w.....w"], bg="backwall_bricks")
    # B: lávové jamy s ohnivými guľami, rímsa s pílou a hviezdou
    lava(34, 36, fire=[35])
    L.fill(37, 38, 11, 12, "g")
    lava(39, 41, fire=[40])
    L.fill(42, 42, 10, 12, "g")
    L.fill(44, 51, 8, 8, "g")
    L.stamp(44, 3, [
        "....O...",
        "........",
        "........",
        "........",
        "..c.c.*.",
    ], bg="backwall_bricks")
    L.cells[(46, 7)] = {"t": "spinner", "bg": "backwall_bricks", "path": [44, 7, 50, 7]}
    # C: nízka chodba s pílami a bodcami na strope
    L.fill(60, 92, 3, 8, "g")
    L.fill(66, 90, 9, 9, "`")
    for x in (68, 76, 84):
        L.cells[(x, 9)] = {"t": "block_spikes"}
    L.cells[(70, 12)] = {"t": "saw_mob", "bg": "backwall_bricks", "path": [64, 12, 74, 12]}
    L.cells[(82, 12)] = {"t": "saw_mob", "bg": "backwall_bricks", "path": [78, 12, 88, 12]}
    L.stamp(62, 11, ["c.c.c........s.s.s.........c.c"], bg="backwall_bricks")
    L.cells[(96, 12)] = {"t": "checkpoint", "bg": "backwall_bricks"}
    # D: šachta s výťahom ku kľúču, hviezda za bodcami
    lava(104, 108)
    L.put(105, 12, "V", distance=7, bg="backwall_bricks")
    L.put(106, 12, "V", distance=7, bg="backwall_bricks")
    L.fill(109, 116, 5, 5, "g")
    L.fill(109, 109, 6, 12, "g")
    L.stamp(110, 4, ["....A..k"], bg="backwall_bricks")
    L.fill(119, 122, 5, 5, "g")
    L.cells[(118, 5)] = {"t": "spikes", "bg": "backwall_bricks"}
    L.cells[(122, 4)] = {"t": "star", "bg": "backwall_bricks"}
    L.fill(110, 116, 12, 12, "`")
    L.stamp(112, 12, ["..Q.."], bg="backwall_bricks")
    # E: lávové jazero s pohyblivými plošinami
    lava(136, 152, fire=[141, 146, 151])
    for x in (137, 138):
        L.put(x, 10, "M", distance=5, bg="backwall_bricks")
    for x in (147, 148):
        L.put(x, 10, "M", distance=4, bg="backwall_bricks")
    L.stamp(140, 6, ["c...c...c...c"], bg="backwall_bricks")
    # F: tajná skrýša v strope, drvič, zamknutá brána a cieľ
    L.fill(160, 176, 3, 10, "g")
    L.fill(164, 166, 7, 9, "`")
    L.cells[(165, 9)] = {"t": "star", "bg": "backwall_bricks"}
    L.put(165, 10, "+")
    L.cells[(157, 3)] = {"t": "block_mob", "bg": "backwall_bricks"}
    L.fill(174, 174, 10, 12, "l")
    L.stamp(178, 10, [
        "...&...&..",
        "..........",
        "....@.D...",
    ], bg="backwall_bricks")
    return L


# =============================================================================
# 1-5 Jazero a jaskyňa: dlhý level (300) – svah, jazero s rybami a hviezdou na dne,
# tajné dvere do jaskyne s tlačidlom, rebríkmi a modrým kľúčom, páčka s výťahom,
# priepasť so zvislým výťahom a záverečné schody.
# =============================================================================

def level_5():
    W = 300
    L = Level("1-5", "Jazero a jaskyňa", height=26)
    L.w = W
    L.fill(0, W - 1, 13, 25, "#")

    # A: štart, bloky, kopec so svahmi, prvá jama
    L.stamp(1, 9, [
        ".........x?x$x...........",
        "..........................",
        "..........................",
        ".P..>..........u..........",
    ])
    L.fill(22, 30, 12, 12, "#")
    L.fill(23, 29, 11, 11, "#")
    L.fill(24, 28, 10, 10, "#")
    for x, y in ((21, 12), (22, 11), (23, 10), (29, 10), (30, 11), (31, 12)):
        L.put(x, y, "/")
    L.stamp(24, 7, ["c.c.c"])
    L.put(26, 9, "a")
    L.fill(34, 36, 13, 25, None)
    L.put(39, 12, "r")

    # B: jazero (voda riadky 13 – 19), hviezda v jaskynke na dne, oblaky nad hladinou
    L.fill(44, 75, 13, 19, "W")
    L.fill(60, 63, 20, 21, "W")
    L.put(62, 21, "*")
    L.stamp(46, 15, [
        "....c.c.c..........c.c.c.....",
        "....d...........................",
        "...................d........",
    ])
    L.put(56, 13, "N")
    L.put(70, 13, "N")
    for x, y in ((47, 10), (53, 9), (59, 10), (65, 9), (71, 10)):
        L.fill(x, x + 1, y, y, "=")
    L.put(56, 6, "y")
    L.put(68, 6, "y")

    # C: checkpoint, tajné dvere do jaskyne, modrá zamknutá stena
    L.stamp(78, 9, [
        "..........H.......x%x.......",
        "............................",
        "............................",
        "....C....;......1.....z..n..",
    ])
    L.fill(150, 150, 3, 8, "#")
    L.fill(150, 150, 9, 12, "J")
    L.stamp(120, 9, [
        "......xxx?xxx.........",
        "......................",
        "......................",
        "...z.......Q......z...",
    ])
    # jaskyňa (riadky 17 – 23)
    L.fill(88, 148, 17, 23, "~")
    L.stamp(88, 17, [
        "............t..........t.....................t.........",
        ".......................................................",
        "...........................................j...........",
        "..............................|BBBBBBBBBBBBBBB.........",
        "..............................|.........c.c.c..........",
        "..............................|........................",
        "..1....n..........b.b.b.......|.......c.c.c.......q....",
    ], bg="backwall")
    L.cells[(105, 23)] = {"t": "switch_blue", "time": 6, "bg": "backwall"}
    for y in range(17, 24):
        L.cells[(112, y)] = {"t": "block_blue", "solid": True, "bg": "backwall"}
    # rebrík zo zeme hore na povrch (šachta)
    for y in range(13, 24):
        L.cells[(146, y)] = {"t": "ladder", "bg": "backwall"}
    # tajný výklenok s hviezdou za koncom jaskyne
    L.fill(149, 151, 22, 23, "Z")
    L.cells[(151, 23)] = {"t": "star", "bg": "secret_wall"}

    # D: druhý checkpoint, páčka s výťahom pri vysokej stene
    L.stamp(152, 9, [
        "....................................",
        "............................ccc.....",
        "....................................",
        "..A.......a...............l.........",
    ])
    L.cells[(178, 12)] = {"t": "lever", "color": "green"}
    for x in (181, 182):
        L.cells[(x, 12)] = {"t": "lift", "color": "green", "direction": "up", "distance": 4}
    L.fill(184, 184, 10, 12, "B")
    L.fill(186, 188, 6, 12, "#")
    L.stamp(189, 9, [
        "..........%.........",
        "....................",
        "....................",
        "..C......n......A...",
    ])

    # E: priepasť so zvislým výťahom a hviezdou nad ním, záverečné schody a vlajka
    L.fill(225, 238, 13, 25, None)
    L.fill(227, 228, 11, 11, "=")
    L.put(231, 12, "V", distance=6)
    L.put(232, 12, "V", distance=6)
    L.fill(235, 236, 11, 11, "=")
    L.put(231, 3, "*")
    L.put(229, 7, "Y")
    L.put(234, 5, "Y")
    L.stamp(240, 9, [
        "....x?x.....................",
        "............................",
        "............................",
        "......u....a.......z........",
    ])
    for i in range(6):
        L.fill(270 + i, 270 + i, 12 - i, 12, "#")
    L.fill(276, 277, 7, 12, "#")
    L.stamp(278, 12, ["............E.@....."[:W - 278]])
    return L


def build_world():
    levels = [level_1(), level_2(), level_3(), level_4(), level_5()]
    return levels


def main():
    levels = build_world()
    world = {
        "version": 1, "id": "zelene_kopce", "name": "Zelené kopce", "terrain": "grass",
        "background": "hills", "music": "", "order": 1, "levels": [lv.data() for lv in levels],
    }
    ok = True
    for lv in levels:
        data = lv.data()
        checkpoints = sum(1 for c in data["cells"].values() if c["t"] == "checkpoint")
        stars = sum(1 for c in data["cells"].values() if c["t"] == "star")
        result = reach.solve(data, "--map" in sys.argv)
        status = "OK" if result["ok"] else "PROBLÉM"
        print("%s %s: šírka %d, checkpointy %d, hviezdy %d – %s" % (lv.id, lv.name, lv.w, checkpoints, stars, status))
        for line in result.get("report", []):
            if "NIE" in line:
                print("     ", line)
        ok = ok and result["ok"] and stars == 3 and lv.w >= 150 and checkpoints == lv.w // 150
    path = ROOT / "data" / "worlds" / "zelene_kopce.json"
    path.write_text(json.dumps(world, ensure_ascii=False, indent="\t"))
    print("uložené", path)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
