class_name PowerDef extends Resource

@export var id: StringName
@export var title: String = ""
@export var era: int = 1
@export var cost: float = 10.0
@export var free: bool = false                    # granted by script (Grip II, first gift)
@export var requires: Array[StringName] = []
@export var grip: int = 0                         # sets hand grip to this if > 0
@export var strength: float = 0.0                 # sets hand strength to this if > 0
@export var gesture: bool = false                 # a hold-E power
@export var opens_region: StringName = &""
@export var opens_jobs: Array[StringName] = []
@export_multiline var what_it_does: String = ""
@export_multiline var what_it_opens: String = ""
