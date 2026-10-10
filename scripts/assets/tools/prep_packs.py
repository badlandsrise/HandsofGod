"""Copy the curated Era 1 kit from the unzipped packs into the repo.

Pipeline (see assets/catalog/INVENTORY.md):
  1. unzip each pack zip from assets-raw/<pack>/ to /tmp/hog-assets/<pack>/x/ (outside the repo)
  2. python3 -I scripts/assets/tools/prep_packs.py <repo root>
  3. python3 -I scripts/assets/tools/bake_mask.py assets/models/characters/Superhero_*_FullBody.gltf
  4. godot --headless --path . --import
  5. godot --headless --path . -s res://scripts/assets/tools/build_villager_anims.gd
  6. godot --headless --path . -s res://scripts/assets/tools/build_props.gd

Reads only from /tmp/hog-assets (unzipped copies), writes to the repo's assets/.
glTF files are rewritten (JSON only) to drop normal / ORM / roughness maps and,
for characters, every texture: the game uses a flat palette shader.
"""
import json, os, shutil, sys
from PIL import Image

SRC = '/tmp/hog-assets'
REPO = sys.argv[1]
M = os.path.join(REPO, 'assets', 'models')
T = os.path.join(REPO, 'assets', 'textures')

def mk(p):
    os.makedirs(p, exist_ok=True)
    return p

# ---------------------------------------------------------------- nature (Quaternius Ultimate Nature, FBX)
nat_src = os.path.join(SRC, 'quaternius-ultimate-nature/x/FBX')
nature = []
for kind in ['PineTree', 'CommonTree', 'BirchTree']:
    for season in ['', '_Autumn', '_Snow']:
        for i in (1, 2, 3, 4, 5):
            nature.append(f'{kind}{season}_{i}')
for kind in ['CommonTree_Dead', 'BirchTree_Dead', 'CommonTree_Dead_Snow']:
    for i in (1, 2, 3):
        nature.append(f'{kind}_{i}')
for i in range(1, 6):
    nature += [f'Willow_{i}']
nature += ['Bush_1', 'Bush_2', 'Bush_Snow_1', 'Bush_Snow_2', 'BushBerries_1', 'BushBerries_2']
for i in range(1, 8):
    nature += [f'Rock_{i}', f'Rock_Moss_{i}', f'Rock_Snow_{i}']
nature += ['Grass', 'Grass_2', 'Grass_Short', 'Flowers', 'Plant_1', 'Plant_2', 'Plant_3', 'Plant_4', 'Plant_5',
           'Lilypad', 'Wheat', 'Corn_1', 'Corn_2',
           'TreeStump', 'TreeStump_Moss', 'TreeStump_Snow', 'WoodLog', 'WoodLog_Moss', 'WoodLog_Snow']
d = mk(os.path.join(M, 'nature'))
for n in nature:
    shutil.copy(os.path.join(nat_src, n + '.fbx'), os.path.join(d, n + '.fbx'))
print('nature', len(nature))

# ---------------------------------------------------------------- props (Kenney Survival Kit, GLB)
ken_src = os.path.join(SRC, 'kenney-survival-kit/x/Models/GLB format')
props = ['campfire-pit', 'campfire-stand', 'campfire-fishing-stand', 'tent', 'tent-canvas', 'tent-canvas-half',
         'structure', 'structure-canvas', 'structure-roof', 'structure-floor', 'floor-old',
         'resource-wood', 'resource-planks', 'resource-stone', 'resource-stone-large',
         'tree-log', 'tree-log-small', 'box', 'box-large', 'barrel', 'bucket', 'chest',
         'bedroll', 'bedroll-frame', 'fish', 'fish-large', 'fence', 'fence-doorway', 'fence-fortified',
         'signpost', 'signpost-single', 'workbench', 'workbench-grind',
         'tool-axe', 'tool-hammer', 'tool-hoe', 'tool-pickaxe', 'tool-shovel']
d = mk(os.path.join(M, 'props'))
mk(os.path.join(d, 'Textures'))
shutil.copy(os.path.join(ken_src, 'Textures/colormap.png'), os.path.join(d, 'Textures/colormap.png'))
for n in props:
    shutil.copy(os.path.join(ken_src, n + '.glb'), os.path.join(d, n + '.glb'))
print('props', len(props))

# ---------------------------------------------------------------- Era 2 village (Quaternius Medieval Village MegaKit, glTF)
mv_src = os.path.join(SRC, 'quaternius-medieval-village-megakit/x/Medieval Village MegaKit[Standard]')
village = ['Wall_Plaster_Straight', 'Wall_Plaster_Door_Round', 'Wall_Plaster_Window_Wide_Round',
           'Wall_Plaster_WoodGrid', 'Wall_UnevenBrick_Straight', 'Wall_UnevenBrick_Door_Round',
           'Wall_UnevenBrick_Window_Wide_Round', 'Corner_Exterior_Wood', 'Corner_Exterior_Brick',
           'Roof_RoundTiles_4x4', 'Roof_RoundTiles_4x6', 'Roof_RoundTiles_6x6', 'Roof_Wooden_2x1', 'Roof_Log',
           'Roof_Front_Brick4', 'Floor_WoodDark', 'Door_1_Round', 'Window_Wide_Round1',
           'Prop_Wagon', 'Prop_Crate', 'Prop_WoodenFence_Single', 'Prop_WoodenFence_Extension1',
           'Prop_Chimney', 'Prop_Support', 'Stairs_Exterior_Straight']
d = mk(os.path.join(M, 'village'))
td = mk(os.path.join(T, 'village'))
used_tex = set()
for n in village:
    j = json.load(open(os.path.join(mv_src, 'glTF', n + '.gltf')))
    keep_img = {}
    for mat in j.get('materials', []):
        mat.pop('normalTexture', None); mat.pop('occlusionTexture', None)
        pbr = mat.setdefault('pbrMetallicRoughness', {})
        pbr.pop('metallicRoughnessTexture', None)
        pbr['metallicFactor'] = 0
        pbr['roughnessFactor'] = 1
    # remap textures to keep only base colour ones
    imgs = j.get('images', []); texs = j.get('textures', [])
    new_imgs, new_texs, tex_map = [], [], {}
    for mat in j.get('materials', []):
        bct = mat['pbrMetallicRoughness'].get('baseColorTexture')
        if bct is None:
            continue
        old = bct['index']
        if old not in tex_map:
            img = imgs[texs[old]['source']]
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
    im = Image.open(os.path.join(mv_src, 'Textures', uri))
    im = im.resize((512, 512), Image.LANCZOS)
    im.save(os.path.join(td, uri), optimize=True)
print('village', len(village), 'textures', sorted(used_tex))

# ---------------------------------------------------------------- characters (Universal Base Characters, glTF, textures stripped)
bc = os.path.join(SRC, 'quaternius-universal-base-characters/x/Universal Base Characters[Standard]')
d = mk(os.path.join(M, 'characters'))
def strip_all_textures(src, dst_name):
    j = json.load(open(src))
    for mat in j.get('materials', []):
        mat.pop('normalTexture', None); mat.pop('occlusionTexture', None); mat.pop('emissiveTexture', None)
        pbr = mat.setdefault('pbrMetallicRoughness', {})
        pbr.pop('baseColorTexture', None); pbr.pop('metallicRoughnessTexture', None)
        pbr['metallicFactor'] = 0; pbr['roughnessFactor'] = 1
    for k in ('images', 'textures', 'samplers'):
        j.pop(k, None)
    # bin name stays the same
    json.dump(j, open(os.path.join(d, dst_name), 'w'), indent=1)
    binsrc = os.path.join(os.path.dirname(src), j['buffers'][0]['uri'])
    shutil.copy(binsrc, os.path.join(d, j['buffers'][0]['uri']))
for n in ['Superhero_Male_FullBody', 'Superhero_Female_FullBody']:
    strip_all_textures(os.path.join(bc, 'Base Characters/Godot - UE', n + '.gltf'), n + '.gltf')
hair_dir = os.path.join(bc, 'Hairstyles/Rigged to Head Bone/glTF (Godot -Unreal)')
for n in ['Hair_Beard', 'Hair_Buns', 'Hair_Buzzed', 'Hair_BuzzedFemale', 'Hair_Long', 'Hair_SimpleParted',
          'Eyebrows_Female', 'Eyebrows_Regular']:
    strip_all_textures(os.path.join(hair_dir, n + '.gltf'), n + '.gltf')
ual = os.path.join(SRC, 'quaternius-universal-animation-library/x/Universal Animation Library[Standard]/Unreal-Godot/UAL1_Standard.glb')
mk(os.path.join(d, 'anims'))
shutil.copy(ual, os.path.join(d, 'anims', 'UAL1_Standard.glb'))
print('characters ok')

# ---------------------------------------------------------------- animals (Quaternius Farm Animals, FBX)
d = mk(os.path.join(M, 'animals'))
for n in ['Sheep', 'Horse', 'Cow', 'Pig']:
    shutil.copy(os.path.join(SRC, 'quaternius-farm-animals/x/FBX', n + '.fbx'), os.path.join(d, n + '.fbx'))
print('animals ok')
