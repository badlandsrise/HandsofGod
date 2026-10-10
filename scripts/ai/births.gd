class_name Births extends Node
## Bonds and births (doc section 3). Adults who work side by side bond; a
## bonded pair with a home that has room, a dawn of food surplus
## and a content mood has a baby. Also assigns homes in huts.
## Village.stats["surplus_days"] counts the dawns in a row with surplus food.

const CHECK := 5.0                 # seconds between checks
const BOND_PER_CHECK := 6.0        # working together for ~75 s bonds a pair
const BOND_NEEDED := 90.0
const BIRTH_COOLDOWN := 300.0      # game seconds between a pair's children
const BIRTH_CHANCE := 0.25         # per check, once every condition holds
const SURPLUS_PER_PERSON := 1      # food units per person at dawn for a "surplus" day (tuned: 2 never happened before the gate)
const MIN_MOOD := 0.5
const SURPLUS_DAYS := 1             # dawns in a row with surplus before a pair will have a child
const PRAYER_CHANCE := 0.4         # a new baby's parents pray at the shrine for the hand to name it
const PRAYER_WAIT := 30.0          # the name box comes once they kneel, or after this long

var _acc: float = 0.0
var _prayers: Array = []           # [{baby, parent, site, t}]

func _ready() -> void:
	Events.sim_tick.connect(_on_tick)
	Events.day_started.connect(_on_dawn)
	Events.building_finished.connect(func(_s): assign_homes())

func _on_dawn(_d: int) -> void:
	if Village.food() >= Village.population() * SURPLUS_PER_PERSON:
		Village.stats["surplus_days"] = int(Village.stats.get("surplus_days", 0)) + 1
	else:
		Village.stats["surplus_days"] = 0
	assign_homes()

func _on_tick(dt: float) -> void:
	_acc += dt
	if _acc < CHECK:
		return
	_acc = 0.0
	update_bonds(CHECK)
	try_births()
	_update_prayers(CHECK)

static func _adults() -> Array:
	return Village.alive().filter(func(p): return p.stage == Person.Stage.ADULT)

static func find(uid: int) -> Person:
	for p in Village.people:
		if is_instance_valid(p) and p.uid == uid:
			return p
	return null

func update_bonds(_dt: float) -> void:
	var adults := Births._adults()
	for i in adults.size():
		var a: Person = adults[i]
		if a.partner != 0 or a.job_site == null or not is_instance_valid(a.job_site):
			continue
		for j in range(i + 1, adults.size()):
			var b: Person = adults[j]
			if b.partner != 0 or b.sex == a.sex or b.job_site != a.job_site:
				continue
			if a.parents.has(b.uid) or b.parents.has(a.uid) or _siblings(a, b):
				continue
			var gain := BOND_PER_CHECK
			if a.has_trait(&"sociable") or b.has_trait(&"sociable"):
				gain *= 2.0
			var v: float = float(a.bonds.get(b.uid, 0.0)) + gain
			a.bonds[b.uid] = v
			b.bonds[a.uid] = v
			if v >= BOND_NEEDED:
				a.partner = b.uid
				b.partner = a.uid
				Events.toast.emit("%s and %s are bonded" % [a.given_name, b.given_name])
				assign_homes()
				break

static func _siblings(a: Person, b: Person) -> bool:
	for u in a.parents:
		if b.parents.has(u):
			return true
	return false

## Population cap for births: a little above the era's band.
static func cap() -> int:
	var e := Defs.era(Village.era)
	# the top of the era's band: newcomers and the next era's homes carry it on
	return e.population_band.y if e else 30

## A bonded pair lives here.
static func _has_family(hut: Site) -> bool:
	for p in Village.alive():
		if p.home == hut and p.partner != 0:
			return true
	return false

static func home_residents(hut: Site) -> int:
	var n := 0
	for p in Village.alive():
		if p.home == hut:
			n += 1
	return n

## True if this pair can have a child right now (the doc's conditions).
static func can_have_child(a: Person, b: Person) -> bool:
	if a.stage != Person.Stage.ADULT or b.stage != Person.Stage.ADULT or a.sex == b.sex:
		return false
	if a.partner != b.uid or b.partner != a.uid:
		return false
	var home := a.home if a.home != null and is_instance_valid(a.home) else b.home
	if home == null or not is_instance_valid(home) or not home.is_shelter():
		return false
	if Births.home_residents(home) >= home.building.shelter:
		return false
	if int(Village.stats.get("surplus_days", 0)) < SURPLUS_DAYS:
		return false
	if (a.mood() + b.mood()) * 0.5 < MIN_MOOD:
		return false
	if a.age - a.last_birth_age < BIRTH_COOLDOWN or b.age - b.last_birth_age < BIRTH_COOLDOWN:
		return false
	return Village.population() < Births.cap()

func try_births() -> void:
	for a in Births._adults():
		if a.partner == 0 or a.sex != "f":
			continue
		var b := Births.find(a.partner)
		if b == null or not b.alive():
			continue
		if Births.can_have_child(a, b) and Game.rng.randf() < BIRTH_CHANCE:
			var baby := Births.have_child(a, b)
			maybe_pray_for_name(baby, a)

## The baby-naming prayer (Austin's ruling on section 3): now and then a new
## baby's parent goes to the shrine and prays "for the hand to name our baby".
## The first baby born after the shrine stands always prays.
func maybe_pray_for_name(baby: Person, parent: Person) -> bool:
	if baby == null or parent == null or not is_instance_valid(parent):
		return false
	var shrine := Site.nearest_shrine(parent.global_position)
	if shrine == null:
		return false
	var first: bool = not Village.stats.get("baby_prayer_done", false)
	if not first and Game.rng.randf() >= PRAYER_CHANCE:
		return false
	Village.stats["baby_prayer_done"] = true
	if shrine.can_accept(1):
		parent.join(shrine, false)
	_prayers.append({"baby": baby, "parent": parent, "site": shrine, "t": 0.0})
	Events.alert.emit("%s prays at the shrine for the hand to name the baby" % parent.given_name, shrine.global_position)
	return true

func _update_prayers(dt: float) -> void:
	for pr in _prayers.duplicate():
		var baby = pr["baby"]
		var parent = pr["parent"]
		if not is_instance_valid(baby) or not baby.alive():
			_prayers.erase(pr)
			continue
		pr["t"] = float(pr["t"]) + dt
		var kneeling: bool = is_instance_valid(parent) and is_instance_valid(pr["site"]) and parent.is_present_at(pr["site"], 1.2)
		if kneeling or float(pr["t"]) >= PRAYER_WAIT:
			_prayers.erase(pr)
			Village.stats["baby_prayers"] = int(Village.stats.get("baby_prayers", 0)) + 1
			Events.name_requested.emit([baby], &"baby_prayer")

static func have_child(a: Person, b: Person) -> Person:
	var home: Site = a.home if a.home != null and is_instance_valid(a.home) else b.home
	var rng := Game.rng
	# Children resemble their parents; traits are inherited with a chance to mutate.
	var look := {"skin": (a.look if rng.randf() < 0.5 else b.look).get("skin", 0),
		"hair": (a.look if rng.randf() < 0.5 else b.look).get("hair", 0),
		"height": (float(a.look.get("height", 1.0)) + float(b.look.get("height", 1.0))) * 0.5 + rng.randf_range(-0.03, 0.03)}
	var pool: Array = a.traits + b.traits
	var tr: Array = []
	for t in pool:
		if tr.size() < 2 and not tr.has(t) and rng.randf() < 0.5:
			tr.append(t)
	if tr.is_empty() or rng.randf() < 0.15:
		var m: StringName = Person.TRAITS[rng.randi() % Person.TRAITS.size()]
		if not tr.has(m):
			if tr.size() >= 2: tr[1] = m
			else: tr.append(m)
	var parent_node: Node = a.get_parent()
	var at := a.global_position + Vector3(0.4, 0, 0.3)
	var baby := Person.spawn(parent_node, at, {
		"age": 0.0, "parents": [a.uid, b.uid], "trust_f": (a.trust_f + b.trust_f) * 0.5,
		"look": look, "traits": tr, "home": home})
	a.children.append(baby.uid)
	b.children.append(baby.uid)
	a.last_birth_age = a.age
	b.last_birth_age = b.age
	Village.stats["births"] = int(Village.stats.get("births", 0)) + 1
	Events.person_born.emit(baby)
	return baby

## Gives homeless people a hut with room. Partners share; babies live with a parent.
static func assign_homes() -> void:
	var huts: Array = Village.sites.filter(func(s): return is_instance_valid(s) and s.is_shelter() and not s.building.camp)
	if huts.is_empty():
		return
	# Families first: single adults give up their places, a bonded pair moves
	# in together (a hut with room for both), children follow their parents,
	# and singles take what is left without filling a family's last place.
	var all: Array = Village.alive()
	for p in all:
		if p.partner == 0 and p.stage != Person.Stage.BABY and p.stage != Person.Stage.CHILD:
			p.home = null
	for a in all:
		if a.partner == 0 or a.sex != "f":
			continue
		var b := Births.find(a.partner)
		if b == null or not b.alive():
			continue
		if a.home != null and is_instance_valid(a.home) and a.home == b.home:
			continue
		a.home = null
		b.home = null
		for h in huts:
			if Births.home_residents(h) + 2 <= h.building.shelter:
				a.home = h
				b.home = h
				break
	for p in all:
		if p.home != null and is_instance_valid(p.home):
			continue
		var want: Site = null
		if p.stage == Person.Stage.BABY or p.stage == Person.Stage.CHILD:
			for u in p.parents:
				var par := Births.find(u)
				if par != null and par.home != null and is_instance_valid(par.home) and Births.home_residents(par.home) < par.home.building.shelter:
					want = par.home
					break
		if want == null:
			var single: bool = p.partner == 0 and p.stage != Person.Stage.BABY and p.stage != Person.Stage.CHILD
			var ranked: Array = huts.duplicate()
			if single:
				ranked.sort_custom(func(x, y): return int(Births._has_family(x)) < int(Births._has_family(y)))
			for h in ranked:
				if Births.home_residents(h) < h.building.shelter:
					if single and Births._has_family(h) and Births.home_residents(h) + 1 >= h.building.shelter:
						continue
					want = h
					break
		if want != null:
			p.home = want
