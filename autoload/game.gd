extends Node
## Top-level glue: input actions, the world reference, command-line flags,
## RNG, and starting a new game or loading one.

var world: Node3D = null           # scripts/world/world.gd sets itself here
var rng := RandomNumberGenerator.new()
var flags: Dictionary = {}          # from user args after "--": --test, --shot=..., --seed=N
var options: Dictionary = {"edge_pan": true, "ui_scale": 1.0}   # player options (title menu writes, camera/HUD read)

const ACTIONS := {
	&"hand_lift": [MOUSE_BUTTON_LEFT],
	&"hand_place_idle": [MOUSE_BUTTON_RIGHT],
	&"hand_add": [KEY_SHIFT],
	&"hand_gesture": [KEY_E],
	&"hand_call": [KEY_C],             # call every idle person to the hand (Village.call_idle)
	&"cam_pan": [MOUSE_BUTTON_MIDDLE],
	&"cam_left": [KEY_A, KEY_LEFT], &"cam_right": [KEY_D, KEY_RIGHT],
	&"cam_up": [KEY_W, KEY_UP], &"cam_down": [KEY_S, KEY_DOWN],
	&"cam_rot_left": [KEY_Q], &"cam_rot_right": [KEY_R],
	&"pause": [KEY_SPACE], &"speed_1": [KEY_1], &"speed_2": [KEY_2], &"speed_3": [KEY_3],
	&"labels": [KEY_TAB], &"book": [KEY_F1], &"menu": [KEY_ESCAPE],
	&"quicksave": [KEY_F5], &"quickload": [KEY_F9],
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_input()
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		flags[kv[0]] = kv[1] if kv.size() > 1 else true
	if flags.has("seed"):
		rng.seed = int(flags["seed"])
	else:
		rng.randomize()

func _register_input() -> void:
	for act in ACTIONS:
		if not InputMap.has_action(act):
			InputMap.add_action(act)
		for code in ACTIONS[act]:
			var ev: InputEvent
			if code is int and code <= MOUSE_BUTTON_XBUTTON2 and act in [&"hand_lift", &"hand_place_idle", &"cam_pan"]:
				ev = InputEventMouseButton.new(); ev.button_index = code
			else:
				ev = InputEventKey.new(); ev.physical_keycode = code
			InputMap.action_add_event(act, ev)

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed(&"pause"): Clock.toggle_pause()
	elif e.is_action_pressed(&"speed_1"): Clock.set_speed(1)
	elif e.is_action_pressed(&"speed_2"): Clock.set_speed(2)
	elif e.is_action_pressed(&"speed_3"): Clock.set_speed(3)
	elif e.is_action_pressed(&"quicksave"): Save.write("quick")
	elif e.is_action_pressed(&"quickload"): Save.load_slot("quick")
	elif e.is_action_pressed(&"hand_call"): call_idle_to_hand()

## Calls every idle person to where the hand points (C, or the HUD button).
func call_idle_to_hand() -> int:
	if world == null or not is_instance_valid(world) or not Clock.running:
		return 0
	var h = world.get("hand")
	var at: Vector3 = h.get("ground") if h != null and is_instance_valid(h) and h.get("ground") is Vector3 else Vector3.INF
	if not at.is_finite():
		return 0
	if world.has_method("walkable_point"):
		at = world.walkable_point(at)
	return Village.call_idle(at)

func testing() -> bool:
	return flags.has("test")
