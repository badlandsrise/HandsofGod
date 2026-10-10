class_name ThreatDef extends Resource

@export var id: StringName
@export var era: int = 1
@export var warning_seconds: float = 20.0
@export var only_at_night: bool = false
@export var season: int = -1                      # -1 any, else Clock.Season
@export var min_population: int = 3
@export var chance_per_day: float = 0.3
@export var duration_seconds: float = 90.0       # how long it lasts once it lands (Era 2 hazards)
@export var needs_region: StringName = &""       # only once this region is open
@export_multiline var warning_text: String = ""  # the alert when it is telegraphed
@export_multiline var start_text: String = ""    # the alert when it lands
