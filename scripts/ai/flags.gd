class_name Flags extends RefCounted
## Village-wide one-off facts ("stone_tools", "festival", "first_fire") kept in
## Village.stats["flags"] so they save with the village. Also the Era 1
## memory log (Village.stats["memories"]), written in the people's voice for the
## Village Book.

static func has(id: StringName) -> bool:
	return (Village.stats.get("flags", []) as Array).has(str(id))

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
