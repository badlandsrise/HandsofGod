"""Copy the extra pack pieces the Era 3 (Town) kit uses into the repo.

    python3 -I scripts/assets/tools/prep_era3.py <repo root> <unzipped packs root>

<unzipped packs root> holds each pack zip from assets-raw/<pack>/ unzipped into <pack>/
(outside the repo; the packs folder itself is read-only). Same treatment as prep_era2.py:
MegaKit glTF JSON is rewritten to drop normal / ORM / roughness maps and point base colours
at assets/textures/village/ (512 px). Window glass, which the pack draws as a nearly clear
alpha blend, becomes an opaque deep blue-grey pane (the palette shader has no alpha).
Then: python3 -I scripts/assets/tools/gen_era3_textures.py <repo>, godot --import, and
godot --headless --path . -s res://scripts/assets/tools/build_era3.gd
"""
import json, os, shutil, sys
from PIL import Image

REPO, SRC = sys.argv[1], sys.argv[2]
M = os.path.join(REPO, 'assets', 'models')
T = os.path.join(REPO, 'assets', 'textures')
GLASS = [0.16, 0.21, 0.27, 1.0]


def mk(p):
    os.makedirs(p, exist_ok=True)
    return p


# ---------------------------------------------------------------- MegaKit: stone walls, glazed windows, tile roofs
mv_src = os.path.join(SRC, 'quaternius-medieval-village-megakit/Medieval Village MegaKit[Standard]')
village = [
    # stone ("uneven brick") walls and the wide brick corner
    'Wall_UnevenBrick_Straight', 'Wall_UnevenBrick_Window_Wide_Round', 'Wall_UnevenBrick_Window_Thin_Round',
    'Wall_UnevenBrick_Window_Wide_Flat', 'Wall_UnevenBrick_Door_Round', 'Wall_UnevenBrick_Door_Flat',
    'Wall_Plaster_Window_Wide_Flat', 'Wall_Plaster_Straight', 'Wall_Plaster_Door_Flat', 'Wall_Plaster_Window_Wide_Round',
    'Corner_Exterior_Brick', 'Corner_ExteriorWide_Brick', 'Corner_Exterior_Wood',
    # glazed windows, shutters, doors and frames
    'Window_Wide_Round1', 'Window_Thin_Round1', 'Window_Wide_Flat1', 'Window_Thin_Flat1',
    'WindowShutters_Wide_Flat_Open', 'WindowShutters_Thin_Flat_Open', 'WindowShutters_Wide_Round_Open',
    'WindowShutters_Thin_Round_Open',
    'Door_8_Round', 'Door_8_Flat', 'Door_1_Flat', 'Door_2_Round', 'DoorFrame_Round_Brick', 'DoorFrame_Flat_Brick',
    # roofs
    'Roof_RoundTiles_4x4', 'Roof_RoundTiles_4x6', 'Roof_RoundTiles_4x8', 'Roof_RoundTiles_6x6', 'Roof_RoundTiles_6x8',
    'Roof_RoundTiles_6x10', 'Roof_RoundTiles_8x8', 'Roof_RoundTiles_8x10', 'Roof_Tower_RoundTiles',
    'Roof_Front_Brick4', 'Roof_Front_Brick6', 'Roof_Front_Brick8', 'Roof_Dormer_RoundTile',
    # balconies, railings, paving, kerbs, steps, brick stacks
    'Balcony_Cross_Straight', 'Balcony_Simple_Straight', 'Prop_MetalFence_Ornament', 'Prop_MetalFence_Simple',
    'Floor_RedBrick', 'Floor_UnevenBrick', 'Prop_ExteriorBorder_Straight1', 'Prop_ExteriorBorder_Corner',
    'Stairs_Exterior_Straight', 'Prop_Brick1', 'Prop_Brick2', 'Prop_Brick3', 'Prop_Chimney', 'Prop_Wagon', 'Prop_Crate',
]
d = mk(os.path.join(M, 'village'))
td = mk(os.path.join(T, 'village'))
used_tex = set()
for n in village:
    j = json.load(open(os.path.join(mv_src, 'glTF', n + '.gltf')))
    for mat in j.get('materials', []):
        mat.pop('normalTexture', None); mat.pop('occlusionTexture', None)
        pbr = mat.setdefault('pbrMetallicRoughness', {})
        pbr.pop('metallicRoughnessTexture', None)
        pbr['metallicFactor'] = 0
        pbr['roughnessFactor'] = 1
        if mat.get('name') == 'MI_WindowGlass':
            mat.pop('alphaMode', None)
            pbr['baseColorFactor'] = GLASS
    imgs = j.get('images', []); texs = j.get('textures', [])
    new_imgs, new_texs, tex_map = [], [], {}
    for mat in j.get('materials', []):
        bct = mat['pbrMetallicRoughness'].get('baseColorTexture')
        if bct is None:
            continue
        old = bct['index']
        img = imgs[texs[old]['source']]
        if not os.path.exists(os.path.join(mv_src, 'Textures', img['uri'])):
            del mat['pbrMetallicRoughness']['baseColorTexture']   # not shipped in the pack: flat dark iron
            mat['pbrMetallicRoughness']['baseColorFactor'] = [0.16, 0.15, 0.14, 1.0]
            continue
        if old not in tex_map:
            used_tex.add(img['uri'])
            new_imgs.append({'mimeType': 'image/png', 'name': img['name'],
                             'uri': '../../textures/village/' + img['uri']})
            t = dict(texs[old]); t['source'] = len(new_imgs) - 1
            new_texs.append(t)
            tex_map[old] = len(new_texs) - 1
        bct['index'] = tex_map[old]
    if new_imgs:
        j['images'] = new_imgs; j['textures'] = new_texs
    else:
        j.pop('images', None); j.pop('textures', None)
    json.dump(j, open(os.path.join(d, n + '.gltf'), 'w'), indent=1)
    shutil.copy(os.path.join(mv_src, 'glTF', n + '.bin'), os.path.join(d, n + '.bin'))
for uri in sorted(used_tex):
    dst = os.path.join(td, uri)
    if os.path.exists(dst):
        continue
    im = Image.open(os.path.join(mv_src, 'Textures', uri))
    im = im.resize((512, 512), Image.LANCZOS)
    im.save(dst, optimize=True)
print('village', len(village), 'textures', sorted(used_tex))

# ---------------------------------------------------------------- Kenney Pirate Kit: sailing ships and cargo crates
pk = os.path.join(SRC, 'kenney-pirate-kit/Models/GLB format')
d = mk(os.path.join(M, 'boats'))
mk(os.path.join(d, 'Textures'))
if not os.path.exists(os.path.join(d, 'Textures/colormap.png')):
    shutil.copy(os.path.join(pk, 'Textures/colormap.png'), os.path.join(d, 'Textures/colormap.png'))
ships = ['ship-small', 'ship-medium', 'crate', 'crate-bottles']
for n in ships:
    shutil.copy(os.path.join(pk, n + '.glb'), os.path.join(d, n + '.glb'))
print('boats', len(ships))
