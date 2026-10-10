class_name BuildingDef extends Resource

@export var id: StringName
@export var title: String = ""
@export var era: int = 1
@export var footprint: Vector2 = Vector2(3, 3)   # metres
@export var cost: Dictionary = {}                # materials carried in by builders
@export var build_work: float = 20.0             # person-seconds of building
@export var build_slots: int = 2
@export var upgrades_to: StringName = &""
@export var jobs: Array[StringName] = []         # JobDef ids this building hosts once finished
@export var shelter: int = 0                     # people it sleeps
@export var warmth_radius: float = 0.0
@export var joy_radius: float = 0.0
@export var weight: float = 40.0                 # for Lift Buildings
@export var scene: PackedScene                   # visual; null = placeholder box
