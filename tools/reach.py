"""Kontrola prejditeľnosti levelu: zjednodušená simulácia skokov hráča po mriežke.

Overí, či sa dá zo štartu dostať ku každej hviezde, kľúču a do cieľa.
Simuluje chôdzu, skoky (plný aj krátky), pády, rebríky, vodu, pružiny,
prechodové dvere, rozbíjanie tehál a objavovanie skrytých blokov hlavou,
zámky po zobratí kľúča. Moby ignoruje (dajú sa obísť alebo zničiť).

Použitie:
    python3 tools/reach.py data/worlds/zelene_kopce.json [id_levelu] [--map]
"""
import json
import math
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
T = 64

# Hodnoty z scripts/player.gd
WALK = 270.0
GRAVITY = 1500.0
JUMP = 800.0
MAX_FALL = 900.0
SPRING = 1050.0
HW = 22.0  # polovičná šírka hráča pre kolízie (guľa s polomerom 26)
HH = 24.0
DT = 1.0 / 30.0


def load_kinds():
    """id predmetu -> kind, načítané z scripts/catalog.gd."""
    text = (ROOT / "scripts" / "catalog.gd").read_text()
    kinds = {}
    for m in re.finditer(r'_add\("([a-z_]+)", "[^"]*", "[a-z]+", "[^"]*", "([a-z_]+)"', text):
        kinds[m.group(1)] = m.group(2)
    for m in re.finditer(r'_ext\("([a-z_]+)"', text):
        kinds[m.group(1)] = "mob"
    for color in ["red", "blue", "green", "yellow"]:
        kinds["key_" + color] = "key"
        kinds["lock_" + color] = "lock"
        kinds["switch_" + color] = "switch"
        kinds["block_" + color] = "color_block"
    return kinds


KINDS = load_kinds()
SOLID_KINDS = {"ground", "solid", "breakable", "item_block", "lock", "spike_block", "conveyor",
               "falling", "crate", "lift", "slope"}
ONEWAY_KINDS = {"platform", "oneway", "vanishing"}
HAZARD_KINDS = {"hazard"}


class Level:
    def __init__(self, data):
        self.w = int(data["width"])
        self.h = int(data["height"])
        self.cells = {}
        for key, cell in data["cells"].items():
            x, y = map(int, key.split(","))
            self.cells[(x, y)] = cell
        self.kind = {p: KINDS.get(c["t"], "?") for p, c in self.cells.items()}
        self.removed = set()   # rozbité tehly, odomknuté zámky
        self.revealed = set()  # objavené skryté bloky
        self.extra_solid = set()  # výťahy v hornej polohe
        self._index()

    def _index(self):
        k = self.kind
        self.solid = set()
        self.oneway = set()
        self.hazard = set()
        self.water = set()
        self.ladder = set()
        self.spring = set()
        self.lava = set()
        self.solid |= getattr(self, "extra_solid", set())
        for p, kind in k.items():
            if p in self.removed:
                continue
            if kind in SOLID_KINDS:
                if kind == "color_block" and not self.cells[p].get("solid", True):
                    continue
                self.solid.add(p)
            elif kind == "color_block" and self.cells[p].get("solid", True):
                self.solid.add(p)
            elif kind == "hidden_block" and p in self.revealed:
                self.solid.add(p)
            elif kind in ONEWAY_KINDS:
                self.oneway.add(p)
            elif kind in HAZARD_KINDS:
                self.hazard.add(p)
            elif kind == "lava" or (kind == "fireball" and any(
                    k.get((p[0] + dx, p[1])) == "lava" for dx in (-1, 1))):
                self.lava.add(p)
            elif kind == "water":
                self.water.add(p)
            elif kind == "ladder":
                self.ladder.add(p)
            elif kind == "spring":
                self.spring.add(p)
            elif kind == "mover":
                c = self.cells[p]
                dist = int(c.get("distance", 3))
                for i in range(dist + 1):
                    q = (p[0], p[1] - i) if c.get("direction") == "vertical" else (p[0] + i, p[1])
                    self.oneway.add(q)
        # predmet obklopený vodou je tiež vo vode (rovnako ako level_loader.submerged)
        for p, kind in k.items():
            if kind in {"coin", "star", "powerup", "key", "mob", "deco", "hazard", "bomb"}:
                around = sum((p[0] + dx, p[1] + dy) in self.water for dx, dy in ((0, -1), (0, 1), (-1, 0), (1, 0)))
                if (p[0], p[1] - 1) in self.water or around >= 3:
                    self.water.add(p)
                    self.hazard.discard(p) if kind != "hazard" else None
        # vrch rebríka sa dá použiť ako plošina
        for p in self.ladder:
            if (p[0], p[1] - 1) not in self.ladder:
                self.oneway.add(p)

    def find(self, kind=None, tid=None):
        return [p for p, c in self.cells.items()
                if (tid is None or c["t"] == tid) and (kind is None or self.kind[p] == kind)]


def cells_of_box(x, y, hw, hh):
    x0 = math.floor((x - hw) / T)
    x1 = math.floor((x + hw - 0.001) / T)
    y0 = math.floor((y - hh) / T)
    y1 = math.floor((y + hh - 0.001) / T)
    for cx in range(x0, x1 + 1):
        for cy in range(y0, y1 + 1):
            yield cx, cy


class Solver:
    def __init__(self, lv):
        self.lv = lv
        self.events = set()   # ("break"/"reveal", cell)
        self.visited = set()  # bunky, ktorými prešiel stred alebo telo hráča
        self.nodes = set()    # bunky, kde hráč stojí

    def blocked(self, x, y):
        lv = self.lv
        for c in cells_of_box(x, y, HW, HH):
            if c in lv.solid or c[0] < 0 or c[0] >= lv.w:
                return c
        return None

    def supported(self, cell):
        lv = self.lv
        below = (cell[0], cell[1] + 1)
        return below in lv.solid or below in lv.oneway

    def standable(self, cell):
        lv = self.lv
        return (cell not in lv.solid and cell not in lv.hazard and cell not in lv.lava
                and self.supported(cell) and 0 <= cell[0] < lv.w)

    def dangerous(self, x, y):
        lv = self.lv
        cc = (math.floor(x / T), math.floor(y / T))
        if cc in lv.lava or (cc[0], math.floor((y + HH) / T)) in lv.lava:
            return True
        for c in cells_of_box(x, y, HW - 6, HH - 6):
            if c in lv.hazard:
                # bodce, hríby a pod. zrania len v spodnej časti bunky
                tid = lv.cells[c]["t"]
                top = c[1] * T + (38 if tid in ("spikes", "mushroom_red", "mushroom_brown") else 8)
                if y + HH - 6 > top:
                    return True
        return y > (lv.h + 3) * T

    def simulate(self, x, y, vx, vy, release=None):
        """Simuluje let. Vráti zoznam dosiahnutých stavov ('stand', bunka) / ('water', bunka) / ('ladder', bunka)."""
        lv = self.lv
        out = []
        t = 0.0
        touched = []
        for _ in range(150):
            t += DT
            if release is not None and t >= release and vy < 0:
                vy *= 0.5
                release = None
            # vodorovne
            nx = x + vx * DT
            if not self.blocked(nx, y):
                x = nx
            # zvisle
            vy = min(vy + GRAVITY * DT, MAX_FALL)
            ny = y + vy * DT
            hit = self.blocked(x, ny)
            if hit is not None:
                if vy < 0:
                    # úder hlavou zospodu
                    for c in cells_of_box(x, ny, HW - 8, HH):
                        if c in lv.solid and c[1] * T + T <= y - HH + 1:
                            kind = lv.kind.get(c)
                            if kind == "breakable":
                                self.events.add(("break", c))
                    vy = 0.0
                else:
                    cell = (math.floor(x / T), math.floor((y + HH - 1) / T))
                    out.append(("stand", self._landing(x, y)))
                    break
            else:
                # skrytý blok (zastaví len úder zospodu)
                if vy < 0:
                    for c in cells_of_box(x, ny, HW - 8, HH):
                        if lv.kind.get(c) == "hidden_block" and c not in lv.revealed and c[1] * T + T <= y - HH + 1:
                            self.events.add(("reveal", c))
                # jednosmerné plošiny len pri páde zhora
                if vy > 0:
                    landed = False
                    for c in cells_of_box(x, ny, HW, HH):
                        if c in lv.oneway and y + HH <= c[1] * T + 1 and ny + HH > c[1] * T:
                            landed = True
                    if landed:
                        out.append(("stand", self._landing(x, y)))
                        break
                y = ny
            cc = (math.floor(x / T), math.floor(y / T))
            for c in cells_of_box(x, y, HW, HH):
                touched.append(c)
            if self.dangerous(x, y):
                return [], []
            if cc in lv.water:
                out.append(("water", cc))
                break
            if cc in lv.ladder:
                out.append(("ladder", cc))
            feet = (cc[0], math.floor((y + HH + 2) / T))
            if vy > 0 and (cc in lv.spring or feet in lv.spring):
                vy = -SPRING
        return out, touched

    def _landing(self, x, y):
        cell = (math.floor(x / T), math.floor((y + HH - 1) / T))
        if self.supported(cell):
            return cell
        # stojí na rohu susednej bunky
        for dx in (-1, 1):
            c = (cell[0] + dx, cell[1])
            if self.supported(c) and abs((c[0] + 0.5) * T - x) < T / 2 + HW:
                return c
        return cell

    def run(self, start):
        lv = self.lv
        sx, sy = start
        queue = []
        seen = set()
        landed, touched = self.simulate((sx + 0.5) * T, (sy + 0.5) * T, 0.0, 0.0)
        self.visited.update(touched)
        for state in landed:
            queue.append(state)
        while queue:
            state = queue.pop()
            if state in seen:
                continue
            seen.add(state)
            kind, cell = state
            self.visited.add(cell)
            results = []
            if kind == "stand":
                if not self.standable(cell):
                    continue
                self.nodes.add(cell)
                base_y = (cell[1] + 1) * T - HH
                cx = (cell[0] + 0.5) * T
                # chôdza (aj hore a dole po svahu)
                for dx in (-1, 1):
                    n = (cell[0] + dx, cell[1])
                    up = (cell[0] + dx, cell[1] - 1)
                    if n in lv.solid and lv.kind.get(n) == "slope" and up not in lv.solid:
                        results.append(("stand", up))
                    elif n not in lv.solid:
                        if self.standable(n):
                            results.append(("stand", n))
                        else:
                            # zíde z okraja
                            for vx in (WALK, WALK * 0.5, WALK * 0.15):
                                landed, touched = self.simulate(n[0] * T + T / 2 - dx * 20, base_y, vx * dx, 0.0)
                                results += landed
                                self.visited.update(touched)
                        if lv.kind.get((n[0], n[1] + 1)) == "slope":
                            results.append(("stand", (n[0], n[1] + 1)))
                # rebrík pod nohami (zlezie dole)
                if (cell[0], cell[1] + 1) in lv.ladder:
                    results.append(("ladder", (cell[0], cell[1] + 1)))
                if cell in lv.ladder:
                    results.append(("ladder", cell))
                # skoky
                for ox in (-24.0, 0.0, 24.0):
                    for vx in (-WALK, -WALK * 0.66, -WALK * 0.33, 0.0, WALK * 0.33, WALK * 0.66, WALK):
                        for release in (None, 0.12):
                            landed, touched = self.simulate(cx + ox, base_y, vx, -JUMP, release)
                            results += landed
                            self.visited.update(touched)
                # prechodové dvere
                c = lv.cells.get(cell)
                if c and c["t"] == "door_warp":
                    for other in lv.find(tid="door_warp"):
                        if other != cell and lv.cells[other].get("color", "red") == c.get("color", "red"):
                            results.append(("stand", other))
            elif kind == "ladder":
                for dy in (-1, 1):
                    n = (cell[0], cell[1] + dy)
                    if n in lv.ladder:
                        results.append(("ladder", n))
                above = (cell[0], cell[1] - 1)
                if above not in lv.ladder and above not in lv.solid:
                    results.append(("stand", above))
                for vx in (-WALK, -WALK * 0.5, WALK * 0.5, WALK):
                    landed, touched = self.simulate((cell[0] + 0.5) * T, (cell[1] + 0.5) * T, vx, 0.0)
                    results += landed
                    self.visited.update(touched)
            elif kind == "water":
                for d in ((0, -1), (0, 1), (-1, 0), (1, 0)):
                    n = (cell[0] + d[0], cell[1] + d[1])
                    if n in lv.water:
                        results.append(("water", n))
                    elif n not in lv.solid and d[1] <= 0:
                        if self.standable(n):
                            results.append(("stand", n))
                if (cell[0], cell[1] - 1) not in lv.water:
                    for vx in (-WALK * 0.6, 0.0, WALK * 0.6):
                        landed, touched = self.simulate((cell[0] + 0.5) * T, (cell[1] + 0.5) * T - 20, vx, -460.0)
                        results += [r for r in landed if r[0] != "water"]
                        self.visited.update(touched)
            for r in results:
                if r not in seen:
                    queue.append(r)


def solve(data, show_map=False):
    lv = Level(data)
    starts = lv.find(tid="start")
    if len(starts) != 1:
        return {"ok": False, "errors": ["štart: %d" % len(starts)]}
    for _ in range(12):
        solver = Solver(lv)
        solver.run(starts[0])
        changed = False
        for event, cell in solver.events:
            if event == "break" and cell not in lv.removed:
                lv.removed.add(cell)
                changed = True
            if event == "reveal" and cell not in lv.revealed:
                lv.revealed.add(cell)
                changed = True
        # tlačidlo / páčka prepne farebné bloky (zjednodušene natrvalo)
        for switch in lv.find(kind="switch") + lv.find(kind="lever"):
            if switch in solver.visited:
                color = lv.cells[switch].get("color") or lv.cells[switch]["t"].split("_")[-1]
                for block in lv.find(tid="block_" + color):
                    if block not in lv.removed and lv.cells[block].get("solid", True):
                        lv.removed.add(block)
                        changed = True
        # páčka posunie výťahy svojej farby (výťah potom môže stáť hore aj dole)
        for lever in lv.find(kind="lever"):
            if lever in solver.visited:
                color = lv.cells[lever].get("color", "red")
                for lift in lv.find(kind="lift"):
                    c = lv.cells[lift]
                    if c.get("color", "red") != color:
                        continue
                    dist = int(c.get("distance", 3))
                    top = (lift[0], lift[1] - dist if c.get("direction", "up") == "up" else lift[1] + dist)
                    if top not in lv.extra_solid:
                        lv.extra_solid.add(top)
                        changed = True
        # bomba zničí tehly a krabice v okruhu
        for bomb in lv.find(kind="bomb"):
            if bomb in solver.visited:
                radius = int(lv.cells[bomb].get("radius", 2))
                for p, kind in lv.kind.items():
                    if kind in ("breakable", "crate", "item_block") and p not in lv.removed \
                            and math.dist(p, bomb) <= radius + 0.5:
                        lv.removed.add(p)
                        changed = True
        for key in lv.find(kind="key"):
            if key in solver.visited:
                color = lv.cells[key]["t"][4:]
                for lock in lv.find(tid="lock_" + color):
                    if lock not in lv.removed:
                        lv.removed.add(lock)
                        changed = True
        if not changed:
            break
        lv._index()
    errors = []
    report = []
    for kind, label in (("star", "hviezda"), ("key", "kľúč"), ("exit", "cieľ"), ("exit_flag", "cieľ"), ("checkpoint", "checkpoint")):
        for p in sorted(lv.find(kind=kind)):
            ok = p in solver.visited or p in solver.nodes
            report.append("%s %s [%d,%d]" % ("OK " if ok else "NIE", label, p[0], p[1]))
            if not ok:
                errors.append("%s [%d,%d] sa nedá dosiahnuť" % (label, p[0], p[1]))
    if show_map:
        print_map(lv, solver)
    return {"ok": not errors, "errors": errors, "report": report, "broken": len(lv.removed), "revealed": len(lv.revealed)}


def print_map(lv, solver):
    for y in range(lv.h):
        row = []
        for x in range(lv.w):
            p = (x, y)
            kind = lv.kind.get(p)
            if p in solver.nodes:
                ch = "o"
            elif kind == "star":
                ch = "*"
            elif p in lv.solid:
                ch = "#"
            elif p in lv.oneway:
                ch = "="
            elif p in lv.water:
                ch = "~"
            elif p in lv.lava:
                ch = "L"
            elif p in lv.hazard:
                ch = "^"
            elif p in solver.visited:
                ch = "."
            else:
                ch = " "
            row.append(ch)
        print("".join(row))


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    show_map = "--map" in sys.argv
    world = json.loads(Path(args[0]).read_text())
    ok = True
    for level in world["levels"]:
        if len(args) > 1 and level["id"] != args[1]:
            continue
        result = solve(level, show_map)
        print("%s: %s (rozbité/odomknuté: %d, objavené: %d)" % (
            level["name"], "PREJDITEĽNÝ" if result["ok"] else "PROBLÉM", result.get("broken", 0), result.get("revealed", 0)))
        for line in result.get("report", []):
            print("   ", line)
        ok = ok and result["ok"]
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
