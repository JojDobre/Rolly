"""Vykreslí náhľad všetkých levelov do levels_preview.png (približne ako v hre).

Spustenie:  python3 tools/preview_levels.py   (potrebuje Pillow)
"""
import math
import re
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
A = ROOT / "assets"
T = 64
OUTLINE = (38, 62, 20, 255)
GRASS = (126, 198, 54, 255)


def load(p):
    return Image.open(A / p).convert("RGBA")


dirt, grass = load("world/dirt.png"), load("world/grass_top.png")
clouds, far, near = load("world/clouds.png"), load("world/hills_far.png"), load("world/hills_near.png")
spikes, star, key, lock = load("objects/spikesLow.png"), load("items/starGold.png"), load("objects/keyRed.png"), load("objects/blockRed_lock.png")
flag_red, flag_green = load("objects/flagRed_down.png"), load("objects/flagGreen_down.png")
arrow, crate, ball = load("objects/signArrow_right.png"), load("objects/crate_wood.png"), load("ui/ball_icon.png")


def tiled(tex, w, h, ox=0, oy=0):
    out = Image.new("RGBA", (w, h))
    for x in range(-(ox % tex.width), w, tex.width):
        for y in range(-(oy % tex.height), h, tex.height):
            out.alpha_composite(tex, (x, y)) if x >= 0 and y >= 0 else out.paste(tex, (x, y), tex)
    return out


def render(rows):
    W, H = len(rows[0]) * T, len(rows) * T
    im = Image.new("RGBA", (W, H))
    d = ImageDraw.Draw(im)
    for y in range(H):
        t = y / H
        d.line([(0, y), (W, y)], fill=(int(120 + 95 * t), int(200 + 40 * t), int(240 + 10 * t), 255))
    k = H / 720
    for tex, top, extra in ((clouds, 30, 0), (far, None, 0), (near, None, -60)):
        t2 = tex.resize((int(tex.width * k), int(tex.height * k)))
        y = int(top * k) if top is not None else int(H - (tex.height + extra) * k)
        for x in range(0, W, t2.width):
            im.alpha_composite(t2, (x, 0) if False else (x, max(0, y)))
    cell = lambda x, y: rows[y][x] if 0 <= y < len(rows) and 0 <= x < len(rows[0]) else ""
    solid = lambda x, y: cell(x, y) in ("#", "/")
    dirt_full = tiled(dirt, W, H)
    mask = Image.new("L", (W, H), 0)
    md = ImageDraw.Draw(mask)
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if c == "#":
                md.rectangle([x * T, y * T, x * T + T - 1, y * T + T - 1], fill=255)
            elif c == "=":
                md.rectangle([x * T, y * T, x * T + T - 1, y * T + 49], fill=255)
            elif c == "/":
                rising = cell(x + 1, y) == "#" or not solid(x - 1, y)
                pts = [(x * T, (y + 1) * T), ((x + 1) * T, y * T), ((x + 1) * T, (y + 1) * T)] if rising else \
                      [(x * T, y * T), ((x + 1) * T, (y + 1) * T), (x * T, (y + 1) * T)]
                md.polygon(pts, fill=255)
    im.paste(dirt_full, (0, 0), mask)
    d = ImageDraw.Draw(im)
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            L, R, Tp = x * T, (x + 1) * T, y * T
            if c == "#":
                if not solid(x - 1, y): d.line([(L, Tp), (L, Tp + T)], fill=OUTLINE, width=5)
                if not solid(x + 1, y): d.line([(R, Tp), (R, Tp + T)], fill=OUTLINE, width=5)
                if not solid(x, y + 1): d.line([(L, Tp + T), (R, Tp + T)], fill=OUTLINE, width=5)
            if c == "=":
                d.line([(L, Tp + 50), (R, Tp + 50)], fill=OUTLINE, width=5)
                if cell(x - 1, y) != "=": d.line([(L, Tp), (L, Tp + 50)], fill=OUTLINE, width=5)
                if cell(x + 1, y) != "=": d.line([(R, Tp), (R, Tp + 50)], fill=OUTLINE, width=5)
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            L, Tp = x * T, y * T
            if (c == "#" and not solid(x, y - 1)) or (c == "=" and cell(x, y - 1) != "="):
                im.alpha_composite(grass.crop(((L % 256), 0, (L % 256) + T, grass.height)), (L, Tp - 12))
                flat = "=" if c == "=" else "#/"
                for side, cx in ((-1, L), (1, L + T)):
                    if cell(x + side, y) == "" or cell(x + side, y) not in flat:
                        d.ellipse([cx - 15, Tp - 7, cx + 15, Tp + 23], fill=OUTLINE)
                        d.ellipse([cx - 11, Tp - 3, cx + 11, Tp + 19], fill=GRASS)
            elif c == "/":
                rising = cell(x + 1, y) == "#" or not solid(x - 1, y)
                L2 = int(T * math.sqrt(2))
                strip = grass.crop((0, 0, L2, grass.height)).rotate(45 if rising else -45, expand=True, resample=Image.BICUBIC)
                sx, sy = (L, (y + 1) * T) if rising else (L, Tp)
                im.alpha_composite(strip, (sx - (0 if rising else 8), (sy - strip.height + 8) if rising else (sy - 8)))
    def put(img, cx, cy, s=1.0):
        if s != 1.0: img = img.resize((int(img.width * s), int(img.height * s)))
        im.alpha_composite(img, (int(cx - img.width / 2), int(cy - img.height / 2)))
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            cx, cy, by = x * T + 32, y * T + 32, (y + 1) * T
            if c == "^": put(spikes, cx, by - 13)
            elif c == "*": put(star, cx, cy, 0.75)
            elif c == "K": put(key, cx, cy, 1.5)
            elif c == "L": put(lock, cx, cy)
            elif c in "CF":
                f = (flag_green if c == "C" else flag_red).resize((24, 98))
                im.alpha_composite(f, (cx - 12, by - 98))
            elif c in "BM": put(crate, cx, by - 34, 68 / 70)
            elif c == ">": im.alpha_composite(arrow, (cx - 24, by - 55))
            elif c == "P": put(ball.resize((52, 52)), cx, by - 26)
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
