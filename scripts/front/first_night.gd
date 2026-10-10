class_name FirstNight extends Node
## The front end's hand-off from the storm night to the naming card: once the
## branch is lifted and the two have run into the cave, it asks the hand to
## name them (Events.name_requested with reason &"first_two", DESIGN 3 and the
## naming card's prompt "Two people shelter in the cave"). One request per
## valley; if anything else asks for the first two's names first, it stands
## down. Attached by the title menu when play starts during the storm.

const DELAY := 1.2               # seconds after they reach the cave

var world: Node = null
var _t: float = 0.0
var _armed: bool = false

## Watches `w`'s storm night, unless it is over or the first two already have names.
static func watch(w: Node) -> FirstNight:
	if w == null or not is_instance_valid(w) or w.get(&"storm") == null:
		return null
	var old := w.get_node_or_null("FirstNight")
	if old != null:
		old.free()
	if not w.storm.active() or BookData.has_first("names"):
		return null
	var n := FirstNight.new()
	n.name = "FirstNight"
	n.world = w
	w.add_child(n)
	return n

func _ready() -> void:
	Events.name_requested.connect(_on_name_requested)

func _on_name_requested(_people: Array, reason: StringName) -> void:
	if reason == &"first_two":
		queue_free()               # someone else asked already

func _process(delta: float) -> void:
	if world == null or not is_instance_valid(world) or world.storm == null:
		queue_free()
		return
	var st: int = world.storm.state
	if st == StormOpening.S.OFF:
		queue_free()
		return
	if st == StormOpening.S.STORM:
		return
	# RUNNING_IN, DAWNING or DONE: they are safe in the cave
	_t += delta
	if _t < DELAY or _armed:
		return
	_armed = true
	var people: Array = world.storm.people.filter(func(p): return p != null and is_instance_valid(p) and p.alive())
	Events.name_requested.disconnect(_on_name_requested)
	if people.size() >= 1:
		Events.name_requested.emit(people, &"first_two")
	queue_free()
