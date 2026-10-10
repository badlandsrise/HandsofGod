class_name Paving extends RefCounted
## [era3] Masons pave the busiest roads (Austin's approved desire-path plan:
## "In Era 3 a stonemason paves the busiest roads automatically").
##
## Once a mason's yard stands, plan() stakes the busiest stretch of dirt road
## (world.paths.busiest_segments) with a pave_road site: a stack of dressed
## blocks and two stakes on the road. The yard's crew works it like any task
## (Workplace, BuildingDef.paves), two masons at most; when the work is done it
## takes PAVE_BLOCKS from the stores and world.paths.pave() lays the stretch in
## stone (paved roads never fade and are +30% faster). One stretch at a time,
## and only while blocks are spare beyond what the plots wait on.

const JOB := &"pave_road"
const PAVE_BLOCKS := 2
const MIN_WEAR := 400.0          # a stretch worth paving (wear summed over its road cells)
const MAX_OPEN := 1              # stretches staked at once
const BLOCK_RESERVE := 6         # blocks left in the stores for the plots
const PLAN_EVERY := 20.0         # game seconds between looks at the roads

static var _plan_t: float = -INF

static func _w():
	var w = Game.world
	return w if w != null and is_instance_valid(w) and "paths" in w and w.paths != null else null

## A finished mason's yard (whose crew paves).
static func yard() -> Site:
	for s in Village.sites:
		if is_instance_valid(s) and s.is_workplace() and s.building.paves:
			return s
	return null

static func open_sites() -> Array:
	return Village.sites.filter(func(s): return is_instance_valid(s) and not s.is_queued_for_deletion() and s.job != null and s.job.id == JOB)

## Blocks the paving may take (beyond the plots' wants and a reserve).
static func spare_blocks() -> int:
	return Village.store(&"blocks") - Workplace.plots_want(&"blocks") - BLOCK_RESERVE

## Segment id (paths grid) of a point.
static func segment_id(at: Vector3) -> Vector2i:
	return Vector2i(floori((at.x - float(Paths.RECT.position.x)) / float(Paths.SEGMENT)),
		floori((at.z - float(Paths.RECT.position.y)) / float(Paths.SEGMENT)))

## Stakes the next stretch when the yard is staffed and blocks are spare.
## Returns the new site, or null.
static func plan(force: bool = false) -> Site:
	if not force and absf(Clock.total_t - _plan_t) < PLAN_EVERY:
		return null
	_plan_t = Clock.total_t
	var w = Paving._w()
	var y := Paving.yard()
	if w == null or y == null or y.slots_filled() == 0:
		return null
	if open_sites().size() >= MAX_OPEN or spare_blocks() < PAVE_BLOCKS:
		return null
	var taken := {}
	for s in open_sites():
		taken[Paving.segment_id(s.global_position)] = true
	for seg in w.paths.busiest_segments(8):
		if float(seg["wear"]) < MIN_WEAR or taken.has(seg["id"]):
			continue
		var c: Vector3 = seg["center"]
		if w.has_method("is_water") and w.is_water(c):
			continue
		var s: Site = w.spawn_site(JOB, Vector3(c.x, 0, c.z))
		if s == null:
			return null
		s.set_meta(&"layout_tag", "paving")
		Village.stats["paving_staked"] = int(Village.stats.get("paving_staked", 0)) + 1
		if not Village.stats.get("paving_told", false):
			Village.stats["paving_told"] = true
			Events.alert.emit("The masons are paving the busiest road with dressed stone", s.global_position)
		return s
	return null

## How much a stretch wants work (Workplace.need): high enough that the two
## pavers walk to town for it, nothing while there are no blocks to lay.
static func need(t: Site) -> float:
	return 6.0 if Village.store(&"blocks") >= PAVE_BLOCKS else 0.0

## A mason works stretch `t` (shared progress); the last strokes take the
## blocks and lay the stone.
static func work(p, w: Site, t: Site, r: float) -> void:
	if Village.store(&"blocks") < PAVE_BLOCKS:
		p._waiting_for = &"blocks"
		return
	p._waiting_for = &""
	p._first_work(w)
	t.progress += r / maxf(t.job.work_time, 0.1)
	if t.progress < 1.0:
		return
	Village.take_store(&"blocks", PAVE_BLOCKS)
	p._gain_skill(&"building", Person.SKILL_PER_CYCLE * 2.0)
	p._placement_faith()
	Paving.lay(t)

## Lays stretch `t` in stone and clears its stakes.
static func lay(t: Site) -> int:
	var n := 0
	var w = Paving._w()
	if w != null:
		n = w.paths.pave(Paving.segment_id(t.global_position))
		w.paths.flush()
	Village.stats["roads_paved"] = int(Village.stats.get("roads_paved", 0)) + 1
	if int(Village.stats["roads_paved"]) == 1:
		Flags.remember("Our masons laid the busiest road in dressed stone. Carts roll on it, and nobody walks in the mud.")
	Events.job_completed.emit(t)
	t.queue_free()        # its masons see the task gone and go back to the yard (Workplace.step)
	return n
