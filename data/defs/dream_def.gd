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
@export var reward_faith: float = 15.0
@export var unlocks_powers: Array[StringName] = []
