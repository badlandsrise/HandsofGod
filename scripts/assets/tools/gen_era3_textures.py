"""Paint the textures the Era 3 (Town) kit adds: slates, cobbles, stained glass, the clock
face and the town flag.

    python3 -I scripts/assets/tools/gen_era3_textures.py <repo root>

Writes assets/textures/era3/*.png. Everything is procedural (numpy + PIL), made for Hands
of God. Stone, brick, plaster and roof tiles reuse the MegaKit base colours already in
assets/textures/village/, so hand-built and pack pieces match. The open hand (DESIGN 7:
"Era 3: in the stained glass of the observatory and on the town flag") is drawn by
hand_shape(), the same palm + four fingers + thumb silhouette as build_era2's relief.
"""
import math, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

REPO = sys.argv[1]
OUT = os.path.join(REPO, 'assets', 'textures', 'era3')
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(31)
SS = 4   # supersampling for the drawn textures


def tile_noise(h, w, scale_y, scale_x, octaves=3):
    """Tileable value noise by summing wrapped random grids (as gen_era2_textures)."""
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


def save(name, img):
    if isinstance(img, np.ndarray):
        img = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), 'RGB')
    img.save(os.path.join(OUT, name), optimize=True)
    print('wrote', name)


def hand_shape(draw, cx, cy, s, fill):
    """The open hand, fingers up: palm ellipse, four rounded fingers, a thumb out to the left."""
    draw.ellipse([cx - 0.42 * s, cy - 0.47 * s, cx + 0.42 * s, cy + 0.47 * s], fill=fill)
    for fx, top, w in [(-0.27, 0.95, 0.15), (-0.09, 1.07, 0.16), (0.09, 1.05, 0.16), (0.26, 0.9, 0.14)]:
        x0, x1 = cx + (fx - w / 2) * s, cx + (fx + w / 2) * s
        draw.rounded_rectangle([x0, cy - top * s, x1, cy - 0.1 * s], radius=w * s / 2, fill=fill)
    x0, y0 = cx - 0.3 * s, cy + 0.12 * s      # the thumb: a rounded bar leaning out and up
    x1, y1 = cx - 0.66 * s, cy - 0.28 * s
    w = 0.17 * s
    draw.line([(x0, y0), (x1, y1)], fill=fill, width=int(w))
    for (x, y) in [(x0, y0), (x1, y1)]:
        draw.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=fill)


# ---------------------------------------------------------------- slates: blue-grey courses, staggered
H = W = 256
base = np.array([96, 104, 116], float)
rows, cols = 8, 6
img = np.zeros((H, W, 3))
yy, xx = np.mgrid[0:H, 0:W]
row = yy // (H // rows)
off = (row % 2) * (W // cols // 2)
col = ((xx + off) // (W // cols)) % cols
tone = (rng.random((rows, cols)) * 0.22 + 0.86)[row, col]
v = (yy % (H // rows)) / (H // rows)
lip = np.where(v > 0.88, 0.62, 1.0) * (0.92 + 0.12 * v)
seam = np.where(((xx + off) % (W // cols)) < 2, 0.7, 1.0)
grain = 0.92 + 0.12 * tile_noise(H, W, 16, 4, 2)
shade = tone * lip * seam * grain
hue = tile_noise(H, W, 2, 2, 2)[..., None]
img = base[None, None, :] * shade[..., None] * (1.0 + 0.08 * np.concatenate([hue * 0.2, hue * 0.5, -hue], -1))
save('slate.png', img)

# ---------------------------------------------------------------- cobbles: rounded setts in mortar, tileable
H = W = 256
ss = Image.new('RGB', (W * 2, H * 2), (118, 108, 96))
d = ImageDraw.Draw(ss)
rows = 8
rh = H * 2 // rows
for r in range(rows):
    y = r * rh
    x = -(r % 2) * rh * 0.5
    while x < W * 2:
        w = rh * (0.85 + rng.random() * 0.5)
        t = 150 + int(rng.random() * 46)
        col = (t + 6, t - 2, t - 14)
        for dx in (-W * 2, 0, W * 2):   # wrap horizontally
            d.rounded_rectangle([x + dx + 3, y + 3, x + dx + w - 3, y + rh - 3], radius=rh * 0.32, fill=col)
            d.rounded_rectangle([x + dx + 6, y + 5, x + dx + w - 8, y + rh * 0.45], radius=rh * 0.2,
                                fill=(min(255, col[0] + 16), min(255, col[1] + 16), min(255, col[2] + 14)))
        x += w
ss = ss.filter(ImageFilter.GaussianBlur(1.2)).resize((W, H), Image.LANCZOS)
a = np.array(ss).astype(float) * (0.93 + 0.1 * tile_noise(H, W, 4, 4, 3))[..., None]
save('cobbles.png', a)

# ---------------------------------------------------------------- stained glass: rose window with the hand
N = 512
S = N * SS
im = Image.new('RGB', (S, S), (24, 22, 26))   # lead came between the panes
d = ImageDraw.Draw(im)
c = S / 2
R = S * 0.49
jewels = [(62, 79, 160), (160, 38, 52), (47, 140, 136), (125, 31, 74), (216, 168, 52), (70, 110, 190)]
lw = int(S * 0.012)
# outer ring of 16 petals, inner ring of 8, a gold centre with the hand in white
for k in range(16):
    a0 = math.tau * k / 16
    a1 = math.tau * (k + 1) / 16
    pts = [(c + math.cos(a) * R * 0.98, c + math.sin(a) * R * 0.98) for a in np.linspace(a0, a1, 8)]
    pts += [(c + math.cos(a) * R * 0.66, c + math.sin(a) * R * 0.66) for a in np.linspace(a1, a0, 8)]
    d.polygon(pts, fill=jewels[[0, 1, 0, 2, 0, 3, 0, 5][k % 8]])
    d.line(pts + [pts[0]], fill=(24, 22, 26), width=lw)
    m = (a0 + a1) / 2
    px, py = c + math.cos(m) * R * 0.82, c + math.sin(m) * R * 0.82
    d.ellipse([px - R * 0.07, py - R * 0.07, px + R * 0.07, py + R * 0.07], fill=(232, 196, 92), outline=(24, 22, 26), width=lw)
for k in range(8):
    a0 = math.tau * k / 8 + math.pi / 8
    a1 = math.tau * (k + 1) / 8 + math.pi / 8
    pts = [(c + math.cos(a) * R * 0.64, c + math.sin(a) * R * 0.64) for a in np.linspace(a0, a1, 8)]
    pts += [(c + math.cos(a) * R * 0.4, c + math.sin(a) * R * 0.4) for a in np.linspace(a1, a0, 8)]
    d.polygon(pts, fill=jewels[[2, 0, 3, 0, 2, 0, 3, 0][k]])
    d.line(pts + [pts[0]], fill=(24, 22, 26), width=lw)
d.ellipse([c - R * 0.38, c - R * 0.38, c + R * 0.38, c + R * 0.38], fill=(226, 172, 56), outline=(24, 22, 26), width=lw)
hand_shape(d, c, c + R * 0.08, R * 0.3, (250, 240, 214))
d.ellipse([c - R, c - R, c + R, c + R], outline=(24, 22, 26), width=lw * 2)
im = im.resize((N, N), Image.LANCZOS)
save('glass_rose.png', im)

# ---------------------------------------------------------------- stained glass: a tall lancet (pointed top drawn by the mesh)
Wl, Hl = 128 * SS, 384 * SS
im = Image.new('RGB', (Wl, Hl), (24, 22, 26))
d = ImageDraw.Draw(im)
lw = int(Wl * 0.03)
nr = 9
for r in range(nr):
    for cc in range(3):
        y0, y1 = Hl * r / nr, Hl * (r + 1) / nr
        x0, x1 = Wl * cc / 3, Wl * (cc + 1) / 3
        k = (r * 2 + cc * 3 + (r * cc) % 2) % len(jewels)
        d.rectangle([x0, y0, x1, y1], fill=jewels[k], outline=(24, 22, 26), width=lw)
# a gold medallion with the hand two thirds up
mc = (Wl / 2, Hl * 0.32)
mr = Wl * 0.36
d.ellipse([mc[0] - mr, mc[1] - mr, mc[0] + mr, mc[1] + mr], fill=(226, 172, 56), outline=(24, 22, 26), width=lw)
hand_shape(d, mc[0], mc[1] + mr * 0.2, mr * 0.62, (250, 240, 214))
im = im.resize((Wl // SS, Hl // SS), Image.LANCZOS)
save('glass_lancet.png', im)

# ---------------------------------------------------------------- clock face: cream dial, twelve marks, gilt ring
N = 256
S = N * SS
im = Image.new('RGB', (S, S), (40, 52, 98))
d = ImageDraw.Draw(im)
c = S / 2
d.ellipse([S * 0.02, S * 0.02, S * 0.98, S * 0.98], fill=(214, 170, 64))
d.ellipse([S * 0.07, S * 0.07, S * 0.93, S * 0.93], fill=(242, 232, 206))
for k in range(12):
    a = math.tau * k / 12
    r0, r1 = (0.30, 0.42) if k % 3 == 0 else (0.35, 0.42)
    w = int(S * (0.04 if k % 3 == 0 else 0.022))
    d.line([(c + math.sin(a) * S * r0, c - math.cos(a) * S * r0), (c + math.sin(a) * S * r1, c - math.cos(a) * S * r1)], fill=(36, 34, 40), width=w)
d.ellipse([c - S * 0.2, c - S * 0.2, c + S * 0.2, c + S * 0.2], outline=(214, 170, 64), width=int(S * 0.012))
im = im.resize((N, N), Image.LANCZOS)
save('clock_face.png', im)

# ---------------------------------------------------------------- town flag: the hand in white on jewel blue, gold border
Wf, Hf = 256 * SS, 160 * SS
im = Image.new('RGB', (Wf, Hf), (214, 170, 64))
d = ImageDraw.Draw(im)
b = int(Hf * 0.07)
d.rectangle([b, b, Wf - b, Hf - b], fill=(56, 72, 152))
d.rectangle([b, Hf * 0.42, Wf - b, Hf * 0.58], fill=(47, 140, 136))   # the river through the valley
hand_shape(d, Wf * 0.5, Hf * 0.58, Hf * 0.34, (248, 240, 220))
im = im.resize((Wf // SS, Hf // SS), Image.LANCZOS)
save('flag_hand.png', im)

# ---------------------------------------------------------------- book spines (library shelves, printing house stacks)
Wb, Hb = 256, 64
im = Image.new('RGB', (Wb, Hb), (60, 40, 28))
d = ImageDraw.Draw(im)
x = 0
cols = [(125, 31, 74), (62, 79, 160), (47, 110, 90), (160, 64, 47), (110, 74, 50), (190, 150, 70), (90, 60, 110)]
while x < Wb:
    w = int(6 + rng.random() * 9)
    h = int(Hb * (0.72 + rng.random() * 0.28))
    col = cols[int(rng.random() * len(cols))]
    d.rectangle([x, Hb - h, x + w - 1, Hb], fill=col)
    d.line([(x + 1, Hb - h + 6), (x + w - 2, Hb - h + 6)], fill=(222, 186, 96), width=1)
    d.line([(x + 1, Hb - 8), (x + w - 2, Hb - 8)], fill=(222, 186, 96), width=1)
    d.line([(x + w - 1, Hb - h), (x + w - 1, Hb)], fill=(30, 22, 18), width=1)
    x += w
save('books.png', im)
