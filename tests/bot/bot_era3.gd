extends RefCounted
## The bot's Era 3 (Town) play, kept out of bot.gd: how it values the new
## work (the stone, iron, brass and book chains, the ship, the observatory,
## the crews of ten), and how it answers the new threats and openings the way
## a player would: lift the ship onto the sea, calm the sea for a voyage,
## light the sky for the astronomers at night, rain on a fire and man the
## bucket line, carry the sick to the clinic, shield people caught out in a
## storm.

var bot = null
var calms := 0
var guides := 0
var launches := 0
var fire_rains := 0
var to_clinic := 0
var shields := 0
var _calm_cd := 0.0
var _guide_cd := 0.0
var _shield_cd := 0.0

func _init(b) -> void:
	bot = b

static func _has(k: StringName, n: int) -> bool:
	return Village.store(k) >= n

## How short the open plots are of `k`, counting what the chains need to make
## the goods they wait for (blocks need stone, iron needs ore and charcoal,
## brass needs island tin).
func short(k: StringName) -> int:
	var own: int = maxi(bot._need(k) - Village.store(k), 0)
	match k:
		&"iron_ore":
			return own + short(&"iron") * 2 + short(&"brass")
		&"charcoal":
			return own + short(&"iron") + short(&"brass")
		&"tin":
			return own + short(&"brass")
		&"wood":
			return own + short(&"books") / 2
		&"cloth":
			return own + short(&"books") / 2
	return own

## Stone beyond what the open plots still need raw.
func _spare_stone() -> bool:
	return Village.store(&"stone") >= bot._need(&"stone") + 2

func _w():
	return Game.world

func _e3():
	var w = _w()
	return w.threats.era3 if w != null and w.threats != null else null

## Sites the bot should not send people to right now.
func site_blocked(s) -> bool:
	if Village.era < 3 or s.job == null or s.is_plot():
		return false
	match s.job.id:
		&"attend_school", &"rest_at_clinic":
			return true       # children go to school themselves; only the sick rest
		&"astronomy":
			return not Clock.is_night
	return false

func _present(s) -> int:
	var n := 0
	for p in s.workers:
		if is_instance_valid(p) and p.is_present_at(s, 1.6):
			n += 1
	return n

## Score for an Era 3 job, or -1.0 to let bot.gd / bot_era2.gd decide.
func score(s, idle_n: int) -> float:
	var j: JobDef = s.job
	if j == null or s.is_plot() or Village.era < 3:
		return -1.0
	var food_low: bool = Village.food() < bot._food_target()
	match j.id:
		&"dress_stone":
			if not _spare_stone(): return 0.0      # the plots want the raw stone (quarrying makes blocks too)
			if short(&"blocks") > 0: return 7.0
			return 5.4 if Village.store(&"blocks") < 30 else 0.6
		&"quarry_stone":
			if short(&"blocks") > 0: return 7.0
			return 4.8 if Village.store(&"blocks") < 30 else 0.5
		&"mine_iron":
			if short(&"iron_ore") > 0: return 6.6
			return 4.6 if Village.store(&"iron_ore") < 10 else 0.4
		&"forge_iron":
			if short(&"iron") > 0 and _has(&"iron_ore", 2) and _has(&"charcoal", 1): return 7.0
			return (5.2 if Village.store(&"iron") < 12 else 0.6) if _has(&"iron_ore", 2) and _has(&"charcoal", 1) else 0.0
		&"cast_brass":
			if _has(&"tin", 1) and _has(&"iron_ore", 1) and _has(&"charcoal", 1):
				return 7.2 if short(&"brass") > 0 else (4.0 if Village.store(&"brass") < 10 else 0.4)
			return 0.0
		&"print_books":
			if short(&"books") > 0 and _has(&"wood", 1) and _has(&"cloth", 1): return 6.8
			return (4.6 if Village.store(&"books") < 12 else 0.5) if _has(&"wood", 3) and _has(&"cloth", 1) else 0.0
		&"experiment":
			return 2.5 if _has(&"books", 6) else 0.0
		&"fight_fire":
			return 9.8 if _has(&"water", 1) else 0.0
		&"repair_roof":
			return 7.6 if _has(&"wood", 2) else 0.0
		&"fire_watch":
			return 2.4 if s.workers.size() < 1 else 0.0
		&"keep_light":
			return 2.4 if s.workers.size() < 1 else 0.0
		&"fish_ship":
			return 6.6 if food_low else 1.6
		&"astronomy":
			return 8.8 if not Flags.has(&"star_charts") else 0.4
		&"pray_hall":
			return 3.0 if s.workers.size() < bot._prayers_wanted() else 0.0
		&"sail_islands":
			var waiting: int = s.workers.filter(func(p): return is_instance_valid(p)).size()
			if maxi(j.min_people - waiting, 0) > idle_n:
				return 0.0
			var want_tin: bool = short(&"tin") > 0 or Village.store(&"tin") < 8
			return (8.6 if want_tin else 2.0) + (1.0 if waiting > 0 else 0.0)
		&"great_hall_raising", &"aqueduct_crew":
			var waiting2: int = s.workers.filter(func(p): return is_instance_valid(p)).size()
			if maxi(j.min_people - waiting2, 0) > idle_n:
				return 0.0
			return 9.3 + (1.0 if waiting2 > 0 else 0.0)
		&"burn_charcoal":
			if short(&"charcoal") > 0 and _has(&"wood", 4): return 6.6
			return (4.6 if Village.store(&"charcoal") < 10 else 0.5) if _has(&"wood", 5) else 0.0
	return -1.0

## [era3] Era 3 workplaces: first crew before most other work, then more
## hands while the bench, the ledges, the seams or the bins have work and the
## chain is wanted. -1 = not an Era 3 workplace.
func workplace_score(s) -> float:
	if Village.era < 3 or not s.is_workplace() or s.building.era < 3:
		return -1.0
	var have: int = s.slots_filled()
	if have >= Workplace.crew_cap(s) or not s.discovered():
		return 0.0
	var busy := Workplace.bench_need(s) > 0.0
	if not busy:
		for t in Workplace.tasks(s):
			if Workplace.need(t) > 0.0:
				busy = true
				break
	var base := 4.0
	match s.building.id:
		&"mason": base = 7.6 if short(&"blocks") > 0 or Village.store(&"blocks") < 20 else 5.0
		&"forge": base = 7.6 if short(&"iron") > 0 or short(&"iron_ore") > 0 or Village.store(&"iron") < 8 else 4.6
		&"watermill", &"windmill": base = 5.6 if Village.food() < bot._food_target() else 3.6
	if have < s.building.crew_min:
		return base + 0.6
	return base - 1.2 if busy else 0.4

## A plot whose workshop the open plots are waiting on (the forge while they
## wait for iron, the printing house for books, the harbour for island tin).
func plot_score(b: BuildingDef) -> float:
	if Village.era < 3:
		return -1.0
	match b.id:
		&"mason":
			return 8.2
		&"forge":
			return 8.2 if short(&"iron") > 0 or Village.store(&"iron") < 4 else -1.0
		&"printing_house":
			return 7.8 if short(&"books") > 0 else -1.0
		&"harbour":
			return 7.8 if short(&"brass") > 0 or short(&"tin") > 0 or Faith.has(&"calm_waters") else -1.0
	return -1.0

## Is a person wasted on this Era 3 job? -1 = let the others decide.
func wasted(s, p = null) -> int:
	var j: JobDef = s.get("job")
	if j == null or s.is_plot() or Village.era < 3:
		return -1
	match j.id:
		&"quarry_stone": return 1 if Village.store(&"blocks") >= 40 and short(&"blocks") == 0 else 0
		&"dress_stone": return 0 if _spare_stone() and (Village.store(&"blocks") < 34 or short(&"blocks") > 0) else 1
		&"mine_iron": return 1 if Village.store(&"iron_ore") >= 14 and short(&"iron_ore") == 0 else 0
		&"forge_iron": return 0 if _has(&"iron_ore", 2) and _has(&"charcoal", 1) and (Village.store(&"iron") < 14 or short(&"iron") > 0) else 1
		&"cast_brass": return 0 if _has(&"tin", 1) and _has(&"iron_ore", 1) and _has(&"charcoal", 1) else 1
		&"print_books": return 0 if _has(&"wood", 1) and _has(&"cloth", 1) and (Village.store(&"books") < 14 or short(&"books") > 0) else 1
		&"experiment": return 0 if _has(&"books", 4) else 1
		&"fight_fire": return 0 if _has(&"water", 1) else 1
		&"repair_roof": return 0 if _has(&"wood", 2) else 1
		&"fire_watch", &"keep_light", &"sail_islands", &"great_hall_raising", &"aqueduct_crew": return 0
		&"fish_ship": return 1 if Village.food() >= bot._food_target() + 10 else 0
		&"astronomy": return 1 if Flags.has(&"star_charts") or not Clock.is_night else 0
		&"pray_hall": return 1 if p != null and s.workers.find(p) >= bot._prayers_wanted() else 0
		&"attend_school", &"rest_at_clinic": return 0
	return -1

# ---------------------------------------------------------------- answers

## Returns true when it used the hand this think.
func think() -> bool:
	if Village.era < 3:
		return false
	if _ship() or _fire() or _sick() or _storm():
		return true
	_calm()
	_guide()
	return false

## The harbour's ship waits on the beach: set it on the sea.
func _ship() -> bool:
	var w = _w()
	if w.era3 == null or w.era3.ship == null or not w.era3.ship.visible or Flags.has(&"ship"):
		return false
	if Faith.strength < w.era3.ship.lift_weight():
		return false
	bot._move_object(w.era3.ship, Vector3(LayoutEra3.SHIP_ANCHOR.x, 0, LayoutEra3.SHIP_ANCHOR.y))
	launches += 1
	return true

## A voyage crew is waiting (or sailing): keep the sea calm under them.
func _calm() -> void:
	_calm_cd -= bot.THINK
	if _calm_cd > 0.0 or not Faith.has(&"calm_waters"):
		return
	var w = _w()
	var voyage: Site = null
	for s in Village.sites:
		if is_instance_valid(s) and s.job != null and s.job.id == &"sail_islands" and not s.is_plot():
			voyage = s
	if voyage == null or not Flags.has(&"ship"):
		return
	var crew: int = voyage.workers.filter(func(p): return is_instance_valid(p)).size()
	if crew < voyage.job.min_people - 1 and not voyage.group_running:
		return
	if w.era3.calm_t > 25.0:
		return
	_calm_cd = 1.5
	bot._gesture(&"calm_waters", w._v3(LayoutEra3.ROUGH_SEA), 4)
	calms += 1

## Night at the observatory: hold the Guiding Light over the sky.
func _guide() -> void:
	_guide_cd -= bot.THINK
	if _guide_cd > 0.0 or not Faith.has(&"guiding_light") or not Clock.is_night or Flags.has(&"star_charts"):
		return
	for s in Village.sites:
		if is_instance_valid(s) and s.job != null and s.job.id == &"astronomy" and not s.is_plot() and _present(s) > 0:
			_guide_cd = 8.0
			bot._gesture(&"guiding_light", s.global_position + Vector3(0, 30, 0), 3)
			guides += 1
			return

## A building burns: rain on it (the bucket line is staffed by score()).
func _fire() -> bool:
	if not Faith.has(&"rain"):
		return false
	for s in Era3Threats.burning_sites():
		bot._gesture(&"rain", s.global_position, 4)
		fire_rains += 1
		return false     # rain is held while the hand also places the bucket line
	return false

## Sickness: lift the sick to the clinic, a few at a time.
func _sick() -> bool:
	var clinic: Site = null
	for s in Village.sites:
		if is_instance_valid(s) and s.job != null and s.job.id == &"rest_at_clinic" and not s.is_plot() and s.can_accept(1):
			clinic = s
			break
	if clinic == null:
		return false
	var sick: Array = Village.alive().filter(func(p): return p.is_sick() and not p.at_clinic() and p.pickable() and p.stage != Person.Stage.BABY \
		and p.state not in [Person.S.HELD, Person.S.FALL] and not (p.job_site == clinic))
	if sick.is_empty():
		return false
	var h = bot._hand()
	var n := mini(clinic.free_slots(), Faith.grip)
	var batch := sick.slice(0, n)
	if h == null:
		bot._place_direct(batch, clinic)
		to_clinic += batch.size()
		return true
	for p in batch:
		if h.can_lift(p):
			h.try_lift(p)
	if h.held.is_empty():
		return false
	to_clinic += h.place_on_site(clinic)
	if not h.held.is_empty():
		h.place_on_ground(clinic.global_position + Vector3(3, 0, 3))
	bot._actions += 1
	return true

## A storm: shield people caught in the open (Warmth held over them).
func _storm() -> bool:
	var e = _e3()
	if e == null or not e.storm_on() or not Faith.has(&"warmth"):
		return false
	_shield_cd -= bot.THINK
	if _shield_cd > 0.0:
		return false
	var best: Person = null
	var best_n := 0
	for p in Village.alive():
		if not p.visible or p.warmed_t > 0.0 or p.state in [Person.S.SHELTER, Person.S.SLEEP]:
			continue
		var n := 0
		for q in Village.alive():
			if q.visible and q.warmed_t <= 0.0 and q.global_position.distance_squared_to(p.global_position) < 12.0:
				n += 1
		if n > best_n:
			best_n = n
			best = p
	if best == null:
		return false
	_shield_cd = 0.5
	bot._gesture(&"warmth", best.global_position, 2)
	shields += 1
	return false

func summary() -> String:
	return "ship launches %d | calms %d | guiding light %d | rain on fire %d | to clinic %d | storm shields %d" % [launches, calms, guides, fire_rains, to_clinic, shields] \
		+ " | [era3] roads paved %d | bench cycles %d | mill fetches %d | foreman joins %d | caravans %d | suggestions %d | threats %s" % [
			int(Village.stats.get("roads_paved", 0)), int(Village.stats.get("bench_cycles", 0)), int(Village.stats.get("mill_fetches", 0)),
			int(Village.stats.get("foreman_joins", 0)), int(Village.stats.get("caravans", 0)), int(Village.stats.get("suggestions", 0)),
			str(Village.stats.get("era3_threats_seen", []))]
