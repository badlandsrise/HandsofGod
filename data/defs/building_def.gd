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
## Workplaces (doc 4, Austin's 2026-10 ruling): a building the hand staffs. Its
## crew handles every task in `work_radius` on its own (sowing and harvesting
## the fields, hunting the herd, felling the trees); those task sites are not
## spots the hand drops people on.
@export var workplace: bool = false
@export var work_radius: float = 0.0
@export var work_jobs: Array[StringName] = []    # JobDef ids of the task sites its crew works
@export var crew_min: int = 1                    # crew size at the lowest grip
@export var crew_max: int = 6                    # the crew grows with the hand's grip, up to this
@export var bin_cap: int = 0                     # > 0: the crew fills the building's bin; a carter takes it to the stores
@export var rest_here: bool = false              # the crew eats and sleeps here (no night walk home)
@export var timbers: int = 0                     # bridge timbers the hand must carry onto the plot (Strong Arms)
@export var spawns: Array = []                   # [job id, x, z] task sites (local, before yaw) laid out when it is finished
## [era3] Era 3 workplaces (the mason's yard, the forge, the mills).
@export var bench_job: StringName = &""          # a CRAFT JobDef the crew works at the building's own bench when it has the inputs (its bin first, then the stores)
@export var fetch_from: Array[StringName] = []   # building ids whose workplace bins the crew empties (the mills take the farmhouses' grain)
@export var paves: bool = false                  # the crew lays the busiest roads in stone (the mason's yard)
