class_name Era2Threats extends Node3D
## Era 2 threat director (doc 8): drought, crop blight, the bear and the
## flood. One at a time (and never with a wolf night or cold snap: Threats
## asks major_active()), never in the quiet stretch after a milestone, each
## telegraphed first (Events.threat_warned + an alert with the hand's answer).
## Each one comes at least once in the era: if the dice have not brought it
## by its due minute, it comes at the next dawn it can.
## Era 2 hazards hurt and cost food and crops; they never kill.
##
##   drought      summer; fields dry three times as fast. Rain on them (hold
##                E with Rain) or carry water from the well.
##   crop_blight  a growing field turns black; two people working it at once
##                fight it off. Left alone it takes the crop and spreads once.
##   bears        a bear comes out of its den above the Hill Quarry when people
##                work the quarry. Flick to scare it, lift it away with
##                Strength II, or build the watchtower over the quarry.
##   flood        the river rises over its banks: lift people out of the water;
##                low fields lose their crop, and grain kept outside a granary rots.

const IDS: Array[StringName] = [&"crop_blight", &"drought", &"bears", &"flood"]
## Era minute by which each threat has come at least once (if it can).
const DUE := {&"crop_blight": 13.0, &"drought": 22.0, &"bears": 28.0, &"flood": 36.0}
const FLOOD_TOP := 4.8
const FLOOD_HURT_AFTER := 7.0
const GRAIN_ROT := 0.4
## The bears' den, up the slope behind the Hill Quarry (2026-10-10: bears at
## the quarry, not at random on the far bank).
const QUARRY_DEN := Vector2(262.0, -134.0)

var current: StringName = &""
var phase: int = 0                 # 0 none, 1 warned, 2 active, 3 receding (flood)
var t: float = 0.0
var at: Vector3 = Vector3.ZERO
var bear: Bear = null
var blight_site: Site = null
var spread: bool = false
var _wet: Dictionary = {}          # person uid -> seconds in flood water
var _acc: float = 0.0

func _ready() -> void:
	name = "Era2Threats"
	Events.day_started.connect(_on_dawn)

func _def(id: StringName) -> ThreatDef:
	return Defs.threats.get(id) if "threats" in Defs else null

func active() -> bool:
	return phase > 0

func drought_active() -> bool:
	return current == &"drought" and phase == 2

static func era_minutes() -> float:
	return (Clock.total_t - float(Village.stats.get("era_started_t", 0.0))) / 60.0

static func seen() -> Array:
	if not Village.stats.has("era2_threats_seen"):
		Village.stats["era2_threats_seen"] = []
	return Village.stats["era2_threats_seen"]

func _w():
	var w = Game.world
	return w if w != null and is_instance_valid(w) else null

# ---------------------------------------------------------------- director

func _on_dawn(_d: int) -> void:
	var th = get_parent()
	if Village.era != 2 or phase > 0 or th == null or not th.enabled:
		return
	if th.quiet() or th.major_active():
		return
	var due: Array = []
	var maybe: Array = []
	for id in IDS:
		if not can(id):
			continue
		if not seen().has(str(id)) and era_minutes() >= float(DUE[id]):
			due.append(id)
		maybe.append(id)
	if Game.flags.has("threat"):
		var forced := StringName(str(Game.flags.get("threat", "")))
		if forced in IDS and can(forced):
			due = [forced]
	if not due.is_empty():
		warn(due[0])
		return
	maybe.shuffle()
	for id in maybe:
		var d := _def(id)
		var chance := (d.chance_per_day if d else 0.1) * Flags.diff_k(&"wolves")
		if Game.rng.randf() < chance:
			warn(id)
			return

## Can this threat come now (population, region, season, something to threaten)?
func can(id: StringName) -> bool:
	var d := _def(id)
	if d != null:
		if Village.population() < d.min_population:
			return false
		if d.needs_region != &"" and not Village.regions.has(d.needs_region):
			return false
		if d.season >= 0 and Clock.season != d.season:
			return false
	match id:
		&"crop_blight":
			return _blight_target() != null
		&"drought":
			# the first summer's crop is young and there is no Rain yet: spare it
			return Clock.season == Clock.Season.SUMMER and (Faith.has(&"rain") or era_minutes() > 20.0) and _fields_growing() > 0
		&"flood":
			return Clock.season != Clock.Season.WINTER
		&"bears":
			return _people_in(&"hill_quarry") > 0
	return true

func warn(id: StringName) -> void:
	current = id
	phase = 1
	var d := _def(id)
	t = d.warning_seconds if d else 30.0
	at = _where(id)
	if not seen().has(str(id)):
		seen().append(str(id))
	Village.stats["threat_" + str(id)] = int(Village.stats.get("threat_" + str(id), 0)) + 1
	Events.threat_warned.emit(id, at)
	Events.alert.emit(d.warning_text if d and d.warning_text != "" else "Trouble is coming", at)
	print("threat: %s warned at %.1f min (era %.1f)" % [id, Clock.total_t / 60.0, era_minutes()])

func _where(id: StringName) -> Vector3:
	var w = _w()
	match id:
		&"bears":
			return w._v3(QUARRY_DEN) if w else Vector3.ZERO
		&"flood":
			return w._v3(Vector2(0.0, Valley.river_z(0.0) - 14.0)) if w else Vector3.ZERO
		&"crop_blight":
			var f := _blight_target()
			return f.global_position if f else Vector3.ZERO
	var fields := _fields()
	return fields[0].global_position if not fields.is_empty() else Site.store_point(Vector3.ZERO)

func _start() -> void:
	phase = 2
	var d := _def(current)
	t = d.duration_seconds if d else 90.0
	var w = _w()
	match current:
		&"crop_blight":
			blight_site = _blight_target()
			spread = false
			if blight_site == null or not blight_site.start_blight():
				_end()
				return
			at = blight_site.global_position
		&"bears":
			bear = Bear.new()
			bear.manager = self
			bear.den = w._v3(QUARRY_DEN) if w else Vector3.ZERO
			bear.home_region = &"hill_quarry"
			add_child(bear)
			bear.global_position = bear.den
		&"flood":
			_wet.clear()
			for f in _fields():
				if Era2World.in_flood_zone(f.global_position) and f.global_position.y < FLOOD_TOP + 0.3:
					f.flood_field()
			if Village.count_buildings(&"granary") == 0 and Village.store(&"grain") > 0:
				var lost := ceili(Village.store(&"grain") * GRAIN_ROT)
				Village.take_store(&"grain", lost)
				Village.stats["grain_rotted"] = int(Village.stats.get("grain_rotted", 0)) + lost
				Events.toast.emit("The water got into the grain: %d rotted (a granary keeps it dry)" % lost)
		&"drought":
			if w and w.look:
				w.look.set_weather(0.0, false)
	Events.threat_started.emit(current, at)
	Events.alert.emit(d.start_text if d and d.start_text != "" else "It has begun", at)

func _end() -> void:
	if phase == 0:
		return
	if current == &"flood" and phase == 2:
		phase = 3          # the water goes down over a few seconds first
		t = 12.0
		return
	_close()

func _close() -> void:
	var id := current
	if bear != null and is_instance_valid(bear):
		bear.go_home()
	bear = null
	blight_site = null
	current = &""
	phase = 0
	_wet.clear()
	var w = _w()
	if w and w.era2:
		w.era2.set_flood(0.0)
	if id == &"drought" and w and w.look:
		w.look.set_weather(0.6, false)     # the drought breaks in a downpour
		Events.alert.emit("The drought has broken. Rain at last", Site.store_point(Vector3.ZERO))
	Village.stats["quiet_until"] = maxf(float(Village.stats.get("quiet_until", -1.0)), Clock.total_t + 90.0)
	Events.threat_ended.emit(id)

func on_bear_home(_b: Bear) -> void:
	if current == &"bears" and phase == 2:
		_end()

# ---------------------------------------------------------------- per frame

func _process(delta: float) -> void:
	if phase == 0 or not Clock.running:
		return
	var w = _w()
	t -= delta
	match phase:
		1:
			if current == &"flood" and w:
				var d := _def(current)
				var total := d.warning_seconds if d else 60.0
				w.era2.set_flood(0.3 * clampf(1.0 - t / total, 0.0, 1.0))
			if t <= 0.0:
				_start()
		2:
			_acc += delta
			if _acc >= 1.0:
				_tick(_acc)
				_acc = 0.0
			if phase == 2 and t <= 0.0:
				_time_up()
		3:
			if w:
				w.era2.set_flood(clampf(t / 12.0, 0.0, 1.0))
			if t <= 0.0:
				_close()

func _tick(dt: float) -> void:
	var w = _w()
	match current:
		&"flood":
			if w:
				w.era2.set_flood(minf(w.era2.flood_k + dt / 8.0, 1.0) if w.era2.flood_k >= 0.3 else 0.3)
				for p in Village.alive():
					if p.state == Person.S.HELD or p.state == Person.S.FALL or p.stage == Person.Stage.BABY:
						continue
					if not p.visible:
						continue
					if w.era2.flooded(p.global_position):
						var k := float(_wet.get(p.uid, 0.0)) + dt
						_wet[p.uid] = k
						if k >= FLOOD_HURT_AFTER:
							_wet[p.uid] = 0.0
							p.hurt(0.6, &"flood")
							Village.stats["flood_hurt"] = int(Village.stats.get("flood_hurt", 0)) + 1
					else:
						_wet.erase(p.uid)
		&"crop_blight":
			if blight_site == null or not is_instance_valid(blight_site) or not blight_site.is_blighted():
				_end()      # cured (field_tend emits threat_ended too; _end is idempotent below)
		&"bears":
			if bear == null or not is_instance_valid(bear):
				_end()

func _time_up() -> void:
	match current:
		&"crop_blight":
			if blight_site != null and is_instance_valid(blight_site) and blight_site.is_blighted():
				blight_site._lose_crop("The blight took the field's crop")
				var next := _blight_target()
				if not spread and next != null and next.start_blight():
					spread = true
					blight_site = next
					at = next.global_position
					Events.alert.emit("The blight has spread to another field! Two people can fight it off", at)
					t = 60.0
					return
		&"bears":
			if bear != null and is_instance_valid(bear):
				bear.go_home("The bear has eaten its fill and wanders back to its den")
	_end()

# ---------------------------------------------------------------- helpers

func _fields() -> Array:
	return Village.sites.filter(func(s): return is_instance_valid(s) and s.is_field() and s.state == Site.State.FINISHED)

func _fields_growing() -> int:
	return _fields().filter(func(s): return s.field_stage in [Site.Field.SPROUTS, Site.Field.GROWING]).size()

## The growing field with the fewest farmers on it (the blight finds the neglected one).
func _blight_target() -> Site:
	var best: Site = null
	var best_n := 99
	for s in _fields():
		if s.is_blighted() or not (s.field_stage in [Site.Field.SPROUTS, Site.Field.GROWING]):
			continue
		var n: int = s.slots_filled()
		if n < best_n:
			best_n = n
			best = s
	return best

func _people_in(region: StringName) -> int:
	var w = _w()
	if w == null:
		return 0
	var n := 0
	for p in Village.alive():
		if w.region_at(p.global_position) == region:
			n += 1
	return n

## The hand's flick near the bear.
func scare(p: Vector3, radius: float) -> int:
	if bear != null and is_instance_valid(bear) and bear.global_position.distance_to(p) <= radius:
		bear.scare(p)
		return 1
	return 0

func reset() -> void:
	if bear != null and is_instance_valid(bear):
		bear.queue_free()
	bear = null
	current = &""
	phase = 0
	t = 0.0
	blight_site = null
	_wet.clear()

func save_state() -> Dictionary:
	return {"current": str(current), "phase": phase, "t": t, "blight": blight_site.uid if blight_site != null and is_instance_valid(blight_site) else 0}

## A threat in progress comes back as its warning (the bear and the water are not saved).
func load_state(d: Dictionary) -> void:
	reset()
	var id := StringName(str(d.get("current", "")))
	if id in IDS and int(d.get("phase", 0)) > 0:
		if id == &"crop_blight":
			blight_site = Site.by_uid(int(d.get("blight", 0)))
			if blight_site != null and blight_site.is_blighted():
				current = id
				phase = 2
				t = float(d.get("t", 30.0))
				return
		current = id
		phase = 1
		var td := _def(id)
		t = minf(float(d.get("t", 20.0)), td.warning_seconds if td else 20.0) if int(d.get("phase", 0)) == 1 else 15.0
