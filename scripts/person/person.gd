class_name Person extends CharacterBody3D
## One named villager. Era 1-2 people never take jobs on their own: the hand
## places them and they keep at it, eat at dawn and dusk, and run to shelter
## at night. Decisions (needs, work, AI) run on Events.sim_tick via sim();
## movement and animation run every frame via motion().
## Collision: layer 2 ("people"), mask 0, so the hand can ray-pick them.

enum Stage { BABY, CHILD, ADULT, ELDER }
enum S { IDLE, HELD, FALL, WALK, WORK, WAIT_GROUP, EAT, SLEEP, SHELTER, FLEE, DEAD }
const STATE_NAMES: Array[String] = ["idle", "held", "falling", "walking", "working", "waiting", "eating", "sleeping", "sheltering", "fleeing", "dead"]

const SCENE := "res://scenes/people/person.tscn"
## Life-cycle table (scaled game seconds): the age each stage begins at.
## Doc section 3: baby 0-6 min, child 6-15, adult 15-50, elder 50-65, death ~65.
const STAGE_START: Array[float] = [0.0, 360.0, 900.0, 3000.0]
const DEATH_AGE := 3900.0
const DEATH_JITTER := 150.0
const SKILLS: Array[StringName] = [&"gathering", &"woodcraft", &"building", &"farming", &"crafting", &"metalwork", &"scholarship", &"engineering"]
const TRAITS: Array[StringName] = [&"strong", &"quick", &"curious", &"devout", &"timid", &"brave", &"sociable", &"stubborn"]
const NEED_KEYS: Array[StringName] = [&"food", &"water", &"warmth", &"joy"]
## Per-second need decay. A day+night is ~105 s and people eat twice in it.
## A meal or a drink only when the need has dropped this far: about one of
## each a day, so a family's gatherers keep up and the rest can build.
const MEAL_BELOW := 0.65
## Gatherers carry this many cycles' worth to the store in one trip.
const ARMFUL := 3
## Builders fetching for a far plot carry a bundle: one more piece for every
## this many metres of walk, up to BUNDLE_MAX.
const BUNDLE_PER_M := 45.0
const BUNDLE_MAX := 4
const DECAY: Dictionary = {&"food": 0.0045, &"water": 0.006, &"joy": 0.002}
const WALK_SPEED := 3.0
const RUN_SPEED := 5.0
const GRAVITY := 20.0
const HAND_NEAR := 4.0
const ARRIVE := 0.35
const SKILL_PER_CYCLE := 0.04
const LIGHT_JOBS: Array[StringName] = [&"gather_berries", &"fetch_water", &"draw_water", &"herd_sheep", &"rich_berries", &"attend_school"]   # children, from Era 2 (school from Era 3)
## Era 3 sickness: a sick person works at half pace and mends in about this
## many game seconds (six times faster resting at the clinic, twice when blessed).
const SICK_TIME := 150.0
const CLINIC_HEAL := 6.0
const HOME_RANGE := 90.0                # beyond this a worker sleeps at the nearest shelter (a far-bank camp)
const WISH_LIFETIME := 90.0
const WISH_GAP := Vector2(600.0, 1100.0)    # game seconds between a granted wish and the next
const WISH_GIFT_CHANCE := 0.12         # a granted wish sometimes leaves a gift as well
const WISH_FAITH := Vector2(4.0, 6.0)     # faith for a granted wish (doc 6: +4 to +10)
const CARGO_COLOURS: Dictionary = {&"berries": Color(0.8, 0.15, 0.3), &"wood": Color(0.5, 0.33, 0.18),
	&"water": Color(0.3, 0.55, 0.95), &"stone": Color(0.6, 0.6, 0.62), &"meat": Color(0.7, 0.3, 0.25),
	&"fish": Color(0.7, 0.75, 0.8), &"hide": Color(0.6, 0.45, 0.3)}

## Foremen (Era 3+): Callable(p: Person) -> bool, true if it gave the idle person work.
static var autonomy_hook: Callable = Callable()

var uid: int = 0
var given_name: String = ""
var sex: String = "f"
var age: float = 1080.0
var death_age: float = DEATH_AGE
var stage: int = Stage.ADULT
var parents: Array[int] = []
var children: Array[int] = []
var partner: int = 0
var needs: Dictionary = {&"food": 1.0, &"water": 1.0, &"warmth": 1.0, &"joy": 0.7}
var skills: Dictionary = {}             # family -> 1.0..5.0 (stars = floor)
var traits: Array[StringName] = []
var trust: int = 1                      # 0..5, see design doc section 7
var trust_f: float = 1.5                # fractional trust; trust = floor(trust_f)
var wish: StringName = &""              # a JobDef id they want, or &"warmth"
var wish_t: float = 40.0                # wish lifetime, or cooldown before the next one
var job_site: Site = null
var home: Site = null
var state: int = S.IDLE
var placed_by_hand: bool = false
var wanderer: bool = false
var blessed_t: float = 0.0
var hurt_t: float = 0.0                 # seconds of injury left (a wolf bite): slower, heals
var warmed_t: float = 0.0
var look: Dictionary = {"skin": 0, "hair": 0, "height": 1.0}
var bonds: Dictionary = {}              # other uid -> bond progress (births.gd)
var last_birth_age: float = -1000.0
var named_by_hand: bool = false         # the hand chose this name (first two, baby prayers): a hand mark in the Book
var first_two: bool = false             # one of the two people of the storm night
var sick_t: float = 0.0                 # Era 3: seconds of sickness left (never fatal)
var _cold_t: float = 0.0                # seconds spent frozen (warmth 0): a cold makes them sick
var _sick_cd: float = 0.0

var visual: PersonVisual
var nav: NavigationAgent3D
var _opts: Dictionary = {}
var _loaded := false
var _resume: Site = null
var _phase: String = ""
var _timer: float = 0.0
var _cargo: Dictionary = {}
var _reserved: StringName = &""
var _target: Vector3 = Vector3.INF
var _speed: float = WALK_SPEED
var _moving := false
var _vel_y: float = 0.0
var _fall_site: Site = null
var _fall_to: Vector3 = Vector3.ZERO
var _wait_t: float = 0.0
var _decide_t: float = 0.0
var _flee_t: float = 0.0
var _rest_t: float = 0.0
var _company_t: float = 0.0
var _has_company := false
var _pray_t: float = 0.0
var _low: Dictionary = {}
var _pending: Dictionary = {}
var _pending_t: float = 0.0
var _dead_t: float = 0.0
var _nav_check_t: float = 0.0
var _nav_ok := false
var _hand_ref: WeakRef = null
var _hand_search_t: float = 0.0
var _started_working := false
var _waiting_for: StringName = &""
var _armful: int = 0
var _stuck_ref := Vector3.INF
var _stuck_t: float = 0.0
var _no_nav_t: float = 0.0
var _offering: Site = null              # walking to the shrine with an offering (trust 4+)

static func stage_for_age(a: float) -> int:
	var s := Stage.BABY
	for i in STAGE_START.size():
		if a >= STAGE_START[i]:
			s = i
	return s

## Instances a person and adds it under `parent` at `at`. `opts` may set any of:
## name, sex, age, parents (Array[int]), trust_f, look, traits, wanderer, home (Site).
static func spawn(parent: Node, at: Vector3, opts: Dictionary = {}) -> Person:
	var p: Person = (load(SCENE) as PackedScene).instantiate()
	p._opts = opts
	parent.add_child(p)
	at.y = Site.ground(at.x, at.z)
	p.global_position = at
	return p

func _ready() -> void:
	add_to_group("persist"); add_to_group("people")
	Village.register_person(self)
	if uid == 0:
		uid = Village.new_person_id()
	if not _loaded:
		_generate()
		_apply_opts()
	_build_nodes()
	_refresh_look()
	if not Events.sim_tick.is_connected(_on_sim_tick):
		Events.sim_tick.connect(_on_sim_tick)
		Events.day_started.connect(_on_day)
		Events.night_started.connect(_on_night)
		Events.era_changed.connect(_on_era)
	_decide_t = Game.rng.randf_range(0.2, 2.0)

func _exit_tree() -> void:
	Village.unregister_person(self)

func _generate() -> void:
	var rng := Game.rng
	sex = "f" if rng.randf() < 0.5 else "m"
	for f in SKILLS:
		skills[f] = 1.0 + rng.randf() * 0.6
	var tcount := 1 + (1 if rng.randf() < 0.45 else 0)
	while traits.size() < tcount:
		var t: StringName = TRAITS[rng.randi() % TRAITS.size()]
		if not traits.has(t):
			traits.append(t)
	look = {"skin": rng.randi() % PersonVisual.SKIN.size(), "hair": rng.randi() % PersonVisual.HAIR.size(),
		"height": rng.randf_range(0.92, 1.08), "outfit": (rng.randi() % 4) * 2 + (1 if sex == "f" else 0)}
	age = rng.randf_range(STAGE_START[Stage.ADULT] + 60.0, STAGE_START[Stage.ADULT] + 600.0)
	death_age = DEATH_AGE + rng.randf_range(-DEATH_JITTER, DEATH_JITTER)
	wish_t = rng.randf_range(60.0, 200.0)

func _apply_opts() -> void:
	var o := _opts
	if o.has("sex"):
		sex = o["sex"]
		if look.has("outfit"):
			look["outfit"] = (int(look["outfit"]) / 2) * 2 + (1 if sex == "f" else 0)
	if o.has("age"): age = float(o["age"])
	if o.has("parents"):
		parents.clear()
		for u in o["parents"]: parents.append(int(u))
	if o.has("trust_f"): trust_f = float(o["trust_f"])
	if o.has("look"): look = o["look"]
	if o.has("traits"):
		traits.clear()
		for t in o["traits"]: traits.append(StringName(t))
	if o.has("wanderer"): wanderer = bool(o["wanderer"])
	if o.has("home") and o["home"] is Site: home = o["home"]
	if o.has("first_two"): first_two = bool(o["first_two"])
	if o.has("death_age"): death_age = float(o["death_age"])
	given_name = o.get("name", "")
	if given_name == "":
		given_name = Names.pick(sex, Village.era, Game.rng, Names.taken_names())
	stage = stage_for_age(age)
	trust = clampi(floori(trust_f), 0, 5)
	_opts = {}

func _build_nodes() -> void:
	collision_layer = 2
	collision_mask = 0
	if get_node_or_null("Shape") == null:
		var cs := CollisionShape3D.new()
		cs.name = "Shape"
		var cap := CapsuleShape3D.new()
		cap.radius = 0.35; cap.height = 1.7
		cs.shape = cap
		cs.position = Vector3(0, 0.85, 0)
		add_child(cs)
	visual = get_node_or_null("Visual") as PersonVisual
	if visual == null:
		visual = PersonVisual.new()
		visual.name = "Visual"
		add_child(visual)
	nav = get_node_or_null("Nav") as NavigationAgent3D
	if nav == null:
		nav = NavigationAgent3D.new()
		nav.name = "Nav"
		nav.path_desired_distance = 0.5
		nav.target_desired_distance = ARRIVE
		nav.radius = 0.35
		nav.avoidance_enabled = false
		add_child(nav)

func _on_era(e: int) -> void:
	if visual != null:
		visual.set_era(e)

func _refresh_look() -> void:
	if visual == null:
		return
	# Older saves have no outfit: derive one that matches the person's sex.
	var outfit := int(look.get("outfit", -1))
	if outfit < 0:
		outfit = (posmod(int(look.get("skin", 0)) + int(look.get("hair", 0)) + uid, 4)) * 2 + (1 if sex == "f" else 0)
	visual.apply_look(int(look.get("skin", 0)), int(look.get("hair", 0)), float(look.get("height", 1.0)), stage == Stage.ELDER, stage, outfit)
	var wj := _job_def()
	visual.set_job_colour(wj.skill if wj != null else &"")
	visual.set_task(wj)   # the job's work clip and tools (TaskAnims)

# --- contract API -------------------------------------------------------------------

func alive() -> bool: return state != S.DEAD

## [hand] can the hand pick this person up now.
func pickable() -> bool:
	return alive() and state != S.HELD and state != S.FALL and stage != Stage.BABY and visible

## [hand] weight for Strength (person = 1).
func weight() -> float:
	match stage:
		Stage.BABY: return 0.3
		Stage.CHILD: return 0.5
	return 1.0

## [hand] called when lifted; person stops what it's doing, plays the held pose.
func on_lifted() -> void:
	if not alive():
		return
	_leave_shelter()
	_leave_job()
	_resume = null
	state = S.HELD
	_target = Vector3.INF
	_moving = false
	if trust >= 3:
		adjust_trust(0.02)

## [hand] called when released. `site` may be null (ground). The person falls,
## lands at `at`, then joins `site` if given and it can accept, else idles.
func on_placed(at: Vector3, site: Site) -> void:
	if not alive():
		return
	state = S.FALL
	_path_to = Vector3.INF          # walk on from where the hand set them down
	_fall_to = at
	_fall_site = site
	_vel_y = 0.0
	placed_by_hand = true

## [hand] while held, the hand moves the person with this each frame.
## +0.2 faith for "a job completed by someone you placed" (doc 6): once per
## placement, and at most once a minute and a half per person, so shuffling
## people about is not a faith farm.
const PLACE_FAITH := 0.2
const PLACE_FAITH_GAP := 90.0
var _place_faith_t: float = -INF

func _placement_faith() -> void:
	if not placed_by_hand:
		return
	placed_by_hand = false
	if Clock.total_t - _place_faith_t < PLACE_FAITH_GAP:
		return
	_place_faith_t = Clock.total_t
	Faith.add(PLACE_FAITH, global_position)

func held_follow(world_pos: Vector3) -> void: global_position = world_pos

## [ui] one line under the name, e.g. "Gathering berries · hungry · wants: tend the fire".
func status_text() -> String:
	var parts: Array[String] = [_activity_text()]
	if needs[&"food"] < 0.3: parts.append("hungry")
	if needs[&"water"] < 0.3: parts.append("thirsty")
	if needs[&"warmth"] < 0.3: parts.append("cold")
	if needs[&"joy"] < 0.25: parts.append("sad")
	if blessed_t > 0.0: parts.append("blessed")
	if sick_t > 0.0: parts.append("sick (carry them to the clinic)" if not at_clinic() else "sick, resting at the clinic")
	if wish != &"":
		parts.append("wants: " + _wish_title())
	return " · ".join(parts)

# --- extra API (hand powers, threats, UI) -----------------------------------------

func stage_name() -> String:
	return ["baby", "child", "adult", "elder"][stage]

func stars(family: StringName) -> int:
	return clampi(floori(float(skills.get(family, 1.0))), 1, 5)

func has_trait(t: StringName) -> bool:
	return traits.has(t)

func mood() -> float:
	return (needs[&"food"] + needs[&"water"] + needs[&"warmth"] + needs[&"joy"]) * 0.25

## Work speed multiplier: mood 70-125%, friend of the hand +25%, Blessing 2x.
func rate() -> float:
	var r := lerpf(0.7, 1.25, clampf(mood(), 0.0, 1.0))
	if trust >= 5: r *= 1.25
	if blessed_t > 0.0: r *= 2.0
	if stage == Stage.ELDER: r *= 0.6
	if sick_t > 0.0: r *= 0.5
	var jd := _job_def()
	if jd != null:
		r *= 1.0 + 0.1 * float(stars(_family(jd.skill)) - 1)
		if Flags.has(&"iron_tools") and jd.kind in [JobDef.Kind.GATHER, JobDef.Kind.CRAFT, JobDef.Kind.TEND, JobDef.Kind.BUILD]:
			r *= 1.7           # iron tools: +70% (Era 3), building too
		elif Flags.has(&"bronze_tools") and jd.kind in [JobDef.Kind.GATHER, JobDef.Kind.CRAFT, JobDef.Kind.TEND]:
			r *= 1.5           # bronze tools: +50% (doc 4, Era 2)
		elif jd.kind == JobDef.Kind.GATHER and Flags.has(&"stone_tools"):
			r *= 1.25          # stone tools: +25% gather speed (doc 4)
	return r

func adjust_trust(d: float) -> void:
	if d > 0.0 and has_trait(&"devout"):
		d *= 1.25
	var before := trust
	trust_f = clampf(trust_f + d, 0.0, 5.99)
	trust = clampi(floori(trust_f), 0, 5)
	if trust != before and trust > before and trust == 5:
		Events.toast.emit("%s is a friend of the hand" % given_name)

## Warmth power: the hand warms this person.
func warm(seconds: float = 10.0) -> void:
	warmed_t = maxf(warmed_t, seconds)
	needs[&"warmth"] = minf(needs[&"warmth"] + 0.3, 1.0)
	if wish == &"warmth":
		_grant_wish()
	else:
		adjust_trust(0.1)

## Blessing power: works 2x for `seconds`.
func bless(seconds: float = 30.0) -> void:
	if blessed_t <= 0.0:
		adjust_trust(0.05)
	blessed_t = maxf(blessed_t, seconds)

func is_blessed() -> bool:
	return blessed_t > 0.0

## Onboarding: they want this job and show it (pointing, a wish bubble).
func point_at(s: Site) -> void:
	if s == null or not is_instance_valid(s) or s.job == null:
		return
	wish = s.job.id
	wish_t = WISH_LIFETIME * 3.0
	var d := s.global_position - global_position
	rotation.y = atan2(d.x, d.z)
	_show_wish()

## [ui] the hand gave this person a name (Events.names_given).
func set_name_from_hand(n: String) -> void:
	n = n.strip_edges()
	if n != "":
		given_name = n.substr(0, 16)
	named_by_hand = true

## Threats: run away from `from` for a while (keeps the job to return to).
func flee_from(from: Vector3, seconds: float = 4.0) -> void:
	if state in [S.HELD, S.FALL, S.DEAD, S.SHELTER] or stage == Stage.BABY:
		return
	if job_site != null and is_instance_valid(job_site):
		_resume = job_site
	_leave_job()
	state = S.FLEE
	_flee_t = seconds
	var away := global_position - from
	away.y = 0.0
	if away.length() < 0.01:
		away = Vector3(Game.rng.randf_range(-1, 1), 0, Game.rng.randf_range(-1, 1))
	_go(global_position + away.normalized() * 6.0, RUN_SPEED)

## Sends the person to sit idle where they are (used by sites when work ends).
func go_idle() -> void:
	if state == S.DEAD or state == S.HELD or state == S.FALL:
		return
	_leave_job()
	state = S.IDLE
	_target = Vector3.INF
	_decide_t = Game.rng.randf_range(0.5, 2.0)

## Joins a site (the hand's placement calls this through on_placed).
func join(s: Site, by_hand: bool = true) -> bool:
	if s == null or not is_instance_valid(s) or not alive():
		return false
	if not s.can_accept(1) or not can_do(s):
		return false
	_offering = null
	_leave_job()
	if s.job == null and s.is_shelter():
		_enter_shelter_site(s)
		return true
	job_site = s
	s.claim(self)
	_phase = "go"
	_timer = 0.0
	_wait_t = 0.0
	_started_working = false
	state = S.WAIT_GROUP if s.is_group() and not s.group_running else S.WORK
	_go(s.slot_position(s.slot_of(self)), WALK_SPEED)
	var jd := s.work_job()
	if visual: visual.set_job_colour(jd.skill if jd else &"")
	if visual: visual.set_task(jd)   # the job's work clip and tools (TaskAnims)
	if by_hand:
		if wish != &"" and jd != null and jd.id == wish:
			_grant_wish()
		else:
			adjust_trust(0.05)
	return true

## Can this person do the work at `s` (stage, era rules)?
func can_do(s: Site) -> bool:
	if s.job == null and s.is_shelter():
		return true
	match stage:
		Stage.BABY: return false
		Stage.CHILD:
			var jd := s.work_job()
			return Village.era >= 2 and jd != null and LIGHT_JOBS.has(jd.id)
	return true

## [site] is this person standing at their slot at `s`?
func is_present_at(s: Site, r: float = 0.9) -> bool:
	if job_site != s or (state != S.WAIT_GROUP and state != S.WORK):
		return false
	var slot := s.slot_position(s.slot_of(self))
	var d := global_position - slot
	d.y = 0.0
	return d.length() <= r

## [site] the group formed: start working together.
func begin_group_work(_s: Site) -> void:
	state = S.WORK
	_phase = "work"
	_wait_t = 0.0

## [site] the group broke up or finished a cycle: wait for the next one.
func back_to_waiting() -> void:
	if state == S.WORK:
		state = S.WAIT_GROUP
		_wait_t = 0.0

## [site] a group cycle finished with this person in it.
func on_group_done(s: Site) -> void:
	_gain_skill(s.job.skill, SKILL_PER_CYCLE * 2.0)
	needs[&"joy"] = minf(needs[&"joy"] + 0.1, 1.0)
	_placement_faith()

## Sends the person to eat at the store (dawn and dusk).
func go_eat() -> void:
	if state in [S.HELD, S.FALL, S.DEAD, S.FLEE] or stage == Stage.BABY:
		return
	if state == S.SHELTER or state == S.SLEEP:
		_leave_shelter()
	var wants_food: bool = needs[&"food"] < MEAL_BELOW and Village.food() > 0
	var wants_water: bool = needs[&"water"] < MEAL_BELOW and Village.store(&"water") > 0
	if not wants_food and not wants_water:
		if (state == S.WORK or state == S.WAIT_GROUP) and job_site != null and is_instance_valid(job_site) and not Clock.is_night:
			return            # nothing to eat: keep working
		_after_eat()
		return
	# Working far from the store: eat when really hungry, not at every meal.
	if job_site != null and is_instance_valid(job_site) and not Clock.is_night \
			and global_position.distance_to(Site.store_point(global_position)) > 35.0 \
			and needs[&"food"] > 0.4 and needs[&"water"] > 0.4:
		return
	if job_site != null and is_instance_valid(job_site):
		_resume = job_site
	_offering = null
	_leave_job()
	state = S.EAT
	_go(_store_slot(), WALK_SPEED)

## Night: to the home hut, any hut with room, the fire, or the stash.
func go_rest() -> void:
	if state in [S.HELD, S.FALL, S.DEAD]:
		return
	if job_site != null and is_instance_valid(job_site):
		_resume = job_site
	_offering = null
	_leave_job()
	var hut: Site = null
	if home != null and is_instance_valid(home) and home.shelter_room() > 0 and home.global_position.distance_to(global_position) < HOME_RANGE:
		hut = home
	else:
		hut = Site.nearest(global_position, 80.0, func(s): return s.is_shelter() and s.shelter_room() > 0 and (s.building.camp or s == home or not _others_home(s)))
	if hut != null:
		state = S.SHELTER
		_phase = "to_hut"
		_fall_site = hut
		_go(hut.global_position + Vector3(0, 0, hut.pick_radius() + 0.2), RUN_SPEED)
		return
	state = S.SLEEP
	_phase = "to_bed"
	var fire := Site.nearest_warmth(global_position)
	var c := fire.global_position if fire else Site.store_point(global_position)
	var a := float(uid) * 2.39996
	_go(c + Vector3(cos(a), 0, sin(a)) * Game.rng.randf_range(1.8, 2.8), WALK_SPEED)

## True when this shelter is someone else's family home with no room to spare.
func _others_home(s: Site) -> bool:
	return s.shelter_room() <= 1 and Births.home_residents(s) >= s.building.shelter - 1

func wake() -> void:
	if state == S.SHELTER or state == S.SLEEP:
		_leave_shelter()
		state = S.IDLE
		_target = Vector3.INF

func die(cause: String = "old age") -> void:
	if state == S.DEAD:
		return
	_leave_shelter()
	_leave_job()
	visible = true
	state = S.DEAD
	_target = Vector3.INF
	remove_from_group("persist")
	Village.stats["deaths"] = int(Village.stats.get("deaths", 0)) + 1
	for p in Village.alive():
		if p.uid == partner or parents.has(p.uid) or children.has(p.uid):
			p.needs[&"joy"] = maxf(p.needs[&"joy"] - 0.35, 0.0)
	Memorial.add_name(self, cause)
	Events.person_died.emit(self)

# --- sim (10 Hz) -------------------------------------------------------------------

const HURT_TIME := 120.0                # a bite heals in about two game minutes

## An injury (a wolf bite, a fall). It slows them and heals by itself; in Era 1 it
## never kills. `amount` 1.0 is one bite; bites stack up to three.
func hurt(amount: float = 1.0, cause: StringName = &"") -> void:
	if state == S.DEAD:
		return
	hurt_t = minf(hurt_t + HURT_TIME * amount, HURT_TIME * 3.0)
	if cause == &"wolf":
		Village.stats["wolf_bites"] = int(Village.stats.get("wolf_bites", 0)) + 1
	needs[&"joy"] = maxf(float(needs.get(&"joy", 0.5)) - 0.15, 0.0)
	if visual: visual.set_hurt(0.8)
	if cause == &"cold":
		Events.alert.emit("%s caught a chill" % given_name, global_position)
	elif cause != &"wolf":    # the wolf raises its own alert
		Events.alert.emit("%s was hurt" % given_name, global_position)
	if state == S.WORK or state == S.IDLE or state == S.WALK or state == S.WAIT_GROUP:
		flee_from(global_position + Vector3(Game.rng.randf_range(-1, 1), 0, Game.rng.randf_range(-1, 1)), 1.0)

func is_hurt() -> bool:
	return hurt_t > 0.0

## Era 3 sickness (never fatal): slower work until they mend.
func fall_sick() -> void:
	if state == S.DEAD or sick_t > 0.0 or stage == Stage.BABY:
		return
	sick_t = SICK_TIME * Game.rng.randf_range(0.85, 1.15)
	Village.stats["fell_sick"] = int(Village.stats.get("fell_sick", 0)) + 1
	if visual: visual.set_hurt(0.6)

func is_sick() -> bool:
	return sick_t > 0.0

## Resting at the clinic (placed there by the hand): mending fast, not passing it on.
func at_clinic() -> bool:
	return job_site != null and is_instance_valid(job_site) and job_site.job != null and job_site.job.id == &"rest_at_clinic" and is_present_at(job_site, 1.6)

func _sim_sick(dt: float) -> void:
	var k := 1.0
	if at_clinic():
		k = CLINIC_HEAL
	if blessed_t > 0.0:
		k *= 2.0
	sick_t = maxf(sick_t - dt * k, 0.0)
	if sick_t <= 0.0:
		Village.stats["got_well"] = int(Village.stats.get("got_well", 0)) + 1
		if visual: visual.set_hurt(0.0)
		if at_clinic():
			go_idle()     # mended: back to their life

func sim(dt: float) -> void:
	if state == S.DEAD:
		return
	_resolve_links()
	_age(dt)
	if state == S.DEAD:
		return
	_sim_needs(dt)
	_sim_wish(dt)
	blessed_t = maxf(blessed_t - dt, 0.0)
	warmed_t = maxf(warmed_t - dt, 0.0)
	if hurt_t > 0.0:
		hurt_t = maxf(hurt_t - dt * (2.0 if blessed_t > 0.0 else 1.0), 0.0)
		if visual: visual.set_hurt(clampf(hurt_t / HURT_TIME, 0.0, 1.0) * 0.8)
	if sick_t > 0.0:
		_sim_sick(dt)
	match state:
		S.IDLE: _sim_idle(dt)
		S.WALK:
			if _arrived():
				state = S.IDLE
				if _offering != null:
					_leave_offering()
		S.WORK: _sim_work(dt)
		S.WAIT_GROUP: _sim_wait(dt)
		S.EAT: _sim_eat()
		S.SLEEP, S.SHELTER: _sim_rest(dt)
		S.FLEE:
			_flee_t -= dt
			if _flee_t <= 0.0:
				state = S.IDLE
				_target = Vector3.INF
				if _resume != null and is_instance_valid(_resume):
					var r := _resume
					_resume = null
					join(r, false)

func _age(dt: float) -> void:
	age += dt
	var st := stage_for_age(age)
	if st != stage:
		stage = st
		_refresh_look()
		Events.person_aged.emit(self, stage)
	if age >= death_age:
		die("old age")

func _is_cold() -> bool:
	return Clock.is_night or Clock.season == Clock.Season.WINTER

func _sim_needs(dt: float) -> void:
	needs[&"food"] -= DECAY[&"food"] * Flags.diff_k(&"food") * dt
	needs[&"water"] -= DECAY[&"water"] * dt
	var sheltered := state == S.SHELTER and _phase == "inside"
	# Which fires and joyful places are near: looked up a few times a second,
	# not every tick (a town has a lot of buildings to look through).
	_env_t -= dt
	if _env_t <= 0.0:
		_env_t = ENV_EVERY
		_env_warm = Site.warmth_at(global_position) != null
		_env_joy = Site.joy_at(global_position)
	var warm_src := sheltered or warmed_t > 0.0 or _env_warm
	var w: float = needs[&"warmth"]
	if warm_src:
		w += 0.04 * dt
	elif _is_cold():
		var loss := (0.012 if Clock.season == Clock.Season.WINTER else 0.007)
		if Game.world != null and is_instance_valid(Game.world) and Game.world.threats != null and Game.world.threats.cold():
			loss *= 1.8        # a cold snap
		if Flags.has(&"woven_clothes"):
			loss *= 0.45       # wool and linen from the loom (Era 2)
		elif Flags.has(&"hide_clothes"):
			loss *= 0.6        # hide clothes from the hunt
		w -= loss * Flags.diff_k(&"cold") * dt
	else:
		w += 0.01 * dt
	needs[&"warmth"] = w
	# Frozen for a while: they catch a chill and work slowly for about a day.
	_sick_cd = maxf(_sick_cd - dt, 0.0)
	if w <= 0.02 and stage != Stage.BABY:
		_cold_t += dt
		if _cold_t > 25.0 and _sick_cd <= 0.0:
			_cold_t = 0.0
			_sick_cd = 150.0
			hurt(0.6, &"cold")
	else:
		_cold_t = 0.0
	var j: float = needs[&"joy"] - DECAY[&"joy"] * dt
	_company_t -= dt
	if _company_t <= 0.0:
		_company_t = 1.0
		_has_company = _near_someone(3.0)
	if _has_company:
		j += (0.008 if has_trait(&"sociable") else 0.004) * dt
	if _env_joy:
		j += 0.006 * dt
	needs[&"joy"] = j
	for k in NEED_KEYS:
		needs[k] = clampf(needs[k], 0.0, 1.0)
		if needs[k] < 0.25 and not _low.get(k, false):
			_low[k] = true
			Events.person_need_low.emit(self, k)
		elif needs[k] > 0.4:
			_low[k] = false

const ENV_EVERY := 0.4
var _env_t: float = 0.0
var _env_warm: bool = false
var _env_joy: bool = false

func _near_someone(r: float) -> bool:
	var r2 := r * r
	for p in Village.people:
		if p != self and is_instance_valid(p) and p.alive() and p.visible and p.global_position.distance_squared_to(global_position) <= r2:
			return true
	return false

## [ui hook] wants are optional bonuses now (scripts/ai/wants.gd owns the rules).
func _sim_wish(dt: float) -> void:
	Wants.sim(self, dt)

func _grant_wish() -> void:
	Wants.grant(self)

func _show_wish() -> void:
	if visual == null:
		return
	if wish == &"":
		visual.set_wish(null)
	elif wish == &"warmth":
		visual.set_wish(Color(1.0, 0.5, 0.1))
	else:
		var jd := Defs.job(wish)
		visual.set_wish(PersonVisual.JOB_COLOURS.get(jd.skill if jd else &"", Color.WHITE))

func _wish_title() -> String:
	if wish == &"warmth":
		return "warmth"
	var jd := Defs.job(wish)
	return jd.title.to_lower() if jd else str(wish)

func _sim_idle(dt: float) -> void:
	if stage == Stage.BABY:
		return
	_decide_t -= dt
	if _decide_t > 0.0:
		return
	_decide_t = Game.rng.randf_range(1.5, 3.5)
	if Village.era >= 3 and autonomy_hook.is_valid():
		if autonomy_hook.call(self):
			return
	# Era 2 autonomy (doc 3): children copy a parent's light job.
	if Village.era >= 2 and stage == Stage.CHILD and not Clock.is_night and _copy_parent_job():
		return
	# Utility scoring: the best-scoring sensible thing to do.
	var best := &"wander"
	var score := 0.15
	var s: float
	if Village.food() > 0:
		s = (1.0 - needs[&"food"]) * 1.3 - 0.45
		if s > score: score = s; best = &"eat"
	if Village.store(&"water") > 0:
		s = (1.0 - needs[&"water"]) * 1.3 - 0.45
		if s > score: score = s; best = &"eat"
	var fire: Site = null
	if _is_cold() and needs[&"warmth"] < 0.7 and Site.warmth_at(global_position) == null:
		fire = Site.nearest_warmth(global_position)
		if fire != null:
			s = (1.0 - needs[&"warmth"]) * 1.1
			if s > score: score = s; best = &"warm"
	var friend: Person = null
	if needs[&"joy"] < 0.6 and not _has_company:
		friend = _nearest_person(14.0)
		if friend != null:
			s = (1.0 - needs[&"joy"]) * 0.6
			if s > score: score = s; best = &"social"
	match best:
		&"eat": go_eat()
		&"warm":
			var a := Game.rng.randf() * TAU
			_walk(fire.global_position + Vector3(cos(a), 0, sin(a)) * Game.rng.randf_range(1.5, 2.5))
		&"social":
			var a2 := Game.rng.randf() * TAU
			_walk(friend.global_position + Vector3(cos(a2), 0, sin(a2)) * 1.4)
		_:
			var anchor := _anchor()
			var off := Vector3(Game.rng.randf_range(-3.5, 3.5), 0, Game.rng.randf_range(-3.5, 3.5))
			if global_position.distance_to(anchor) > 6.0 or Game.rng.randf() < 0.6:
				_walk(anchor + off)

func _copy_parent_job() -> bool:
	var par := _a_parent()
	if par == null or par.job_site == null or not is_instance_valid(par.job_site):
		return false
	var s: Site = par.job_site
	var jd := s.work_job()
	if jd == null or not LIGHT_JOBS.has(jd.id):
		return false
	if s.can_accept(1):
		return join(s, false)
	var near := Site.nearest(s.global_position, 25.0, func(o): return o.job != null and o.job.id == jd.id and o.can_accept(1) and not o.is_plot())
	return near != null and join(near, false)

## Devoted people (trust 4+) bring the hand things (doc 7): they walk to the
## shrine or temple and leave an offering there.
func bring_offering(shrine: Site) -> bool:
	if shrine == null or stage == Stage.BABY:
		return false
	if state == S.WORK and job_site != null and is_instance_valid(job_site) and not job_site.is_group() and not job_site.is_plot():
		_resume = job_site       # back to work afterwards
		_leave_job()
		state = S.IDLE
	if state != S.IDLE:
		return false
	_offering = shrine
	_walk(shrine.global_position + Vector3(Game.rng.randf_range(-1.5, 1.5), 0, shrine.pick_radius() + 1.0))
	return true

func _leave_offering() -> void:
	var s := _offering
	_offering = null
	if s == null or not is_instance_valid(s):
		return
	var g := Gifts.spawn_gift(self)
	if g != null:
		g.faith_value = maxf(g.faith_value, 4.0)
		Village.stats["offerings"] = int(Village.stats.get("offerings", 0)) + 1
		adjust_trust(0.05)
		VillageEra2.hint("offering", "%s brought the hand an offering at the shrine. Pick it up" % given_name, g.global_position)
	if _resume != null and is_instance_valid(_resume):
		var r := _resume
		_resume = null
		join(r, false)

func _anchor() -> Vector3:
	if stage == Stage.CHILD:
		var par := _a_parent()
		if par != null:
			return par.global_position
	if home != null and is_instance_valid(home):
		return home.global_position + Vector3(0, 0, home.pick_radius() + 1.5)
	return Site.store_point(global_position)

func _nearest_person(r: float) -> Person:
	var best: Person = null
	var bd := r * r
	for p in Village.people:
		if p != self and is_instance_valid(p) and p.alive() and p.visible and p.stage != Stage.BABY:
			var d: float = p.global_position.distance_squared_to(global_position)
			if d < bd:
				bd = d; best = p
	return best

func _a_parent() -> Person:
	# asked every frame for a baby on a hip: looked up again twice a second
	if absf(Clock.total_t - _parent_t) < 0.5 and (_parent == null or (is_instance_valid(_parent) and _parent.alive())):
		return _parent
	_parent_t = Clock.total_t
	var best: Person = null
	if not parents.is_empty():
		for p in Village.people:
			if is_instance_valid(p) and p.alive() and parents.has(p.uid):
				if best == null or (p.sex == "f" and best.sex != "f"):
					best = p
	_parent = best
	return best

var _parent: Person = null
var _parent_t: float = -10.0

# --- work -----------------------------------------------------------------------------

func _job_def() -> JobDef:
	if job_site != null and is_instance_valid(job_site):
		return job_site.work_job()
	return null

static func _family(skill: StringName) -> StringName:
	if skill == &"gather": return &"gathering"
	return skill

func _gain_skill(skill: StringName, amount: float) -> void:
	var f := _family(skill)
	if not SKILLS.has(f):
		return
	if has_trait(&"curious"):
		amount *= 1.5
	if job_site != null and is_instance_valid(job_site):
		for w in job_site.workers:
			if is_instance_valid(w) and w != self and w.stage == Stage.ELDER:
				amount *= 2.0     # an elder beside an apprentice doubles skill gain
				break
	skills[f] = minf(float(skills.get(f, 1.0)) + amount, 5.0)

func _sim_work(dt: float) -> void:
	var s := job_site
	if s == null or not is_instance_valid(s) or s.is_queued_for_deletion():
		go_idle()
		return
	if s.is_plot():
		_work_build(dt, s)
		return
	if s.job == null:
		go_idle()
		return
	match s.job.kind:
		JobDef.Kind.GROUP:
			if not s.group_running:
				state = S.WAIT_GROUP
		JobDef.Kind.DEVOTION:
			_work_pray(dt, s)
		JobDef.Kind.TEND, JobDef.Kind.CRAFT:
			if s.is_field():
				_work_field(dt, s)
			else:
				_work_craft(dt, s)
		_:
			_work_gather(dt, s)

func _first_work(s: Site) -> void:
	if not _started_working:
		_started_working = true
		Events.job_started.emit(s, [self])

func _work_gather(dt: float, s: Site) -> void:
	match _phase:
		"go":
			_target = s.slot_position(s.slot_of(self))
			if _arrived():
				_phase = "work"
				_timer = 0.0
		"work":
			if not s.can_work_now():
				_waiting_for = &"regrowth"
				var other := Site.nearest(global_position, 15.0, func(o): return o != s and o.job == s.job and o.can_accept(1) and o.can_work_now())
				if other != null:
					join(other, false)
				return
			_waiting_for = &""
			_first_work(s)
			_timer += dt * rate()
			if _timer >= s.job.work_time:
				_timer = 0.0
				if s.take_one():
					for k in s.job.outputs:
						_cargo[k] = int(_cargo.get(k, 0)) + int(s.job.outputs[k])
					_set_cargo_visual()
					# an armful before the walk to the store (one trip per ARMFUL cycles)
					_armful += 1
					if _armful >= ARMFUL or not s.can_work_now():
						_armful = 0
						_phase = "carry"
						_go(_store_slot(), WALK_SPEED)
		"carry":
			if _arrived():
				for k in _cargo:
					Village.add_store(k, int(_cargo[k]))
				_cargo.clear()
				_set_cargo_visual()
				_gain_skill(s.job.skill, SKILL_PER_CYCLE)
				_placement_faith()
				Events.job_completed.emit(s)
				_phase = "go"

func _work_craft(dt: float, s: Site) -> void:
	_target = s.slot_position(s.slot_of(self))
	if not _arrived():
		return
	if s.is_fire() and not s.fire_wants_fuel():
		_waiting_for = &""
		return                  # the fire is full; sit by it
	if _phase != "work":
		# Start a cycle: take the inputs from the stores.
		for k in s.job.inputs:
			if Village.store(k) < int(s.job.inputs[k]):
				_waiting_for = k
				return
		for k in s.job.inputs:
			Village.take_store(k, int(s.job.inputs[k]))
		_waiting_for = &""
		_phase = "work"
		_timer = 0.0
		_first_work(s)
	_timer += dt * rate()
	if _timer >= s.job.work_time:
		_timer = 0.0
		_phase = "go"
		for k in s.job.outputs:
			Village.add_store(k, int(s.job.outputs[k]))
		_gain_skill(s.job.skill, SKILL_PER_CYCLE)
		_placement_faith()
		s.on_cycle_done(self)

## Farming (Era 2): sow, water and weed, harvest, fight the blight. The field
## says what it needs; with nothing to do they wait for the crop to grow.
func _work_field(dt: float, s: Site) -> void:
	_target = s.slot_position(s.slot_of(self))
	if not _arrived():
		return
	var want := s.field_want()
	if want == &"" and s.field_stage != Site.Field.SPROUTS and s.field_stage != Site.Field.GROWING:
		_waiting_for = &"growing" if Site.sowing_season() else &"spring"
		_phase = "wait"
		return
	_waiting_for = &""
	_phase = "work"
	_first_work(s)
	if s.field_tend(dt * rate()):
		_gain_skill(&"farming", SKILL_PER_CYCLE * 2.0)
		_placement_faith()

func _work_pray(dt: float, s: Site) -> void:
	_target = s.slot_position(s.slot_of(self))
	if not _arrived():
		return
	_phase = "work"
	_first_work(s)
	var m := lerpf(0.5, 1.2, mood()) * (1.5 if has_trait(&"devout") else 1.0)
	Faith.add(s.job.faith_rate * dt * m, global_position)
	needs[&"joy"] = minf(needs[&"joy"] + 0.003 * dt, 1.0)
	_gain_skill(&"scholarship", 0.002 * dt)
	_pray_t += dt
	if _pray_t >= 60.0:
		_pray_t = 0.0
		if Game.rng.randf() < minf(0.04 + 0.02 * float(trust), 0.15):
			Gifts.spawn_gift(self)

func _work_build(dt: float, s: Site) -> void:
	if s.state == Site.State.BUILDING:
		_target = s.slot_position(s.slot_of(self))
		if _arrived():
			_first_work(s)
			_phase = "build"
			s.add_build_work(dt * rate())
			_gain_skill(&"building", 0.003 * dt)
		return
	match _phase:
		"go", "fetch":
			if _reserved == &"":
				var m := s.next_material()
				if m == &"":
					_target = s.slot_position(s.slot_of(self))   # all on its way; wait to build
					return
				_reserved = m
				s.reserve(m, 1)
				_phase = "fetch"
				_go(_store_slot(), WALK_SPEED)
			if _arrived():
				# a bundle for a long walk (the bridge, a far-bank plot), one more if strong
				var bmax := BUNDLE_MAX * (2 if Flags.has(&"carts") else 1)     # Era 3 carts
				var want := 1 + clampi(int(global_position.distance_to(s.global_position) / BUNDLE_PER_M), 0, bmax - 1)
				if has_trait(&"strong"):
					want += 1
				var extra := mini(want - 1, mini(s.remaining(_reserved), Village.store(_reserved) - 1))
				extra = maxi(extra, 0)
				s.reserve(_reserved, extra)
				var n := 1 + extra
				if Village.take_store(_reserved, n):
					_waiting_for = &""
					_cargo = {_reserved: n}
					_set_cargo_visual()
					_phase = "deliver"
					_go(s.slot_position(s.slot_of(self)), WALK_SPEED)
				else:
					if extra > 0:
						s.unreserve(_reserved, extra)
					_waiting_for = _reserved
					# none in the store: drop the claim and fetch something the store has
					s.unreserve(_reserved, 1)
					var alt := s.next_material()
					if alt != _reserved and Village.store(alt) > 0:
						_reserved = alt
						s.reserve(alt, 1)
						_waiting_for = &""
					else:
						s.reserve(_reserved, 1)
		"deliver":
			_target = s.slot_position(s.slot_of(self))
			if _arrived():
				_first_work(s)
				for k in _cargo:
					s.deliver(k, int(_cargo[k]))
				_cargo.clear()
				_reserved = &""
				_set_cargo_visual()
				_phase = "fetch"
		_:
			_phase = "fetch"

func _sim_wait(dt: float) -> void:
	var s := job_site
	if s == null or not is_instance_valid(s) or s.is_queued_for_deletion():
		go_idle()
		return
	_target = s.slot_position(s.slot_of(self))
	if s.group_running:
		return
	_wait_t += dt
	if _wait_t >= s.job.wait_before_wander:
		_leave_job()
		Events.group_job_failed.emit(s)
		var a := Game.rng.randf() * TAU
		state = S.WALK
		_go(global_position + Vector3(cos(a), 0, sin(a)) * Game.rng.randf_range(4.0, 6.0), WALK_SPEED)

func _sim_eat() -> void:
	if not _arrived():
		return
	if needs[&"food"] < MEAL_BELOW and Village.eat_one():
		needs[&"food"] = minf(needs[&"food"] + 0.6, 1.0)
		needs[&"joy"] = minf(needs[&"joy"] + 0.03, 1.0)
	if needs[&"water"] < MEAL_BELOW and Village.take_store(&"water", 1):
		needs[&"water"] = minf(needs[&"water"] + 0.7, 1.0)
	# Feed any baby they are carrying.
	for p in Village.people:
		if is_instance_valid(p) and p.alive() and p.stage == Stage.BABY and p.parents.has(uid) and p._carrier() == self:
			if p.needs[&"food"] < 0.8 and Village.eat_one():
				p.needs[&"food"] = 1.0
			p.needs[&"water"] = 1.0
	_after_eat()

func _after_eat() -> void:
	if Clock.is_night:
		go_rest()
		return
	state = S.IDLE
	_target = Vector3.INF
	if _resume != null and is_instance_valid(_resume):
		var r := _resume
		_resume = null
		join(r, false)

func _sim_rest(dt: float) -> void:
	_rest_t += dt
	if state == S.SHELTER and _phase == "to_hut":
		if _arrived():
			var hut := _fall_site
			if hut != null and is_instance_valid(hut) and hut.enter_shelter(self):
				_phase = "inside"
				visible = false
				_rest_t = 0.0
			else:
				go_rest()
		return
	if state == S.SLEEP and _phase == "to_bed" and _arrived():
		_phase = "asleep"
	# Placed in a shelter by day (a storm, a wolf): come out after a while.
	if not Clock.is_night and _rest_t > 30.0:
		wake()
		if _resume != null and is_instance_valid(_resume):
			var r := _resume
			_resume = null
			join(r, false)

func _enter_shelter_site(s: Site) -> void:
	if job_site != null and is_instance_valid(job_site):
		_resume = job_site
	_leave_job()
	state = S.SHELTER
	_phase = "to_hut"
	_fall_site = s
	_rest_t = 0.0
	_go(s.global_position + Vector3(0, 0, s.pick_radius() + 0.2), RUN_SPEED)

func _leave_shelter() -> void:
	if state == S.SHELTER and _fall_site != null and is_instance_valid(_fall_site):
		_fall_site.leave_shelter(self)
		if _phase == "inside":
			var door := _fall_site.global_position + Vector3(0, 0, _fall_site.pick_radius() + 0.4)
			door.y = Site.ground(door.x, door.z)
			global_position = door
	if state == S.SHELTER or state == S.SLEEP:
		_phase = ""
	visible = true

func _leave_job() -> void:
	var s := job_site
	if s != null and is_instance_valid(s):
		if _reserved != &"":
			var carried := int(_cargo.get(_reserved, 0))
			s.unreserve(_reserved, maxi(carried, 1))
		s.release(self)
	# Anything in their arms goes back to the stores: nothing is lost.
	for k in _cargo:
		Village.add_store(k, int(_cargo[k]))
	_cargo.clear()
	_armful = 0
	_reserved = &""
	_waiting_for = &""
	job_site = null
	_phase = ""
	_timer = 0.0
	_set_cargo_visual()
	if visual: visual.set_job_colour(&"")
	if visual: visual.set_task(null)
	if state == S.WORK or state == S.WAIT_GROUP:
		state = S.IDLE

func _set_cargo_visual() -> void:
	if visual == null:
		return
	if _cargo.is_empty():
		visual.set_cargo(null)
	else:
		visual.set_cargo(StringName(_cargo.keys()[0]))   # a real armful of that kind (PropKit)

func _store_slot() -> Vector3:
	var c := Site.store_point(global_position)
	var a := float(uid) * 2.39996
	return c + Vector3(cos(a), 0, sin(a)) * 1.3

func _on_day(_d: int) -> void:
	if state == S.DEAD:
		return
	wake()
	go_eat()

func _on_night(_d: int) -> void:
	if state == S.DEAD or state == S.HELD or state == S.FALL:
		return
	go_eat()      # dusk meal; _after_eat sends them to bed at night

# --- movement (every frame) -----------------------------------------------------------

func _go(p: Vector3, speed: float) -> void:
	_target = p
	_speed = speed

func _walk(p: Vector3) -> void:
	state = S.WALK
	_go(p, WALK_SPEED)

func _arrived() -> bool:
	if _target == Vector3.INF:
		return true
	var d := _target - global_position
	d.y = 0.0
	return d.length() <= ARRIVE

## Fast-forward: at 3x and up a town of a hundred thinks on every second sim
## tick and walks on every second physics step (each person in turn, with the
## time of the steps it skipped); at 5x and up on every third. A tick is a
## tenth of a game second, so at those speeds nobody can tell.
const FAST_SCALE := 2.9
const FASTER_SCALE := 4.5
var _sim_acc: float = 0.0
var _move_acc: float = 0.0
var _move_n: int = 0

static func _stride() -> int:
	return 1 if Engine.time_scale < FAST_SCALE else (2 if Engine.time_scale < FASTER_SCALE else 3)

func _on_sim_tick(dt: float) -> void:
	var k := _stride()
	if k == 1 or state == S.HELD or state == S.FALL:
		if _sim_acc > 0.0:
			dt += _sim_acc
			_sim_acc = 0.0
		sim(dt)
		return
	_sim_acc += dt
	if (Clock.tick_n + uid) % k == 0:
		var d := _sim_acc
		_sim_acc = 0.0
		sim(d)

func _physics_process(delta: float) -> void:
	if not Clock.running and state != S.FALL:
		if visual: visual.animate(delta, _pose(), false, Vector3.INF)
		return
	var k := _stride()
	if k > 1 and state != S.FALL and state != S.HELD and stage != Stage.BABY:
		_move_acc += delta
		_move_n += 1
		if (_move_n + uid) % k != 0:
			return
		delta = _move_acc
		_move_acc = 0.0
	elif _move_acc > 0.0:
		delta += _move_acc
		_move_acc = 0.0
	motion(delta)

func _process(delta: float) -> void:
	if state == S.DEAD:
		_dead_t += delta
		if _dead_t > 4.0:
			queue_free()
	# Animation runs once per drawn frame, not once per physics step: at 3x
	# speed a frame holds several physics steps, and a town holds a hundred people.
	if visual and _anim_dt > 0.0:
		visual.animate(_anim_dt, _pose(), _moving, _hand_look())
		_anim_dt = 0.0

## Moves and animates the person by `dt` seconds.
func motion(dt: float) -> void:
	_moving = false
	match state:
		S.HELD:
			pass
		S.FALL:
			_fall(dt)
		S.DEAD:
			global_position.y = move_toward(global_position.y, Site.ground(global_position.x, global_position.z), 4.0 * dt)
		_:
			if stage == Stage.BABY:
				_follow_carrier(dt)
			elif not (state == S.SHELTER and _phase == "inside"):
				if (state == S.WORK or state == S.WAIT_GROUP) and job_site != null and is_instance_valid(job_site) and _phase != "carry" and _phase != "fetch":
					if job_site.moves_to_store() or state == S.WAIT_GROUP:
						_target = job_site.slot_position(job_site.slot_of(self))
				_react_to_hand(dt)
				if _target != Vector3.INF and not _frozen():
					_step(dt)
	_anim_dt += dt

var _anim_dt: float = 0.0

func _step(dt: float) -> void:
	var pos := global_position
	var flat := _target - pos
	flat.y = 0.0
	var dist := flat.length()
	if dist <= ARRIVE * 0.8:
		return
	var dir := flat
	# Stuck on a navmesh corner for a few seconds: walk straight for a while.
	_no_nav_t = maxf(_no_nav_t - dt, 0.0)
	if not _stuck_ref.is_finite() or pos.distance_to(_stuck_ref) > 0.6:
		_stuck_ref = pos
		_stuck_t = 0.0
	else:
		_stuck_t += dt
		if _stuck_t > 3.0:
			_stuck_t = 0.0
			_no_nav_t = 4.0
	if _no_nav_t <= 0.0 and _use_nav():
		var nd := _path_dir(pos)
		if nd.length() > 0.05:
			dir = nd
	var spd := _speed
	if has_trait(&"quick"): spd *= 1.2
	if stage == Stage.ELDER: spd *= 0.75
	elif stage == Stage.CHILD: spd *= 0.9
	if Clock.season == Clock.Season.WINTER: spd *= 0.85
	if hurt_t > 0.0: spd *= 0.6
	var wp = Game.world.paths if Game.world != null and &"paths" in Game.world else null
	if wp != null:
		spd *= wp.speed_mult(pos)       # roads worn by use are quicker (scripts/world/paths.gd)
	var st := minf(spd * dt, dist)
	if wp != null:
		wp.step(pos, st, dir)           # and every step wears them in
	pos += dir.normalized() * st
	pos.y = Site.ground(pos.x, pos.z)
	global_position = pos
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), minf(10.0 * dt, 1.0))
	_moving = true

## Walking a path: asked of the navigation map once per destination (and
## again when the map is rebaked), then followed corner by corner. Asking a
## NavigationAgent every step costs most of a town's frame.
const CORNER_REACHED := 0.6
var _path: PackedVector3Array = PackedVector3Array()
var _path_i: int = 0
var _path_to: Vector3 = Vector3.INF
var _path_map_it: int = -1

## Flat direction toward the next corner of the path to _target.
func _path_dir(pos: Vector3) -> Vector3:
	var it := NavigationServer3D.map_get_iteration_id(_nav_map)
	if it != _path_map_it or not _path_to.is_finite() or _path_to.distance_to(_target) > 0.3:
		_path_to = _target
		_path_map_it = it
		_path = Nav.find_path(_nav_map, pos, _target, nav.navigation_layers if nav != null else 1)
		if Game.world != null and &"paths" in Game.world and Game.world.paths != null:
			_path = Game.world.paths.refine(_path)    # keep to the worn roads
		_path_i = 0
	while _path_i < _path.size():
		var c := _path[_path_i]
		if Vector2(c.x - pos.x, c.z - pos.z).length() > CORNER_REACHED:
			break
		_path_i += 1
	if _path_i >= _path.size():
		return Vector3.ZERO
	var d := _path[_path_i] - pos
	d.y = 0.0
	return d

var _nav_map: RID = RID()

func _use_nav() -> bool:
	_nav_check_t -= get_physics_process_delta_time()
	if _nav_check_t <= 0.0:
		_nav_check_t = 1.0
		_nav_ok = false
		if nav != null and is_inside_tree() and get_world_3d() != null:
			var map := get_world_3d().navigation_map
			_nav_ok = NavigationServer3D.map_get_iteration_id(map) > 0 and NavigationServer3D.map_get_regions(map).size() > 0
			_nav_map = map
	return _nav_ok

func _fall(dt: float) -> void:
	var pos := global_position
	var gy := Site.ground(_fall_to.x, _fall_to.z)
	_vel_y = minf(_vel_y + GRAVITY * dt, 30.0)
	pos.y -= _vel_y * dt
	pos.x = lerpf(pos.x, _fall_to.x, minf(12.0 * dt, 1.0))
	pos.z = lerpf(pos.z, _fall_to.z, minf(12.0 * dt, 1.0))
	if pos.y <= gy:
		pos = Vector3(_fall_to.x, gy, _fall_to.z)
		global_position = pos
		_land()
		return
	global_position = pos

func _land() -> void:
	_vel_y = 0.0
	if visual: visual.land_squash()
	state = S.IDLE
	_target = Vector3.INF
	var s := _fall_site
	_fall_site = null
	if s != null and is_instance_valid(s) and join(s, true):
		return
	adjust_trust(-0.02)      # set down somewhere pointless
	_decide_t = Game.rng.randf_range(1.0, 2.5)

## True when a baby of theirs rides on their hip (it follows _carrier()).
func _carrying_baby() -> bool:
	if children.is_empty():
		return false
	if absf(Clock.total_t - _carry_t) < 0.5:
		return _carry
	_carry_t = Clock.total_t
	_carry = false
	for p in Village.people:
		if is_instance_valid(p) and p.stage == Stage.BABY and p.alive() and p.parents.has(uid) and p._carrier() == self:
			_carry = true
			break
	return _carry

var _carry: bool = false
var _carry_t: float = -10.0

func _carrier() -> Person:
	return _a_parent()

func _follow_carrier(_dt: float) -> void:
	var c := _carrier()
	if c != null and c.visible:
		visible = true
		var p := c.global_position + c.global_basis * Vector3(0.05, 0.82, 0.3)
		global_position = p
		rotation.y = c.rotation.y
	elif c != null and not c.visible:
		visible = false            # inside the hut with the parent
		global_position = c.global_position
	else:
		visible = true
		global_position.y = Site.ground(global_position.x, global_position.z)

# --- hand reactions -------------------------------------------------------------------

func _hand() -> Node3D:
	if _hand_ref != null:
		var h = _hand_ref.get_ref()
		if h != null and is_instance_valid(h):
			return h
		_hand_ref = null
	_hand_search_t -= get_process_delta_time()
	if _hand_search_t > 0.0 or not is_inside_tree():
		return null
	_hand_search_t = 2.0
	var n := get_tree().get_first_node_in_group("hand")
	if n == null and Game.world != null and is_instance_valid(Game.world):
		n = Game.world.get_node_or_null("Hand")
	if n is Node3D:
		_hand_ref = weakref(n)
		return n
	return null

func _hand_dist() -> float:
	var h := _hand()
	if h == null:
		return INF
	var d := h.global_position - global_position
	d.y = 0.0
	return d.length()

func _hand_look() -> Vector3:
	var h := _hand()
	if h == null or _hand_dist() > HAND_NEAR * 1.5:
		return Vector3.INF
	return h.global_position

func _effective_trust() -> int:
	return maxi(trust - (1 if has_trait(&"timid") else 0), 0)

func _react_to_hand(_dt: float) -> void:
	if state != S.IDLE and state != S.WALK:
		return
	if _effective_trust() == 0 and not has_trait(&"brave") and _hand_dist() < HAND_NEAR * 0.7:
		var h := _hand()
		flee_from(h.global_position, 1.5)     # scatter from the shadow

func _frozen() -> bool:
	# Wary people freeze and watch the hand while idle.
	return state == S.IDLE and _effective_trust() == 1 and _hand_dist() < HAND_NEAR

func _pose() -> int:
	match state:
		S.HELD:
			# scared people cover up; friends of the hand wave happily while carried
			var et := _effective_trust()
			return PersonVisual.Pose.COWER if et == 0 else (PersonVisual.Pose.WAVE if et >= 4 else PersonVisual.Pose.HELD)
		S.FALL:
			return PersonVisual.Pose.HELD
		S.DEAD:
			return PersonVisual.Pose.DEAD
		S.SLEEP:
			return PersonVisual.Pose.SLEEP if _phase == "asleep" else PersonVisual.Pose.WALK
		S.FLEE:
			return PersonVisual.Pose.COWER if not _moving else PersonVisual.Pose.RUN
	if stage == Stage.BABY:
		return PersonVisual.Pose.SIT
	if not _cargo.is_empty():
		return PersonVisual.Pose.CARRY
	if _moving and _carrying_baby():
		return PersonVisual.Pose.CARRY
	# a moving group job (the log carry): carrying it, walking or stood still
	if state == S.WORK and job_site != null and is_instance_valid(job_site) and job_site.moves_to_store() and job_site.group_running:
		return PersonVisual.Pose.CARRY
	if state == S.WORK and not _moving:
		var jd := _job_def()
		if jd != null and jd.kind == JobDef.Kind.DEVOTION:
			return PersonVisual.Pose.PRAY
		if _phase == "work" or _phase == "build":
			return PersonVisual.Pose.WORK
	if state == S.IDLE or state == S.WAIT_GROUP or state == S.EAT:
		if _hand_dist() < HAND_NEAR:
			match _effective_trust():
				0: return PersonVisual.Pose.COWER
				1: return PersonVisual.Pose.WATCH
				2: return PersonVisual.Pose.POINT
				3: return PersonVisual.Pose.WAVE
				_: return PersonVisual.Pose.REACH
	return PersonVisual.Pose.IDLE

func _activity_text() -> String:
	if stage == Stage.BABY:
		return "baby"
	match state:
		S.HELD: return "in your hand"
		S.FALL: return "falling"
		S.EAT: return "going to eat"
		S.SLEEP: return "sleeping"
		S.SHELTER: return "sheltering"
		S.FLEE: return "running away"
		S.WALK when _offering != null: return "bringing the hand an offering"
		S.DEAD: return "at rest"
		S.WAIT_GROUP:
			var need := job_site.group_needs() if job_site and is_instance_valid(job_site) else 0
			return "waiting for %d more" % need
		S.WORK:
			var jd := _job_def()
			var t := jd.title if jd else "working"
			if job_site and is_instance_valid(job_site) and job_site.is_plot():
				t = "building a %s" % job_site.building.title.to_lower()
			if _waiting_for == &"regrowth":
				return t + " (waiting for regrowth)"
			if _waiting_for == &"growing":
				return t + " (the crop is growing)"
			if _waiting_for == &"spring":
				return t + " (resting until spring)"
			if _waiting_for != &"":
				return t + " (needs %s)" % _waiting_for
			return t
	return "idle"

# --- links and save ---------------------------------------------------------------

func _resolve_links() -> void:
	if _pending.is_empty():
		return
	var done: Array = []
	for key in _pending:
		var s := Site.by_uid(int(_pending[key]))
		if s == null:
			continue
		done.append(key)
		match key:
			"home": home = s
			"resume": _resume = s
			"job":
				if s.can_accept(1) or s.workers.has(self):
					join(s, false)
			"shelter":
				if s.enter_shelter(self):
					state = S.SHELTER
					_fall_site = s
					_phase = "inside"
					visible = false
	for k in done:
		_pending.erase(k)
	# Sites that never appear (removed) are forgotten after a while.
	_pending_t += Clock.TICK
	if not _pending.is_empty() and _pending_t > 5.0:
		_pending.clear()

func save_state() -> Dictionary:
	var p := global_position if is_inside_tree() else position
	var nd := {}
	for k in needs: nd[str(k)] = needs[k]
	var sk := {}
	for k in skills: sk[str(k)] = skills[k]
	var bd := {}
	for k in bonds: bd[str(k)] = bonds[k]
	var st := state
	if st == S.HELD or st == S.FALL or st == S.FLEE or st == S.WALK or st == S.EAT:
		st = S.IDLE
	var inside_uid := 0
	if state == S.SHELTER and _phase == "inside" and _fall_site != null and is_instance_valid(_fall_site):
		inside_uid = _fall_site.uid
	var job_uid := 0
	if job_site != null and is_instance_valid(job_site):
		job_uid = job_site.uid
	elif _resume != null and is_instance_valid(_resume):
		job_uid = _resume.uid
	return {
		"scene": SCENE, "uid": uid, "name": given_name, "sex": sex, "age": age, "death_age": death_age,
		"stage": stage, "parents": Array(parents), "children": Array(children), "partner": partner,
		"needs": nd, "skills": sk, "traits": traits.map(func(t): return str(t)),
		"trust_f": trust_f, "wish": str(wish), "wish_t": wish_t,
		"job": job_uid, "home": home.uid if home != null and is_instance_valid(home) else 0,
		"shelter": inside_uid, "state": st, "placed_by_hand": placed_by_hand, "wanderer": wanderer,
		"blessed_t": blessed_t, "hurt_t": hurt_t, "sick_t": sick_t, "named_by_hand": named_by_hand, "first_two": first_two, "look": look, "bonds": bd, "last_birth_age": last_birth_age,
		"pos": [p.x, p.y, p.z], "rot_y": rotation.y,
	}

func load_state(d: Dictionary) -> void:
	_loaded = true
	uid = int(d.get("uid", uid))
	given_name = str(d.get("name", given_name))
	sex = str(d.get("sex", "f"))
	age = float(d.get("age", age))
	death_age = float(d.get("death_age", DEATH_AGE))
	stage = int(d.get("stage", stage_for_age(age)))
	parents.clear()
	for u in d.get("parents", []): parents.append(int(u))
	children.clear()
	for u in d.get("children", []): children.append(int(u))
	partner = int(d.get("partner", 0))
	var nd: Dictionary = d.get("needs", {})
	for k in nd: needs[StringName(k)] = float(nd[k])
	skills.clear()
	var sk: Dictionary = d.get("skills", {})
	for k in sk: skills[StringName(k)] = float(sk[k])
	traits.clear()
	for t in d.get("traits", []): traits.append(StringName(t))
	trust_f = float(d.get("trust_f", 1.5))
	trust = clampi(floori(trust_f), 0, 5)
	wish = StringName(str(d.get("wish", "")))
	wish_t = float(d.get("wish_t", 60.0))
	placed_by_hand = bool(d.get("placed_by_hand", false))
	wanderer = bool(d.get("wanderer", false))
	blessed_t = float(d.get("blessed_t", 0.0))
	hurt_t = float(d.get("hurt_t", 0.0))
	sick_t = float(d.get("sick_t", 0.0))
	named_by_hand = bool(d.get("named_by_hand", false))
	first_two = bool(d.get("first_two", false))
	if first_two:
		# saves from before the first two were given their longer lives
		death_age = maxf(death_age, DEATH_AGE + LayoutEra1.FIRST_TWO_EXTRA_LIFE)
	var lk: Dictionary = d.get("look", {})
	look = {"skin": int(lk.get("skin", 0)), "hair": int(lk.get("hair", 0)), "height": float(lk.get("height", 1.0))}
	if lk.has("outfit"):
		look["outfit"] = int(lk["outfit"])
	bonds.clear()
	var bd: Dictionary = d.get("bonds", {})
	for k in bd: bonds[int(k)] = float(bd[k])
	last_birth_age = float(d.get("last_birth_age", -1000.0))
	state = S.IDLE
	_pending.clear()
	if int(d.get("home", 0)) != 0: _pending["home"] = int(d["home"])
	if int(d.get("shelter", 0)) != 0:
		_pending["shelter"] = int(d["shelter"])
		if int(d.get("job", 0)) != 0: _pending["resume"] = int(d["job"])
	elif int(d.get("job", 0)) != 0:
		_pending["job"] = int(d["job"])
	if int(d.get("state", 0)) == S.SLEEP:
		state = S.SLEEP
		_phase = "asleep"
	var pa: Array = d.get("pos", [0, 0, 0])
	var pos := Vector3(float(pa[0]), float(pa[1]), float(pa[2]))
	if is_inside_tree():
		global_position = pos
	else:
		position = pos
	rotation.y = float(d.get("rot_y", 0.0))
	if is_inside_tree():
		_refresh_look()
		_show_wish()
