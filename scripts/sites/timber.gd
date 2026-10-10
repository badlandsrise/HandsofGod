class_name Timber extends Liftable
## A bridge timber (Strong Arms, Era 2): a squared beam too heavy for anyone
## but the hand. Set down on a bridge plot that wants timbers, it becomes part
## of the bridge (Site.add_timber); set down anywhere else it stays there.
## Loose timbers are kept in Village.stats["timbers"] (positions), so they come
## back after a load (VillageEra2.sync_timbers).

const WEIGHT := 6.0
const DROP_RADIUS := 10.0

var key: int = 0          # index in Village.stats["timbers"]

func _init() -> void:
	weight = WEIGHT
	kind = &"timber"
	label = "Bridge timber"

func _ready() -> void:
	super._ready()
	add_to_group("timbers")
	if get_node_or_null("Visual") == null:
		build_log_visual(6.0, 0.28, false)      # length and the pick body
		var v := get_node_or_null("Visual")
		if v != null:
			# the squared, adzed beam (build_workplaces.gd) in place of a round log
			for c in v.get_children():
				v.remove_child(c)
				c.queue_free()
			v.add_child(AssetCatalog.instance(&"bridge_timber", key))

func hover_text() -> String:
	if Faith.strength < weight:
		return "Bridge timber (weight %d: the hand needs Strong Arms)" % int(weight)
	var p := Timber.wanting_plot(global_position, 9999.0)
	return "Bridge timber: carry it to the %s" % (p.building.title.to_lower().trim_prefix("the ") if p != null else "bridge")

## The nearest bridge plot within `r` that still wants a timber.
static func wanting_plot(at: Vector3, r: float) -> Site:
	var best: Site = null
	var bd := r
	for s in Village.sites:
		if not is_instance_valid(s) or not s.wants_timber():
			continue
		var d := Vector2(s.global_position.x - at.x, s.global_position.z - at.z).length()
		if d <= bd:
			bd = d
			best = s
	return best

func on_placed(at: Vector3) -> void:
	super.on_placed(at)
	var plot := Timber.wanting_plot(global_position, DROP_RADIUS)
	if plot != null and plot.add_timber():
		Events.alert.emit("A timber for the %s (%d/%d)" % [plot.building.title.to_lower().trim_prefix("the "), plot.timbers_in, plot.building.timbers], plot.global_position)
		Flags.remember("The hand carried a great timber to the Great River for our bridge.")
		_forget()
		queue_free()
		return
	_remember()

func _remember() -> void:
	var a: Array = Village.stats.get("timbers", [])
	if key >= 0 and key < a.size():
		a[key] = [global_position.x, global_position.z, rotation.y]
	Village.stats["timbers"] = a

func _forget() -> void:
	var a: Array = Village.stats.get("timbers", [])
	if key >= 0 and key < a.size():
		a[key] = []           # used up (kept as an empty slot so the other keys hold)
	Village.stats["timbers"] = a
