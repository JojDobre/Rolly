"""Vykreslí náhľad všetkých levelov do levels_preview.png (približne ako v hre).

Spustenie:  python3 tools/preview_levels.py   (potrebuje Pillow)
Výber dlaždíc kopíruje logiku zo scripts/level_builder.gd.
"""
import re
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
A = ROOT / "assets"
T = 64
DECORATIONS = {"g": "grass", "u": "bush", "m": "mushroom_red", "o": "rock", ">": "sign_right"}
_cache = {}


def tex(path):
    if path not in _cache:
        _cache[path] = Image.open(A / path).convert("RGBA")
    return _cache[path]


def tile(name):
    return tex(f"tiles/terrain_grass_{name}.png")


def obj(name):
    return tex(f"objects/{name}.png")


def render(rows):
    cols, height = len(rows[0]), len(rows)
    W, H = cols * T, height * T
    cell = lambda x, y: rows[y][x] if 0 <= y < height and 0 <= x < cols else ""

    def ground(x, y, edge):
        if x < 0 or x >= cols or y >= height:
            return edge
        return y >= 0 and cell(x, y) in ("#", "/")

    def ground_tile(x, y):
        up, down = ground(x, y - 1, False), ground(x, y + 1, True)
        left, right = ground(x - 1, y, True), ground(x + 1, y, True)
        if not left and not right:
            if not up and not down: return "block"
            if not up: return "vertical_top"
            return "vertical_bottom" if not down else "vertical_middle"
        if not up and not down:
            if not left: return "horizontal_left"
            return "horizontal_right" if not right else "horizontal_middle"
        row = "top" if not up else ("bottom" if not down else "")
        col = "left" if not left else ("right" if not right else "")
        if not row and not col: return "block_center"
        if not row or not col: return "block_" + row + col
        return f"block_{row}_{col}"

    im = Image.new("RGBA", (W, H))
    band = int(300 * H / 720)
    sky, clouds, hills = tex("backgrounds/background_solid_sky.png"), tex("backgrounds/background_clouds.png"), tex("backgrounds/background_fade_hills.png")
    im.paste(sky.resize((W, H)), (0, 0))
    top = int(60 * H / 720)
    for img, y in ((clouds, top), (hills, top + band)):
        strip = img.resize((band, band))
        for x in range(0, W, band):
            im.alpha_composite(strip, (x, y))

    def put(img, cx, cy, scale=1.0, flip=False):
        if scale != 1.0:
            img = img.resize((int(img.width * scale), int(img.height * scale)))
        if flip:
            img = img.transpose(Image.FLIP_LEFT_RIGHT)
        im.alpha_composite(img, (int(cx - img.width / 2), int(cy - img.height / 2)))

    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            cx, cy, by = x * T + 32, y * T + 32, (y + 1) * T
            if c in DECORATIONS: put(obj(DECORATIONS[c]), cx, cy)
            elif c == "F":
                put(obj("door_open"), cx, cy)
                put(obj("door_open_top"), cx, cy - T)
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            cx, cy = x * T + 32, y * T + 32
            if c == "#": put(tile(ground_tile(x, y)), cx, cy)
            elif c == "=":
                left, right = cell(x - 1, y) == "=", cell(x + 1, y) == "="
                name = "cloud_middle" if left and right else "cloud_left" if right else "cloud_right" if left else "cloud"
                put(tile(name), cx, cy)
            elif c == "/":
                rising = cell(x + 1, y) == "#" or cell(x - 1, y) not in ("#", "/")
                put(tile("ramp_short_b"), cx, cy, flip=rising)
            elif c == "^": put(obj("spikes"), cx, cy)
            elif c == "*": put(obj("star"), cx, cy, 1.1)
            elif c == "K": put(obj("key_red"), cx, cy)
            elif c == "L": put(obj("lock_red"), cx, cy)
            elif c == "C": put(obj("flag_off"), cx + 20, cy - 16, 1.5)
            elif c == "B": put(obj("block_planks"), cx, (y + 1) * T - 34, 68 / 64)
            elif c == "M": put(obj("block_strong_empty"), cx, (y + 1) * T - 34, 68 / 64)
            elif c == "P":
                d = ImageDraw.Draw(im)
                d.ellipse([cx - 26, (y + 1) * T - 52, cx + 26, (y + 1) * T], fill=(140, 22, 18), outline=None)
                d.ellipse([cx - 23, (y + 1) * T - 49, cx + 23, (y + 1) * T - 3], fill=(226, 57, 47))
    return im


if __name__ == "__main__":
    shots = []
    for f in sorted((ROOT / "levels").glob("level_*.gd")):
        rows = re.findall(r'^\t"(.*)",$', f.read_text(), re.M)
        shots.append(render(rows))
    w = max(s.width for s in shots)
    h = sum(s.height for s in shots) + 20 * (len(shots) - 1)
    sheet = Image.new("RGBA", (w, h), (40, 40, 48, 255))
    y = 0
    for s in shots:
        sheet.alpha_composite(s, (0, y))
        y += s.height + 20
    sheet.convert("RGB").resize((w // 2, h // 2)).save(ROOT / "levels_preview.png")
    print("levels_preview.png", sheet.size)
