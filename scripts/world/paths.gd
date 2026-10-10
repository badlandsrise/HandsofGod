class_name Paths extends Node
## Desire paths (world.paths): the village draws its own roads by living.
##
## Every footstep wears a 1 m grid over the land (`wear`, in metres walked
## over a cell). Wear fades slowly when unused. The terrain shader reads it as
## a texture (global hog_wear, refreshed every few seconds) and blends
##     grass -> worn grass (WORN) -> dirt track (TRACK) -> dirt road (ROAD)
## with a little blur and noise, so a path reads as a clean ribbon. Steps
## are drawn toward the most-worn cell beside them (people keep to the path),
## which caps a path's width and merges parallel trails. Nothing wears under
## buildings or fields (block_rect).
##
## It matters for play: people walk up to 20% faster on a road (speed_mult),
## and refine() bends a navmesh path onto worn ground nearby, so roads
## reinforce themselves instead of spreading into spaghetti.
##
## Era 3 hook: busiest_segments(n) lists the most-walked stretches of road and
## pave(segment) lays them in stone (paved cells never fade and are faster).
##
## Hooks used by people (scripts/person/person.gd):
##     world.paths.step(pos, metres, dir)   every walking step
##     world.paths.speed_mult(pos)          walking speed multiplier
##     world.paths.refine(path)             after asking the navmesh for a path

signal refreshed

## The worn grid covers the land people walk in Eras 1-3 (Clearing to Coast).
const RECT := Rect2i(-216, -168, 640, 640)
const W := 640
const CHUNK := 32
const CHUNKS := W / CHUNK
const CAP := 80.0                 # wear stops growing here
const WORN := 3.0                 # trampled grass
const TRACK := 12.0               # a dirt track
const ROAD := 32.0                # a dirt road
const TAU := 1800.0               # game seconds for unused wear to fall to 37% (~17 days)
const FLOOR_FADE := 0.002         # and a slow linear fade so faint trails vanish
const TEX_EVERY := 3.0            # real seconds between texture uploads
const DECAY_EVERY := 0.5          # game seconds between decay passes
const DECAY_CHUNKS := 6           # chunks faded per pass
const ROAD_SPEED := 0.2           # +20% on a dirt road
const PAVED_SPEED := 0.3          # +30% on paving
const PULL_RADIUS := 3            # cells: refine() looks this far either side of a path
const SEGMENT := 8                # metres per road segment (busiest_segments)

var wear := PackedFloat32Array()
var block := PackedByteArray()     # 1 = never wears (under a building or field)
var paved := PackedByteArray()     # 1 = paved (Era 3)
var _bytes := PackedByteArray()    # RG8 texture data: r = wear / CAP, g = paved
var _active := PackedByteArray()   # per chunk: has wear (needs fading)
var _img: Image
var tex: ImageTexture
var _tex_t := 0.0
var _tex_dirty := false
var _decay_t := 0.0
var _decay_i := 0
var _decay_last := PackedFloat32Array()   # per chunk: Clock.total_t of its last fade
var enabled := true
var steps := 0                     # footsteps recorded (tests, stats)
var world = null
var _pull: Array = []              # [Vector2i offset, distance] within PULL_RADIUS, nearest first

func _init() -> void:
	name = "Paths"
	wear.resize(W * W)
	block.resize(W * W)
	paved.resize(W * W)
	_bytes.resize(W * W * 2)
	_active.resize(CHUNKS * CHUNKS)
	_decay_last.resize(CHUNKS * CHUNKS)
	for j in range(-PULL_RADIUS, PULL_RADIUS + 1):
		for i in range(-PULL_RADIUS, PULL_RADIUS + 1):
			var d := Vector2(i, j).length()
			if d <= PULL_RADIUS + 0.01:
				_pull.append([Vector2i(i, j), d])
	_pull.sort_custom(func(a, b): return a[1] < b[1])

func setup(w) -> void:
	world = w
	_img = Image.create_from_data(W, W, false, Image.FORMAT_RG8, _bytes)
	tex = ImageTexture.create_from_image(_img)
	RenderingServer.global_shader_parameter_set(&"hog_wear", tex)
	RenderingServer.global_shader_parameter_set(&"hog_wear_rect", Vector4(RECT.position.x, RECT.position.y, W, W))

static func register_globals() -> void:
	if not ProjectSettings.has_setting("shader_globals/hog_wear"):
		var img := Image.create(4, 4, false, Image.FORMAT_RG8)
		RenderingServer.global_shader_parameter_add(&"hog_wear", RenderingServer.GLOBAL_VAR_TYPE_SAMPLER2D, ImageTexture.create_from_image(img))
	if not ProjectSettings.has_setting("shader_globals/hog_wear_rect"):
		RenderingServer.global_shader_parameter_add(&"hog_wear_rect", RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(RECT.position.x, RECT.position.y, W, W))

# ---------------------------------------------------------------- cells

func _cell(x: float, z: float) -> int:
	var i := floori(x) - RECT.position.x
	var j := floori(z) - RECT.position.y
	if i < 0 or j < 0 or i >= W or j >= W:
		return -1
	return j * W + i

func _put(k: int, v: float) -> void:
	wear[k] = v
	_bytes[k * 2] = int(clampf(v / CAP, 0.0, 1.0) * 255.0)
	_tex_dirty = true

func _touch(k: int) -> void:
	var c := ((k / W) / CHUNK) * CHUNKS + (k % W) / CHUNK
	if _active[c] == 0:
		_active[c] = 1
		_decay_last[c] = Clock.total_t

## Wear (metres walked) at x, z.
func wear_at(x: float, z: float) -> float:
	var k := _cell(x, z)
	return wear[k] if k >= 0 else 0.0

## 0 grass, 1 worn grass, 2 dirt track, 3 dirt road, 4 paved.
func level_at(x: float, z: float) -> int:
	var k := _cell(x, z)
	if k < 0:
		return 0
	if paved[k] == 1:
		return 4
	var v := wear[k]
	return 3 if v >= ROAD else (2 if v >= TRACK else (1 if v >= WORN else 0))

# ---------------------------------------------------------------- footsteps

## A person walked `metres` at `pos` heading `dir`. The step lands on the most
## worn cell beside it (up to 2 m either side), so trails stay narrow.
func step(pos: Vector3, metres: float = 0.1, dir: Vector3 = Vector3.ZERO) -> void:
	if not enabled or metres <= 0.0:
		return
	var k := _cell(pos.x, pos.z)
	if k < 0:
		return
	steps += 1
	var best := k
	var bw := wear[k] if block[k] == 0 else -1.0
	if dir.length_squared() > 0.0001:
		var side := Vector2(-dir.z, dir.x).normalized()
		for s in [1.0, -1.0, 2.0, -2.0]:
			var q := _cell(pos.x + side.x * s, pos.z + side.y * s)
			if q < 0 or block[q] == 1:
				continue
			# keep to the path: a clearly more worn cell beside us wins
			var need := bw * 1.2 + 1.0 + absf(s) * 0.5
			if wear[q] > need:
				best = q
				bw = wear[q]
	if block[best] == 1:
		return
	var v := wear[best]
	if v >= CAP:
		return
	_put(best, minf(v + metres, CAP))
	_touch(best)

## Walking speed multiplier at `pos`: up to +20% on a dirt road, +30% on paving.
func speed_mult(pos: Vector3) -> float:
	var k := _cell(pos.x, pos.z)
	if k < 0:
		return 1.0
	if paved[k] == 1:
		return 1.0 + PAVED_SPEED
	var v := wear[k]
	if v <= TRACK:
		return 1.0
	return 1.0 + ROAD_SPEED * clampf((v - TRACK) / (ROAD - TRACK), 0.0, 1.0)

# ---------------------------------------------------------------- the ground under things

## Nothing wears under a building or a field: clears and blocks its footprint.
func block_rect(center: Vector3, size: Vector2, yaw: float = 0.0, on: bool = true) -> void:
	var r := (size * 0.5).length() + 1.0
	var cs := cos(-yaw)
	var sn := sin(-yaw)
	for z in range(floori(center.z - r), ceili(center.z + r) + 1):
		for x in range(floori(center.x - r), ceili(center.x + r) + 1):
			var k := _cell(x, z)
			if k < 0:
				continue
			var dx := x + 0.5 - center.x
			var dz := z + 0.5 - center.z
			if absf(dx * cs - dz * sn) > size.x * 0.5 or absf(dx * sn + dz * cs) > size.y * 0.5:
				continue
			block[k] = 1 if on else 0
			if on and wear[k] > 0.0:
				_put(k, 0.0)

## Lays wear along a polyline (the old trails of a new valley, tests).
func stamp_line(points: Array, amount: float, width: float = 1.2) -> void:
	for i in points.size() - 1:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var n := maxi(int(a.distance_to(b) / 0.5), 1)
		for s in n + 1:
			var p := a.lerp(b, float(s) / n)
			for oz in range(-1, 2):
				for ox in range(-1, 2):
					var d := Vector2(ox, oz).length()
					if d > width:
						continue
					var k := _cell(p.x + ox, p.y + oz)
					if k < 0 or block[k] == 1:
						continue
					var v := amount * (1.0 - d / (width + 1.0))
					if v > wear[k]:
						_put(k, minf(v, CAP))
						_touch(k)

# ---------------------------------------------------------------- route preference

## Bends a navmesh path onto worn ground within PULL_RADIUS metres, where the
## detour stays on the navmesh. Paths reinforce themselves; the cost is a few
## grid reads per 3 m of path, once per destination.
func refine(path: PackedVector3Array) -> PackedVector3Array:
	if not enabled or path.size() < 2 or world == null or world.nav == null or not world.nav.is_inside_tree():
		return path
	var total := 0.0
	for i in path.size() - 1:
		total += Vector2(path[i + 1].x - path[i].x, path[i + 1].z - path[i].z).length()
	if total < 12.0:
		return path
	var map: RID = world.nav.get_world_3d().navigation_map
	var out := PackedVector3Array([path[0]])
	var walked := 0.0
	var changed := false
	for i in path.size() - 1:
		var a := path[i]
		var b := path[i + 1]
		var seg := Vector2(b.x - a.x, b.z - a.z).length()
		var n := int(seg / 3.0)
		for s in range(1, n + 1):
			var t := float(s) / float(n + 1)
			var p := a.lerp(b, t)
			var along := walked + seg * t
			if along < 4.0 or along > total - 4.0:
				continue
			var q := _pull_point(p)
			if q.is_finite() and _clear(map, out[out.size() - 1], q):
				out.append(q)
				changed = true
			else:
				out.append(p)
		walked += seg
		if i + 1 < path.size() - 1:
			out.append(b)        # keep the navmesh's corners (round buildings)
	out.append(path[path.size() - 1])
	return out if changed else path

func _pull_point(p: Vector3) -> Vector3:
	var k0 := _cell(p.x, p.z)
	if k0 < 0:
		return Vector3.INF
	if wear[k0] >= TRACK or paved[k0] == 1:
		return Vector3.INF          # already on the road
	var best := Vector2i(-9999, 0)
	var best_s := TRACK
	var bx := floori(p.x)
	var bz := floori(p.z)
	for e in _pull:
		var o: Vector2i = e[0]
		var k := _cell(bx + o.x, bz + o.y)
		if k < 0:
			continue
		var v := wear[k] + (CAP if paved[k] == 1 else 0.0)
		var sc := v - float(e[1]) * 4.0
		if v >= TRACK and sc > best_s:
			best_s = sc
			best = o
	if best.x == -9999:
		return Vector3.INF
	var x := bx + best.x + 0.5
	var z := bz + best.y + 0.5
	return Vector3(x, world.ground_y(x, z), z)

func _clear(map: RID, a: Vector3, b: Vector3) -> bool:
	for t in [0.33, 0.66, 1.0]:
		var m := a.lerp(b, t)
		var c := NavigationServer3D.map_get_closest_point(map, m)
		if Vector2(c.x - m.x, c.z - m.z).length() > 0.35:
			return false
	return true

# ---------------------------------------------------------------- Era 3: paving

## The `n` most-walked stretches of dirt road, busiest first. Each is a
## Dictionary: id (Vector2i), center (Vector3), wear (sum over its road
## cells), cells (count), a and b (its ends along the road), paved (bool).
func busiest_segments(n: int = 5, include_paved: bool = false) -> Array:
	var tiles := {}
	for c in CHUNKS * CHUNKS:
		if _active[c] == 0:
			continue
		var ci := c % CHUNKS
		var cj := c / CHUNKS
		for j in range(cj * CHUNK, (cj + 1) * CHUNK):
			for i in range(ci * CHUNK, (ci + 1) * CHUNK):
				var k := j * W + i
				if wear[k] < ROAD and paved[k] == 0:
					continue
				var id := Vector2i(i / SEGMENT, j / SEGMENT)
				var t: Array = tiles.get(id, [0.0, 0, Vector2.ZERO, [], 0])
				t[0] += wear[k] if paved[k] == 0 else CAP
				t[1] += 1
				t[2] += Vector2(i + 0.5, j + 0.5)
				(t[3] as Array).append(Vector2(i + 0.5, j + 0.5))
				t[4] += paved[k]
				tiles[id] = t
	var out: Array = []
	for id in tiles:
		var t: Array = tiles[id]
		var cells: int = t[1]
		if cells < 3:
			continue
		var is_paved: bool = t[4] * 2 > cells
		if is_paved and not include_paved:
			continue
		var c2: Vector2 = t[2] / cells
		# the road's direction through the tile: the farthest pair of cells
		var pts: Array = t[3]
		var a: Vector2 = pts[0]
		for p in pts:
			if (p as Vector2).distance_squared_to(c2) > a.distance_squared_to(c2):
				a = p
		var b: Vector2 = a
		for p in pts:
			if (p as Vector2).distance_squared_to(a) > b.distance_squared_to(a):
				b = p
		var off := Vector2(RECT.position)
		out.append({
			"id": id, "wear": float(t[0]), "cells": cells, "paved": is_paved,
			"center": _v3(c2 + off), "a": _v3(a + off), "b": _v3(b + off),
		})
	out.sort_custom(func(x, y): return x["wear"] > y["wear"])
	return out.slice(0, n)

func _v3(p: Vector2) -> Vector3:
	return Vector3(p.x, world.ground_y(p.x, p.y) if world != null else 0.0, p.y)

## Lays a segment (from busiest_segments) in stone: its worn cells, and a
## little either side so the paving reads as a street. Returns cells paved.
func pave(segment) -> int:
	var id: Vector2i = segment["id"] if segment is Dictionary else segment
	var n := 0
	for j in range(id.y * SEGMENT - 1, (id.y + 1) * SEGMENT + 1):
		for i in range(id.x * SEGMENT - 1, (id.x + 1) * SEGMENT + 1):
			if i < 0 or j < 0 or i >= W or j >= W:
				continue
			var k := j * W + i
			if block[k] == 1 or paved[k] == 1:
				continue
			if wear[k] >= TRACK or _near_road(i, j):
				paved[k] = 1
				_bytes[k * 2 + 1] = 255
				_put(k, maxf(wear[k], ROAD))
				_touch(k)
				n += 1
	if n > 0:
		_tex_dirty = true
	return n

func _near_road(i: int, j: int) -> bool:
	for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var ii: int = i + o.x
		var jj: int = j + o.y
		if ii >= 0 and jj >= 0 and ii < W and jj < W and wear[jj * W + ii] >= ROAD:
			return true
	return false

func paved_count() -> int:
	return paved.count(1)

# ---------------------------------------------------------------- upkeep

func _process(delta: float) -> void:
	var rd := Clock.real_delta if Clock.real_delta > 0.0 else delta
	_tex_t += rd
	if _tex_t >= TEX_EVERY:
		_tex_t = 0.0
		flush()
	if not Clock.running:
		return
	_decay_t += delta
	if _decay_t >= DECAY_EVERY:
		_decay_t = 0.0
		_fade_some(DECAY_CHUNKS)

## Uploads the wear texture now (normally every TEX_EVERY seconds).
func flush() -> void:
	if not _tex_dirty or tex == null:
		return
	_tex_dirty = false
	_img.set_data(W, W, false, Image.FORMAT_RG8, _bytes)
	tex.update(_img)
	refreshed.emit()

## Fades a few active chunks by the game time since they were last faded.
func _fade_some(count: int) -> void:
	var done := 0
	var guard := 0
	var total := CHUNKS * CHUNKS
	while done < count and guard < total:
		guard += 1
		_decay_i = (_decay_i + 1) % total
		if _active[_decay_i] == 0:
			continue
		done += 1
		_fade_chunk(_decay_i, Clock.total_t - _decay_last[_decay_i])
		_decay_last[_decay_i] = Clock.total_t

func _fade_chunk(c: int, dt: float) -> void:
	if dt <= 0.0:
		return
	var keep := exp(-dt / TAU)
	var lin := FLOOR_FADE * dt
	var ci := c % CHUNKS
	var cj := c / CHUNKS
	var any := false
	for j in range(cj * CHUNK, (cj + 1) * CHUNK):
		var row := j * W
		for i in range(ci * CHUNK, (ci + 1) * CHUNK):
			var k := row + i
			var v := wear[k]
			if v <= 0.0:
				continue
			if paved[k] == 1:
				any = true
				continue
			v = v * keep - lin
			if v < 0.05:
				v = 0.0
			else:
				any = true
			_put(k, v)
	if not any:
		_active[c] = 0

## Ages all the wear by `dt` game seconds at once (tests, fast-forward).
func fade_all(dt: float) -> void:
	for c in CHUNKS * CHUNKS:
		if _active[c] == 1:
			_fade_chunk(c, dt)
			_decay_last[c] = Clock.total_t

# ---------------------------------------------------------------- state

func clear() -> void:
	wear.fill(0.0)
	paved.fill(0)
	block.fill(0)
	_bytes.fill(0)
	_active.fill(0)
	_tex_dirty = true
	steps = 0

## The active chunks, quantised to a byte per cell and deflated.
func save_state() -> Dictionary:
	var chunks := {}
	for c in CHUNKS * CHUNKS:
		if _active[c] == 0:
			continue
		var raw := PackedByteArray()
		raw.resize(CHUNK * CHUNK * 2)
		var ci := c % CHUNKS
		var cj := c / CHUNKS
		var n := 0
		for j in range(cj * CHUNK, (cj + 1) * CHUNK):
			for i in range(ci * CHUNK, (ci + 1) * CHUNK):
				var k := j * W + i
				raw[n] = int(clampf(wear[k] / CAP, 0.0, 1.0) * 255.0 + 0.5)
				raw[n + CHUNK * CHUNK] = paved[k]
				n += 1
		chunks[str(c)] = Marshalls.raw_to_base64(raw.compress(FileAccess.COMPRESSION_DEFLATE))
	return {"v": 1, "chunk": CHUNK, "w": W, "chunks": chunks}

func load_state(d: Dictionary) -> void:
	var keep_block := block.duplicate()
	clear()
	block = keep_block
	if int(d.get("w", 0)) != W or int(d.get("chunk", 0)) != CHUNK:
		return
	var chunks: Dictionary = d.get("chunks", {})
	for key in chunks:
		var c := int(key)
		if c < 0 or c >= CHUNKS * CHUNKS:
			continue
		var raw: PackedByteArray = Marshalls.base64_to_raw(str(chunks[key])).decompress(CHUNK * CHUNK * 2, FileAccess.COMPRESSION_DEFLATE)
		if raw.size() != CHUNK * CHUNK * 2:
			continue
		var ci := c % CHUNKS
		var cj := c / CHUNKS
		var n := 0
		for j in range(cj * CHUNK, (cj + 1) * CHUNK):
			for i in range(ci * CHUNK, (ci + 1) * CHUNK):
				var k := j * W + i
				var v := raw[n] / 255.0 * CAP
				paved[k] = 1 if raw[n + CHUNK * CHUNK] == 1 else 0
				_bytes[k * 2 + 1] = 255 if paved[k] == 1 else 0
				if v > 0.0 and block[k] == 0:
					_put(k, v)
				n += 1
		_active[c] = 1
		_decay_last[c] = Clock.total_t
	_tex_dirty = true
	flush()
