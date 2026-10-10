class_name NameGenerator

const VOWELS: String = "aeiou"
const VOWELS_Y: String = "aeiouy"
const H_TRIGGERS: String = "bdfjlmnpvx"

static var _excluded_words: Array[String] = []
static var _excluded_syllables: Array[String] = []

static var _pools: Dictionary = {}
static var _prefab_pools: Dictionary = {}
static var _recent_surnames: Dictionary = {}
static var _recent_first_names: Dictionary = {}


#Receives the pools read from the TSV sheets; called once while the data loads.
static func install_pools(excluded_words: Array[String], excluded_syllables: Array[String],
		pools: Dictionary, prefab_pools: Dictionary) -> void:
	_excluded_words = excluded_words
	_excluded_syllables = excluded_syllables
	_pools = pools
	_prefab_pools = prefab_pools


static func generate(location: LocationData) -> String:
	var region: String = _find_region(location)
	if region.is_empty():
		return "Unknown"
	return make_full_name(region)


static func get_regions() -> Array[String]:
	var result: Array[String] = []
	for k: String in _pools:
		result.append(k)
	return result


static func _find_region(location: LocationData) -> String:
	var cur: LocationData = location
	while cur:
		if _pools.has(cur.location_name):
			return cur.location_name
		cur = cur.parent
	return ""


#Post-processes one generated name part.
static func _finish_part(part: String, region: String) -> String:
	return _fix_trailing_apos(_cap_first(_post_process(part, region)))


#One finished name part: a prefab draw or a generated part run through the post steps.
static func _resolve_name(region: String, is_surname: bool, prefab_out: Array = []) -> String:
	var use_prefab: bool = _has_prefab(region, is_surname) and randf() < 0.5
	prefab_out.append(use_prefab)
	if use_prefab:
		return _pick_prefab(region, is_surname)
	var part: String = _generate_part(region, is_surname)
	if part.is_empty():
		return part
	part = _finish_part(part, region)
	if not is_surname and region == "Cyfrolaef" and part.length() <= 3:
		part = _cap_first(_reverse_string(part.to_lower()))
	return part


static func make_full_name(region: String) -> String:
	for _i: int in range(20):
		if region == "Aldurstein" and randf() < 0.5:
			var first_a: String = _generate_part(region, false)
			var first_b: String = _generate_part(region, false)
			if first_a.is_empty() or first_b.is_empty():
				continue
			first_a = _finish_part(first_a, region)
			first_b = _finish_part(first_b, region)
			if _is_excluded(first_a) or _is_excluded(first_b):
				continue
			while first_b.length() > 1 and (first_b.length() > 6 or not _is_v(first_b[first_b.length() - 1].to_lower(), false)):
				first_b = first_b.substr(0, first_b.length() - 1)
			return first_a + " " + first_b + "dottir"
		var first: String = _resolve_name(region, false)
		if first.is_empty() or first.length() < 2 or _is_excluded(first) or _has_digraph_conflict(first):
			continue
		var rec_first: Array = _recent_first_names.get(region, []) as Array
		if _first_name_conflicts(first, rec_first):
			var rerolled_f: String = _resolve_name(region, false)
			if not rerolled_f.is_empty() and not _is_excluded(rerolled_f) and not _has_digraph_conflict(rerolled_f):
				first = rerolled_f
		var pfab_flag: Array = []
		var last: String = _resolve_name(region, true, pfab_flag)
		var use_pfab_last: bool = pfab_flag[0]
		if last.is_empty() or last.length() < 2 or _is_excluded(last) or _has_digraph_conflict(last):
			continue
		if region == "Aerdis" and not use_pfab_last and last.length() < 4:
			continue
		if region == "Zukei":
			if last.length() < first.length():
				var tmp: String = first
				first = last
				last = tmp
			if first.replace("'", "").length() > 9:
				continue
		if region == "Cyfrolaef" and (_has_double_char_segment(first) or _has_double_char_segment(last)):
			continue
		var rec_last: Array = _recent_surnames.get(region, []) as Array
		if rec_last.has(last):
			var rerolled2: String = _resolve_name(region, true)
			if not rerolled2.is_empty() and not _is_excluded(rerolled2):
				last = rerolled2
		if not first.is_empty() and not last.is_empty():
			if first[first.length() - 1].to_lower() == last[last.length() - 1].to_lower():
				var rerolled: String = _resolve_name(region, true)
				if not rerolled.is_empty() and not _is_excluded(rerolled):
					last = rerolled
		if (first + " " + last).length() <= 64:
			if not _recent_surnames.has(region):
				_recent_surnames[region] = []
			var reg_rec: Array = _recent_surnames[region] as Array
			reg_rec.append(last)
			if reg_rec.size() > 5:
				reg_rec.pop_front()
			if not _recent_first_names.has(region):
				_recent_first_names[region] = []
			var reg_rec_f: Array = _recent_first_names[region] as Array
			reg_rec_f.append(first)
			if reg_rec_f.size() > 5:
				reg_rec_f.pop_front()
			return first + " " + last
	return "Unknown"


static func _generate_part(region: String, is_surname: bool) -> String:
	if not _pools.has(region):
		return ""
	var pool: Dictionary = _pools[region]
	var prefixes: Array = pool["prefix2" if is_surname else "prefix1"] as Array
	var mids: Array = pool["middlefix2" if is_surname else "middlefix1"] as Array
	var sufs: Array = pool["suffix2" if is_surname else "suffix1"] as Array

	if prefixes.is_empty():
		return ""

	var chances: Array[float] = _part_chances(region, is_surname)
	var mid_chance: float = chances[0]
	var suf_chance: float = chances[1]

	if region == "Zukei" and not is_surname and not mids.is_empty() and randf() < 0.15:
		return _zukei_mid_start(mids, sufs, suf_chance, region, is_surname)

	var prefix: String = _strip_markers(_pick(prefixes))

	var has_mid: bool = false
	var mid: String = ""
	if not mids.is_empty() and randf() < mid_chance:
		mid = _strip_markers(_pick(mids))
		has_mid = true

	if region == "Miliim":
		return _miliim_part(prefix, mid, has_mid, sufs, suf_chance, region, is_surname)

	var suf: String = _part_suffix(region, is_surname, has_mid, sufs, suf_chance)

	var assembled: String = prefix
	if not mid.is_empty():
		assembled = _join(assembled, mid, region, is_surname)
	if not suf.is_empty():
		assembled = _join(assembled, suf, region, is_surname)

	return _part_tail(assembled, region, is_surname, has_mid, suf, sufs, pool)


#The middlefix and suffix chances for one part; index 0 is the middlefix chance and 1 the suffix chance.
static func _part_chances(region: String, is_surname: bool) -> Array[float]:
	var mid_chance: float = 0.50 if is_surname else 0.25
	var suf_chance: float = 0.60 if is_surname else 0.75
	match region:
		"Buern":
			mid_chance = 0.75 if is_surname else 0.50
		"Vaernebo":
			if not is_surname:
				mid_chance = 0.0
		"Kathaya":
			if not is_surname:
				mid_chance = 0.05
				suf_chance = 0.25
	var out: Array[float] = [mid_chance, suf_chance]
	return out


#Zukei first names sometimes drop the prefix and open on a capitalised middlefix instead.
static func _zukei_mid_start(mids: Array, sufs: Array, suf_chance: float, region: String,
		is_surname: bool) -> String:
	var mid_start: String = _strip_markers(_pick(mids))
	mid_start = mid_start.substr(0, 1).to_upper() + mid_start.substr(1)
	if not sufs.is_empty() and randf() < suf_chance:
		return _join(mid_start, _strip_markers(_pick(sufs)), region, is_surname)
	return mid_start


#Miliim parts take a suffix only when no middlefix was drawn.
static func _miliim_part(prefix: String, mid: String, has_mid: bool, sufs: Array,
		suf_chance: float, region: String, is_surname: bool) -> String:
	var part: String = _join(prefix, mid, region, is_surname) if has_mid else prefix
	if not has_mid and not sufs.is_empty() and randf() < suf_chance:
		part = _join(part, _strip_markers(_pick(sufs)), region, is_surname)
	return part


#Draws the suffix, with the per region chance shifts and weighted picks.
static func _part_suffix(region: String, is_surname: bool, has_mid: bool, sufs: Array,
		suf_chance: float) -> String:
	var suf: String = ""
	if sufs.is_empty():
		return suf
	var actual_suf: float = suf_chance
	if region == "Buern" and not is_surname and not has_mid:
		actual_suf -= 0.25
	if region == "Kathaya" and not is_surname and has_mid:
		actual_suf = 0.05
	if randf() < actual_suf:
		if region == "Suorr":
			suf = _strip_markers(_pick_vowel_weighted(sufs))
		elif region == "Rossade":
			suf = _strip_markers(_pick_length_weighted(sufs))
		elif region == "Aldurstein" and not is_surname:
			suf = _strip_markers(_pick_target_ending_weighted(sufs, ["a", "y", "i"], 1.25))
		else:
			suf = _strip_markers(_pick(sufs))
	if region == "Kathaya" and is_surname and has_mid:
		suf = "i" if randf() < 0.5 else suf
	return suf


#The per region endings: the Kathaya tail, the Aldurstein trim and the Cyfrolaef two letter pad.
static func _part_tail(assembled: String, region: String, is_surname: bool, has_mid: bool,
		suf: String, sufs: Array, pool: Dictionary) -> String:
	if region == "Kathaya" and not is_surname and not has_mid and suf.is_empty():
		var lc: String = assembled[assembled.length() - 1].to_lower()
		if not _is_v(lc, false):
			var already_doubled: bool = assembled.length() >= 2 and assembled[assembled.length() - 2].to_lower() == lc
			if not already_doubled:
				assembled += lc
		else:
			var sm_arr: Array = pool["middlefix2"] as Array
			if not sm_arr.is_empty():
				assembled += _strip_markers(_pick(sm_arr))

	if region == "Aldurstein" and not is_surname and assembled.length() >= 4:
		var lchar: String = assembled[assembled.length() - 1].to_lower()
		if not _is_v(lchar, false) and lchar != "'":
			var prev: String = assembled[assembled.length() - 2].to_lower()
			if prev == "a" or prev == "y" or prev == "i":
				if randf() < 0.5:
					assembled = assembled.substr(0, assembled.length() - 1)

	if region == "Cyfrolaef" and assembled.length() == 2:
		if not _is_v(assembled[0].to_lower(), true) and not _is_v(assembled[1].to_lower(), true):
			if not sufs.is_empty():
				assembled = _join(assembled, _strip_markers(_pick(sufs)), region, is_surname)

	return assembled


static func _join(a: String, b: String, region: String, is_surname: bool) -> String:
	if b.is_empty(): return a
	if a.is_empty(): return b

	var lc: String = a[a.length() - 1].to_lower()
	var fc: String = b[0].to_lower()
	var use_y: bool = (region == "Cyfrolaef")
	var lv: bool = _is_v(lc, use_y)
	var fv: bool = _is_v(fc, use_y)

	match region:
		"Buern":
			if lv and fv:
				return (a + b.substr(1)) if randf() < 0.5 else (a.substr(0, a.length() - 1) + b)
			if is_surname and not lv and not fv:
				return a.substr(0, a.length() - 1) + b if randf() < 0.5 else a + b.substr(1)
		"Cyfrolaef":
			if lv and fv:
				return (a + b.substr(1)) if randf() < 0.5 else (a.substr(0, a.length() - 1) + b)
			if not lv and not fv and lc != fc:
				return a + "'" + b
		"Kathaya":
			if is_surname and a.length() <= 2 and not lv and not fv:
				return a + "-" + b
		"Zukei":
			if lv and fv and lc == fc:
				return a + b.substr(1)
		"Copari":
			if lv and fv and lc == fc:
				return a + b.substr(1)
			if lc == "e" and not fv:
				return a + "'" + b

	return a + b


static func _post_process(name: String, region: String) -> String:
	var r: String = name
	match region:
		"Miliim":    r = _pp_miliim(r)
		"Cyfrolaef": r = _pp_cyfrolaef(r)
		"Rossade":   r = _pp_rossade(r)
		"Zukei":     r = _collapse_doubles(r)
	r = _collapse_repeating(r)
	r = _fix_triple_same_consonant(r)
	if region != "Copari" and region != "Cyfrolaef":
		r = _fix_triple_vowels(r)
	if region != "Kathaya" and region != "Cyfrolaef":
		r = _fix_triple_consonants(r)
	return r


static func _pp_miliim(name: String) -> String:
	#Double isolated 'i' surrounded by consonants (like 'Aziir' 'Mhiina')
	var buf: String = ""
	for idx: int in range(name.length()):
		var c: String = name[idx]
		if c.to_lower() == "i":
			var has_prev: bool = idx > 0
			var has_next: bool = idx < name.length() - 1
			if has_prev and has_next:
				var pv: bool = _is_v(name[idx - 1].to_lower(), false)
				var nv: bool = _is_v(name[idx + 1].to_lower(), false)
				if not pv and not nv:
					buf += "ii"
					continue
		buf += c
	var result: String = buf

	#Insert h after trigger consonants before i
	buf = ""
	var i2: int = 0
	while i2 < result.length():
		var c2: String = result[i2]
		if i2 + 1 < result.length() and result[i2 + 1].to_lower() == "i":
			if H_TRIGGERS.contains(c2.to_lower()):
				buf += c2 + "h"
				i2 += 1
				continue
		buf += c2
		i2 += 1
	result = buf

	if not result.to_lower().contains("d") and not result.to_lower().contains("z") and randf() < 0.5:
		var cpos: Array[int] = []
		for ci: int in range(result.length()):
			if not _is_v(result[ci].to_lower(), false) and result[ci] != "'":
				cpos.append(ci)
		if not cpos.is_empty():
			var pos: int = cpos[randi() % cpos.size()]
			result = result.substr(0, pos) + ("d" if randf() < 0.5 else "z") + result.substr(pos + 1)

	return result


static func _pp_cyfrolaef(name: String) -> String:
	var vowel_count: int = 0
	for ch: String in name:
		if _is_v(ch.to_lower(), true):
			vowel_count += 1
	if vowel_count <= 1:
		return name
	var buf: String = ""
	for idx: int in range(name.length()):
		var c: String = name[idx]
		if _is_v(c.to_lower(), true) and randf() < 0.05:
			var pc: String = ""
			var nc: String = ""
			if idx > 0 and not _is_v(name[idx - 1].to_lower(), true):
				pc = name[idx - 1]
			if idx < name.length() - 1 and not _is_v(name[idx + 1].to_lower(), true):
				nc = name[idx + 1]
			var cands: Array[String] = []
			if not pc.is_empty(): cands.append(pc)
			if not nc.is_empty(): cands.append(nc)
			if not cands.is_empty():
				buf += cands[randi() % cands.size()]
				continue
		buf += c
	return buf


static func _pp_rossade(name: String) -> String:
	var seen: Dictionary = {}
	var result: String = ""
	for idx: int in range(name.length()):
		var c: String = name[idx]
		var cl: String = c.to_lower()
		if _is_v(cl, false):
			if seen.has(cl):
				var repl: String = _unused_vowel(seen)
				if not repl.is_empty():
					result += repl
					seen[repl] = true
				continue
			seen[cl] = true
		result += c
	return result


#Splices out the middle character wherever three in a row answer the predicate.
static func _collapse_triples(name: String, predicate: Callable) -> String:
	var result: String = name
	var i: int = 0
	while i < result.length() - 2:
		if predicate.call(result[i].to_lower(), result[i + 1].to_lower(), result[i + 2].to_lower()):
			result = result.substr(0, i + 1) + result.substr(i + 2)
		else:
			i += 1
	return result


static func _fix_triple_vowels(name: String) -> String:
	return _collapse_triples(name, _three_vowels)


static func _three_vowels(a: String, b: String, c: String) -> bool:
	return _is_v(a, false) and _is_v(b, false) and _is_v(c, false)


static func _fix_triple_consonants(name: String) -> String:
	return _collapse_triples(name, _three_consonants)


static func _three_consonants(a: String, b: String, c: String) -> bool:
	return _is_hard(a) and _is_hard(b) and _is_hard(c)


static func _fix_triple_same_consonant(name: String) -> String:
	return _collapse_triples(name, _three_same_consonants)


static func _three_same_consonants(a: String, b: String, c: String) -> bool:
	return a == b and a == c and _is_hard(a)


#True for a consonant that is not the apostrophe.
static func _is_hard(c: String) -> bool:
	return not _is_v(c, false) and c != "'"


static func _pick(pool: Array) -> String:
	return pool[randi() % pool.size()] as String if not pool.is_empty() else ""


#Weighted draw over pool; weight_fn returns the weight of one entry.
static func _pick_weighted(pool: Array, weight_fn: Callable) -> String:
	var total: float = 0.0
	var weights: Array[float] = []
	for item in pool:
		var w: float = weight_fn.call(item)
		weights.append(w)
		total += w
	var r: float = randf() * total
	var cum: float = 0.0
	for i: int in range(weights.size()):
		cum += weights[i]
		if r <= cum:
			return pool[i] as String
	return pool[-1] as String


static func _pick_vowel_weighted(pool: Array) -> String:
	return _pick_weighted(pool, func(item: Variant) -> float:
		var s: String = str(item)
		return 1.25 if (not s.is_empty() and _is_v(s[s.length() - 1].to_lower(), false)) else 1.0)


static func _pick_length_weighted(pool: Array) -> String:
	return _pick_weighted(pool, func(item: Variant) -> float:
		return maxf(1.0, float(str(item).length())))


static func _pick_target_ending_weighted(pool: Array, targets: Array[String], boost: float) -> String:
	return _pick_weighted(pool, func(item: Variant) -> float:
		var s: String = _strip_markers(str(item))
		var ends_in_target: bool = not s.is_empty() and targets.has(s[s.length() - 1].to_lower())
		return boost if ends_in_target else 1.0)


static func _first_name_conflicts(name: String, recent: Array) -> bool:
	var nl: String = name.to_lower()
	for entry in recent:
		var rl: String = (entry as String).to_lower()
		if nl == rl:
			return true
		var shorter: String = nl if nl.length() <= rl.length() else rl
		var longer: String = rl if nl.length() <= rl.length() else nl
		if shorter.length() >= 3 and longer.begins_with(shorter):
			return true
	return false


static func _has_digraph_conflict(name: String) -> bool:
	var l: String = name.to_lower()
	if l.contains("sh") and l.contains("ch"):
		return true
	if l.count("ck") >= 2:
		return true
	return false


static func _has_double_char_segment(name: String) -> bool:
	var segments: PackedStringArray = name.split("'")
	for seg in segments:
		if seg.length() == 2 and seg[0].to_lower() == seg[1].to_lower():
			return true
	return false


static func _has_prefab(region: String, is_surname: bool) -> bool:
	if not _prefab_pools.has(region):
		return false
	var key: String = "last" if is_surname else "first"
	return not (_prefab_pools[region][key] as Array).is_empty()


static func _pick_prefab(region: String, is_surname: bool) -> String:
	var key: String = "last" if is_surname else "first"
	var arr: Array = _prefab_pools[region][key] as Array
	return _pick(arr) if not arr.is_empty() else ""


static func _is_v(c: String, use_y: bool) -> bool:
	return (VOWELS_Y if use_y else VOWELS).contains(c)


static func _unused_vowel(seen: Dictionary) -> String:
	for v: String in ["a", "e", "i", "o", "u"]:
		if not seen.has(v):
			return v
	return ""


static func _strip_markers(s: String) -> String:
	var result: String = s
	while result.length() > 0 and result[result.length() - 1].is_valid_int():
		result = result.substr(0, result.length() - 1)
	return result


static func _cap_first(s: String) -> String:
	if s.is_empty(): return s
	return s[0].to_upper() + s.substr(1)


static func _is_excluded(name: String) -> bool:
	var lower: String = name.to_lower()
	for w: String in _excluded_words:
		if lower == w:
			return true
	for s: String in _excluded_syllables:
		if lower.contains(s):
			return true
	return false


static func _reverse_string(s: String) -> String:
	var result: String = ""
	for i: int in range(s.length() - 1, -1, -1):
		result += s[i]
	return result


static func _fix_trailing_apos(name: String) -> String:
	if name.length() >= 2 and name[name.length() - 2] == "'":
		return name.substr(0, name.length() - 2) + name[name.length() - 1]
	return name


static func _collapse_doubles(s: String) -> String:
	var result: String = ""
	var i: int = 0
	while i < s.length():
		result += s[i]
		if i + 1 < s.length() and s[i + 1].to_lower() == s[i].to_lower():
			i += 2
		else:
			i += 1
	return result


static func _collapse_repeating(s: String) -> String:
	var result: String = s
	var changed: bool = true
	while changed:
		changed = false
		var rl: String = result.to_lower()
		var max_len: int = result.length() >> 1
		for length: int in range(2, max_len + 1):
			var i: int = 0
			while i <= result.length() - length * 2:
				if rl.substr(i, length) == rl.substr(i + length, length):
					result = result.substr(0, i + length) + result.substr(i + length * 2)
					changed = true
					break
				i += 1
			if changed:
				break
	return result
