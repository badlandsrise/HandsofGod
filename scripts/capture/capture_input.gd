extends Node
## [capture] The capture keys. Added as the root's last child, so it sees key
## events before the HUD, the hand and the goodbye; keys it uses are marked
## handled, every other key goes on to the game.

var director: Node = null

func _input(e: InputEvent) -> void:
	if director == null or not is_instance_valid(director):
		return
	if e is InputEventKey and director.handle_key(e):
		get_viewport().set_input_as_handled()
