extends Node
## Music with adaptive layers, plus one-shot SFX.
## Music: each era has stems (base, rhythm, melody, colour) as looping OGG
## files of identical length under res://assets/audio/music/<set>/<stem>.ogg.
## All stems play in sync; set_layer() fades a stem's volume.

const STEMS: Array[StringName] = [&"base", &"rhythm", &"melody", &"colour", &"tense"]
const FADE := 1.5

var music_db: float = -6.0
var sfx_db: float = 0.0
var _players: Dictionary = {}     # stem -> AudioStreamPlayer
var _target: Dictionary = {}      # stem -> 0..1
var _set: StringName = &""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for s in STEMS:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		p.volume_db = -80.0
		add_child(p)
		_players[s] = p
		_target[s] = 0.0

func play_set(set_name: StringName) -> void:
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

func set_layer(stem: StringName, on: float) -> void:
	_target[stem] = clampf(on, 0.0, 1.0)

func _process(_d: float) -> void:
	var dt := Clock.real_delta
	for s in STEMS:
		var p: AudioStreamPlayer = _players[s]
		var cur := db_to_linear(p.volume_db) / db_to_linear(music_db) if p.volume_db > -79.0 else 0.0
		cur = move_toward(cur, _target[s], dt / FADE)
		p.volume_db = linear_to_db(maxf(cur, 0.0001)) + music_db

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
