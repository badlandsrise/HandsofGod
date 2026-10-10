class_name EraDef extends Resource

@export var era: int = 1
@export var title: String = ""
@export var target_minutes: float = 45.0
@export var population_band: Vector2i = Vector2i(12, 20)
@export var faith_target: float = 150.0
@export var dreams: Array[StringName] = []        # DreamDef ids, in order; the last is the gate
@export var palette: Dictionary = {}              # name -> Color, fed to the global shader params
@export var music: StringName = &""
@export var day_seconds: float = 75.0
@export var night_seconds: float = 30.0
@export var season_seconds: float = 240.0
