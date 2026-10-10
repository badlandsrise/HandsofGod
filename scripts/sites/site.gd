class_name Site extends Node3D
## CONTRACT STUB (owner: people/sites worker). A place where work happens:
## a gather node (berry bush), a job at a building (fire tending), a group
## job (log haul), or a build plot that becomes a building.
## The hand only ever talks to Sites through the functions marked [hand].

enum State { JOB, PLOT, BUILDING, FINISHED }

@export var job: JobDef                 # the work done here (null for an unfinished plot)
@export var building: BuildingDef       # set for plots/buildings
var state: int = State.JOB
var uid: int = 0
var workers: Array = []                 # Person nodes assigned here (working or waiting)

func _ready() -> void:
	add_to_group("persist"); add_to_group("sites")
	Village.register_site(self)

func _exit_tree() -> void:
	Village.unregister_site(self)

## [hand] true if `n` more people can be placed here right now.
func can_accept(n: int = 1) -> bool: return false
## [hand] free slots.
func free_slots() -> int: return 0
## [hand] slots needed before a group job starts (0 for non-group work).
func group_needs() -> int: return 0
## [hand] where the i-th placed person should land (world position).
func slot_position(i: int) -> Vector3: return global_position
## [hand] short label for the hover tooltip, e.g. "Haul log 2/3".
func hover_text() -> String: return ""
## [hand] radius used for picking this site with the mouse.
func pick_radius() -> float: return 1.5
## Called by Person when it arrives/leaves.
func claim(p) -> void: pass
func release(p) -> void: pass
func is_finished_building(id: StringName) -> bool: return false
func save_state() -> Dictionary: return {}
func load_state(d: Dictionary) -> void: pass
