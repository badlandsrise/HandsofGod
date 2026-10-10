extends Node
## Faith is the one currency the hand spends. It is never drained.
## Also owns which powers are unlocked and the hand's grip and strength.

var total: float = 0.0            # earned over the whole game
var spent: float = 0.0
var unlocked: Dictionary = {}     # StringName -> true
var grip: int = 1
var strength: float = 2.0         # the hand starts able to lift a person or the storm branch

func available() -> float:
	return total - spent

func add(amount: float, at: Vector3 = Vector3.INF) -> void:
	if amount <= 0.0:
		return
	total += amount
	Events.faith_changed.emit(total)

func has(id: StringName) -> bool:
	return unlocked.has(id)

func can_buy(id: StringName) -> bool:
	var p := Defs.power(id)
	if p == null or has(id) or p.free:
		return false
	for r in p.requires:
		if not has(r):
			return false
	return p.era <= Village.era and available() >= p.cost

func buy(id: StringName) -> bool:
	if not can_buy(id):
		return false
	spent += Defs.power(id).cost
	_unlock(id)
	return true

## Script-granted powers (Grip II on the first gift).
func grant(id: StringName) -> void:
	if not has(id) and Defs.power(id) != null:
		_unlock(id)

func _unlock(id: StringName) -> void:
	var p := Defs.power(id)
	unlocked[id] = true
	if p.grip > grip:
		grip = p.grip
	if p.strength > strength:
		strength = p.strength
	Events.power_unlocked.emit(id)
	if p.opens_region != &"":
		Village.open_region(p.opens_region)

func save_state() -> Dictionary:
	return {"total": total, "spent": spent, "unlocked": unlocked.keys().map(func(k): return str(k))}

func load_state(d: Dictionary) -> void:
	total = d.get("total", 0.0); spent = d.get("spent", 0.0)
	unlocked.clear(); grip = 1; strength = 2.0
	for k in d.get("unlocked", []):
		var p := Defs.power(StringName(k))
		if p == null:
			continue
		unlocked[StringName(k)] = true
		grip = maxi(grip, p.grip); strength = maxf(strength, p.strength)
