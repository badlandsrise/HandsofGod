class_name ThreatDef extends Resource

@export var id: StringName
@export var era: int = 1
@export var warning_seconds: float = 20.0
@export var only_at_night: bool = false
@export var season: int = -1                      # -1 any, else Clock.Season
@export var min_population: int = 3
@export var chance_per_day: float = 0.3
