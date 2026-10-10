extends "res://tests/guard_tree.gd"
## Generates data/capture/era1_mid.json, the bundled mid-Era-1 start state for
## the marketing capture mode (`--capture --era=1`): the Era 1 bot plays from
## the storm night until the Clearing has huts, a lit fire and about eight
## people, then the snapshot is written on a green morning (spring after the thaw,
## or summer).
## Run (a few minutes):
##   godot --headless --path . -s tests/capture/gen_era1_mid.gd [-- --seed=7 --out=data/capture/era1_mid.json]

const MIN_POP := 8
const MIN_HUTS := 2

var _frame := 0
var _world: Node = null
var _out := "data/capture/era1_mid.json"
var _last_log := -1

func _initialize() -> void:
	time_limit = 1500.0

func _process(_d: float) -> bool:
	if not guard():
		return true
	_frame += 1
	if _frame == 2:
		var game: Node = root.get_node("Game")
		if game.flags.has("out"):
			_out = str(game.flags["out"])
		if not game.flags.has("seed"):
			game.flags["seed"] = "7"
			game.rng.seed = 7
		seed(int(game.flags["seed"]))
		game.flags["test"] = true
		game.flags["quit-after-game"] = "100000"
		game.flags["speed"] = "6"
		_world = load("res://scenes/world/world.tscn").instantiate()
		root.add_child(_world)
		current_scene = _world
		return false
	if _world == null:
		return false
	var village: Node = root.get_node("Village")
	var clock: Node = root.get_node("Clock")
	if clock.day != _last_log:
		_last_log = clock.day
		print("gen: day %d era %d pop %d huts %d fire %s" % [clock.day, village.era, village.population(), village.count_buildings(&"hut"), _world.fire_lit()])
	if village.era != 1:
		printerr("FAIL gen: Era 1 ended before the Clearing reached %d people and %d huts" % [MIN_POP, MIN_HUTS])
		quit(1)
		return true
	var ready: bool = village.population() >= MIN_POP and village.count_buildings(&"hut") >= MIN_HUTS and _world.fire_lit()
	# a green (spring past the thaw, or summer) morning, so the bundled state
	# opens in daylight and matches the Era 2 and 3 views
	var green: bool = clock.season == 1 or (clock.season == 0 and clock.season_fraction() > 0.3)
	if ready and green and not clock.is_night and clock.phase_t > 6.0 and clock.phase_t < 20.0:
		var path: String = _out if _out.is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(_out)
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(JSON.stringify(root.get_node("Save").snapshot(), " "))
		f.close()
		print("gen: wrote %s (day %d, pop %d, huts %d)" % [_out, clock.day, village.population(), village.count_buildings(&"hut")])
		quit(0)
		return true
	return false
