class_name Names extends RefCounted
## Era-appropriate given names. Era 1 are short tribal names; later eras get
## longer, softer ones. A syllable generator fills in when a list runs dry.

const LISTS: Dictionary = {
	1: {
		"f": ["Ona", "Ara", "Mira", "Suri", "Nell", "Asha", "Wen", "Ilka", "Yara", "Tova", "Rin", "Lema",
			"Kesi", "Ama", "Dela", "Fia", "Hana", "Isa", "Juna", "Lio", "Mae", "Nia", "Oda", "Pela", "Sela", "Tia", "Vala", "Zuri"],
		"m": ["Pim", "Teo", "Kesh", "Lun", "Bo", "Tam", "Ilo", "Daro", "Ruk", "Fen", "Gor", "Hal",
			"Jarn", "Kai", "Lok", "Mo", "Nuk", "Oren", "Pell", "Rafe", "Sten", "Tor", "Ulf", "Vek", "Wim", "Yan", "Zev", "Brin"],
	},
	2: {
		"f": ["Elin", "Maren", "Sigrun", "Alva", "Brenna", "Celia", "Edda", "Freya", "Greta", "Hilde", "Linnea", "Rosa"],
		"m": ["Aldo", "Bram", "Corin", "Davin", "Edric", "Galen", "Hector", "Ivo", "Joren", "Leif", "Matti", "Osric"],
	},
	3: {
		"f": ["Adela", "Beatrix", "Clara", "Dorothea", "Eleanor", "Isolde", "Lucia", "Margit", "Odile", "Viola"],
		"m": ["Anselm", "Benedikt", "Casimir", "Dominic", "Florian", "Konrad", "Lorenz", "Matthias", "Tobias", "Viktor"],
	},
	4: {
		"f": ["Ada", "Grace", "Hedy", "Katherine", "Mae", "Nina", "Sally", "Valentina", "Yuri", "Zoe"],
		"m": ["Alan", "Buzz", "Edwin", "Gene", "Ilan", "Kalpa", "Neil", "Otto", "Sergei", "Wernher"],
	},
}
const SYL_A: Array[String] = ["Ka", "Lo", "Ma", "Ne", "Ri", "Ta", "Vo", "Sa", "Mi", "Do", "Fe", "Gu", "Ha", "Ju"]
const SYL_B: Array[String] = ["ra", "na", "li", "ro", "ka", "ssa", "ven", "rin", "lo", "mi", "dra", "th"]

static func pick(sex: String, era: int, rng: RandomNumberGenerator, taken: Array = []) -> String:
	var lists: Dictionary = LISTS.get(clampi(era, 1, 4), LISTS[1])
	var pool: Array = lists.get(sex, lists["f"])
	var free: Array = pool.filter(func(n): return not taken.has(n))
	if not free.is_empty():
		return free[rng.randi() % free.size()]
	for _i in 20:
		var n: String = SYL_A[rng.randi() % SYL_A.size()] + SYL_B[rng.randi() % SYL_B.size()]
		if not taken.has(n):
			return n
	return pool[rng.randi() % pool.size()] + " " + str(rng.randi() % 100)

static func taken_names() -> Array:
	var out: Array = []
	for p in Village.alive():
		out.append(p.given_name)
	return out
