class_name Gifts extends Node
## People leave gifts at the shrine. This spawns Gift nodes (group "gift");
## the hand picks them up. The first fire they tend leaves the first gift, a
## stone with a handprint, which grants Grip II when picked up (onboarding 5-8 min).

const MAX_WAITING := 6        # no more than this many gifts lying around

func _ready() -> void:
	Events.job_completed.connect(_on_job_completed)

func _on_job_completed(site) -> void:
	# The first gift is an onboarding beat (onboarding.gd); this is only the
	# fallback for saves made before the beats existed.
	if Village.stats.get("first_gift", false) or not Flags.onboarding_done():
		return
	if site is Site and is_instance_valid(site) and site.is_fire():
		Village.stats["first_gift"] = true
		var near: Person = null
		for w in site.workers:
			if is_instance_valid(w):
				near = w
				break
		Gifts.spawn_gift(near, site.global_position, &"grip_2", "handprint stone")

## Spawns a gift from `p` at the nearest shrine (or by `at`, or the stash).
static func spawn_gift(p: Person, at: Vector3 = Vector3.INF, grants: StringName = &"", kind: String = "") -> Gift:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.get_nodes_in_group("gift").size() >= MAX_WAITING:
		return null
	var from := p.global_position if p != null and is_instance_valid(p) and p.is_inside_tree() else Vector3.ZERO
	var shrine := Site.nearest_shrine(from)
	var base: Vector3
	if shrine != null:
		base = shrine.global_position + Vector3(0, 0, shrine.pick_radius() + 0.6)
	elif at != Vector3.INF:
		base = at + Vector3(0, 0, 1.6)
	else:
		base = Site.store_point(from) + Vector3(0.8, 0, 0.8)
	var g: Gift = (load(Gift.SCENE) as PackedScene).instantiate()
	g.era = Village.era
	var kinds: Array = Gift.KINDS.get(clampi(Village.era, 1, 4), Gift.KINDS[1])
	g.kind = kind if kind != "" else str(kinds[Game.rng.randi() % kinds.size()])
	g.faith_value = 3.0
	if p != null and is_instance_valid(p):
		g.from_uid = p.uid
		g.from_name = p.given_name
		if p.trust >= 5:
			g.faith_value = 5.0           # better gifts from friends of the hand
	if grants != &"" and not Faith.has(grants):
		g.grants_power = grants
	var parent: Node = Game.world if Game.world != null and is_instance_valid(Game.world) else tree.current_scene
	if parent == null:
		parent = tree.root
	parent.add_child(g)
	var jitter := Vector3(Game.rng.randf_range(-0.6, 0.6), 0, Game.rng.randf_range(-0.3, 0.3))
	var pos := base + jitter
	pos.y = Site.ground(pos.x, pos.z)
	g.global_position = pos
	Events.toast.emit("%s left a gift" % g.from_name if g.from_name != "" else "A gift was left for you")
	return g
