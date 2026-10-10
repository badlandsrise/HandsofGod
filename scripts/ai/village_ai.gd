class_name VillageAI extends Node
## One node the world adds once per new game or load (add_child(VillageAI.new())).
## It owns the village-level AI: the onboarding beats, dreams, births and homes,
## wanderers, gifts, the rest of the era's progression (discoveries, family
## plots, festival), what the hand's gestures do, the era transition, and
## counting winters survived (Village.stats["winters_survived"]).

var onboarding: Onboarding
var dreams: Dreams
var births: Births
var wanderers: Wanderers
var gifts: Gifts
var progression: Progression
var hand_powers: HandPowers
var era_transition: EraTransition
var era2: VillageEra2
var era3: VillageEra3
var _last_season: int = -1

func _ready() -> void:
	name = "VillageAI"
	onboarding = Onboarding.new(); add_child(onboarding)
	dreams = Dreams.new(); dreams.name = "Dreams"; add_child(dreams)
	births = Births.new(); births.name = "Births"; add_child(births)
	wanderers = Wanderers.new(); wanderers.name = "Wanderers"; add_child(wanderers)
	gifts = Gifts.new(); gifts.name = "Gifts"; add_child(gifts)
	progression = Progression.new(); add_child(progression)
	hand_powers = HandPowers.new(); add_child(hand_powers)
	era_transition = EraTransition.new(); add_child(era_transition)
	era2 = VillageEra2.new(); add_child(era2)
	era3 = VillageEra3.new(); add_child(era3)
	_last_season = Clock.season
	Events.season_changed.connect(_on_season)

func _on_season(s: int) -> void:
	if not is_inside_tree():
		return          # an old game's AI, removed and waiting to be freed
	if _last_season == Clock.Season.WINTER and s == Clock.Season.SPRING:
		Village.stats["winters_survived"] = int(Village.stats.get("winters_survived", 0)) + 1
		Flags.remember("We lived through winter number %d." % int(Village.stats["winters_survived"]))
	_last_season = s
