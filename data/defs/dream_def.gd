class_name DreamDef extends Resource
## A Village Dream: the people's own goal. Conditions are checked by
## scripts/ai/dreams.gd against Village stats.

@export var id: StringName
@export var era: int = 1
@export var text: String = ""                     # in the people's voice
@export var gate: bool = false
@export var needs_buildings: Dictionary = {}      # {&"hut": 2}
@export var needs_stores: Dictionary = {}         # {&"food": 30}
@export var needs_population: int = 0
@export var needs_survive_winter: bool = false
@export var needs_winters: int = 0                # winters survived (overrides needs_survive_winter when > 1)
@export var needs_flags: Array[StringName] = []   # Village.stats["flags"] entries, e.g. &"festival"
@export var winters_after_start: int = 0          # winters lived through since the dream appeared (the granary: "survive a winter on stores")
@export var needs_regions: Array[StringName] = [] # regions that must be open
@export var wanderers: int = 0                    # newcomers who arrive when the dream appears
@export var quiet_before: float = 0.0             # game seconds of quiet after the last dream before this one appears
@export var plots: Dictionary = {}                # extra plots the dream lays out beyond needs_buildings, {&"food_store": 1}
@export_multiline var voice: String = ""          # a line the people say when they dream it
@export var reward_faith: float = 15.0
@export var unlocks_powers: Array[StringName] = []
