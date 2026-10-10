"""Paint the few tileable textures the Era 2 kit uses (thatch, wattle weave, plank boards).

    python3 -I scripts/assets/tools/gen_era2_textures.py <repo root>

Writes assets/textures/era2/*.png. Everything is procedural (numpy + PIL), made for
Hands of God. Textures are gentle: the shader grades them like any albedo, and the
game's look is flat colour, so they only add a hint of strands, courses and grain.
"""
import os, sys
import numpy as np
from PIL import Image, ImageFilter

REPO = sys.argv[1]
OUT = os.path.join(REPO, 'assets', 'textures', 'era2')
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)


def tile_noise(h, w, scale_y, scale_x, octaves=3):
    """Tileable value noise by summing wrapped random grids."""
    out = np.zeros((h, w))
    amp = 1.0
    for o in range(octaves):
        gy, gx = max(1, scale_y * 2 ** o), max(1, scale_x * 2 ** o)
        g = rng.random((gy, gx))
        img = Image.fromarray((g * 255).astype(np.uint8))
        # wrap-pad then resize so the result tiles
        big = np.pad(np.array(img), 1, mode='wrap')
        im = Image.fromarray(big).resize(((gx + 2) * w // gx, (gy + 2) * h // gy), Image.BICUBIC)
        a = np.array(im).astype(float) / 255.0
        oy, ox = h // gy, w // gx
        out += amp * a[oy:oy + h, ox:ox + w]
        amp *= 0.5
    out -= out.min()
    return out / max(out.max(), 1e-6)


def save(name, rgb):
    Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), 'RGB').save(os.path.join(OUT, name), optimize=True)
    print('wrote', name)


# ---------------------------------------------------------------- thatch: strands down the slope, 2 soft courses
H = W = 256
base = np.array([196, 152, 88], float)        # weathered straw
strands = tile_noise(H, W, 1, 64, 2)            # varies across, constant down (v = down the slope)
strands = 0.5 * strands + 0.3 * tile_noise(H, W, 4, 128, 1) + 0.2 * tile_noise(H, W, 8, 32, 2)
v = (np.arange(H)[:, None] % 128) / 128.0      # position inside a course
course = 0.86 + 0.2 * v                          # each course gets lighter toward its lower lip
lip = 1.0 - 0.22 * np.clip((v - 0.9) / 0.1, 0, 1)             # thin shadow under the lip of the course above
shade = (0.78 + 0.36 * strands) * course * lip
blot = tile_noise(H, W, 2, 2, 2)
tint = np.stack([1.0 + 0.04 * blot, 1.0 - 0.02 * blot, 1.0 - 0.10 * blot], -1)
save('thatch.png', base[None, None, :] * shade[..., None] * tint)

# ---------------------------------------------------------------- planks: vertical boards with grain
base = np.array([132, 94, 62], float)
board = (np.arange(W)[None, :] // 32)
board_tone = (rng.random(8) * 0.18 + 0.9)[board]
grain = tile_noise(H, W, 32, 2, 3)
seam = np.where((np.arange(W)[None, :] % 32) < 2, 0.6, 1.0)
shade = board_tone * (0.85 + 0.25 * grain) * seam
save('planks.png', base[None, None, :] * np.broadcast_to(shade, (H, W))[..., None])

# ---------------------------------------------------------------- daub: soft lime-washed plaster
base = np.array([233, 223, 201], float)
n = tile_noise(H, W, 4, 4, 4)
shade = 0.93 + 0.1 * n
save('daub.png', base[None, None, :] * shade[..., None])
