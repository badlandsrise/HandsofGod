class_name Options extends RefCounted
## Player options (DESIGN 11.5): stored in user://options.cfg, mirrored into
## Game.options for other systems to read, and applied to the audio, the
## window, the renderer and the camera.
##   Game.options keys: master, music, sfx, voices (0..1), ui_scale (0.8..1.5),
##   edge_pan, invert_rotate, subtitles, screen_shake (bools), camera_speed (0.5..2),
##   difficulty ("gentle" | "normal" | "harsh"), fullscreen, vsync, quality ("low" | "medium" | "high"),
##   skip_intros (bool: no studio splash on launch, no opening on New Game).

const PATH := "user://options.cfg"
const DIFFICULTIES := ["gentle", "normal", "harsh"]
const QUALITIES := ["low", "medium", "high"]
const DEFAULTS := {
	"master": 1.0, "music": 0.5, "sfx": 1.0, "voices": 0.63,
	"ui_scale": 1.0, "edge_pan": true, "invert_rotate": false, "subtitles": true,
	"screen_shake": true, "camera_speed": 1.0, "difficulty": "normal",
	"fullscreen": false, "vsync": true, "quality": "high", "skip_intros": false,
}

static var path: String = PATH          # tests point this elsewhere
static var loaded: bool = false

static func get_opt(key: String):
	return Game.options.get(key, DEFAULTS.get(key))

static func set_opt(key: String, value, apply_now: bool = true) -> void:
	Game.options[key] = value
	if apply_now:
		apply()

## Loads the file (missing keys take defaults) into Game.options and applies it.
static func load_options(do_apply: bool = true) -> void:
	loaded = true
	for k in DEFAULTS:
		if not Game.options.has(k):
			Game.options[k] = DEFAULTS[k]
	var cf := ConfigFile.new()
	if cf.load(path) == OK:
		for k in DEFAULTS:
			if cf.has_section_key("options", k):
				Game.options[k] = cf.get_value("options", k)
		# older files (the M1 title menu) kept a few values elsewhere
		if not cf.has_section_key("options", "ui_scale") and cf.has_section_key("ui", "scale"):
			Game.options["ui_scale"] = cf.get_value("ui", "scale")
		if not cf.has_section_key("options", "music") and cf.has_section_key("audio", "music_db"):
			Game.options["music"] = clampf(db_to_linear(float(cf.get_value("audio", "music_db"))), 0.0, 1.0)
	if not str(Game.options["difficulty"]) in DIFFICULTIES:
		Game.options["difficulty"] = "normal"
	if not str(Game.options["quality"]) in QUALITIES:
		Game.options["quality"] = "high"
	if do_apply:
		apply()

static func save_options() -> void:
	var cf := ConfigFile.new()
	for k in DEFAULTS:
		cf.set_value("options", k, Game.options.get(k, DEFAULTS[k]))
	cf.save(path)

static func vol_db(v: float) -> float:
	return linear_to_db(maxf(v, 0.0005))

## Pushes the options out to the systems that use them.
static func apply() -> void:
	var o := Game.options
	Audio.music_db = vol_db(float(o.get("music", 0.5)))
	Audio.sfx_db = vol_db(float(o.get("sfx", 1.0)))
	Audio.voice_db = vol_db(float(o.get("voices", 0.63)))
	var master := AudioServer.get_bus_index("Master")
	if master >= 0:
		AudioServer.set_bus_volume_db(master, vol_db(float(o.get("master", 1.0))))
		AudioServer.set_bus_mute(master, float(o.get("master", 1.0)) <= 0.001)
	var tree := Engine.get_main_loop() as SceneTree
	var headless := DisplayServer.get_name() == "headless"
	if tree != null and tree.root != null:
		tree.root.content_scale_factor = clampf(float(o.get("ui_scale", 1.0)), 0.8, 1.5)
		if not headless:
			_apply_quality(tree.root, str(o.get("quality", "high")))
	if not headless and not Game.testing():
		var want_fs := bool(o.get("fullscreen", false))
		var mode := DisplayServer.window_get_mode()
		var is_fs := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		if want_fs != is_fs:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if want_fs else DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(o.get("vsync", true)) else DisplayServer.VSYNC_DISABLED)
	if tree != null and not Game.testing():
		var cam := tree.get_first_node_in_group(&"camera_rig")
		if cam != null:
			if &"edge_pan" in cam and not headless:
				cam.set(&"edge_pan", bool(o.get("edge_pan", true)))
			if &"invert_rotate" in cam:
				cam.set(&"invert_rotate", bool(o.get("invert_rotate", false)))
			var cs := clampf(float(o.get("camera_speed", 1.0)), 0.5, 2.0)
			if &"pan_speed" in cam:
				if not cam.has_meta(&"base_pan"):
					cam.set_meta(&"base_pan", cam.get(&"pan_speed"))
					cam.set_meta(&"base_rot", cam.get(&"rot_speed"))
				cam.set(&"pan_speed", float(cam.get_meta(&"base_pan")) * cs)
				cam.set(&"rot_speed", float(cam.get_meta(&"base_rot")) * cs)

static func _apply_quality(vp: Viewport, q: String) -> void:
	match q:
		"low":
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.scaling_3d_scale = 0.75
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
		"medium":
			vp.msaa_3d = Viewport.MSAA_2X
			vp.scaling_3d_scale = 0.9
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
		_:
			vp.msaa_3d = Viewport.MSAA_2X
			vp.scaling_3d_scale = 1.0
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
