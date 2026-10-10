extends Node
## Music with adaptive layers, stingers, ambience, one-shot SFX and villager voices.
##
## Music: each era has stems (base, rhythm, melody, colour, tense) as looping OGG files
## of identical length under res://assets/audio/music/<set>/<stem>.ogg. All stems play
## in sync; set_layer() fades a stem's volume. The director (_direct) decides the layers:
##   base     always
##   rhythm   daytime with people at work
##   melody   while the hand holds people
##   colour   quietly at night by the fire
##   tense    from threat_warned until threat_ended
## Stingers play over the top on region_opened, dream_done, power_unlocked and era change
## (era<N>_begin when that era has one, else era_complete).
## The title theme (title.ogg) plays on the title screen instead of the stems.

const STEMS: Array[StringName] = [&"base", &"rhythm", &"melody", &"colour", &"tense"]
const FADE := 1.5
const STINGERS := "res://assets/audio/music/stingers/%s.ogg"
const VOICE_DIR := "res://assets/audio/sfx/voice/"
const VOICE_GAP := 0.7            # seconds between any two voice lines
const VOICE_PERSON_GAP := 6.0     # seconds before the same person speaks again

var music_db: float = -6.0
var sfx_db: float = 0.0
var voice_db: float = -4.0
var _players: Dictionary = {}     # stem -> AudioStreamPlayer
var _target: Dictionary = {}      # stem -> 0..1
var _set: StringName = &""
var _title: AudioStreamPlayer
var _stinger: AudioStreamPlayer
var _rain: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _duck: float = 0.0            # seconds left of ducking under a stinger
var _title_gain: float = 1.0      # 0..1, fade_title() eases it down
var _title_fade: float = 0.0      # seconds of fade, 0 = not fading
var _threats: Dictionary = {}     # threat id -> true while warned / active
var _direct_t: float = 0.0
var _voice_t: float = 0.0
var _voice_last: Dictionary = {}  # person instance id -> time of last line
var _syllables: Array = []
var _hums: Dictionary = {}        # mood -> Array[AudioStream]
var _now: float = 0.0
var layer_log: Dictionary = {}    # stem -> last target (tests read this)
var layer_seen: Dictionary = {}   # stem -> true once it has been on (the bot reports it)
var stinger_log: Array[StringName] = []
var voice_count: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for s in STEMS:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		p.volume_db = -80.0
		add_child(p)
		_players[s] = p
		_target[s] = 0.0
	_title = _player()
	_stinger = _player()
	_rain = _player()
	_wind = _player()
	Events.threat_warned.connect(func(id, _at): _threats[id] = true)
	Events.threat_started.connect(func(id, _at): _threats[id] = true)
	Events.threat_ended.connect(func(id): _threats.erase(id))
	Events.region_opened.connect(func(_id): stinger(&"region_opened"))
	Events.dream_done.connect(func(_id): stinger(&"dream_done"))
	Events.power_unlocked.connect(func(_id): stinger(&"power_unlocked"))
	Events.era_changed.connect(_on_era)
	Events.hand_lifted.connect(_on_hand_lifted)
	Events.hand_placed.connect(_on_hand_placed)

func _player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Master"
	add_child(p)
	return p

# ---------------------------------------------------------------- music

## Starts an era's stems in sync (stops the title theme).
func play_set(set_name: StringName) -> void:
	if _title.playing:
		_title.stop()
	if set_name == _set:
		return
	_set = set_name
	for s in STEMS:
		var path := "res://assets/audio/music/%s/%s.ogg" % [set_name, s]
		var p: AudioStreamPlayer = _players[s]
		p.stop()
		p.stream = load(path) if ResourceLoader.exists(path) else null
	for s in STEMS:
		if _players[s].stream:
			_players[s].play()
	set_layer(&"base", 1.0)

## The title theme; the stems fall silent.
func play_title() -> void:
	_set = &""
	for s in STEMS:
		(_players[s] as AudioStreamPlayer).stop()
		_target[s] = 0.0
	_title_gain = 1.0
	_title_fade = 0.0
	if not _title.playing:
		var path := "res://assets/audio/music/title.ogg"
		_title.stream = load(path) if ResourceLoader.exists(path) else null
		_title.volume_db = music_db
		if _title.stream:
			_title.play()

## Fades the title theme out over `seconds` (the intro's own music takes over).
func fade_title(seconds: float = 1.5) -> void:
	_title_fade = maxf(seconds, 0.01)

## The stem set for an era: music/era<N>/ (era1, era2 ...), falling back to era1
## for an era whose music isn't made yet.
func era_set(era: int) -> StringName:
	var s := StringName("era%d" % era)
	return s if ResourceLoader.exists("res://assets/audio/music/%s/base.ogg" % s) else &"era1"

## The stinger for arriving in an era: stingers/era<N>_begin.ogg (in the new era's
## key and tempo, lined up with its stems' first bars), else the generic era_complete.
func era_stinger(era: int) -> StringName:
	var s := StringName("era%d_begin" % era)
	return s if ResourceLoader.exists(STINGERS % s) else &"era_complete"

func set_layer(stem: StringName, on: float) -> void:
	_target[stem] = clampf(on, 0.0, 1.0)
	layer_log[stem] = _target[stem]
	if _target[stem] > 0.0:
		layer_seen[stem] = true

func layer(stem: StringName) -> float:
	return _target.get(stem, 0.0)

func stinger(id: StringName) -> void:
	var path := STINGERS % id
	if not ResourceLoader.exists(path):
		return
	stinger_log.append(id)
	_stinger.stream = load(path)
	_stinger.volume_db = music_db + 2.0
	_stinger.play()
	_duck = minf(_stinger.stream.get_length(), 4.0) if _stinger.stream else 2.0

func _process(_d: float) -> void:
	var dt := Clock.real_delta
	_now += dt
	_duck = maxf(_duck - dt, 0.0)
	_direct_t -= dt
	if _direct_t <= 0.0:
		_direct_t = 0.5
		_direct()
	var duck := 0.45 if _duck > 0.0 else 1.0
	for s in STEMS:
		var p: AudioStreamPlayer = _players[s]
		var cur := db_to_linear(p.volume_db - music_db) if p.volume_db > -79.0 else 0.0
		cur = move_toward(cur, _target[s] * duck, dt / FADE)
		p.volume_db = linear_to_db(maxf(cur, 0.0001)) + music_db
	if _title_fade > 0.0 and _title.playing:
		_title_gain = move_toward(_title_gain, 0.0, dt / _title_fade)
		if _title_gain <= 0.0:
			_title.stop()
			_title_fade = 0.0
	_title.volume_db = music_db + linear_to_db(maxf(_title_gain, 0.0001))

## Decides the adaptive layers from the state of the world.
func _direct() -> void:
	var w = Game.world
	var playing := _set != &"" and Clock.running
	if not playing:
		_ambience(0.0, 0.0)
		return
	set_layer(&"base", 1.0)
	var working := 0
	for p in Village.people:
		if is_instance_valid(p) and p.get("state") == Person.S.WORK:
			working += 1
	set_layer(&"rhythm", 1.0 if (not Clock.is_night and working > 0) else 0.0)
	var holding := false
	if w != null and is_instance_valid(w) and w.get("hand") != null and is_instance_valid(w.hand):
		holding = not w.hand.held.is_empty()
	set_layer(&"melody", 1.0 if holding else 0.0)
	var fire_lit: bool = w != null and is_instance_valid(w) and w.has_method("fire_lit") and w.fire_lit()
	set_layer(&"colour", 0.6 if (Clock.is_night and fire_lit) else 0.0)
	set_layer(&"tense", 1.0 if not _threats.is_empty() else 0.0)
	var rain := 0.0
	if w != null and is_instance_valid(w) and w.get("look") != null:
		rain = float(w.look.rain_amount)
	_ambience(rain, 0.35)

func _ambience(rain: float, wind: float) -> void:
	_loop(_rain, "res://assets/audio/sfx/rain_loop.ogg", rain)
	_loop(_wind, "res://assets/audio/sfx/wind_loop.ogg", wind)

func _loop(p: AudioStreamPlayer, path: String, amount: float) -> void:
	if amount <= 0.02:
		if p.playing:
			p.stop()
		return
	if p.stream == null and ResourceLoader.exists(path):
		p.stream = load(path)
	if p.stream == null:
		return
	p.volume_db = linear_to_db(amount) + sfx_db - 8.0
	if not p.playing:
		p.play()

# ---------------------------------------------------------------- sfx

## One-shot sound, optionally positioned. `stream` may be an AudioStream or a res path.
func sfx(stream, at: Vector3 = Vector3.INF, pitch: float = 1.0, db: float = 0.0) -> void:
	var st: AudioStream = stream if stream is AudioStream else (load(stream) if ResourceLoader.exists(str(stream)) else null)
	if st == null:
		return
	var p: Node
	if at == Vector3.INF or Game.world == null:
		var a := AudioStreamPlayer.new(); a.stream = st; a.pitch_scale = pitch; a.volume_db = db + sfx_db
		p = a; add_child(a); a.play()
	else:
		var b := AudioStreamPlayer3D.new(); b.stream = st; b.pitch_scale = pitch; b.volume_db = db + sfx_db
		b.unit_size = 12.0
		p = b; Game.world.add_child(b); b.global_position = at; b.play()
	p.finished.connect(p.queue_free)

# ---------------------------------------------------------------- voices

## A short villager line: one or two babble syllables (or a hum for a mood), pitched
## per person (children higher, elders lower). Rate-limited so the village never
## chatters over itself. mood: &"" (babble), &"happy", &"cheer", &"worry", &"sad",
## &"question". Returns true if a line played.
func voice(person: Node, mood: StringName = &"") -> bool:
	if person == null or not is_instance_valid(person):
		return false
	if _now - _voice_t < VOICE_GAP:
		return false
	var key := person.get_instance_id()
	if _now - float(_voice_last.get(key, -100.0)) < VOICE_PERSON_GAP:
		return false
	_load_voices()
	var pitch := voice_pitch(person)
	var at: Vector3 = person.global_position if person is Node3D and person.is_inside_tree() else Vector3.INF
	if mood != &"" and _hums.has(mood):
		var list: Array = _hums[mood]
		sfx(list[randi() % list.size()], at, pitch, voice_db)
	elif not _syllables.is_empty():
		var n := 1 + randi() % 2
		for i in n:
			var st: AudioStream = _syllables[(hash(key) + randi()) % _syllables.size()]
			if i == 0:
				sfx(st, at, pitch * randf_range(0.97, 1.04), voice_db)
			else:
				get_tree().create_timer(0.2, true, false, true).timeout.connect(func(): sfx(st, at, pitch * randf_range(0.95, 1.05), voice_db))
	else:
		return false
	_voice_t = _now
	_voice_last[key] = _now
	voice_count += 1
	return true

## Each person keeps a voice of their own: a pitch from their uid and age.
func voice_pitch(person: Node) -> float:
	var uid := int(person.get("uid")) if person.get("uid") != null else person.get_instance_id()
	var base := 0.86 + float(posmod(hash(uid), 1000)) / 1000.0 * 0.32
	var stage = person.get("stage")
	if stage is int:
		match stage:
			0, 1: base *= 1.3      # baby, child
			3: base *= 0.88        # elder
	if str(person.get("sex")) == "f":
		base *= 1.12
	return base

func _load_voices() -> void:
	if not _syllables.is_empty() or not _hums.is_empty():
		return
	var d := DirAccess.open(VOICE_DIR)
	if d == null:
		return
	for f in d.get_files():
		var fname := f.trim_suffix(".import").trim_suffix(".remap")
		if not fname.ends_with(".ogg"):
			continue
		var path := VOICE_DIR + fname
		if not ResourceLoader.exists(path):
			continue
		if fname.begins_with("syl_"):
			if not _syllables.has(load(path)):
				_syllables.append(load(path))
		elif fname.begins_with("hum_"):
			var mood := StringName(fname.trim_prefix("hum_").get_slice("_", 0))
			if not _hums.has(mood):
				_hums[mood] = []
			var st = load(path)
			if not (_hums[mood] as Array).has(st):
				_hums[mood].append(st)

func _on_era(era: int) -> void:
	stinger(era_stinger(era))
	if _set != &"":
		play_set(era_set(era))

func _on_hand_lifted(people: Array) -> void:
	if people.is_empty():
		return
	if _set != &"":
		set_layer(&"melody", 1.0)   # at once; the director turns it off once the hand is empty
	var p = people[randi() % people.size()]
	var t := int(p.get("trust")) if p.get("trust") != null else 2
	voice(p, &"worry" if t <= 0 else (&"question" if t <= 1 else &"happy"))

func _on_hand_placed(people: Array, target) -> void:
	if people.is_empty():
		return
	voice(people[randi() % people.size()], &"" if target != null else &"question")
