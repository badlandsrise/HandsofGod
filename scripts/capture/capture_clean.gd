extends Node
## [capture] Clean frames (key H, --hide-ui): hides every UI layer (HUD,
## notices, tooltips, cards, the goodbye's captions), the OS cursor, the 3D
## helpers that are UI in the world (progress bars, labels, the hand's cursor
## dot, target ring, drop ghosts and slot pips) and the empty "ghost" hand.
## With hand_visible (key G, --hand-visible) the glove stays in shot while
## everything else is clean. Runs last in the frame, after the HUD and the
## hand have drawn, and only touches what it hid, so turning it off restores
## the game exactly.

const HIDE_LAYER_BIT := 1 << 19          # VisualInstance3D layer 20: "UI in the world"
## The hand's helper visuals (scripts/hand/hand_visual.gd), by node name.
const HAND_HELPERS := ["CursorDot", "TargetRing", "Ghosts", "SitePips"]

var world: Node = null
var on: bool = false
var hand_visible: bool = false
var keep: Array = []                     # CanvasLayers that are capture's own (the F1 overlay)
var _hidden_layers: Array = []           # CanvasLayers this hid
var _hid_hand: bool = false
var _sweep_n: int = 0

func _init() -> void:
	name = "CaptureClean"
	process_priority = 1000
	process_mode = Node.PROCESS_MODE_ALWAYS

func set_on(v: bool) -> void:
	if v == on:
		return
	on = v
	if on:
		_sweep_n = 0
		_apply()
	else:
		_restore()

func set_hand_visible(v: bool) -> void:
	hand_visible = v
	if on:
		_apply()

func _process(_dt: float) -> void:
	if on:
		_apply()

func _apply() -> void:
	# ---- 2D: every CanvasLayer but our own
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var cl := n as CanvasLayer
		if cl == null or keep.has(cl) or not is_instance_valid(cl):
			continue
		if cl.visible:
			cl.visible = false
			if not _hidden_layers.has(cl):
				_hidden_layers.append(cl)
	# ---- the OS cursor
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	# ---- the hand: hidden, or in shot without its helpers
	var hand = world.get(&"hand") if world != null else null
	if hand != null and is_instance_valid(hand) and hand is Node3D:
		if hand_visible:
			if _hid_hand:
				hand.visible = true
				_hid_hand = false
			_mark_hand_helpers(hand)
		elif hand.visible:
			hand.visible = false
			_hid_hand = true
	# ---- 3D UI in the world (site bars, labels): moved to the hidden layer
	# a few times a second (new ones appear as work starts)
	_sweep_n -= 1
	if _sweep_n <= 0:
		_sweep_n = 10
		for s in Village.sites:
			if is_instance_valid(s):
				_mark_ui3d(s)
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		cam.cull_mask = cam.cull_mask & ~HIDE_LAYER_BIT

func _restore() -> void:
	for cl in _hidden_layers:
		if is_instance_valid(cl):
			cl.visible = true
	_hidden_layers.clear()
	var hand = world.get(&"hand") if world != null else null
	if _hid_hand and hand != null and is_instance_valid(hand):
		hand.visible = true
	_hid_hand = false
	if Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE     # the hand hides it again over the world
	for c in get_tree().root.find_children("*", "Camera3D", true, false):
		(c as Camera3D).cull_mask = (c as Camera3D).cull_mask | HIDE_LAYER_BIT

func _mark_hand_helpers(hand: Node) -> void:
	var vis := hand.get_node_or_null(^"Visual")
	if vis == null:
		return
	for n in HAND_HELPERS:
		var h := vis.get_node_or_null(NodePath(n))
		if h != null:
			_to_hidden_layer(h)
	for c in vis.get_children():
		if c is Label3D:
			_to_hidden_layer(c)

## Moves a site's progress bar and labels (not its building) to the hidden layer.
func _mark_ui3d(site: Node) -> void:
	var bar = site.get(&"bar")
	if bar is Node and is_instance_valid(bar):
		_to_hidden_layer(bar)
	for c in site.get_children():
		if c is Label3D or c is Sprite3D:
			_to_hidden_layer(c)

static func _to_hidden_layer(n: Node) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = HIDE_LAYER_BIT
	for c in n.get_children():
		_to_hidden_layer(c)

## [tests] true when nothing of the UI is on screen.
func ui_hidden() -> bool:
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if not keep.has(n) and (n as CanvasLayer).visible:
			return false
	return true
