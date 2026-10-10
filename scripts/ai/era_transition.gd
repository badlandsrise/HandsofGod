class_name EraTransition extends Node
## The era transition (doc 5). When an era's gate dream is done:
##   1. the camera pulls back over the village and the hand is set aside;
##   2. a short time-lapse: the season turns over a few seconds;
##   3. only then Village.era goes up and Events.era_changed fires (Audio plays
##      the era_complete stinger and moves to the next era's music);
##   4. Events.era_complete_shown(old_era) asks the UI for the "Era N complete"
##      card; its numbers are in Village.stats["era_summary"][str(old_era)].
## M2: Era 2 is a placeholder (EraDef.playable = false), so play continues in
## free mode with no new dreams.

signal finished(era: int)

const PULL_BACK_S := 2.5           # real seconds before the time-lapse
const LAPSE_S := 4.0               # real seconds of season turning
const PULL_DIST := 75.0

var running: bool = false
var from_era: int = 0
var _t: float = 0.0
var _phase: int = 0
var _season_from: float = 0.0

func _ready() -> void:
	name = "EraTransition"
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.dream_done.connect(_on_dream_done)

func _on_dream_done(id: StringName) -> void:
	var d := Defs.dream(id)
	if d != null and d.gate and d.era == Village.era and not running:
		begin(d.era)

## Records the era's numbers for the card (and the bot's timeline).
static func summary(era: int) -> Dictionary:
	var mins := Clock.total_t / 60.0
	var started := float(Village.stats.get("era_started_t", 0.0))
	var s := {
		"era": era,
		"minutes": (Clock.total_t - started) / 60.0,
		"game_minutes_total": mins,
		"population": Village.population(),
		"births": int(Village.stats.get("births", 0)),
		"deaths": int(Village.stats.get("deaths", 0)),
		"joined": int(Village.stats.get("joined", 0)),
		"faith_earned": Faith.total,
		"powers": Faith.unlocked.keys().map(func(k): return str(k)),
		"regions": Village.regions.keys().map(func(k): return str(k)),
		"dreams": (Village.stats.get("dreams_done", []) as Array).duplicate(),
		"winters": int(Village.stats.get("winters_survived", 0)),
		"gifts": int(Village.stats.get("gifts", 0)),
		"first_two": Village.alive().filter(func(p): return p.first_two).map(func(p): return p.given_name),
		"day": Clock.day,
	}
	return s

func begin(era: int) -> void:
	running = true
	from_era = era
	_t = 0.0
	_phase = 0
	if not Village.stats.has("era_summary"):
		Village.stats["era_summary"] = {}
	Village.stats["era_summary"][str(era)] = EraTransition.summary(era)
	Village.stats["era_complete_t"] = Clock.total_t
	print("era: Era %d complete at %.0fs (%.1f min)" % [era, Clock.total_t, Clock.total_t / 60.0])
	var w = Game.world
	if w != null and is_instance_valid(w):
		var rig = w.get("camera_rig")
		if rig != null and is_instance_valid(rig) and rig.has_method("focus_on"):
			var c: Vector3 = w.fire_position() if w.has_method("fire_position") else Vector3.ZERO
			rig.focus_on(c + Vector3(-8, 0, 2), PULL_DIST)
		var hand = w.get("hand")
		if hand != null and is_instance_valid(hand) and hand.has_method("release_all"):
			hand.release_all()
	Events.toast.emit("The %s era is complete" % (Defs.era(era).title if Defs.era(era) else str(era)))

func _process(_delta: float) -> void:
	if not running:
		return
	_t += Clock.real_delta if Clock.real_delta > 0.0 else 0.016
	match _phase:
		0:
			if _t >= PULL_BACK_S:
				_phase = 1
				_t = 0.0
				_season_from = Clock.season_t
		1:
			# Time-lapse: the season turns. Never past the season's end, so the
			# winter count and season events stay with the clock.
			var k := clampf(_t / LAPSE_S, 0.0, 1.0)
			Clock.season_t = minf(lerpf(_season_from, Clock.season_seconds - 1.0, k), Clock.season_seconds - 0.5)
			if _t >= LAPSE_S:
				_finish()

func _finish() -> void:
	running = false
	var next := from_era + 1
	Village.era = next
	Village.stats["era_started_t"] = Clock.total_t
	Village.stats["free_mode"] = Defs.era(next) == null or not Defs.era(next).playable
	var e := Defs.era(next)
	if e != null:
		Clock.apply_era(e)
	Events.era_changed.emit(next)
	Events.era_complete_shown.emit(from_era)
	finished.emit(from_era)
