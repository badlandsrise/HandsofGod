class_name Hand extends Node3D
## CONTRACT STUB (owner: hand worker). The player's only verb.
## Reads Faith.grip and Faith.strength. Emits Events.hand_* signals.

var held: Array = []                    # Person nodes
var held_object: Node3D = null          # a liftable (log, boulder, building) when not holding people

func is_holding() -> bool: return not held.is_empty() or held_object != null
## Liftable world objects (logs, boulders, buildings) implement:
##   func lift_weight() -> float ; func on_lifted() ; func on_placed(at: Vector3)
## and are in group "liftable".
