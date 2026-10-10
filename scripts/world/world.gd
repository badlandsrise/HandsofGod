extends Node3D
## CONTRACT STUB (owner: world worker). Builds the valley, camera, light,
## navmesh; spawns people and sites from the Era layout; owns save/load of
## dynamic nodes. Sets Game.world = self.

func _enter_tree() -> void:
	Game.world = self

## Ground height at x,z (terrain is a heightmap). People and the hand use this.
func ground_y(x: float, z: float) -> float: return 0.0
## Point on the ground under the mouse, or Vector3.INF.
func mouse_ground() -> Vector3: return Vector3.INF
## Nearest Site within `r` of `p` matching `filter` (Callable(site)->bool), or null.
func site_near(p: Vector3, r: float, filter: Callable = Callable()) -> Site: return null
func spawn_person(at: Vector3, name_hint: String = "") -> Person: return null
func save_state() -> Dictionary: return {}
func load_state(d: Dictionary, nodes: Array) -> void: pass
