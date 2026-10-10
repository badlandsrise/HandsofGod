class_name SiteVisual extends Node3D
## The look of a Site, from the art catalog (scripts/assets/asset_catalog.gd).
## The Site puts the result under its child named "Visual". Huts go through their
## build stages (hut_plot, hut_frame, hut); other buildings rise out of their plot.
## Slot pips and hover rings are drawn by the hand.

## BuildingDef id -> catalog id, when the names differ.
const BUILDING_ART := {&"camp": &"era2_shed", &"market": &"market_stall"}
## Moving parts in the Era 2 and 3 kits (scripts/assets/spinner.gd) turn while
## someone works: mill sails and wheels, the well's windlass, the school bell,
## the observatory dome, the harbour crane. The clock's hands always turn; the
## fire station's bell rings while anything burns; the lighthouse beam turns
## at night (Era3World).
const SPINNERS: Array[StringName] = [&"Sails", &"Wheel", &"Windlass", &"Bell", &"Dome", &"Jib", &"Hands"]
const ALWAYS_SPIN: Array[StringName] = [&"Hands"]

var site: Site = null
var _fill_nodes: Array[Node3D] = []   # berries, sticks, deer: shown in proportion to amount
var _flame: Node3D = null             # the campfire's Fire node (flicker.gd)
var _rising: Node3D = null            # building model that grows with build progress
var _rising_s := 1.0                  # the rising model's fitted scale
var _rising_from := 0.15              # height fraction at progress 0
var _hut_stage := -1                  # huts: 0 plot, 1 frame, 2 walls rising
var _spinners: Array[Node] = []       # spinner nodes (mill sails, potter's wheel, well windlass)
var _spin_t := 0.0
var _staged := false                  # the building has <id>_plot / <id>_frame art (Era 2 kit)
var _symbol: Node3D = null            # the painted hand, once the people love the hand

static func make(s: Site) -> SiteVisual:
	var v := SiteVisual.new()
	v.site = s
	var seed_v := absi(hash(Vector2i(roundi(s.position.x * 10.0), roundi(s.position.z * 10.0))))
	if s.building != null and s.building.scene != null and s.state == Site.State.FINISHED:
		v.add_child(s.building.scene.instantiate())
		return v
	if s.building != null and s.building.id == &"aqueduct":
		v._aqueduct(s)
	elif s.is_plot():
		v._plot(s, seed_v)
	elif s.is_field():
		v._field(s)
	elif s.building != null:
		v._building(s.building.id, s.building.footprint, seed_v)
		if s.building.era >= 2:
			v._hand_symbol(s)
	elif s.job != null:
		v._job(s.job.id, seed_v)
	v.rotation.y = 0.0
	for n in v.find_children("*", "", true, false):
		if SPINNERS.has(StringName(n.name)) and "spinning" in n:
			if ALWAYS_SPIN.has(StringName(n.name)):
				n.set("spinning", true)
				continue
			v._spinners.append(n)
			n.set("spinning", false)
	return v

func set_fill(f: float) -> void:
	var n := _fill_nodes.size()
	for i in n:
		if is_instance_valid(_fill_nodes[i]):
			_fill_nodes[i].visible = float(i) < f * float(n) - 0.01

func _process(dt: float) -> void:
	if site == null or not is_instance_valid(site):
		return
	if not _spinners.is_empty():
		_spin_t -= dt
		if _spin_t <= 0.0:
			_spin_t = 0.5
			var on := site.busy()
			if site.building != null and site.building.id == &"fire_station":
				on = site.get_tree().get_first_node_in_group(&"burning") != null
			for n in _spinners:
				if is_instance_valid(n):
					n.set("spinning", on)
	if _symbol != null and not _symbol.visible and Trust.village_loves_hand():
		_symbol.visible = true
	if _flame != null:
		var on := site.lit()
		if _flame.visible != on:
			_flame.set("burning", on)
	if _hut_stage == 1 and site.state == Site.State.BUILDING and site.build_progress() >= HUT_WALLS_AT:
		site.rebuild_visual.call_deferred()      # the frame gets its walls and roof
		_hut_stage = 2
	if _staged and _hut_stage == 1 and site.state == Site.State.BUILDING and site.build_progress() >= HUT_WALLS_AT and not site.awaiting_raise():
		site.rebuild_visual.call_deferred()
		_hut_stage = 2
	if _rising != null and site.state == Site.State.BUILDING:
		var p := site.build_progress()
		if _hut_stage == 2:
			p = clampf((p - HUT_WALLS_AT) / (1.0 - HUT_WALLS_AT), 0.0, 1.0)
		_rising.scale = Vector3(_rising_s, _rising_s * lerpf(_rising_from, 1.0, p), _rising_s)

# ---------------------------------------------------------------- helpers

func _art(id: StringName, variant: int = 0, pos := Vector3.ZERO, yaw := 0.0, s := 1.0) -> Node3D:
	var n := AssetCatalog.instance(id, variant)
	n.position = pos
	n.rotation.y = yaw
	n.scale = Vector3.ONE * s
	add_child(n)
	return n

func _ball(r: float, mat: Material, pos: Vector3, segs := 6) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = r; sm.height = r * 2.0; sm.radial_segments = segs; sm.rings = maxi(segs / 2, 3)
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

func _stick(mat: Material, pos: Vector3, yaw: float, len_m: float = 0.9) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cy := CylinderMesh.new(); cy.top_radius = 0.035; cy.bottom_radius = 0.045; cy.height = len_m; cy.radial_segments = 5; cy.rings = 1
	mi.mesh = cy
	mi.material_override = mat
	mi.position = pos
	mi.rotation = Vector3(0, yaw, PI * 0.5)
	add_child(mi)
	return mi

# ---------------------------------------------------------------- jobs

func _job(id: StringName, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	match id:
		&"gather_berries", &"rich_berries":
			var rich := id == &"rich_berries"
			var bs := 1.45 if rich else 1.15
			_art(&"berry_bush", seed_v, Vector3.ZERO, rng.randf() * TAU, bs)
			var berry := ArtPalette.material("berry")
			var nb := 14 if rich else 9
			for i in nb:
				var a := TAU * i / float(nb) + rng.randf_range(-0.2, 0.2)
				var h := rng.randf_range(0.55, 1.25) * bs / 1.15
				var r := 0.82 * bs / 1.15 * sqrt(maxf(0.0, 1.0 - pow((h * 1.15 / bs - 0.7) / 0.8, 2.0)))
				_fill_nodes.append(_ball(0.09, berry, Vector3(cos(a) * r, h, sin(a) * r), 5))
		&"fetch_water", &"fish_by_hand":
			for i in 3:
				var a := rng.randf() * TAU
				_art(&"rock_small", i + seed_v, Vector3(cos(a), 0, sin(a)) * rng.randf_range(1.3, 1.9), rng.randf() * TAU, rng.randf_range(0.7, 1.2))
			if id == &"fish_by_hand":
				_art(&"fish", seed_v, Vector3(0.8, 0.05, 0.6), rng.randf() * TAU)
		&"collect_sticks":
			_art(&"stump", seed_v, Vector3(0.2, 0, -0.3), rng.randf() * TAU)
			_art(&"fern", seed_v, Vector3(-0.9, 0, 0.4), rng.randf() * TAU)
			var wood := ArtPalette.material("wood")
			for i in 10:
				var a := TAU * i / 10.0 + rng.randf_range(-0.2, 0.2)
				_fill_nodes.append(_stick(wood, Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.6, 1.3) + Vector3(0, 0.05, 0), rng.randf() * TAU, rng.randf_range(0.6, 1.0)))
		&"fell_tree":
			_art(&"tree_pine" if seed_v % 2 == 0 else &"tree_broad", seed_v, Vector3.ZERO, rng.randf() * TAU, rng.randf_range(1.5, 1.8))
			_art(&"tool_axe", 0, Vector3(1.2, 0.0, 0.6), 0.6)
		&"knap_flint":
			_art(&"flint_node", seed_v, Vector3.ZERO, rng.randf() * TAU)
		&"tend_fire":
			var fire := _art(&"campfire", 0, Vector3.ZERO, 0.0, 1.25)
			# The world's FirePit owns the firelight; keep only the flames here.
			for l in fire.find_children("*", "OmniLight3D", true, false):
				l.queue_free()
			_flame = fire.find_child("Fire", true, false) as Node3D
			for i in 3:
				var a := TAU * i / 3.0 + 0.5
				_art(&"log_fallen", i, Vector3(cos(a), 0, sin(a)) * 2.7, -a + PI * 0.5, 0.5)
		&"carry_log":
			_art(&"log_fallen", seed_v, Vector3.ZERO, 0.0, 0.85)
		&"haul_log":
			pass    # the world's fallen trunk (a Blocker) is the visual and rolls with the haulers
		&"hunt":
			for i in 3:
				var a := TAU * i / 3.0 + rng.randf_range(-0.3, 0.3)
				_fill_nodes.append(_art(&"deer", i, Vector3(cos(a), 0, sin(a)) * 2.2, rng.randf() * TAU))
		&"pray":
			_art(&"cairn", 0)
		&"great_elk_hunt":
			# one great elk, half again the size of the deer, among the flint and ferns
			_fill_nodes.append(_art(&"deer", 1, Vector3(0, 0, 0.4), rng.randf() * TAU, 1.7))
			_art(&"fern", seed_v, Vector3(-1.6, 0, -0.8), rng.randf() * TAU)
			_art(&"rock_small", seed_v, Vector3(1.7, 0, -1.1), rng.randf() * TAU, 1.3)
		&"festival":
			# a dancing ring marked with flowers
			for i in 8:
				var a := TAU * i / 8.0
				_art(&"flowers", i + seed_v, Vector3(cos(a), 0, sin(a)) * 2.3, rng.randf() * TAU, 0.9)
		&"harvest_festival":
			# sheaves in a ring, a haystack and flowers: the harvest home
			for i in 6:
				var a := TAU * i / 6.0
				_art(&"sheaves", i, Vector3(cos(a), 0, sin(a)) * 3.2, -a)
				_art(&"flowers", i + seed_v, Vector3(cos(a + 0.5), 0, sin(a + 0.5)) * 3.6, rng.randf() * TAU, 0.8)
			_art(&"haystack", 0, Vector3(0, 0, -0.5), 0.3, 0.7)
		&"dig_clay":
			_art(&"clay_pit", seed_v, Vector3.ZERO, rng.randf() * TAU)
			_art(&"tool_shovel", 0, Vector3(1.9, 0.0, 1.2), 0.8)
		&"mine_ore":
			_art(&"copper_ore", seed_v, Vector3.ZERO, rng.randf() * TAU, 1.2)
			_art(&"tool_pickaxe_bronze", 0, Vector3(1.4, 0.0, 0.9), 0.4)
		&"quarry_stone":
			# a ledge of cut stone on the quarry face
			_art(&"rock_large" if AssetCatalog.has(&"rock_large") else &"rock_small", seed_v, Vector3(0, 0, -1.2), rng.randf() * TAU, 1.6)
			_art(&"rock_small", seed_v + 1, Vector3(1.2, 0, 0.6), rng.randf() * TAU, 1.3)
			_art(&"tool_pickaxe_bronze", 0, Vector3(-1.0, 0.0, 0.8), 1.2)
		&"raft_launch":
			_art(&"raft_frame", 0, Vector3.ZERO, 0.0)
		&"fish_boat":
			var wl := 0.0
			var w = Game.world
			if w != null and is_instance_valid(w) and w.get("valley") != null:
				var sp := site.global_position + Vector3(0, 0, 5.0)
				wl = w.valley.water_level(sp.x, sp.z)
				wl = (wl - site.global_position.y) if wl > -INF else -0.4
			_art(&"raft", 0, Vector3(0, wl - 0.1, 5.0), 0.2, 0.8)
			_art(&"rowboat", 0, Vector3(2.2, wl - 0.1, 6.5), -0.3)
			_art(&"barrels", 0, Vector3(-1.2, 0, 0.6), 0.5, 0.7)
		&"temple_raising", &"bridge_building", &"barn_raising":
			# coils of rope and a ladder's worth of timber for the crew
			_art(&"planks_pile", 0, Vector3(0, 0, 0), 0.4, 0.6)
		_:
			_art(&"rock_small", seed_v)

# ---------------------------------------------------------------- buildings

func _art_id(bid: StringName) -> StringName:
	var id: StringName = BUILDING_ART.get(bid, bid)
	return id if AssetCatalog.has(id) else &""

const HUT_WALLS_AT := 0.5             # build progress where a hut's frame gets its walls
const GHOST_ALPHA := 0.22

## Plots show their stage (doc 4, Build): staked ground with a faint ghost of
## what will stand there, then (huts) the pole frame, then walls and roof
## rising; other buildings rise out of their staked plot. Fitted to the
## footprint so a plot reads at the size of the finished building.
func _plot(s: Site, seed_v: int) -> void:
	var fp := s.building.footprint
	var span := maxf(fp.x, fp.y)
	var bid := s.building.id
	var id := _art_id(bid)
	if bid == &"field":
		# clearing the ground for a new field: stubble and stakes
		_art(&"field_stubble", 0, Vector3.ZERO, 0.0, 1.0)
		_ghost(_art(&"field_tilled", 0, Vector3(0, 0.02, 0), 0.0, 1.0))
		return
	if id != &"" and AssetCatalog.has(StringName(str(id) + "_plot")):
		_staged_plot(s, id, seed_v)
		_material_piles(s, span)
		return
	var is_hut := bid == &"hut"
	var ks := 1.0 if is_hut else maxf(span / 3.9, 0.8)
	if s.state == Site.State.PLOT:
		_hut_stage = 0
		_art(&"hut_plot", 0, Vector3.ZERO, 0.0, ks)
		if id != &"":
			_ghost(_art(id, seed_v, Vector3.ZERO, 0.0, 1.0 if is_hut else _fit(id, fp)))
	elif is_hut:
		if s.build_progress() < HUT_WALLS_AT:
			_hut_stage = 1
			_art(&"hut_frame", 0)
		else:
			_hut_stage = 2
			_art(&"hut_plot", 0)
			_rising_s = 1.0
			_rising_from = 0.55
			_rising = _art(&"hut", seed_v, Vector3.ZERO, 0.0, 1.0)
			_rising.scale.y = _rising_from
	else:
		_art(&"hut_plot", 0, Vector3.ZERO, 0.0, ks)
		if id != &"":
			_rising_s = _fit(id, fp)
			_rising = _art(id, seed_v, Vector3.ZERO, 0.0, _rising_s)
			_rising.scale.y = _rising_s * lerpf(_rising_from, 1.0, s.build_progress())
	_material_piles(s, span)

## Era 2 kit buildings: <id>_plot (pegged out, materials stacked), then
## <id>_frame (timber frame, scaffold), then the building rising out of it.
func _staged_plot(s: Site, id: StringName, seed_v: int) -> void:
	_staged = true
	var plot_id := StringName(str(id) + "_plot")
	var frame_id := StringName(str(id) + "_frame")
	# Era 3 buildings may be drawn smaller than their kit model (the great hall
	# over the old temple): plot, frame and building all scale together.
	var k := _fit(id, s.building.footprint) if s.building.era >= 3 else 1.0
	if s.state == Site.State.PLOT:
		_hut_stage = 0
		_art(plot_id, 0, Vector3.ZERO, 0.0, k)
		_ghost(_art(id, seed_v, Vector3.ZERO, 0.0, k))
	elif s.awaiting_raise() or s.build_progress() < HUT_WALLS_AT or not AssetCatalog.has(id):
		_hut_stage = 1
		_art(frame_id if AssetCatalog.has(frame_id) else plot_id, 0, Vector3.ZERO, 0.0, k)
	else:
		_hut_stage = 2
		_art(plot_id, 0, Vector3.ZERO, 0.0, k)
		_rising_s = k
		_rising_from = 0.55
		_rising = _art(id, seed_v, Vector3.ZERO, 0.0, k)
		_rising.scale.y = _rising_from * k

func _material_piles(s: Site, span: float) -> void:
	# Material piles grow as builders deliver.
	var i := 0
	for k in s.building.cost:
		var got := int(s.delivered.get(k, 0))
		var need := maxi(int(s.building.cost[k]), 1)
		if got > 0 and s.state == Site.State.PLOT:
			var f := clampf(float(got) / float(need), 0.15, 1.0)
			var at := Vector3(span * 0.5 + 0.8, 0, -span * 0.25 + i * 1.6)
			var pile: StringName = PILE_ART.get(k, &"rock_small")
			if k == &"wood":
				_art(&"firewood_pile", 0, at, 0.3, lerpf(0.45, 0.9, f))
			elif pile != &"rock_small" and AssetCatalog.has(pile):
				_art(pile, 0, at, 0.3, lerpf(0.6, 1.0, f))
			else:
				_art(&"rock_small", i, at, 0.0, lerpf(0.8, 1.6, f))
		i += 1

## A pile for each building material as it is delivered.
const PILE_ART := {&"clay": &"clay_pile", &"pots": &"pots", &"cloth": &"cloth_bolts", &"bronze": &"bronze_ingots",
	&"blocks": &"rock_small", &"grain": &"grain_sacks"}

## Field art by crop stage: tilled, sprouts, growing, ripe, stubble; blighted
## and parched when the threats land.
func _field(s: Site) -> void:
	var id := StringName("field_" + str(Site.Field.keys()[clampi(s.field_stage, 0, 4)]).to_lower())
	if s.is_blighted():
		id = &"field_blighted"
	elif s.field_stage in [Site.Field.SPROUTS, Site.Field.GROWING] and s.moisture < 0.15:
		id = &"field_parched"
	_art(id if AssetCatalog.has(id) else &"field", 0)
	if s.field_stage == Site.Field.RIPE:
		_art(&"scarecrow", 0, Vector3(3.2, 0, -2.2), 0.6)

## The painted hand (doc 7: the hand symbol, Era 2 "painted on pots and on the
## temple doors"): once the village loves the hand, its buildings carry the
## sign above their doors.
func _hand_symbol(s: Site) -> void:
	if s.building == null or s.building.camp or s.building.id == &"temple" or s.building.id == &"field":
		return
	var fp := s.building.footprint
	if s.building.id == &"observatory" or s.building.id == &"great_hall":
		# Era 3: the hand in the coloured glass over the door
		_symbol = HandSymbol.make(1.1)
		_symbol.position = Vector3(0, 4.2, fp.y * 0.5 * (_fit(_art_id(s.building.id), fp) if _art_id(s.building.id) != &"" else 1.0) + 0.1)
		_symbol.visible = Trust.village_loves_hand()
		add_child(_symbol)
		return
	_symbol = HandSymbol.make(0.55)
	_symbol.position = Vector3(0, minf(2.6, 1.0 + fp.y * 0.25), fp.y * 0.5 + 0.06)
	_symbol.visible = Trust.village_loves_hand()
	add_child(_symbol)

## A see-through preview of the building to come, so a plot never reads as a blob.
func _ghost(n: Node3D) -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.92, 0.75, GHOST_ALPHA)
	m.cull_mode = BaseMaterial3D.CULL_BACK
	m.no_depth_test = false
	for c in n.find_children("*", "GeometryInstance3D", true, false):
		var gi := c as GeometryInstance3D
		gi.material_override = m
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.find_children("*", "Light3D", true, false):
		c.queue_free()
	n.name = "Ghost"

## Scale that fits a catalog model into a building's footprint (never above 1.15).
func _fit(id: StringName, fp: Vector2) -> float:
	var cf := AssetCatalog.footprint(id)
	var k := minf(fp.x / maxf(cf.x, 0.1), fp.y / maxf(cf.y, 0.1))
	return clampf(k, 0.6, 1.15) if k < 1.0 else 1.0

func _building(bid: StringName, fp: Vector2, seed_v: int) -> void:
	match bid:
		&"market":
			for i in 3:
				_art(&"market_stall", i, Vector3((i - 1) * 2.7, 0, -0.4 if i == 1 else 0.6), (i - 1) * -0.25)
			_art(&"barrels", 0, Vector3(3.4, 0, 1.8), 0.4, 0.8)
			_art(&"pots", 0, Vector3(-3.3, 0, 1.9), 0.0, 0.9)
			return
		&"sheep_pen":
			_art(&"sheep_pen", seed_v)
			for i in 4:
				_fill_nodes.append(_art(&"sheep", i, Vector3((i % 2) * 2.4 - 1.2, 0, (i / 2) * 2.0 - 1.0), i * 1.3, 0.9))
			return
		&"camp":
			_art(&"era2_shed", seed_v)
			_art(&"campfire", 0, Vector3(2.6, 0, 1.6), 0.0, 0.8)
			_art(&"barrels", 0, Vector3(-2.2, 0, 1.2), 0.3, 0.7)
			_art(&"era2_crate", 0, Vector3(-2.4, 0, -0.4), 0.2)
			return
		&"fire_circle":
			var fire := _art(&"campfire", 0, Vector3.ZERO, 0.0, 1.4)
			_flame = fire.find_child("Fire", true, false) as Node3D
			for i in 4:
				var a := TAU * i / 4.0 + 0.4
				_art(&"log_fallen", i, Vector3(cos(a), 0, sin(a)) * 2.6, -a + PI * 0.5, 0.55)
			return
		&"hut":
			_art(&"hut", seed_v, Vector3.ZERO, 0.0)
			return
	var id := _art_id(bid)
	if id != &"":
		_art(id, seed_v, Vector3.ZERO, 0.0, _fit(id, fp))
	else:
		_art(&"hut_plot", 0, Vector3.ZERO, 0.0, maxf(fp.x, fp.y) / 4.0)

# ---------------------------------------------------------------- the aqueduct

## The aqueduct (Era 3): the castellum at the town end (the site itself) and
## its arches walking east to the spring, 12 m apart and level with the
## castellum, on stone plinths where the ground dips. Pegged out while the
## materials come in, timber frames while it waits for its raising crew, and
## stone when it is raised.
func _aqueduct(s: Site) -> void:
	var finished := s.state == Site.State.FINISHED
	var framed := s.state == Site.State.BUILDING
	_art(&"aqueduct_end" if finished else &"aqueduct_plot", 0)
	if not finished:
		_ghost(_art(&"aqueduct_end", 0))
	var level := s.global_position.y
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.62, 0.58, 0.52)
	stone.roughness = 0.95
	for i in LayoutEra3.AQUEDUCT_SEGMENTS:
		var lx := -(LayoutEra3.AQUEDUCT_FIRST + LayoutEra3.AQUEDUCT_SEGMENT * float(i))
		var at := Vector3(lx, 0, 0)
		if finished:
			_art(&"aqueduct", i, at)
		elif framed:
			_art(&"aqueduct_frame", i, at)
		else:
			_ghost(_art(&"aqueduct", i, at))
			continue
		for px in [-4.0, 0.0, 4.0]:
			var wp := s.to_global(Vector3(lx + px, 0, 0))
			var g := Site.ground(wp.x, wp.z)
			var drop := level - g
			if drop > 0.12:
				var mi := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(1.5, drop + 0.4, 1.5)
				mi.mesh = bm
				mi.material_override = stone
				mi.position = Vector3(lx + px, -drop * 0.5 + 0.1, 0)
				add_child(mi)
