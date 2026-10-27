"""Vygeneruje grafiku sveta v štýle Red Ball (tráva, hlina, oblaky, kopce).

Spustenie:  python3 tools/generate_art.py   (potrebuje Pillow)
Všetky textúry sa vodorovne opakujú bez švov.
"""
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parent.parent / "assets" / "world"
S = 4  # prevzorkovanie kvôli hladkým hranám

GRASS = (126, 198, 54)
GRASS_LIGHT = (168, 224, 82)
GRASS_DARK = (74, 140, 30)
OUTLINE = (38, 62, 20)
DIRT = (139, 90, 43)
DIRT_LIGHT = (168, 116, 63)
DIRT_DARK = (104, 64, 28)


def save(img: Image.Image, name: str, size: tuple[int, int]) -> None:
    img.resize(size, Image.LANCZOS).save(OUT / name)
    print("ok", name, size)


def wrap_ellipse(d: ImageDraw.ImageDraw, w: int, h: int, box, **kw) -> None:
    """Nakreslí elipsu aj s presahom cez okraj, aby textúra nemala šev."""
    x0, y0, x1, y1 = box
    for dx in (-w, 0, w):
        for dy in (-h, 0, h):
            d.ellipse([x0 + dx, y0 + dy, x1 + dx, y1 + dy], **kw)


def dirt(size=256) -> None:
    rnd = random.Random(3)
    W = size * S
    img = Image.new("RGB", (W, W), DIRT)
    d = ImageDraw.Draw(img)
    for _ in range(26):  # kamienky
        x, y = rnd.uniform(0, W), rnd.uniform(0, W)
        r = rnd.uniform(10, 22) * S
        wrap_ellipse(d, W, W, [x - r, y - r * 0.75, x + r, y + r * 0.75], fill=DIRT_DARK)
        wrap_ellipse(d, W, W, [x - r * 0.8, y - r * 0.75, x + r * 0.8, y + r * 0.45], fill=DIRT_LIGHT)
    for _ in range(140):  # zrnká
        x, y = rnd.uniform(0, W), rnd.uniform(0, W)
        r = rnd.uniform(2, 4) * S
        wrap_ellipse(d, W, W, [x - r, y - r, x + r, y + r], fill=DIRT_DARK)
    save(img, "dirt.png", (size, size))


def grass_top(width=256, height=48) -> None:
    """Pás trávy na vrchu zeme. Horných 12 px trčí nad terén (steblá)."""
    W, H = width * S, height * S
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    top = 12 * S

    def edge(base, amp, n, phase):
        pts = []
        for i in range(0, W + 1, S):
            t = i / W * math.tau
            pts.append((i, base + amp * math.sin(t * n + phase) + amp * 0.5 * math.sin(t * n * 2 + 1)))
        return pts

    # spodný zubatý okraj trávy (presahuje do hliny)
    bottom = edge(34 * S, 4 * S, 8, 0.3)
    outline_top = [(x, top - 3 * S) for x, _ in bottom]
    d.polygon(outline_top + bottom[::-1] + [(W, H)][:0], fill=OUTLINE)
    body = [(x, top) for x, _ in bottom] + [(x, y - 3 * S) for x, y in bottom[::-1]]
    d.polygon(body, fill=GRASS)
    # svetlejší pruh hore
    d.rectangle([0, top, W, top + 6 * S], fill=GRASS_LIGHT)
    # steblá trávy nad hranou
    rnd = random.Random(7)
    x = 0.0
    while x < W:
        h = rnd.uniform(6, 12) * S
        w = rnd.uniform(5, 8) * S
        for dx in (-W, 0, W):
            cx = x + dx
            d.polygon([(cx - w, top + 2 * S), (cx + w * 0.2, top - h - 2 * S), (cx + w, top + 2 * S)], fill=OUTLINE)
            d.polygon([(cx - w + 2.5 * S, top + 3 * S), (cx + w * 0.2, top - h + 1 * S), (cx + w - 2.5 * S, top + 3 * S)], fill=GRASS_LIGHT)
        x += rnd.uniform(14, 26) * S
    # tmavšie bodky v tráve
    for _ in range(30):
        cx, cy = rnd.uniform(0, W), rnd.uniform(top + 10 * S, 28 * S)
        r = rnd.uniform(1.5, 3) * S
        wrap_ellipse(d, W, 10**9, [cx - r, cy - r, cx + r, cy + r], fill=GRASS_DARK)
    save(img, "grass_top.png", (width, height))


def clouds(width=1024, height=360) -> None:
    W, H = width * S, height * S
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    shade = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ds, d = ImageDraw.Draw(shade), ImageDraw.Draw(img)
    rnd = random.Random(11)
    for i in range(5):
        cx = (i + rnd.uniform(0.1, 0.6)) * W / 5
        cy = rnd.uniform(0.3, 0.7) * H
        scale = rnd.uniform(0.7, 1.15)
        puffs = []
        for _ in range(7):
            px = cx + rnd.uniform(-110, 110) * S * scale
            py = cy + rnd.uniform(-25, 10) * S * scale
            r = rnd.uniform(38, 62) * S * scale
            puffs.append((px, py, r))
        base_y = max(py + r * 0.5 for px, py, r in puffs)
        for px, py, r in puffs:
            wrap_ellipse(ds, W, 10**9, [px - r, py - r + 6 * S, px + r, min(py + r + 6 * S, base_y + 6 * S)], fill=(205, 232, 245, 255))
            wrap_ellipse(d, W, 10**9, [px - r, py - r, px + r, min(py + r, base_y)], fill=(255, 255, 255, 255))
    shade.alpha_composite(img)
    save(shade, "clouds.png", (width, height))


def hills(name, width, height, color, light, outline, n, amp, base, trees, seed, fade_from=0.6) -> None:
    W, H = width * S, height * S
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rnd = random.Random(seed)
    phases = [rnd.uniform(0, math.tau) for _ in range(3)]

    def y_at(x):
        t = x / W * math.tau
        return H * base - H * amp * (0.6 * math.sin(t * n + phases[0]) + 0.3 * math.sin(t * n * 2 + phases[1]) + 0.1 * math.sin(t * n * 3 + phases[2]))

    # stromy (guľaté koruny) za kopcom
    for _ in range(trees):
        x = rnd.uniform(0, W)
        r = rnd.uniform(18, 34) * S
        y = y_at(x) - r * 0.4
        for dx in (-W, 0, W):
            if outline:
                d.ellipse([x + dx - r - 3 * S, y - r - 3 * S, x + dx + r + 3 * S, y + r + 3 * S], fill=outline)
            d.ellipse([x + dx - r, y - r, x + dx + r, y + r], fill=light)
    pts = [(x, y_at(x)) for x in range(0, W + 1, S)]
    if outline:
        d.polygon([(x, y - 4 * S) for x, y in pts] + [(W, H), (0, H)], fill=outline)
    d.polygon(pts + [(W, H), (0, H)], fill=color)
    # Spodok kopcov sa stratí do neba, aby jamy v teréne nevyzerali ako zem.
    fade = Image.new("L", (1, H))
    for y in range(H):
        t = (y / H - fade_from) / (1.0 - fade_from)
        fade.putpixel((0, y), int(255 * min(1.0, max(0.0, 1.0 - t))))
    alpha = img.getchannel("A")
    img.putalpha(Image.composite(alpha, Image.new("L", (W, H), 0), fade.resize((W, H))))
    save(img, name, (width, height))


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    dirt()
    grass_top()
    clouds()
    hills("hills_far.png", 1024, 420, (176, 220, 196), (190, 230, 206), None, 2, 0.16, 0.55, 14, 1, fade_from=0.5)
    hills("hills_near.png", 1024, 320, (120, 190, 70), (98, 168, 52), (60, 110, 34), 3, 0.14, 0.45, 9, 2, fade_from=0.4)
