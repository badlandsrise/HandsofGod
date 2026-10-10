"""Paint the textures the Era 4 (Launch) kit adds: board-marked concrete, asphalt,
curtain-wall glazing, the mission patch and flag, a launch poster and the steam puff.

    python3 -I scripts/assets/tools/gen_era4_textures.py <repo root>

Writes assets/textures/era4/*.png. Everything is procedural (numpy + PIL), made for Hands
of God. The open hand (DESIGN 7: "Era 4: on the mission patch and the rocket's side") is
drawn by hand_shape(), the same silhouette as gen_era3_textures.py and build_era2's relief.
Colours follow the Era 4 palette (DESIGN 12.2): steel, warm white, signal orange, deep
night blue.
"""
import math, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

REPO = sys.argv[1]
OUT = os.path.join(REPO, 'assets', 'textures', 'era4')
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(41)
SS = 4
ORANGE = (242, 107, 29)
NAVY = (28, 42, 74)
WHITE = (242, 238, 230)
GOLD = (226, 180, 76)


def tile_noise(h, w, scale_y, scale_x, octaves=3):
    """Tileable value noise by summing wrapped random grids (as gen_era3_textures)."""
    out = np.zeros((h, w))
    amp = 1.0
    for o in range(octaves):
        gy, gx = max(1, scale_y * 2 ** o), max(1, scale_x * 2 ** o)
        g = rng.random((gy, gx))
        big = np.pad((g * 255).astype(np.uint8), 1, mode='wrap')
        im = Image.fromarray(big).resize(((gx + 2) * w // gx, (gy + 2) * h // gy), Image.BICUBIC)
        a = np.array(im).astype(float) / 255.0
        oy, ox = h // gy, w // gx
        out += amp * a[oy:oy + h, ox:ox + w]
        amp *= 0.5
    out -= out.min()
    return out / max(out.max(), 1e-6)


def save(name, img, mode='RGB'):
    if isinstance(img, np.ndarray):
        img = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), mode)
    img.save(os.path.join(OUT, name), optimize=True)
    print('wrote', name)


def hand_shape(draw, cx, cy, s, fill):
    """The open hand, fingers up: palm ellipse, four rounded fingers, a thumb out to the left."""
    draw.ellipse([cx - 0.42 * s, cy - 0.47 * s, cx + 0.42 * s, cy + 0.47 * s], fill=fill)
    for fx, top, w in [(-0.27, 0.95, 0.15), (-0.09, 1.07, 0.16), (0.09, 1.05, 0.16), (0.26, 0.9, 0.14)]:
        x0, x1 = cx + (fx - w / 2) * s, cx + (fx + w / 2) * s
        draw.rounded_rectangle([x0, cy - top * s, x1, cy - 0.1 * s], radius=w * s / 2, fill=fill)
    x0, y0 = cx - 0.3 * s, cy + 0.12 * s
    x1, y1 = cx - 0.66 * s, cy - 0.28 * s
    w = 0.17 * s
    draw.line([(x0, y0), (x1, y1)], fill=fill, width=int(w))
    for (x, y) in [(x0, y0), (x1, y1)]:
        draw.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=fill)


def rocket_shape(draw, cx, base_y, h, body, accent, window):
    """A friendly retro rocket standing on its fins, nose up (as build_era4's rocket)."""
    r = h * 0.12
    top = base_y - h
    draw.rounded_rectangle([cx - r, base_y - h * 0.72, cx + r, base_y - h * 0.08], radius=r * 0.3, fill=body)
    draw.polygon([(cx - r, base_y - h * 0.7), (cx, top), (cx + r, base_y - h * 0.7)], fill=body)
    draw.polygon([(cx - r * 0.45, base_y - h * 0.86), (cx, top), (cx + r * 0.45, base_y - h * 0.86)], fill=accent)
    for s in (-1, 1):
        draw.polygon([(cx + s * r, base_y - h * 0.34), (cx + s * r * 2.3, base_y), (cx + s * r * 2.0, base_y + h * 0.02),
                      (cx + s * r, base_y - h * 0.1)], fill=accent)
    draw.rectangle([cx - r, base_y - h * 0.2, cx + r, base_y - h * 0.12], fill=accent)
    draw.ellipse([cx - r * 0.5, base_y - h * 0.6, cx + r * 0.5, base_y - h * 0.6 + r], fill=window)


# ---------------------------------------------------------------- concrete: warm board-marked panels
H = W = 256
n = tile_noise(H, W, 4, 4, 4)
fine = tile_noise(H, W, 32, 32, 2)
yy, xx = np.mgrid[0:H, 0:W]
boards = 0.97 + 0.03 * np.sin(yy / H * math.tau * 8) ** 8          # faint shuttering boards
joint = np.where((yy % 128 < 2) | (xx % 128 < 2), 0.8, 1.0)       # panel joints every 2 m
tie = np.ones((H, W))
for cy in (32, 96, 160, 224):
    for cx in (32, 96, 160, 224):
        tie[(yy - cy) ** 2 + (xx - cx) ** 2 < 6] = 0.78               # form-tie holes
shade = (0.9 + 0.1 * n) * (0.95 + 0.05 * fine) * boards * joint * tie
base = np.array([226, 220, 206], float)
save('concrete.png', base[None, None, :] * shade[..., None])

# ---------------------------------------------------------------- asphalt: dark, fine aggregate
H = W = 256
n = tile_noise(H, W, 4, 4, 3)
grit = rng.random((H, W))
a = 70 + 10 * n + np.where(grit > 0.93, 18, 0) - np.where(grit < 0.05, 10, 0)
save('asphalt.png', np.stack([a, a + 2, a + 6], -1))

# ---------------------------------------------------------------- curtain wall: glass panes in slim mullions, spandrels
Wc, Hc = 256, 256      # one texture = 4 bays x 2 storeys (8 m x 6 m at the kit's UVs)
im = Image.new('RGB', (Wc * SS, Hc * SS), (180, 186, 192))
d = ImageDraw.Draw(im)
bw, sh = Wc * SS / 4, Hc * SS / 2
for s in range(2):
    for b in range(4):
        x0, y0 = b * bw, s * sh
        k = rng.random()
        sky = (96 + int(k * 26), 132 + int(k * 24), 166 + int(k * 18))
        d.rectangle([x0 + 6 * SS, y0 + sh * 0.26, x0 + bw - 6 * SS, y0 + sh - 6 * SS], fill=sky)
        # a sky reflection streak and a blind or curtain in some panes
        d.polygon([(x0 + bw * 0.2, y0 + sh - 6 * SS), (x0 + bw * 0.45, y0 + sh * 0.26), (x0 + bw * 0.6, y0 + sh * 0.26),
                   (x0 + bw * 0.35, y0 + sh - 6 * SS)], fill=(min(255, sky[0] + 40), min(255, sky[1] + 34), min(255, sky[2] + 26)))
        if k > 0.6:
            d.rectangle([x0 + 6 * SS, y0 + sh * 0.26, x0 + bw - 6 * SS, y0 + sh * 0.26 + sh * 0.18], fill=(236, 226, 200))
        d.rectangle([x0, y0, x0 + bw, y0 + sh * 0.26], fill=(232, 228, 218))      # spandrel panel
        d.rectangle([x0, y0 + sh * 0.2, x0 + bw, y0 + sh * 0.26], fill=(242, 107, 29) if (s + b) % 4 == 1 else (63, 167, 160))
    d.rectangle([0, s * sh - 2 * SS, Wc * SS, s * sh + 2 * SS], fill=(90, 98, 110))
for b in range(5):
    d.rectangle([b * bw - 3 * SS, 0, b * bw + 3 * SS, Hc * SS], fill=(90, 98, 110))
im = im.resize((Wc, Hc), Image.LANCZOS)
save('curtain_wall.png', im)

# ---------------------------------------------------------------- the mission patch: round, navy sky, the rocket and the hand
N = 512
S = N * SS
im = Image.new('RGB', (S, S), WHITE)
d = ImageDraw.Draw(im)
c = S / 2
d.ellipse([0, 0, S, S], fill=ORANGE)
d.ellipse([S * 0.06, S * 0.06, S * 0.94, S * 0.94], fill=WHITE)
d.ellipse([S * 0.1, S * 0.1, S * 0.9, S * 0.9], fill=NAVY)
for k in range(26):   # stars
    a = rng.random() * math.tau
    r = math.sqrt(rng.random()) * S * 0.36
    x, y = c + math.cos(a) * r, c + math.sin(a) * r * 0.9 - S * 0.05
    s = S * (0.006 + rng.random() * 0.008)
    d.ellipse([x - s, y - s, x + s, y + s], fill=(250, 240, 210))
# the valley: green hill and river at the bottom of the disc
d.chord([S * 0.1, S * 0.62, S * 0.9, S * 1.18], 180, 360, fill=(106, 125, 69))
d.chord([S * 0.3, S * 0.78, S * 0.7, S * 0.98], 180, 360, fill=(95, 147, 176))
# the hand, open, cupping the rocket rising from it
for k in range(3):   # the rocket's trail rising from the palm
    d.line([(c + (k - 1) * S * 0.025, c + S * 0.12), (c + (k - 1) * S * 0.012, c - S * 0.1)], fill=(250, 240, 210), width=int(S * 0.012))
hand_shape(d, c + S * 0.02, c + S * 0.24, S * 0.25, GOLD)
rocket_shape(d, c, c - S * 0.06, S * 0.32, WHITE, ORANGE, NAVY)
im = im.resize((N, N), Image.LANCZOS)
save('mission_patch.png', im)

# ---------------------------------------------------------------- the mission flag: patch on warm white, orange and navy stripes
Wf, Hf = 256 * SS, 160 * SS
im = Image.new('RGB', (Wf, Hf), WHITE)
d = ImageDraw.Draw(im)
d.rectangle([0, 0, Wf * 0.12, Hf], fill=NAVY)
d.rectangle([Wf * 0.12, 0, Wf * 0.2, Hf], fill=ORANGE)
patch = Image.open(os.path.join(OUT, 'mission_patch.png')).resize((int(Hf * 0.78), int(Hf * 0.78)), Image.LANCZOS)
mask = Image.new('L', patch.size, 0)
ImageDraw.Draw(mask).ellipse([0, 0, patch.size[0] - 1, patch.size[1] - 1], fill=255)
im.paste(patch, (int(Wf * 0.6 - patch.size[0] / 2), int(Hf * 0.11)), mask)
im = im.resize((Wf // SS, Hf // SS), Image.LANCZOS)
save('flag_mission.png', im)

# ---------------------------------------------------------------- launch poster: a sunburst, the rocket, the hand below
Wp, Hp = 192 * SS, 256 * SS
im = Image.new('RGB', (Wp, Hp), (246, 228, 190))
d = ImageDraw.Draw(im)
cx, cy = Wp / 2, Hp * 0.5
for k in range(24):
    if k % 2:
        continue
    a0, a1 = math.tau * k / 24, math.tau * (k + 1) / 24
    d.polygon([(cx, cy), (cx + math.cos(a0) * Hp, cy + math.sin(a0) * Hp), (cx + math.cos(a1) * Hp, cy + math.sin(a1) * Hp)],
              fill=(244, 200, 140))
d.rectangle([0, Hp * 0.8, Wp, Hp], fill=NAVY)
d.chord([-Wp * 0.2, Hp * 0.7, Wp * 1.2, Hp * 0.95], 180, 360, fill=(106, 125, 69))
hand_shape(d, cx + Wp * 0.02, Hp * 0.7, Wp * 0.3, GOLD)
rocket_shape(d, cx, Hp * 0.42, Hp * 0.34, WHITE, ORANGE, NAVY)
d.rectangle([Wp * 0.08, Hp * 0.86, Wp * 0.92, Hp * 0.9], fill=ORANGE)
d.rectangle([Wp * 0.2, Hp * 0.93, Wp * 0.8, Hp * 0.95], fill=(220, 214, 200))
d.rectangle([0, 0, Wp - 1, Hp - 1], outline=NAVY, width=int(Wp * 0.03))
im = im.resize((Wp // SS, Hp // SS), Image.LANCZOS)
save('poster_launch.png', im)

# ---------------------------------------------------------------- steam / smoke puff: soft billowy white, alpha falloff
N = 128
yy, xx = np.mgrid[0:N, 0:N] / (N - 1) * 2 - 1
r = np.sqrt(xx ** 2 + yy ** 2)
lumps = np.zeros((N, N))
for k in range(9):   # a cauliflower edge from overlapping blobs
    a = k / 9 * math.tau + rng.random() * 0.4
    cx, cy, rr = math.cos(a) * 0.38, math.sin(a) * 0.38, 0.42 + rng.random() * 0.12
    lumps = np.maximum(lumps, 1 - np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / rr)
lumps = np.maximum(lumps, 1 - r / 0.62)
alpha = np.clip(lumps * 2.2, 0, 1) ** 1.3
light = np.clip(0.8 + 0.25 * (-yy * 0.7 - xx * 0.3) + 0.08 * lumps, 0.6, 1.0)
rgba = np.stack([255 * light, 255 * light, 252 * light, 255 * alpha], -1)
save('puff.png', rgba, 'RGBA')
