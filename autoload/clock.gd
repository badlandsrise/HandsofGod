extends Node
## Game time. Emits Events.sim_tick at 10 Hz (scaled by speed), and the
## day/night and season changes. Speed works through Engine.time_scale, so
## everything that uses _process delta speeds up together; the hand and the
## camera read real time (Clock.real_delta) so they stay responsive at any
## speed, including pause.

enum Season { SPRING, SUMMER, AUTUMN, WINTER }
const TICK := 0.1
const SPEEDS: Array[float] = [0.0, 1.0, 2.0, 3.0]

var speed_index: int = 1
var day: int = 1
var is_night: bool = false
var season: int = Season.SPRING
var year: int = 1
var phase_t: float = 0.0          # seconds into the current day or night
var season_t: float = 0.0
var total_t: float = 0.0          # scaled game seconds since the start
var day_seconds: float = 75.0
var night_seconds: float = 30.0
var season_seconds: float = 240.0
var real_delta: float = 0.0
var running: bool = false         # false on the title screen and during cutscenes that freeze time

var _acc: float = 0.0
var _last_us: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_last_us = Time.get_ticks_usec()

func apply_era(e: EraDef) -> void:
	if e == null:
		return
	day_seconds = e.day_seconds
	night_seconds = e.night_seconds
	season_seconds = e.season_seconds

func set_speed(i: int) -> void:
	speed_index = clampi(i, 0, SPEEDS.size() - 1)
	Engine.time_scale = SPEEDS[speed_index]

func toggle_pause() -> void:
	set_speed(1 if speed_index == 0 else 0)

func paused() -> bool:
	return speed_index == 0

## 0..1 through the full day+night, 0 = dawn. Used for sun angle.
func day_fraction() -> float:
	var full := day_seconds + night_seconds
	return ((phase_t if not is_night else day_seconds + phase_t) / full)

func season_fraction() -> float:
	return season_t / season_seconds

func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	real_delta = minf((now - _last_us) / 1000000.0, 0.1)
	_last_us = now
	if not running:
		return
	total_t += delta
	phase_t += delta
	season_t += delta
	if not is_night and phase_t >= day_seconds:
		phase_t -= day_seconds
		is_night = true
		Events.night_started.emit(day)
	elif is_night and phase_t >= night_seconds:
		phase_t -= night_seconds
		is_night = false
		day += 1
		Events.day_started.emit(day)
	if season_t >= season_seconds:
		season_t -= season_seconds
		season = (season + 1) % 4
		if season == Season.SPRING:
			year += 1
		Events.season_changed.emit(season)
	_acc += delta
	var n := 0
	while _acc >= TICK and n < 8:
		_acc -= TICK
		n += 1
		Events.sim_tick.emit(TICK)

func save_state() -> Dictionary:
	return {"day": day, "is_night": is_night, "season": season, "year": year,
		"phase_t": phase_t, "season_t": season_t, "total_t": total_t}

func load_state(d: Dictionary) -> void:
	day = d.get("day", 1); is_night = d.get("is_night", false)
	season = d.get("season", 0); year = d.get("year", 1)
	phase_t = d.get("phase_t", 0.0); season_t = d.get("season_t", 0.0)
	total_t = d.get("total_t", 0.0)
