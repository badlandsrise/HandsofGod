class_name Flags extends RefCounted
## Village-wide one-off facts ("stone_tools", "festival", "first_fire") kept in
## Village.stats["flags"] so they save with the village. Also the Era 1
## memory log (Village.stats["memories"]), written in the people's voice for the
## Village Book.

static func has(id: StringName) -> bool:
	var a = Village.stats.get("flags", null)
	if not (a is Array):
		return false
	# asked thousands of times a second by a town: a set, rebuilt when the list changes
	if not is_same(a, _src) or (a as Array).size() != _n:
		_src = a
		_n = (a as Array).size()
		_set.clear()
		for f in a:
			_set[StringName(str(f))] = true
	return _set.has(id)

static var _set: Dictionary = {}
static var _src = null
static var _n: int = -1

## Sets a flag. Returns true the first time.
static func set_flag(id: StringName) -> bool:
	if not Village.stats.has("flags"):
		Village.stats["flags"] = []
	var a: Array = Village.stats["flags"]
	if a.has(str(id)):
		return false
	a.append(str(id))
	return true

## Remembers something the hand did, in the people's voice ("On day 3 the hand ...").
static func remember(text: String) -> void:
	if not Village.stats.has("memories"):
		Village.stats["memories"] = []
	(Village.stats["memories"] as Array).append({"day": Clock.day, "t": Clock.total_t, "text": text})

## The onboarding beat the village has reached (Onboarding.Beat); saves made
## before onboarding existed count as finished.
static func beat() -> int:
	return int(Village.stats.get("onboarding", 99))

static func onboarding_done() -> bool:
	return Flags.beat() >= 7

## Difficulty (Game.options["difficulty"]: gentle / normal / harsh) as a
## multiplier: &"cold" (warmth lost), &"wolves" (chance of a pack and of a
## cold snap), &"food" (how fast people get hungry).
const DIFFICULTY := {
	"gentle": {&"cold": 0.7, &"wolves": 0.5, &"food": 0.8},
	"normal": {&"cold": 1.0, &"wolves": 1.0, &"food": 1.0},
	"harsh": {&"cold": 1.35, &"wolves": 1.5, &"food": 1.2},
}

static func difficulty() -> String:
	var d := str(Game.options.get("difficulty", "normal")) if Game.options is Dictionary else "normal"
	return d if DIFFICULTY.has(d) else "normal"

static func diff_k(kind: StringName) -> float:
	return float(DIFFICULTY[difficulty()].get(kind, 1.0))
