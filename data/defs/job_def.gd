class_name JobDef extends Resource
## One kind of work. Sites (scripts/sites/site.gd) are placed instances of a JobDef.

enum Kind { GATHER, CRAFT, BUILD, GROUP, TEND, HAUL, LEAD, DEVOTION }

@export var id: StringName
@export var title: String = ""
@export var era: int = 1
@export var kind: Kind = Kind.GATHER
@export var skill: StringName = &"gather"        # skill family that levels up
@export var min_people: int = 1                  # GROUP jobs start only when min_people are present at once
@export var max_people: int = 1
@export var wait_before_wander: float = 20.0     # seconds a person waits at an unfilled group job
@export var inputs: Dictionary = {}              # {&"wood": 1}
@export var outputs: Dictionary = {}             # {&"berries": 1}
@export var work_time: float = 6.0               # seconds per cycle for one person at skill 1
@export var group_bonus: float = 0.0             # extra speed per person above min_people
@export var node_amount: int = -1                # GATHER: units before depleted (-1 = infinite)
@export var regrow_time: float = 0.0             # GATHER: seconds to regrow one unit (0 = never)
@export var winter_stops: bool = false
@export var only_season: int = -1               # only in this Clock.Season (-1 = any): the bridge piers go in when the river runs low, in winter
@export var season_note: String = ""            # said when the work is ready but out of season
@export var needs_power: StringName = &""        # job only available once this power is unlocked
@export var needs_discovery: StringName = &""     # a Village.stats["flags"] entry (e.g. &"stone_tools")
@export var needs_blessed: bool = false          # GROUP: only blessed workers make progress (the great elk hunt)
@export var carry_to: StringName = &"store"       # GROUP hauls (node_amount 1): &"store" or &"fire"
@export var faith_rate: float = 0.1              # DEVOTION: faith per second per worshipper at mood 1
@export var once: bool = false                   # removed after one completion (festival, elk hunt)
@export var anim: StringName = &""                # villager work clip; "" = TaskAnims picks one by job id or kind
