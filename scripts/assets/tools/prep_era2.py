"""Copy the extra pack pieces the Era 2 (Village) kit uses into the repo.

    python3 -I scripts/assets/tools/prep_era2.py <repo root> <unzipped packs root>

<unzipped packs root> holds each pack zip from assets-raw/<pack>/ unzipped into <pack>/
(outside the repo). Same treatment as prep_packs.py: MegaKit glTF JSON is rewritten to drop
normal / ORM / roughness maps and point base colours at assets/textures/village/ (512 px).
Then: python3 -I scripts/assets/tools/gen_era2_textures.py <repo>, godot --import, and
godot --headless --path . -s res://scripts/assets/tools/build_era2.gd
"""
import json, os, shutil, sys
from PIL import Image

REPO, SRC = sys.argv[1], sys.argv[2]
M = os.path.join(REPO, 'assets', 'models')
T = os.path.join(REPO, 'assets', 'textures')


def mk(p):
    os.makedirs(p, exist_ok=True)
    return p


# ---------------------------------------------------------------- MegaKit (doors, shutters, plinth walls, chimney)
mv_src = os.path.join(SRC, 'quaternius-medieval-village-megakit/Medieval Village MegaKit[Standard]')
village = ['Wall_Plaster_Straight_Base', 'Wall_Plaster_Window_Thin_Round', 'Wall_Plaster_Door_Flat',
           'WindowShutters_Wide_Round_Open', 'WindowShutters_Thin_Round_Open', 'WindowShutters_Wide_Flat_Open',
           'Door_2_Round', 'Door_4_Flat', 'DoorFrame_Round_WoodDark', 'Prop_Chimney2',
           'Prop_WoodenFence_Extension2', 'Floor_WoodLight', 'Roof_Support2']
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

# ---------------------------------------------------------------- Kenney Survival Kit: bronze-age tools and work stations
ken_src = os.path.join(SRC, 'kenney-survival-kit/Models/GLB format')
d = os.path.join(M, 'props')
props = ['workbench', 'workbench-anvil', 'workbench-grind', 'box-open', 'barrel-open',
         'tool-axe-upgraded', 'tool-hoe-upgraded', 'tool-hammer-upgraded', 'tool-shovel-upgraded', 'tool-pickaxe-upgraded']
for n in props:
    shutil.copy(os.path.join(ken_src, n + '.glb'), os.path.join(d, n + '.glb'))
print('props', len(props))

# ---------------------------------------------------------------- Kenney Pirate Kit: rowing boats (own colormap)
pk = os.path.join(SRC, 'kenney-pirate-kit/Models/GLB format')
d = mk(os.path.join(M, 'boats'))
mk(os.path.join(d, 'Textures'))
shutil.copy(os.path.join(pk, 'Textures/colormap.png'), os.path.join(d, 'Textures/colormap.png'))
for n in ['boat-row-small', 'boat-row-large', 'tool-paddle']:
    shutil.copy(os.path.join(pk, n + '.glb'), os.path.join(d, n + '.glb'))
print('boats ok')
