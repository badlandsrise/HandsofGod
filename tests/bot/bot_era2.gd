extends RefCounted
## The bot's Era 2 (Village) play, kept out of bot.gd: how it values the new
## work (fields by what they need, the craft chains by their inputs, the
## raising crews), and how it answers the new threats and openings the way a
## player would: rain on dry fields, roll the rockfall boulders aside with
## Strength II, scare or carry off the bear, lift people out of a flood, put
## a second person on a blighted field.

const SAFE := Vector2(-4.0, 8.0)        # high ground in the Clearing for flood evacuees

var bot = null
var rains := 0
var boulders := 0
var timbers := 0
var bear_moves := 0
var bear_scares := 0
var evacuated := 0
var _rain_cd := 0.0

func _init(b) -> void:
	bot = b

static func _has(k: StringName, n: int) -> bool:
	return Village.store(k) >= n

## How short the open plots are of `k`, counting what the craft chains need
## to make the goods they wait for (bronze needs ore and charcoal, pots need
## clay, cloth needs wool). Above zero, the chain job outranks foraging.
func short(k: StringName) -> int:
	var want: int = bot._need(k)
	match k:
		&"charcoal":
			want += short(&"bronze")
		&"ore":
			want += short(&"bronze") * 2
		&"clay":
			want += short(&"pots") * 2 + (4 if Village.count_buildings(&"smelter") == 0 and short(&"bronze") > 0 else 0)
		&"wool":
			want += short(&"cloth") * 2
	return maxi(want - Village.store(k), 0)      # what the stores already hold counts

func _flood_on() -> bool:
	var w = Game.world
	var e = w.threats.era2 if w != null and w.threats != null else null
	return e != null and e.current == &"flood" and e.phase > 0

func _in_flood(p: Vector3) -> bool:
	return Era2World.in_flood_zone(p) and Game.world.ground_y(p.x, p.z) < Era2Threats.FLOOD_TOP + 0.4

## Sites the bot should not send people to right now.
func site_blocked(s) -> bool:
	if Village.era < 2:
		return false
	if _flood_on() and _in_flood(s.global_position):
		return true
	if s.job != null and s.job.only_season >= 0 and not s.in_season():
		return true
	return false

## Score for an Era 2 job, or -1.0 to let bot.gd decide.
func score(s, idle_n: int) -> float:
	var v := _base_score(s, idle_n)
	# work on the chain the shown dream waits on (the bridge's bronze, the
	# temple's cloth and pots), as its goal checklist names it, comes first
	var j: JobDef = s.job
	if v > 0.5 and j != null and not s.is_plot() and not s.is_group():
		var chain: Array = bot._dream_chain()
		if (s.building != null and chain.has(s.building.id)) or chain.has(j.id):
			for k in j.outputs:
				if short(k) > 0:
					return maxf(v, 7.6)
	return v

func _base_score(s, idle_n: int) -> float:
	var j: JobDef = s.job
	if j == null or s.is_plot():
		return -1.0
	var pop := maxi(Village.population(), 1)
	var food_low: bool = Village.food() < bot._food_target()
	match j.id:
		&"mill_grain":
			return (6.7 if Village.store(&"flour") < 12 else 1.0) if _has(&"grain", 2) else 0.0
		&"bake_bread":
			# bread burns wood: only while the stores want food
			if not (_has(&"flour", 2) and _has(&"wood", 1)): return 0.0
			return 8.0 if food_low else (2.0 if Village.food() < bot._food_target() + 20 else 0.0)
		&"fire_kiln":
			if short(&"pots") > 0 and _has(&"clay", 2) and _has(&"wood", 1): return 6.6
			return (5.2 if Village.store(&"pots") < bot._need(&"pots") + 6 else 0.8) if _has(&"clay", 2) and _has(&"wood", 1) else 0.0
		&"burn_charcoal":
			if short(&"charcoal") > 0 and _has(&"wood", 4): return 6.6
			return (4.6 if Village.store(&"charcoal") < 8 and Village.count_buildings(&"smelter") > 0 else 0.5) if _has(&"wood", 5) else 0.0
		&"smelt_bronze":
			if short(&"bronze") > 0 and _has(&"ore", 2) and _has(&"charcoal", 1): return 6.8
			return (5.6 if Village.store(&"bronze") < bot._need(&"bronze") + 6 else 0.8) if _has(&"ore", 2) and _has(&"charcoal", 1) else 0.0
		&"forge_tools":
			return (5.0 if not Flags.has(&"bronze_tools") else 0.3) if _has(&"bronze", 1) and _has(&"charcoal", 1) else 0.0
		&"weave_cloth":
			if short(&"cloth") > 0 and _has(&"wool", 2): return 6.6
			return (4.8 if Village.store(&"cloth") < bot._need(&"cloth") + 5 else 0.6) if _has(&"wool", 2) else 0.0
		&"herd_sheep":
			if short(&"wool") > 0: return 6.3
			return 3.8 if Village.store(&"wool") < 10 else 0.4
		&"dig_clay":
			if short(&"clay") > 0: return 6.3
			return 5.0 if Village.store(&"clay") < 10 + bot._need(&"clay") else 0.4
		&"mine_ore":
			if short(&"ore") > 0: return 6.3
			return 5.0 if Village.store(&"ore") < 8 else 0.4
		&"quarry_stone":
			return 6.6 if Village.store(&"blocks") < bot._need(&"blocks") + 4 else 0.5
		&"draw_water":
			return 8.6 if Village.store(&"water") < pop else (3.0 if Village.store(&"water") < pop * 3 else 0.5)
		&"fish_boat":
			return 6.4 if food_low else 1.5
		&"keep_market":
			return 1.8 if s.workers.size() < 1 else 0.0
		&"keep_watch":
			return 2.2 if s.workers.size() < 1 and int(Village.stats.get("bears_seen", 0)) > 0 else 0.0
		&"pray_temple":
			return 3.0 if s.workers.size() < bot._prayers_wanted() else 0.0
		&"barn_raising", &"bridge_building", &"temple_raising", &"harvest_festival", &"raft_launch", &"footbridge_raising":
			var waiting := 0
			for p in s.workers:
				if is_instance_valid(p):
					waiting += 1
			if maxi(j.min_people - waiting, 0) > idle_n:
				return 0.0
			return (9.2 if j.id != &"raft_launch" else 8.0) + (1.0 if waiting > 0 else 0.0)
	return -1.0

## Is a person wasted on this Era 2 job? -1 = let bot.gd decide.
func wasted(s, p = null) -> int:
	var j: JobDef = s.get("job")
	if j == null or s.is_plot():
		return -1
	match j.id:
		&"mill_grain": return 0 if _has(&"grain", 2) else 1
		&"bake_bread": return 0 if _has(&"flour", 2) and _has(&"wood", 1) and Village.food() < bot._food_target() + 10 else 1
		&"fire_kiln": return 0 if _has(&"clay", 2) and _has(&"wood", 1) else 1
		&"burn_charcoal": return 0 if _has(&"wood", 4) and (Village.store(&"charcoal") < 12 or short(&"charcoal") > 0) else 1
		&"smelt_bronze": return 0 if _has(&"ore", 2) and _has(&"charcoal", 1) else 1
		&"forge_tools": return 0 if _has(&"bronze", 1) and _has(&"charcoal", 1) and not Flags.has(&"bronze_tools") else 1
		&"weave_cloth": return 0 if _has(&"wool", 2) else 1
		&"herd_sheep": return 1 if Village.store(&"wool") >= 14 else 0
		&"dig_clay": return 1 if Village.store(&"clay") >= 14 + bot._need(&"clay") and short(&"clay") == 0 else 0
		&"mine_ore": return 1 if Village.store(&"ore") >= 12 and short(&"ore") == 0 else 0
		&"quarry_stone": return 1 if Village.store(&"blocks") >= bot._need(&"blocks") + 6 else 0
		&"keep_market", &"keep_watch": return 0
		&"fish_boat": return 1 if Village.food() >= bot._food_target() + 10 else 0
		&"draw_water": return 1 if Village.store(&"water") >= mini(Village.population() * 4, Village.store_cap - 1) else 0
		&"pray_temple": return 1 if p != null and s.workers.find(p) >= bot._prayers_wanted() else 0
		&"tend_fire": return -1
	if j.kind == JobDef.Kind.TEND:
		return 0
	return -1

# ---------------------------------------------------------------- answers

## Returns true when it used the hand this think.
func think() -> bool:
	if Village.era < 2:
		return false
	var w = Game.world
	if _flood() or _bear() or _boulders() or _timbers():
		return true
	_rain_cd -= bot.THINK
	if _rain_cd <= 0.0 and Faith.has(&"rain"):
		var f := _driest_field()
		if f != null:
			_rain_cd = 1.5
			bot._gesture(&"rain", f.global_position, 4)
			rains += 1
	return false

func _driest_field() -> Site:
	var best: Site = null
	for s in Village.sites:
		if not is_instance_valid(s) or not s.is_field() or s.state != Site.State.FINISHED:
			continue
		if not (s.field_stage in [Site.Field.SPROUTS, Site.Field.GROWING, Site.Field.TILLED]):
			continue
		if s.moisture >= 0.5:
			continue
		if best == null or s.moisture < best.moisture:
			best = s
	return best

## Strong Arms: carry the footbridge's timbers from the bridge yard to its plot.
func _timbers() -> bool:
	var w = Game.world
	var e2 = w.village_ai.era2 if w.village_ai != null else null
	if e2 == null or Faith.strength < Timber.WEIGHT:
		return false
	for t in e2.timbers():
		var plot: Site = Timber.wanting_plot(t.global_position, 9999.0)
		if plot == null:
			return false
		var i: int = plot.timbers_in
		bot._move_object(t, plot.global_position + Vector3(-1.0 + 2.0 * i, 0, -2.5))
		timbers += 1
		return true
	return false

func _boulders() -> bool:
	var w = Game.world
	if w.era2 == null or w.is_region_open(&"hill_quarry") or Faith.strength < LayoutEra2.BOULDER_WEIGHT:
		return false
	for i in w.era2.boulders.size():
		var b: Liftable = w.era2.boulders[i]
		if Vector2(b.global_position.x, b.global_position.z).distance_to(LayoutEra2.ROCKFALL) < LayoutEra2.ROCKFALL_CLEAR:
			bot._move_object(b, Vector3(LayoutEra2.ROCKFALL.x - 12.0, 0, LayoutEra2.ROCKFALL.y - 5.0 + i * 5.0))
			boulders += 1
			return true
	return false

func _bear() -> bool:
	var w = Game.world
	var e = w.threats.era2
	if e == null or e.bear == null or not is_instance_valid(e.bear) or e.bear.state == Bear.S.HOME:
		return false
	var bear: Bear = e.bear
	var tgt = bear.target
	var close: bool = tgt != null and is_instance_valid(tgt) and tgt.global_position.distance_to(bear.global_position) < 14.0
	if not close:
		return false
	if Faith.strength >= bear.lift_weight():
		bot._move_object(bear, bear.den + Vector3(-5, 0, -4))
		bear_moves += 1
		return true
	if Game.rng.randf() < 0.6:
		if w.scare_threats(bear.global_position, 7.0) > 0:
			bear_scares += 1
			bot._gestures[&"flick"] = int(bot._gestures.get(&"flick", 0)) + 1
			return true
	return false

func _flood() -> bool:
	if not _flood_on():
		return false
	var h = bot._hand()
	var wet: Array = []
	for p in Village.alive():
		if not p.pickable() or p.stage == Person.Stage.BABY or not p.visible:
			continue
		if _in_flood(p.global_position):
			wet.append(p)
	if wet.is_empty():
		return false
	var w = Game.world
	var to: Vector3 = w._v3(SAFE + Vector2(Game.rng.randf_range(-6, 6), Game.rng.randf_range(-4, 4)))
	if h == null:
		for p in wet.slice(0, Faith.grip):
			p.on_lifted()
			p.on_placed(to, null)
			evacuated += 1
		return true
	for p in wet:
		if h.held.size() >= h.grip():
			break
		if h.can_lift(p):
			h.try_lift(p)
	if h.held.is_empty():
		return false
	evacuated += h.held.size()
	h.place_on_ground(to)
	bot._actions += 1
	return true

func summary() -> String:
	return "rain %d | timbers %d | boulders %d | bear lifted %d scared %d | flood evacuated %d" % [rains, timbers, boulders, bear_moves, bear_scares, evacuated]
