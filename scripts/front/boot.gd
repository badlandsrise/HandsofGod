extends Node
## The launch scene (project main scene): the Badlandsrise studio splash while
## the world scene loads in the background, then the world, which opens on the
## title. Test and review runs (--test, --shots, --no-title) and players with
## Options "skip_intros" go straight to the world.

const WORLD := "res://scenes/world/world.tscn"

var splash: StudioSplash = null
var _layer: CanvasLayer
var _going: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not Options.loaded:
		Options.load_options()
	ResourceLoader.load_threaded_request(WORLD)
	var direct := Game.testing() or Game.flags.has("shots") or Game.flags.has("no-title") or bool(Options.get_opt("skip_intros"))
	if direct:
		_go_world.call_deferred()
		return
	_layer = CanvasLayer.new()
	_layer.layer = 50
	add_child(_layer)
	splash = StudioSplash.new()
	_layer.add_child(splash)
	splash.finished.connect(_on_splash_finished)

func _on_splash_finished() -> void:
	# let the black frame draw before the world builds behind it
	await get_tree().process_frame
	await get_tree().process_frame
	_go_world()

func _go_world() -> void:
	if _going:
		return
	_going = true
	var ps: PackedScene = ResourceLoader.load_threaded_get(WORLD) as PackedScene
	if ps == null:
		ps = load(WORLD)
	var w := ps.instantiate()
	var tree := get_tree()
	tree.root.add_child(w)
	tree.current_scene = w
	queue_free()
