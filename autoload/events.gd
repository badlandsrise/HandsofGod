extends Node
## Global event bus. Systems emit here instead of calling each other, so the
## hand, the people, dreams, tutorials, audio and the test bot stay decoupled.
## Payloads are plain nodes/values; never store a reference past the frame
## unless you also listen for the matching removal signal.

# hand
signal hand_lifted(people: Array)            # Array[Person]
signal hand_placed(people: Array, target)    # target: Site or null (ground)
signal hand_lifted_object(obj: Node3D)
signal hand_placed_object(obj: Node3D, at: Vector3)
signal hand_gesture(power_id: StringName, at: Vector3)   # hold-over powers

# people
signal person_born(p)
signal person_joined(p)          # wanderer arrived
signal person_died(p)
signal person_aged(p, stage: int)
signal person_need_low(p, need: StringName)

# work
signal job_started(site, people: Array)
signal job_completed(site)
signal group_job_failed(site)    # people wandered off before the group formed
signal resource_changed(kind: StringName, amount: int)
signal building_finished(site)

# progression
signal faith_changed(total: float)
signal power_unlocked(id: StringName)
signal dream_started(id: StringName)
signal dream_done(id: StringName)
signal region_opened(id: StringName)
signal era_changed(era: int)

# time
signal sim_tick(dt: float)       # 10 Hz, already scaled by game speed
signal day_started(day: int)
signal night_started(day: int)
signal season_changed(season: int)

# threats
signal threat_warned(id: StringName, at: Vector3)
signal threat_started(id: StringName, at: Vector3)
signal threat_ended(id: StringName)

# ui
signal toast(text: String)
signal alert(text: String, at: Vector3)
