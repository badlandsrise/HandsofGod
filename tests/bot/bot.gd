extends Node
## Headless test bot. Attached by the world when Game.flags has "test".
## Plays the Era 1 loop through the contract APIs only (no input events):
## lifts the storm branch, staffs jobs by calling Person.on_lifted/on_placed
## (preferring group jobs once it can fill them), buys powers with Faith.buy,
## moves the meadow logs once strong enough, and picks up gifts.
## Prints a report every in-game day. Tolerates missing data and stub nodes.
##
## Flags (after "--"):
##   --test                 attach the bot
##   --shot=a.png[,b.png]   screenshot path(s) (needs a renderer, not --headless)
##   --shot-at=15,90        game seconds for each screenshot
##   --quit-after-game=N    quit after N game seconds (default 240)
##   --speed=N              Engine.time_scale (default 4 headless, 2 with shots)

const THINK := 1.2               # game seconds between hand actions (a human pace)

var quit_after: float = 240.0
var shots: Array = []            # [[time, path], ...]
var _think_t: float = 0.0
var _last_day: int = -1
var _dreams: Dictionary = {}     # id -> game time done
var _regions: Dictionary = {}    # id -> game time opened
var _deaths: int = 0
var _actions: int = 0
var _placed: int = 0
var _bought: Array = []
var _gifts: int = 0
var _errors: int = 0
var _fps_sum: float = 0.0
var _fps_n: int = 0
var _start_ms: int = 0
var _quitting: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Save.enabled = false
	_start_ms = Time.get_ticks_msec()
	var f: Dictionary = Game.flags
	if f.has("quit-after-game"):
		quit_after = float(f["quit-after-game"])
	var paths: Array = []
	if f.has("shot"):
		paths = str(f["shot"]).split(",", false)
	var times: Array = [15.0, 90.0]
	if f.has("shot-at"):
		times = Array(str(f["shot-at"]).split(",", false)).map(func(s): return float(s))
	if not paths.is_empty():
		for i in times.size():
			var p: String = paths[i] if i < paths.size() else str(paths[0]).get_basename() + "_%d.png" % i
			shots.append([times[i], p])
		quit_after = maxf(quit_after if f.has("quit-after-game") else 0.0, float(times.max()) + 2.0)
	var speed := 4.0 if DisplayServer.get_name() == "headless" else 2.0
	if f.has("speed"):
		speed = float(f["speed"])
	Engine.time_scale = speed
	Events.dream_done.connect(func(id): _dreams[id] = Clock.total_t; print("BOT dream done: %s at %.0fs" % [id, Clock.total_t]))
	Events.region_opened.connect(func(id): _regions[id] = Clock.total_t; print("BOT region opened: %s at %.0fs" % [id, Clock.total_t]))
	Events.person_died.connect(func(_p): _deaths += 1)
	Events.day_started.connect(func(_d): _report())
	if Game.flags.has("verbose"):
		Events.night_started.connect(func(_d): _last_day = -1; _report())
	Events.power_unlocked.connect(func(id): print("BOT power unlocked: %s at %.0fs" % [id, Clock.total_t]))
	Events.threat_warned.connect(func(id, _at): print("BOT threat warned: %s at %.0fs" % [id, Clock.total_t]))
	Events.alert.connect(func(t, _at): print("BOT alert: %s" % t))
	print("BOT start: quit after %.0f game s, speed %.1f, shots %s" % [quit_after, speed, str(shots)])

func _process(delta: float) -> void:
	if _quitting:
		return
	_fps_sum += Engine.get_frames_per_second()
	_fps_n += 1
	if not Clock.running:
		return
	var t := Clock.total_t
	if not shots.is_empty() and t >= float(shots[0][0]):
		var s: Array = shots.pop_front()
		if Game.flags.has("light-fire") and Clock.is_night and Game.world.get("fire") != null:
			Game.world.fire.add_fuel(1.0)     # test aid: show the firelight in the night shot
			await get_tree().create_timer(0.5).timeout
		await _shot(str(s[1]))
	if t >= quit_after:
		_finish()
		return
	_think_t -= delta
	if _think_t <= 0.0:
		_think_t = THINK
		_think()

# ---------------------------------------------------------------- play

func _think() -> void:
	var w: Node = Game.world
	if w == null:
		return
	# 1. the storm branch
	if "storm" in w and w.storm != null and w.storm.active() and w.storm.state == StormOpening.S.STORM:
		var b: Liftable = w.branch
		if Faith.strength >= b.lift_weight():
			_move_object(b, b.global_position + Vector3(5.5, 0, 3.5))
		return
	# 2. powers as they become affordable (cheapest first)
	var ps: Array = Defs.powers.values()
	ps.sort_custom(func(a, b): return a.cost < b.cost)
	for p in ps:
		if Faith.can_buy(p.id) and Faith.buy(p.id):
			_bought.append(p.id)
			print("BOT bought %s for %.0f faith" % [p.id, p.cost])
	# 3. gifts
	for g in get_tree().get_nodes_in_group("gift") + get_tree().get_nodes_in_group("gifts"):
		if is_instance_valid(g) and not g.is_queued_for_deletion():
			_pick_gift(g)
	# 4. the meadow logs, once the hand is strong enough
	if not Village.regions.has(&"western_meadow") and "logs" in w:
		for i in w.logs.size():
			var lg: Liftable = w.logs[i]
			if Faith.strength >= lg.lift_weight() and Vector2(lg.global_position.x, lg.global_position.z).distance_to(Valley.WEST_GAP) < w.GAP_CLEAR:
				_move_object(lg, Vector3(Valley.WEST_GAP.x + 9.0, 0, Valley.WEST_GAP.y - 9.0 + i * 3.0))
				return
	# 5. staff jobs
	_staff()

func _move_object(o: Node3D, to: Vector3) -> void:
	o.on_lifted()
	Events.hand_lifted_object.emit(o)
	var at := Vector3(to.x, Game.world.ground_y(to.x, to.z), to.z)
	o.on_placed(at)
	Events.hand_placed_object.emit(o, at)
	_actions += 1
	print("BOT moved %s to (%.0f, %.0f) at %.0fs" % [o.name, at.x, at.z, Clock.total_t])

func _pick_gift(g: Node) -> void:
	var hand = Game.world.get("hand") if Game.world else null
	if hand != null and is_instance_valid(hand) and hand.has_method("collect_gift"):
		var grants: StringName = g.get("grants_power") if g.get("grants_power") != null else &""
		if hand.collect_gift(g):
			_gifts += 1
			# the gift's power (Grip II on the first gift): grant it if the hand did not
			if grants != &"" and not Faith.has(grants):
				Faith.grant(grants)
				print("BOT granted %s from the gift (hand did not)" % grants)
			print("BOT picked up a gift at %.0fs" % Clock.total_t)
		return
	for m in ["collect", "pick_up", "on_picked", "take"]:
		if g.has_method(m):
			g.call(m)
			_gifts += 1
			return
	if g.has_method("on_lifted"):
		g.on_lifted()
		Events.hand_lifted_object.emit(g)
		_gifts += 1

func _idle_people() -> Array:
	var out: Array = []
	for p in Village.alive():
		if not is_instance_valid(p):
			continue
		if p.has_method("pickable") and not p.pickable():
			continue
		var js = p.get("job_site")
		if js != null and is_instance_valid(js) and not _wasted(js):
			continue
		if "stage" in p and p.stage != Person.Stage.ADULT and p.stage != Person.Stage.ELDER:
			continue
		out.append(p)
	return out

## Working a gather job whose store is full is wasted: re-place that person.
func _wasted(s) -> bool:
	var j: JobDef = s.get("job")
	if j == null or j.kind != JobDef.Kind.GATHER or j.outputs.is_empty():
		return false
	for k in j.outputs:
		if Village.store(k) < Village.store_cap - 2:
			return false
	return true

func _site_ok(s) -> bool:
	if not is_instance_valid(s) or s.is_queued_for_deletion():
		return false
	var j: JobDef = s.get("job")
	if j != null and j.needs_power != &"" and not Faith.has(j.needs_power):
		return false
	if Game.world.has_method("is_region_open") and not Game.world.is_region_open(Game.world.region_at(s.global_position)):
		return false
	return true

func _score(s, idle_n: int) -> float:
	var j: JobDef = s.get("job")
	var food := Village.food()
	var pop := maxi(Village.population(), 1)
	if s.get("state") == Site.State.PLOT or s.get("state") == Site.State.BUILDING:
		# builders fetch materials from the stores: worth it once some are in
		var b: BuildingDef = s.get("building")
		var ready := true
		if b != null and s.has_method("remaining"):
			for k in b.cost:
				if s.remaining(k) > 0 and Village.store(k) <= 0:
					ready = false
		return 6.5 if ready else 0.8
	if j == null:
		return 0.5
	var id := j.id
	var sc := 1.0
	if id in [&"gather_berries", &"hunt"]:
		sc = 6.0 if food < pop * 4 else 2.5
	elif id == &"tend_fire":
		sc = 5.0 if (Clock.is_night or Clock.phase_t > Clock.day_seconds * 0.7) else 1.5
	elif id == &"carry_log":
		sc = 7.0
	elif id in [&"collect_sticks", &"fell_tree"]:
		sc = 3.0 if Village.store(&"wood") < 12 else 1.0
	elif id == &"knap_flint":
		sc = 4.0 if Village.store(&"stone") < 20 else 0.5
	elif id == &"pray":
		sc = 2.0
	elif id == &"fetch_water":
		sc = 2.5 if Village.store(&"water") < pop * 3 else 1.0
	if s.group_needs() > 0 or j.min_people > 1:
		var need := maxi(j.min_people - s.workers.size(), 1)
		sc = 8.0 if idle_n >= need else 0.0      # prefer group jobs once we can fill them
	return sc

func _staff() -> void:
	var idle := _idle_people()
	if idle.is_empty():
		return
	var best = null
	var best_sc := 0.0
	for s in Village.sites:
		if not _site_ok(s) or not s.can_accept(1) or _wasted(s):
			continue
		var sc := _score(s, idle.size())
		if sc > best_sc:
			best_sc = sc
			best = s
	if best == null:
		return
	# one hand action: up to grip people (all a group needs if the grip allows)
	var j: JobDef = best.get("job")
	var n := 1
	if j != null and j.min_people > 1:
		n = maxi(j.min_people - best.workers.size(), 1)
	n = mini(n, maxi(Faith.grip, 1))
	n = mini(n, maxi(best.free_slots(), 1))
	var batch: Array = idle.slice(0, mini(n, idle.size()))
	for p in batch:
		p.on_lifted()
	Events.hand_lifted.emit(batch)
	for i in batch.size():
		var p = batch[i]
		if is_instance_valid(p):
			p.on_placed(best.slot_position(best.workers.size() + i), best)
			_placed += 1
	Events.hand_placed.emit(batch, best)
	_actions += 1

# ---------------------------------------------------------------- report

func _stores_text() -> String:
	var parts: Array = []
	for k in Village.stores:
		parts.append("%s=%d" % [k, Village.stores[k]])
	return ", ".join(parts) if not parts.is_empty() else "none"

func _report() -> void:
	if Clock.day == _last_day:
		return
	_last_day = Clock.day
	var fps := _fps_sum / maxf(_fps_n, 1)
	print("BOT day %d | pop %d | stores %s | faith %.0f (avail %.0f) | dreams %d %s | deaths %d | fps %.0f | regions %s | actions %d" % [
		Clock.day, Village.population(), _stores_text(), Faith.total, Faith.available(), _dreams.size(), str(_dreams),
		_deaths, fps, str(_regions), _actions])
	if Game.flags.has("verbose"):
		for p in Village.alive():
			var js = p.get("job_site")
			var st = p.get("state")
			print("BOT   %s: %s at (%.0f, %.0f) job %s | %s" % [p.get("given_name"), Person.STATE_NAMES[st] if st is int and st < Person.STATE_NAMES.size() else "?",
				p.global_position.x, p.global_position.z, js.job.id if js != null and is_instance_valid(js) and js.job else "-", p.status_text() if p.has_method("status_text") else ""])
			print("BOT     phase %s target %s timer %s" % [p.get("_phase"), str(p.get("_target")), str(p.get("_timer"))])

func _shot(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("BOT shot skipped (headless): %s" % path)
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var abs_path := path if path.is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var err := img.save_png(abs_path)
	print("BOT shot %s at %.0fs (%s)" % [abs_path, Clock.total_t, "ok" if err == OK else "error %d" % err])

func _finish() -> void:
	_quitting = true
	if Game.flags.has("overview") and DisplayServer.get_name() != "headless":
		# dev aid: a wide shot of the whole valley from the title camera
		var w = Game.world
		w.title_camera.far = 2000.0
		w.title_camera.current = true
		w.frame_camera(w.title_camera, Vector3(-20, 0, 20), 520.0, 0.35, 50.0)
		await get_tree().create_timer(0.3).timeout
		await _shot(str(Game.flags["overview"]))
	_report()
	var real_s := (Time.get_ticks_msec() - _start_ms) / 1000.0
	print("BOT summary: game %.0fs in %.1fs real | day %d | pop %d | faith %.0f | dreams %s | regions %s | powers %s | placed %d | gifts %d | deaths %d" % [
		Clock.total_t, real_s, Clock.day, Village.population(), Faith.total, str(_dreams), str(_regions), str(_bought), _placed, _gifts, _deaths])
	print("BOT audio: set %s | layers on %s | stingers %s | voices %d" % [Audio._set, str(Audio.layer_seen.keys()), str(Audio.stinger_log), Audio.voice_count])
	var ok := Game.world != null and Village.population() >= 0
	print("BOT %s" % ("PASS" if ok else "FAIL"))
	Engine.time_scale = 1.0
	get_tree().quit(0 if ok else 1)
