class_name Person extends CharacterBody3D
## CONTRACT STUB (owner: people/sites worker). One named villager.

enum Stage { BABY, CHILD, ADULT, ELDER }

var uid: int = 0
var given_name: String = ""
var stage: int = Stage.ADULT
var trust: int = 1                      # 0..5, see design doc section 7
var job_site: Site = null

func _ready() -> void:
	add_to_group("persist"); add_to_group("people")
	Village.register_person(self)

func _exit_tree() -> void:
	Village.unregister_person(self)

func alive() -> bool: return true
## [hand] can the hand pick this person up now (not dead, not already held, not a baby being carried...)
func pickable() -> bool: return alive()
## [hand] weight for Strength (person = 1).
func weight() -> float: return 1.0
## [hand] called when lifted; person stops what it's doing, plays the held pose.
func on_lifted() -> void: pass
## [hand] called when released. `site` may be null (ground). The person falls,
## lands at `at`, then joins `site` if given and it can accept, else idles.
func on_placed(at: Vector3, site: Site) -> void: pass
## [hand] while held, the hand moves the person with this each frame.
func held_follow(world_pos: Vector3) -> void: global_position = world_pos
## [ui] one line under the name, e.g. "Hungry, wants: fire".
func status_text() -> String: return ""
func save_state() -> Dictionary: return {}
func load_state(d: Dictionary) -> void: pass
