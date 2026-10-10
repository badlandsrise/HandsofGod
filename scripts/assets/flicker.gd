extends Node3D
## Campfire flicker: wobbles the flame meshes (children named Flame*) and the light.
## Cheap: one sin/noise per frame. Turn off with `burning = false` (fire died).

@export var burning: bool = true:
	set(v):
		burning = v
		visible = v

var _t: float = 0.0
var _base_energy: float = -1.0
var _flames: Array[Node3D] = []
var _light: OmniLight3D


func _ready() -> void:
	_t = randf() * 10.0
	for c in get_children():
		if c is OmniLight3D:
			_light = c
			_base_energy = _light.light_energy
		elif c is Node3D and String(c.name).begins_with("Flame"):
			_flames.append(c)


func _process(delta: float) -> void:
	if not burning:
		return
	_t += delta
	for i in _flames.size():
		var f := _flames[i]
		var k := 1.0 + 0.18 * sin(_t * (7.0 + i * 2.3) + i) + 0.08 * sin(_t * 17.0 + i * 3.1)
		f.scale = Vector3(1.0 + (1.0 - k) * 0.4, k, 1.0 + (1.0 - k) * 0.4)
	if _light:
		_light.light_energy = _base_energy * (0.85 + 0.15 * sin(_t * 9.0) * sin(_t * 5.3 + 1.0))
