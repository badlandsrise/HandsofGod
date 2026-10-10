# Art inventory and Era 1 kit

Source zips: `/mnt/project-files/hands-of-god/assets-raw/<pack>/` (licences in `SOURCES.md` there).
All packs are CC0. The pipeline is in `scripts/assets/tools/prep_packs.py` (its docstring lists the steps).

## What each pack contains

| Pack | Zip | Files by format (unzipped) | glTF/GLB? | Used |
| --- | --- | --- | --- | --- |
| quaternius-ultimate-nature | 23.0 MB | 150 models as fbx / obj / blend | no (FBX imports cleanly via ufbx) | **Primary: nature** |
| quaternius-medieval-village-megakit (Standard) | 161.0 MB | 176 modular pieces as gltf / fbx / obj, 54 png (2K PBR) | yes, glTF | **Era 2 buildings** (25 pieces) |
| quaternius-universal-base-characters (Standard) | 129.0 MB | 2 rigged bodies + 8 hair/eyebrow pieces, gltf / fbx, 48 png | yes, glTF | **Villagers** |
| quaternius-universal-animation-library (Standard) | 15.9 MB | 43 clips in 1 glb (+ root-motion glb, fbx) | yes, GLB | **Villager animations** |
| quaternius-farm-animals | 7.0 MB | 7 rigged animals (cow, horse, llama, pig, pug, sheep, zebra), fbx / obj / blend | no (FBX) | **Sheep, horse** (+ cow, pig for later) |
| quaternius-modular-scifi-megakit (Standard) | 48.6 MB | 190 pieces, gltf / fbx / obj | yes | later (Era 4) |
| quaternius-ultimate-spaceships | 0.9 MB | 5 ships, fbx / obj / blend | no | later (rocket) |
| kenney-survival-kit | 1.9 MB | 80 models, glb / fbx / obj, one colormap texture | yes, GLB | **Primary: Era 1 props** (38 models) |
| kenney-pirate-kit | 3.2 MB | 72 models, glb / fbx / obj | yes | later (boats, harbour) |
| kenney-city-kit-commercial | 4.1 MB | 41 models, glb / fbx / obj | yes | later (Era 4) |
| kenney-city-kit-industrial | 5.0 MB | 37 models, glb / fbx / obj | yes | later (Era 4) |
| kenney-space-kit | 6.7 MB | 153 models, glb / fbx / obj / dae / stl, 772 png previews | yes | later (launch) |
| kenney-game-icons | 1.0 MB | 425 png, 2 svg | n/a | UI worker |
| kenney-ui-pack | 1.2 MB | 870 png, 434 svg, 2 ttf, 6 ogg | n/a | UI worker |
| kenney-impact-sounds / interface-sounds / rpg-audio | 2.6 MB | 130 + 100 + 52 ogg | n/a | audio worker |
| kaykit-adventurers | 13.0 MB | 6 characters + props, glb / gltf / fbx / obj | yes | fallback only (not used) |
| kaykit-medieval-hexagon | 35.3 MB | 221 hex tiles / buildings, gltf / fbx / obj | yes | fallback only (not used) |

Missing: **Quaternius Ultimate Animated Animals** (wolf, deer, bear): `deer`, `wolf` and `bear` are
low-poly primitive placeholders (`scenes/props/deer.tscn` etc., flagged `"placeholder": true`).

## The Era 1 kit (one primary pack per category)

| Category | Pack | In the repo |
| --- | --- | --- |
| Trees, bushes (incl. berry bushes), rocks, grass, flowers, ferns, logs, stumps, crops | Quaternius Ultimate Nature | `assets/models/nature/` 105 FBX: pine / common / birch trees with autumn and snow variants, dead trees, willows, bushes, 7 rocks x plain / moss / snow, grass, plants, wheat, corn, logs, stumps |
| Fire, firewood, tools, baskets, drying rack, bedroll, fish | Kenney Survival Kit | `assets/models/props/` 38 GLB + `Textures/colormap.png` |
| Era 1 huts | built from primitives + Kenney/Quaternius pieces | `scenes/props/hut.tscn` (cone of hides on poles: reads far more primitive than the Survival Kit tents or any MegaKit piece), `hut_frame`, `hut_plot` |
| Cave, cliff, cairn, shrine, Stone Circle, flint, food store | composed from Quaternius rocks + primitives | `scenes/props/*.tscn` (built by `scripts/assets/tools/build_props.gd`) |
| Era 2 buildings | Quaternius Medieval Village MegaKit | `assets/models/village/` 25 glTF pieces (normal/ORM maps stripped, base colours at 512 px in `assets/textures/village/`), assembled into `era2_cottage`, `era2_longhouse`, `era2_shed` |
| Villagers | Quaternius Universal Base Characters + Universal Animation Library (same skeleton) | `assets/models/characters/` 2 bodies + 8 hair pieces (textures stripped, body-region mask baked into vertex colour), `anims/villager_anims.res` (17 baked clips) |
| Farm animals | Quaternius Farm Animals | `assets/models/animals/` Sheep, Horse, Cow, Pig (FBX, with Idle/Walk/... clips) |

Import settings: Godot defaults for scenes (LODs generated, shadow meshes on); **no collision is
generated**: gameplay owns its shapes, and the catalog's footprint is there to size them.

## Palette approach: shared shader remap (not a baked palette texture)

Every visual is drawn with one shader, `assets/models/materials/hog_flat.gdshader` (and a
double-sided twin), through `ArtPalette` (`scripts/assets/art_palette.gd`):

- At instance time each source material is swapped for a cached ShaderMaterial on the shared
  shader that keeps the source colour or texture (Kenney colormap, MegaKit base colours).
- The shader tames loud packs (`source_saturation`, used for Kenney), pulls each colour's
  chroma toward the nearest swatch of the **era palette** while keeping its brightness
  (`palette_pull`), then applies era saturation and a warm era tint.
- Lighting is identical for everything: soft two-tone toon diffuse, no specular, a faint rim.
  There are no outlines, because the silhouettes already read at the game's camera height.
- Era 1 palette: ochre `#c8902e`, moss `#6b7f3a`, charcoal `#3a3633`, firelight `#e8803a`, plus
  hide, bone, stone, deep moss, red ochre and lichen neutrals. Eras 2 to 4 are defined too.
- `AssetCatalog.set_era(n)` / `ArtPalette.apply_era(n)` rewrites the era uniforms on every library
  material, so the whole world regrades at once. Hand-made props use the named library
  materials in `assets/models/materials/*.tres` (stone, hide, wood, red_ochre, ...).
- Villagers use `villager.gdshader` (same lighting and era grade) with per-instance colours, so
  all villagers share three materials.

## Catalog

`assets/catalog/catalog.json` + `AssetCatalog` (`scripts/assets/asset_catalog.gd`). Visuals sit on
the ground at their footprint centre and face +Z.

- Era 1: `tree_pine tree_broad tree_birch tree_willow tree_dead bush berry_bush rock_small
  rock_large cliff grass_clump flowers fern lilypad log_fallen trunk_fallen stump campfire
  firewood_pile flint_node hut hut_frame hut_plot food_store drying_rack cairn shrine stone_circle
  cave_mouth deer* wolf* villager tool_axe tool_pickaxe bedroll fish`
- Era 2: `era2_cottage era2_longhouse era2_shed era2_wagon era2_crate era2_fence crop_wheat
  crop_corn sheep horse bear*` (`*` placeholder)
- Seasons: trees, bushes, rocks, logs and stumps have `autumn` and/or `winter` variant lists.

Contact sheets: `tests/assets/contact_era1.png`, `tests/assets/villagers.png`.
