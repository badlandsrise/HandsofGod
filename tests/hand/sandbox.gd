extends "res://tests/hand/mock_world.gd"
## Hand sandbox: flat ground, 6 mock people, a 3-slot mock group job, the
## camera rig, the hand and the HUD. Play it to try the hand:
##   godot --path . tests/hand/sandbox.tscn
## Screenshot (the hand holding 2 over the site, ghosts and pips showing):
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver vulkan --path . tests/hand/sandbox.tscn -- --shot=res://tests/hand/sandbox.png

const MockPerson := preload("res://tests/hand/mock_person.gd")
const MockSite := preload("res://tests/hand/mock_site.gd")
const MockGift := preload("res://tests/hand/mock_gift.gd")
const HandScene := preload("res://scenes/hand/hand.tscn")
const HudScene := preload("res://scenes/ui/hud.tscn")
const RigScene := preload("res://scenes/world/camera_rig.tscn")
const NAMES := ["Ama", "Bo", "Cira", "Dov", "Esi", "Fen"]
const COLOURS := [Color(0.85, 0.45, 0.3), Color(0.35, 0.55, 0.8), Color(0.55, 0.7, 0.35),
	Color(0.8, 0.7, 0.3), Color(0.65, 0.4, 0.7), Color(0.4, 0.7, 0.7)]

# `hand` is world.gd's member (a Hand here).
var site: Site
var rig: CameraRig
var _frames: int = 0
var _shot: String = ""

func _ready() -> void:
	_shot = str(Game.flags.get("shot", ""))
	_env()
	rig = RigScene.instantiate()
	add_child(rig)
	rig.snap_to(Vector3(-0.5, 0, 0.5), float(Game.flags.get("dist", 20.0)))
	_powers()
	site = MockSite.new()
	add_child(site)
	site.global_position = Vector3(2.5, 0, -1.0)
	for i in 6:
		var p: Person = MockPerson.new()
		p.given_name = NAMES[i]
		p.colour = COLOURS[i]
		p.trust = 1 + i % 4
		add_child(p)
		p.global_position = Vector3(-6.0 + float(i % 3) * 1.4, 0, 2.5 + float(i / 3) * 1.6)
	var g: Node3D = MockGift.new()
	add_child(g)
	var gm := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.25
	sm.height = 0.5
	gm.mesh = sm
	gm.position.y = 0.25
	g.add_child(gm)
	g.global_position = Vector3(-4, 0, -4)
	hand = HandScene.instantiate()
	add_child(hand)
	add_child(HudScene.instantiate())
	Village.stores = {&"berries": 9, &"wood": 6}
	Faith.grip = 5
	Faith.strength = 4.0
	Faith.grant(&"grip2")
	Faith.add(14.0)
	Clock.running = true
	Events.dream_started.emit(&"shelter")
	if _shot != "":
		hand.input_enabled = false
		rig.input_enabled = false
		hand.try_lift(Village.people[0])
		hand.try_lift(Village.people[1])
		hand.aim_override = site.global_position + Vector3(0, 0, 0.3)
		Events.alert.emit("Dov is hungry", Village.people[3].global_position)

func _process(_d: float) -> void:
	if _shot == "":
		return
	_frames += 1
	if _frames == 50:
		var img := get_viewport().get_texture().get_image()
		img.save_png(_shot)
		print("saved ", _shot)
		get_tree().quit()

func _env() -> void:
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.48, 0.62, 0.33)
	ground.material_override = gm
	add_child(ground)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-55), deg_to_rad(35), 0)
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.shadow_enabled = true
	add_child(sun)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.75, 0.86)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.72, 0.68)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	we.environment = env
	add_child(we)

func _powers() -> void:
	var specs := [
		[&"grip2", "Grip II", 10.0, true, 2, 0.0, false, "Lift 2 people; unlocks the scoop gesture", "Log hauling and the hunt"],
		[&"strength1", "Strength I", 25.0, false, 0, 4.0, false, "Lift weight 4 (fallen logs)", "The western meadow"],
		[&"warmth", "Warmth", 12.0, false, 0, 0.0, true, "Hold over people or a fire to warm them", "Survive the first winter"],
		[&"blessing", "Blessing", 40.0, false, 0, 0.0, true, "People you set down work 2x for 30 s", "Racing a deadline"],
	]
	for s in specs:
		if Defs.power(s[0]) != null:
			continue
		var d := PowerDef.new()
		d.id = s[0]; d.title = s[1]; d.cost = s[2]; d.free = s[3]; d.grip = s[4]
		d.strength = s[5]; d.gesture = s[6]; d.what_it_does = s[7]; d.what_it_opens = s[8]
		Defs.powers[d.id] = d
	if Defs.dream(&"shelter") == null:
		var dr := DreamDef.new()
		dr.id = &"shelter"
		dr.text = "A shelter of our own"
		dr.needs_buildings = {&"hut": 1}
		dr.needs_population = 6
		Defs.dreams[dr.id] = dr
