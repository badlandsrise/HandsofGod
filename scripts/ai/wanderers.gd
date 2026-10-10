class_name Wanderers extends Node
## Newcomers arrive at the map edge and walk in: with dreams (DreamDef.wanderers;
## one with the first dream, onboarding minute 8-10), a hunting pair when the
## Valley Floor opens, four when the Western Meadow opens, and the safety net
## (doc 8.1): if the population is 1 or less, two wanderers arrive within a day.
## The world may implement edge_point(region: StringName) -> Vector3 to pick
## where they appear; otherwise they come from a ring around the stash.

const EDGE_RADIUS := 28.0
const REGION_WANDERERS: Dictionary = {&"valley_floor": 2, &"western_meadow": 4}

var _net_t: float = 0.0

func _ready() -> void:
	Events.sim_tick.connect(_on_tick)
	Events.region_opened.connect(_on_region)
	Events.dream_started.connect(_on_dream)

func _on_tick(dt: float) -> void:
	if Village.population() <= 1:
		_net_t += dt
		var within := (Clock.day_seconds + Clock.night_seconds) * 0.5
		if _net_t >= within:
			_net_t = 0.0
			arrive(2, &"")
	else:
		_net_t = 0.0

func _on_region(id: StringName) -> void:
	var key := "wanderers_for_" + str(id)
	if REGION_WANDERERS.has(id) and not Village.stats.get(key, false):
		Village.stats[key] = true
		arrive(int(REGION_WANDERERS[id]), id)

func _on_dream(id: StringName) -> void:
	var key := "wanderers_for_" + str(id)
	var d := Defs.dream(id)
	if d != null and d.wanderers > 0 and not Village.stats.get(key, false):
		Village.stats[key] = true
		arrive(d.wanderers, &"")

func _parent_node() -> Node:
	if Game.world != null and is_instance_valid(Game.world):
		return Game.world
	return get_parent() if get_parent() else get_tree().root

func edge_point(region: StringName) -> Vector3:
	if Game.world != null and is_instance_valid(Game.world) and Game.world.has_method("edge_point"):
		var p: Vector3 = Game.world.edge_point(region)
		if p != Vector3.INF:
			return p
	var c := Site.store_point(Vector3.ZERO)
	var a := Game.rng.randf() * TAU
	return c + Vector3(cos(a), 0, sin(a)) * EDGE_RADIUS

## Spawns `n` wanderers (a small group arrives together) who walk to the stash.
func arrive(n: int, region: StringName) -> Array:
	var out: Array = []
	var at := edge_point(region)
	var dest := Site.store_point(at)
	var first_f := Game.rng.randf() < 0.5
	for i in n:
		var off := Vector3(Game.rng.randf_range(-1.5, 1.5), 0, Game.rng.randf_range(-1.5, 1.5))
		var p := Person.spawn(_parent_node(), at + off, {
			"age": Game.rng.randf_range(Person.STAGE_START[Person.Stage.ADULT] + 10.0, Person.STAGE_START[Person.Stage.ADULT] + 240.0),
			"trust_f": Game.rng.randf_range(0.5, 1.6), "wanderer": true,
			"sex": "f" if (i % 2 == 0) == first_f else "m"})
		var a := Game.rng.randf() * TAU
		p._walk(dest + Vector3(cos(a), 0, sin(a)) * Game.rng.randf_range(2.0, 4.0))
		Village.stats["joined"] = int(Village.stats.get("joined", 0)) + 1
		Events.person_joined.emit(p)
		out.append(p)
	if n > 0:
		Events.alert.emit("%s arrived" % ("A wanderer" if n == 1 else "%d wanderers" % n), at)
	return out
