class_name VillageAI extends Node
## One node the world adds once (add_child(VillageAI.new())). It owns the
## village-level AI: dreams, births and homes, wanderers, gifts, and counting
## winters survived (Village.stats["winters_survived"]).

var dreams: Dreams
var births: Births
var wanderers: Wanderers
var gifts: Gifts
var _last_season: int = -1

func _ready() -> void:
	name = "VillageAI"
	dreams = Dreams.new(); dreams.name = "Dreams"; add_child(dreams)
	births = Births.new(); births.name = "Births"; add_child(births)
	wanderers = Wanderers.new(); wanderers.name = "Wanderers"; add_child(wanderers)
	gifts = Gifts.new(); gifts.name = "Gifts"; add_child(gifts)
	_last_season = Clock.season
	Events.season_changed.connect(_on_season)

func _on_season(s: int) -> void:
	if _last_season == Clock.Season.WINTER and s == Clock.Season.SPRING:
		Village.stats["winters_survived"] = int(Village.stats.get("winters_survived", 0)) + 1
	_last_season = s
