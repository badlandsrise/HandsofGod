"""Copy the pack pieces the Era 4 (Launch) kit uses into the repo.

    python3 -I scripts/assets/tools/prep_era4.py <repo root> <unzipped packs root>

<unzipped packs root> holds each pack zip from assets-raw/<pack>/ unzipped into <pack>/
(outside the repo; the packs folder itself is read-only). Kenney GLBs are copied as they
are: each kit keeps its own colormap in a Textures/ folder beside its models, because the
GLBs reference it by that relative path (City Kit Industrial and Commercial ship different
colormaps). The Space Kit uses flat material colours, no textures.
Then: python3 -I scripts/assets/tools/gen_era4_textures.py <repo>, godot --import, and
godot --headless --path . -s res://scripts/assets/tools/build_era4.gd
"""
import os, shutil, sys

REPO, SRC = sys.argv[1], sys.argv[2]
M = os.path.join(REPO, 'assets', 'models')


def mk(p):
    os.makedirs(p, exist_ok=True)
    return p


def kit(pack, sub, dest, names, colormap=True):
    src = os.path.join(SRC, pack, 'Models', sub)
    d = mk(os.path.join(M, dest))
    if colormap:
        mk(os.path.join(d, 'Textures'))
        shutil.copy(os.path.join(src, 'Textures', 'colormap.png'), os.path.join(d, 'Textures', 'colormap.png'))
    for n in names:
        shutil.copy(os.path.join(src, n + '.glb'), os.path.join(d, n + '.glb'))
    print(dest, len(names))


# City Kit Industrial: storage tanks for the refinery, shipping containers, the water tower
kit('kenney-city-kit-industrial', 'GLB format', 'industry', [
    'detail-tank', 'detail-tank-large', 'water-tower', 'shipping-container-a', 'shipping-container-b',
    'shipping-container-c'])
# City Kit Commercial: low-detail blocks for the far city skyline, shop awnings
kit('kenney-city-kit-commercial', 'GLB format', 'city', [
    'low-detail-building-a', 'low-detail-building-b', 'low-detail-building-c', 'low-detail-building-wide-a',
    'low-detail-building-wide-b', 'detail-awning-wide'])
# Space Kit: the dishes on mission control
kit('kenney-space-kit', 'GLTF format', 'space', ['satelliteDish_detailed', 'satelliteDish_large'], colormap=False)
