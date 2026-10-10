extends Node
## Loads every data Resource under res://data once at startup.
## Look things up by id: Defs.job(&"gather_berries").

var jobs: Dictionary = {}
var buildings: Dictionary = {}
var powers: Dictionary = {}
var eras: Dictionary = {}
var dreams: Dictionary = {}
var threats: Dictionary = {}

func _ready() -> void:
	_load_dir("res://data/jobs", jobs)
	_load_dir("res://data/buildings", buildings)
	_load_dir("res://data/powers", powers)
	_load_dir("res://data/dreams", dreams)
	_load_dir("res://data/threats", threats)
	var era_list: Dictionary = {}
	_load_dir("res://data/eras", era_list)
	for e in era_list.values():
		eras[e.era] = e

func _load_dir(path: String, into: Dictionary) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	for f in d.get_files():
		var fn := f.trim_suffix(".remap")   # exported builds rename .tres
		if not fn.ends_with(".tres"):
			continue
		var r = load(path + "/" + fn)
		if r != null and "id" in r and r.id != &"":
			into[r.id] = r
		elif r != null and r is EraDef:
			into[StringName(str(r.era))] = r

func job(id: StringName) -> JobDef: return jobs.get(id)
func building(id: StringName) -> BuildingDef: return buildings.get(id)
func power(id: StringName) -> PowerDef: return powers.get(id)
func era(n: int) -> EraDef: return eras.get(n)
func dream(id: StringName) -> DreamDef: return dreams.get(id)
