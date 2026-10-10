extends Node3D
## A minimal persisted node for tests/unit/test_save.gd.

var uid: int = 0
var value: String = ""
var loaded_from: Dictionary = {}

func _ready() -> void:
	add_to_group("persist")

func save_state() -> Dictionary:
	return {"scene": "res://tests/unit/save_stub.gd", "uid": uid, "value": value, "pos": [position.x, position.y, position.z]}

func load_state(d: Dictionary) -> void:
	loaded_from = d
	uid = int(d.get("uid", 0))
	value = str(d.get("value", ""))
	var p: Array = d.get("pos", [0, 0, 0])
	position = Vector3(p[0], p[1], p[2])
