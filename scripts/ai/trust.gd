class_name Trust extends RefCounted
## How the village as a whole feels about the hand (doc 7). Each person holds
## their own trust (Person.trust_f); this sums it up for the things the whole
## village does: painting the hand on its buildings, offerings at the temple,
## crowds waving when the hand passes.
##
##   average()            mean trust of everyone past babyhood (0..5)
##   village_loves_hand() the average has reached Fond (3): the hand symbol is
##                        painted over the doors of the Era 2 buildings
##   stage_name()         "afraid" .. "friends", for the Book and the bot

const LOVE_AT := 3.0
const CACHE_S := 1.0

static var _cache_t: float = -INF
static var _cache: float = 0.0

static func average() -> float:
	if absf(Clock.total_t - _cache_t) < CACHE_S:
		return _cache
	_cache_t = Clock.total_t
	var n := 0
	var sum := 0.0
	for p in Village.alive():
		if p.stage == Person.Stage.BABY:
			continue
		sum += p.trust_f
		n += 1
	_cache = sum / float(n) if n > 0 else 0.0
	return _cache

static func village_loves_hand() -> bool:
	return Flags.has(&"hand_symbol") or average() >= LOVE_AT

static func stage_name(t: float = -1.0) -> String:
	var v := average() if t < 0.0 else t
	return ["afraid", "wary", "curious", "fond", "devoted", "friends"][clampi(floori(v), 0, 5)]
