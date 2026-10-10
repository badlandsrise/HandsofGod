# Art inventory and Era 1 kit

Source zips: `/mnt/project-files/hands-of-god/assets-raw/<pack>/` (licences in `SOURCES.md` there).
All packs are CC0. The pipeline is in `scripts/assets/tools/prep_packs.py` (its docstring lists the steps).

## What each pack contains

| Pack | Zip | Files by format (unzipped) | glTF/GLB? | Used |
| --- | --- | --- | --- | --- |
| quaternius-ultimate-nature | 23.0 MB | 150 models as fbx / obj / blend | no (FBX imports cleanly via ufbx) | **Primary: nature** |
| quaternius-medieval-village-megakit (Standard) | 161.0 MB | 176 modular pieces as gltf / fbx / obj, 54 png (2K PBR) | yes, glTF | **Era 2 buildings** (25 pieces), **Era 3 town** (55 more: brick and stone walls, glazed windows, doors, tile roofs, balconies, dormers, wagon) |
| quaternius-universal-base-characters (Standard) | 129.0 MB | 2 rigged bodies + 8 hair/eyebrow pieces, gltf / fbx, 48 png | yes, glTF | **Villagers** |
| quaternius-universal-animation-library (Standard) | 15.9 MB | 43 clips in 1 glb (+ root-motion glb, fbx) | yes, GLB | **Villager animations** |
| quaternius-farm-animals | 7.0 MB | 7 rigged animals (cow, horse, llama, pig, pug, sheep, zebra), fbx / obj / blend | no (FBX) | **Sheep, horse** (+ cow, pig for later) |
| quaternius-modular-scifi-megakit (Standard) | 48.6 MB | 190 pieces, gltf / fbx / obj | yes | later (Era 4) |
| quaternius-ultimate-spaceships | 0.9 MB | 5 ships, fbx / obj / blend | no | later (rocket) |
| kenney-survival-kit | 1.9 MB | 80 models, glb / fbx / obj, one colormap texture | yes, GLB | **Primary: Era 1 props** (38 models) |
| kenney-pirate-kit | 3.2 MB | 72 models, glb / fbx / obj | yes | **Era 2 row boats** (2 boats + paddle, own colormap in `assets/models/boats/`), **Era 3 ships and cargo** (ship-small, ship-medium, crate, crate-bottles) |
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

## The Era 2 (Village) kit

Built in code by `scripts/assets/tools/build_era2.gd` into `scenes/props/era2/*.scn` (98 scenes):

    godot --headless --path . -s res://scripts/assets/tools/build_era2.gd [-- --only=mill,fields]

Pack pieces are copied in by `scripts/assets/tools/prep_era2.py` (MegaKit walls, doors, shutters,
chimney; Kenney workbenches, barrels, crates; Pirate Kit row boats), and the thatch / plank / daub
textures are painted by `scripts/assets/tools/gen_era2_textures.py`. Everything else (roofs,
timber frames, ovens, kilns, fields, piles, tools, stalls, the temple) is modelled from the
named palette materials; Era 2 adds daub, timber, straw, thatch, terracotta, clay, soil, crop
greens and golds, bronze, wool, linen, dyed cloth and hand gold (`ArtPalette.NAMED`).

- Buildings have three stages like the Era 1 hut: `<id>_plot` (pegged, strung outline with the
  materials stacked beside it), `<id>_frame` (timber frame, scaffold and ladder), `<id>` (done).
- Moving parts are named nodes running `scripts/assets/spinner.gd` (`speed`, `axis`, `spinning`):
  `mill/Sails`, `kiln/Wheel` (potter's wheel), `well/Windlass` (stopped by default).
- The temple of the Hand keeps the Era 1 shrine stone as its altar, with the hand painted in
  red ochre; the hand is also on the pediment, the doors, the ridge finial and the painted pots
  (section 5: "painted on pots and temple doors").
- Villagers: `VillagerVisual.set_era(2)` switches to woven clothes (linen undershirt, hose or
  long skirt, trim bands, belts, aprons) and hats on some outfits (straw hat, coif, felt cap,
  headscarf, on a head-bone attachment). Without a call it follows `ArtPalette.current_era()`.

Import settings: Godot defaults for scenes (LODs generated, shadow meshes on); **no collision is
generated**: gameplay owns its shapes, and the catalog's footprint is there to size them.

## The Era 3 (Town) kit

Built in code by `scripts/assets/tools/build_era3.gd` (it extends `build_era2.gd` and reuses its
mesh helpers) into `scenes/props/era3/*.scn` (90 scenes):

    godot --headless --path . -s res://scripts/assets/tools/build_era3.gd [-- --only=townhouse,harbour]

Pack pieces are copied in by `scripts/assets/tools/prep_era3.py` (MegaKit uneven-brick and brick
walls, glazed window frames, doors, round-tile roof pieces, balconies, dormer, chimney, wagon;
Pirate Kit ships and crates). The slate, cobble, stained-glass (rose and lancet), clock-face,
town-flag and book-spine textures (`assets/textures/era3/`) are painted by
`scripts/assets/tools/gen_era3_textures.py`.

- Look: the Era 1-2 palette family grown up. There are stone ground floors (MegaKit) with hand-built
  plaster upper floors in ochre, rose, sky and sage, limestone string courses and quoins, red
  tile and blue slate roofs, and doors and shutters in jewel paints (teal, blue, red, green,
  plum). Brass, iron, copper and verdigris are used for science and civic pieces. Stained glass,
  lamp glass and the beacon are unshaded so they glow. Era 3 adds `limestone iron iron_light brass
  copper slate_flat plaster_* paint_* cloth_teal cloth_plum cloth_jewel paper glass_dark coal
  rust` and textured `town_stone ashlar ashlar_warm brick roof_tiles plaster slate cobbles books
  clock_face flag_hand` to `ArtPalette`.
- Every building has three stages: `<id>_plot` (pegged outline, stone and timber stacked), then
  `<id>_frame` (half-built ragged masonry, scaffold with plank decks, ladder, gin-pole hoist and
  mortar tub; the aqueduct shows timber centering under its first arches), then `<id>` (done).
- Moving parts (spinner nodes, as in Era 2): `windmill/Sails`, `watermill/Wheel`,
  `mason/Wheel` (treadwheel crane), `clocktower/Hands`, `observatory/Dome`, `harbour/Jib`,
  `lighthouse/Beam`, `school/Bell`, `fire_station/Bell`.
- Lights ship switched off for gameplay to turn on at dusk: `street_lamp/Light` (OmniLight3D)
  and `lighthouse/BeamLight` (SpotLight3D under the turning Beam).
- The great hall of the Hand is the Era 3 stage of the shrine (DESIGN 7). It is a nave with
  stained lancets and buttresses, a west tower and spire with the hand finial, a rose window
  with the hand, and the old shrine stone kept in a railed garden beside it.
- The aqueduct is modular: `aqueduct` is a 12 m arched segment with piers at x = -4, 0, 4 that
  ends mid-span, so segments chain end to end along X. `aqueduct_end` is the castellum,
  spilling into a basin.
- `harbour` is a quay built along X with its sea side at -Z. The quay face and piles go 2.2 m
  below ground.
- Villagers: `VillagerVisual.set_era(3)` switches to town clothes. Men wear coats over breeches
  and stockings, with buckled shoes and waistcoats; women wear bodices and skirts with
  stomachers. Both have aprons, collars, cuffs and lace frills. Hats are a tricorn, bonnet,
  flat cap, mob cap and felt hat.

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
- Era 2 (earlier): `era2_cottage` (now the kit cottages) `era2_longhouse era2_shed era2_wagon
  era2_crate era2_fence crop_wheat crop_corn sheep horse bear*` (`*` placeholder)
- Era 2 buildings, each with `_plot` and `_frame`: `cottage` (2 variants) `granary mill bakery
  kiln smelter smithy weaver workshop barn temple bridge well watchtower sheep_pen`; plus
  `market_stall` (3 awnings) `market_stall_frame charcoal_clamp jetty`
- Era 2 farming: `field` (variants: tilled, sprouts, growing, ripe, stubble) and the single states
  `field_tilled field_sprouts field_growing field_ripe field_stubble field_blighted field_parched`,
  `garden_plot sheaves haystack scarecrow`
- Era 2 resources: `grain_sacks flour_sacks bread_basket pots pots_unfired clay_pile planks_pile
  charcoal_pile ore_pile bronze_ingots wool_bales cloth_bolts barrels water_trough`; nodes and
  hazards `clay_pit copper_ore rockfall`
- Era 2 props: `fence_wattle fence_wattle_gate handcart` (empty, loaded) `hay_wagon raft raft_frame
  rowboat fishing_boat`; tools `tool_axe_bronze tool_pickaxe_bronze tool_hoe tool_sickle
  tool_pitchfork tool_shovel tool_hammer`; animals `cow pig`
- Era 3 buildings, each with `_plot` and `_frame`: `townhouse` (3 variants) `great_hall
  market_hall clocktower school printing_house laboratory clinic fire_station forge mason
  windmill watermill observatory harbour lighthouse aqueduct`; plus `aqueduct_end`
- Era 3 streets: `road_paved road_paved_cross road_paved_end plaza fountain town_flag
  street_lamp banner_pole bench_iron planter pump notice_board statue_hand`
- Era 3 carts and ships: `cart` (empty, loaded) `caravan_wagon fire_cart ship_small ship_merchant`
- Era 3 resources: `stone_blocks bricks_pile iron_ore_pile iron_bars books_pile paper_stack
  crates glassware fire_buckets`; nodes `quarry iron_ore`; tools `tool_axe_iron
  tool_pickaxe_iron tool_mallet tool_chisel tool_saw tool_trowel`
- Seasons: trees, bushes, rocks, logs and stumps have `autumn` and/or `winter` variant lists.

Contact sheets: `tests/assets/contact_era1.png`, `tests/assets/villagers.png`; Era 2:
`tests/shots/era2_art_kit.png` and the diorama `tests/shots/era2_village.png`
(`tests/assets/era2_shots.gd`, `--shot=kit` or `--shot=village`); Era 3:
`tests/shots/era3_art_kit.png` and the coastal town diorama `tests/shots/era3_town.png`
(`tests/assets/era3_shots.gd`, `--shot=kit`, `--shot=town` or `--shot=preview --ids=...`).
