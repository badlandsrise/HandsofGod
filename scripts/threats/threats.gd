class_name Threats extends Node3D
## Era 1 threat director: wolves at night, cold snaps and the first winter
## (section 8). Every threat is telegraphed first with
## Events.threat_warned and Events.alert. Never more than one major threat at
## once in Eras 1 and 2. Strength scales with era and population, not time.
## Tuning comes from ThreatDef resources (ids wolves, cold_snap) when present.

const COLD_ID := &"cold_snap"
const WINTER_ID := &"first_winter"

var wolves: Wolves
var era2: Era2Threats
var cold_warned: bool = false
var cold_active: bool = false
var cold_warn_t: float = -1.0
var winter_warned_year: int = 0
var enabled: bool = true          # false during the onboarding storm

func _ready() -> void:
	name = "Threats"
	wolves = Wolves.new()
	add_child(wolves)
	era2 = Era2Threats.new()
	add_child(era2)
	Events.day_started.connect(_on_dawn)
	Events.night_started.connect(_on_night)
	Events.season_changed.connect(_on_season)

func _def(id: StringName) -> ThreatDef:
	return Defs.threats.get(id) if "threats" in Defs else null

## No new threat during the onboarding, or in the quiet stretch after a
## milestone (doc 5 pacing rules: a quiet stretch after every milestone).
func quiet() -> bool:
	if not Flags.onboarding_done():
		return true
	return Clock.total_t < float(Village.stats.get("quiet_until", -1.0))

func major_active() -> bool:
	return wolves.active or wolves.warned or cold_active or cold_warned or era2.active()

## The Era 2 drought is on (fields dry three times as fast).
func drought_active() -> bool:
	return era2.drought_active()

func cold() -> bool:
	return cold_active

func _process(delta: float) -> void:
	if not Clock.running or not enabled:
		return
	# dusk: decide on wolves before night falls
	var wd := _def(Wolves.ID)
	var warn_s := wd.warning_seconds if wd else 15.0
	if not Clock.is_night and not wolves.warned and Clock.phase_t >= Clock.day_seconds - warn_s and Village.era <= 2:
		var min_pop := wd.min_population if wd else 3
		var chance := (wd.chance_per_day if wd else 0.55) * Flags.diff_k(&"wolves")
		if Village.population() >= min_pop and not cold_active and not cold_warned and not era2.active() and not quiet():
			# the hunt for the dusk roll happens once per day
			if not has_meta("rolled_day") or int(get_meta("rolled_day")) != Clock.day:
				set_meta("rolled_day", Clock.day)
				if Game.rng.randf() < chance or Game.flags.has("wolves"):
					var n := clampi(1 + Village.population() / 7, 1, 3)
					wolves.warn(n)
	# cold snap creeps in over its warning time
	if cold_warned and not cold_active:
		cold_warn_t -= delta
		var cd := _def(COLD_ID)
		var total := cd.warning_seconds if cd else 20.0
		_set_frost(clampf(1.0 - cold_warn_t / total, 0.0, 1.0) * 0.6)
		if cold_warn_t <= 0.0:
			cold_active = true
			Events.threat_started.emit(COLD_ID, _fire())
			Events.alert.emit("A cold snap. Carry people to the fire.", _fire())
	# the first winter is announced near the end of autumn
	if Clock.season == Clock.Season.AUTUMN and Clock.season_fraction() > 0.85 and winter_warned_year != Clock.year:
		winter_warned_year = Clock.year
		Events.threat_warned.emit(WINTER_ID, _fire())
		Events.alert.emit("Winter is coming. Store food and firewood.", _fire())

func _on_night(_day: int) -> void:
	if enabled and wolves.warned and not wolves.active:
		wolves.start()

func _on_dawn(_day: int) -> void:
	if wolves.active or wolves.warned:
		wolves.end()
	if cold_active or cold_warned:
		cold_active = false
		cold_warned = false
		_set_frost(0.0)
		Events.threat_ended.emit(COLD_ID)
	elif enabled:
		_maybe_cold_snap()

func _maybe_cold_snap() -> void:
	var cd := _def(COLD_ID)
	var seasons := [Clock.Season.AUTUMN, Clock.Season.WINTER]
	if cd != null and cd.season >= 0:
		seasons = [cd.season]
	if not (Clock.season in seasons) or Clock.day < 3 or major_active() or quiet():
		return
	if Village.population() < (cd.min_population if cd else 3):
		return
	if Game.rng.randf() < (cd.chance_per_day if cd else 0.3) * Flags.diff_k(&"wolves") or Game.flags.has("cold"):
		start_cold_warning()

func start_cold_warning() -> void:
	var cd := _def(COLD_ID)
	cold_warned = true
	cold_warn_t = cd.warning_seconds if cd else 20.0
	Events.threat_warned.emit(COLD_ID, _fire())
	Events.alert.emit("Frost is creeping across the ground. People are shivering.", _fire())

func _on_season(s: int) -> void:
	if s == Clock.Season.WINTER:
		Events.threat_started.emit(WINTER_ID, _fire())
	elif s == Clock.Season.SPRING and Clock.year > 1:
		Events.threat_ended.emit(WINTER_ID)   # VillageAI counts winters survived

## The population safety net (wanderers at 1 person) lives in scripts/ai/wanderers.gd.

func _set_frost(v: float) -> void:
	if Game.world != null and "look" in Game.world and Game.world.look != null:
		Game.world.look.frost_target = v

func _fire() -> Vector3:
	return Game.world.fire_position() if Game.world != null and Game.world.has_method("fire_position") else Vector3.ZERO

func reset() -> void:
	wolves.clear_all()
	era2.reset()
	cold_active = false
	cold_warned = false
	_set_frost(0.0)
	if has_meta("rolled_day"):
		remove_meta("rolled_day")

func save_state() -> Dictionary:
	return {"cold_active": cold_active, "winter_warned_year": winter_warned_year, "era2": era2.save_state()}

func load_state(d: Dictionary) -> void:
	reset()
	cold_active = d.get("cold_active", false)
	winter_warned_year = d.get("winter_warned_year", 0)
	era2.load_state(d.get("era2", {}))
	if cold_active:
		_set_frost(0.6)
