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
@export var raise_job: StringName = &""          # GROUP JobDef that raises it once the materials are in (barn raising, the bridge, the temple)
@export var camp: bool = false                   # a far-bank camp: a stockpile and a night shelter, never a family home
@export var store_bonus: int = 0                 # Village.store_cap gained when it is finished (granary, barn)
@export var yaw: float = 0.0                     # radians; the plot (and building) faces this way
@export var replaces: Array[StringName] = []     # finished sites of these ids under its footprint are taken down when it is finished (the temple over the shrine)
