class_name PowerDef extends Resource

@export var id: StringName
@export var title: String = ""
@export var era: int = 1
@export var cost: float = 10.0
@export var free: bool = false                    # granted by script (Grip II, first gift)
@export var requires: Array[StringName] = []
@export var grip: int = 0                         # sets hand grip to this if > 0
@export var strength: float = 0.0                 # sets hand strength to this if > 0
@export var gesture: bool = false                 # a hold-E power
@export var opens_region: StringName = &""
@export var opens_jobs: Array[StringName] = []
@export_multiline var what_it_does: String = ""
@export_multiline var what_it_opens: String = ""
@export var requires_regions: Array[StringName] = []   # regions that must be open before it can be bought
@export var requires_dreams: Array[StringName] = []    # dreams that must be done first
@export var min_population: int = 0
@export var requires_flags: Array[StringName] = []   # Village flags (e.g. &"far_bank_seen", set when the people first look across the river)
@export var flag_hint: String = ""                    # HUD line while a requires_flags entry is missing

## Gameplay prerequisites beyond other powers (Faith.can_buy asks this), so a
## power can't be afforded long before its region or job is needed (doc 6).
func prerequisites_met() -> bool:
	for r in requires_regions:
		if not Village.regions.has(r):
			return false
	var done: Array = Village.stats.get("dreams_done", [])
	for d in requires_dreams:
		if not done.has(str(d)):
			return false
	for f in requires_flags:
		if not Flags.has(f):
			return false
	return min_population <= 0 or Village.population() >= min_population

## Short reason for the HUD when prerequisites are not met ("" when met).
func locked_reason() -> String:
	for r in requires_regions:
		if not Village.regions.has(r):
			return "Open the %s first" % str(r).replace("_", " ").capitalize()
	var done: Array = Village.stats.get("dreams_done", [])
	for d in requires_dreams:
		if not done.has(str(d)):
			var dd = Defs.dream(d)
			return "After \"%s\"" % (dd.text if dd else str(d))
	if min_population > 0 and Village.population() < min_population:
		return "Needs %d people" % min_population
	for f in requires_flags:
		if not Flags.has(f):
			return flag_hint if flag_hint != "" else "Not yet"
	return ""
