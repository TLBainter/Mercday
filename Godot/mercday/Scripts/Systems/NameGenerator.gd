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
static var _loaded: bool = false


static func generate(location: LocationData) -> String:
	_ensure_loaded()
	var region: String = _find_region(location)
	if region.is_empty():
		return "Unknown"
	return _make_full_name(region)


static func generate_for_region(region: String) -> String:
	_ensure_loaded()
	return _make_full_name(region)


static func get_regions() -> Array[String]:
	_ensure_loaded()
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


static func _make_full_name(region: String) -> String:
	for _i: int in range(20):
		if region == "Aldurstein" and randf() < 0.5:
			var first_a: String = _generate_part(region, false)
			var first_b: String = _generate_part(region, false)
			if first_a.is_empty() or first_b.is_empty():
				continue
			first_a = _post_process(first_a, region)
			first_b = _post_process(first_b, region)
			first_a = _cap_first(first_a)
			first_b = _cap_first(first_b)
			first_a = _fix_trailing_apos(first_a)
			first_b = _fix_trailing_apos(first_b)
			if _is_excluded(first_a) or _is_excluded(first_b):
				continue
			while first_b.length() > 1 and (first_b.length() > 6 or not _is_v(first_b[first_b.length() - 1].to_lower(), false)):
				first_b = first_b.substr(0, first_b.length() - 1)
			return first_a + " " + first_b + "dottir"
		var use_pfab_first: bool = _has_prefab(region, false) and randf() < 0.5
		var first: String
		if use_pfab_first:
			first = _pick_prefab(region, false)
		else:
			first = _generate_part(region, false)
			if not first.is_empty():
				first = _post_process(first, region)
				first = _cap_first(first)
				first = _fix_trailing_apos(first)
				if region == "Cyfrolaef" and first.length() <= 3:
					first = _cap_first(_reverse_string(first.to_lower()))
		if first.is_empty() or first.length() < 2 or _is_excluded(first) or _has_digraph_conflict(first):
			continue
		var rec_first: Array = _recent_first_names.get(region, []) as Array
		if _first_name_conflicts(first, rec_first):
			var use_pfab_reroll_f: bool = _has_prefab(region, false) and randf() < 0.5
			var rerolled_f: String
			if use_pfab_reroll_f:
				rerolled_f = _pick_prefab(region, false)
			else:
				rerolled_f = _generate_part(region, false)
				if not rerolled_f.is_empty():
					rerolled_f = _post_process(rerolled_f, region)
					rerolled_f = _cap_first(rerolled_f)
					rerolled_f = _fix_trailing_apos(rerolled_f)
					if region == "Cyfrolaef" and rerolled_f.length() <= 3:
						rerolled_f = _cap_first(_reverse_string(rerolled_f.to_lower()))
			if not rerolled_f.is_empty() and not _is_excluded(rerolled_f) and not _has_digraph_conflict(rerolled_f):
				first = rerolled_f
		var use_pfab_last: bool = _has_prefab(region, true) and randf() < 0.5
		var last: String
		if use_pfab_last:
			last = _pick_prefab(region, true)
		else:
			last = _generate_part(region, true)
			if not last.is_empty():
				last = _post_process(last, region)
				last = _cap_first(last)
				last = _fix_trailing_apos(last)
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
			var use_pfab_reroll2: bool = _has_prefab(region, true) and randf() < 0.5
			var rerolled2: String
			if use_pfab_reroll2:
				rerolled2 = _pick_prefab(region, true)
			else:
				rerolled2 = _generate_part(region, true)
				if not rerolled2.is_empty():
					rerolled2 = _post_process(rerolled2, region)
					rerolled2 = _cap_first(rerolled2)
					rerolled2 = _fix_trailing_apos(rerolled2)
			if not rerolled2.is_empty() and not _is_excluded(rerolled2):
				last = rerolled2
		if not first.is_empty() and not last.is_empty():
			if first[first.length() - 1].to_lower() == last[last.length() - 1].to_lower():
				var use_pfab_reroll: bool = _has_prefab(region, true) and randf() < 0.5
				var rerolled: String
				if use_pfab_reroll:
					rerolled = _pick_prefab(region, true)
				else:
					rerolled = _generate_part(region, true)
					if not rerolled.is_empty():
						rerolled = _post_process(rerolled, region)
						rerolled = _cap_first(rerolled)
						rerolled = _fix_trailing_apos(rerolled)
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

	var mid_chance: float = 0.50 if is_surname else 0.25
	var suf_chance: float = 0.60 if is_surname else 0.75

	match region:
		"Buern":
			if not is_surname:
				mid_chance = 0.50
			else:
				mid_chance = 0.75
		"Vaernebo":
			if not is_surname:
				mid_chance = 0.0
		"Kathaya":
			if not is_surname:
				mid_chance = 0.05
				suf_chance = 0.25

	if region == "Zukei" and not is_surname and not mids.is_empty() and randf() < 0.15:
		var mid_start: String = _strip_markers(_pick(mids))
		mid_start = mid_start.substr(0, 1).to_upper() + mid_start.substr(1)
		if not sufs.is_empty() and randf() < suf_chance:
			return _join(mid_start, _strip_markers(_pick(sufs)), region, is_surname)
		return mid_start

	var prefix: String = _strip_markers(_pick(prefixes))

	var has_mid: bool = false
	var mid: String = ""
	if not mids.is_empty() and randf() < mid_chance:
		mid = _strip_markers(_pick(mids))
		has_mid = true

	if region == "Miliim":
		var part: String = _join(prefix, mid, region, is_surname) if has_mid else prefix
		if not has_mid and not sufs.is_empty() and randf() < suf_chance:
			part = _join(part, _strip_markers(_pick(sufs)), region, is_surname)
		return part

	var suf: String = ""
	if not sufs.is_empty():
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

	var assembled: String = prefix
	if not mid.is_empty():
		assembled = _join(assembled, mid, region, is_surname)
	if not suf.is_empty():
		assembled = _join(assembled, suf, region, is_surname)

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
		r = _fix_triple_vowels(r, false)
	if region != "Kathaya" and region != "Cyfrolaef":
		r = _fix_triple_consonants(r, false)
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


static func _fix_triple_vowels(name: String, use_y: bool) -> String:
	var result: String = name
	var i: int = 0
	while i < result.length() - 2:
		if _is_v(result[i].to_lower(), use_y) and _is_v(result[i+1].to_lower(), use_y) and _is_v(result[i+2].to_lower(), use_y):
			result = result.substr(0, i + 1) + result.substr(i + 2)
		else:
			i += 1
	return result


static func _fix_triple_consonants(name: String, use_y: bool) -> String:
	var result: String = name
	var i: int = 0
	while i < result.length() - 2:
		var a: String = result[i].to_lower()
		var b: String = result[i + 1].to_lower()
		var cc: String = result[i + 2].to_lower()
		if not _is_v(a, use_y) and a != "'" and not _is_v(b, use_y) and b != "'" and not _is_v(cc, use_y) and cc != "'":
			result = result.substr(0, i + 1) + result.substr(i + 2)
		else:
			i += 1
	return result


static func _fix_triple_same_consonant(name: String) -> String:
	var result: String = name
	var i: int = 0
	while i < result.length() - 2:
		var c: String = result[i].to_lower()
		if c == result[i + 1].to_lower() and c == result[i + 2].to_lower() and not _is_v(c, false) and c != "'":
			result = result.substr(0, i + 1) + result.substr(i + 2)
		else:
			i += 1
	return result


static func _pick(pool: Array) -> String:
	return pool[randi() % pool.size()] as String if not pool.is_empty() else ""


static func _pick_vowel_weighted(pool: Array) -> String:
	var total: float = 0.0
	var weights: Array[float] = []
	for item in pool:
		var s: String = str(item)
		var w: float = 1.25 if (not s.is_empty() and _is_v(s[s.length() - 1].to_lower(), false)) else 1.0
		weights.append(w)
		total += w
	var r: float = randf() * total
	var cum: float = 0.0
	for i: int in range(weights.size()):
		cum += weights[i]
		if r <= cum:
			return pool[i] as String
	return pool[-1] as String


static func _pick_length_weighted(pool: Array) -> String:
	var total: float = 0.0
	var weights: Array[float] = []
	for item in pool:
		var w: float = maxf(1.0, float(str(item).length()))
		weights.append(w)
		total += w
	var r: float = randf() * total
	var cum: float = 0.0
	for i: int in range(weights.size()):
		cum += weights[i]
		if r <= cum:
			return pool[i] as String
	return pool[-1] as String


static func _pick_target_ending_weighted(pool: Array, targets: Array[String], boost: float) -> String:
	var total: float = 0.0
	var weights: Array[float] = []
	for item in pool:
		var s: String = _strip_markers(str(item))
		var ends_in_target: bool = not s.is_empty() and targets.has(s[s.length() - 1].to_lower())
		var w: float = boost if ends_in_target else 1.0
		weights.append(w)
		total += w
	var r: float = randf() * total
	var cum: float = 0.0
	for i: int in range(weights.size()):
		cum += weights[i]
		if r <= cum:
			return pool[i] as String
	return pool[-1] as String


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


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_load_exclusions()
	_load_prefab_names()
	_load_names()


static func _load_exclusions() -> void:
	var file := FileAccess.open("res://TSVs/NameExclusions.txt", FileAccess.READ)
	if not file:
		push_error("NameGenerator: cannot open res://TSVs/NameExclusions.txt")
		return
	var section: String = ""
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if line == "[words]":
			section = "words"
		elif line == "[syllables]":
			section = "syllables"
		elif section == "words":
			_excluded_words.append(line.to_lower())
		elif section == "syllables":
			_excluded_syllables.append(line.to_lower())
	file.close()


static func _load_prefab_names() -> void:
	var file := FileAccess.open("res://TSVs/Names_Prefab.tsv", FileAccess.READ)
	if not file:
		push_error("NameGenerator: cannot open res://TSVs/Names_Prefab.tsv")
		return
	file.get_csv_line("\t")
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line("\t")
		if row.size() < 3:
			continue
		var region: String = row[0].strip_edges()
		if region.is_empty():
			continue
		if not _prefab_pools.has(region):
			_prefab_pools[region] = {"first": [], "last": []}
		var fn: String = row[1].strip_edges()
		var ln: String = row[2].strip_edges()
		if not fn.is_empty():
			(_prefab_pools[region]["first"] as Array).append(fn)
		if not ln.is_empty():
			(_prefab_pools[region]["last"] as Array).append(ln)
	file.close()


static func _load_names() -> void:
	var file := FileAccess.open("res://TSVs/Names_Gen.tsv", FileAccess.READ)
	if not file:
		push_error("NameGenerator: cannot open res://TSVs/Names.tsv")
		return
	file.get_csv_line("\t")
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line("\t")
		if row.size() < 7:
			continue
		var region: String = row[0].strip_edges()
		if region.is_empty():
			continue
		if not _pools.has(region):
			_pools[region] = {
				"prefix1": [], "middlefix1": [], "suffix1": [],
				"prefix2": [], "middlefix2": [], "suffix2": []
			}
		var pool: Dictionary = _pools[region]
		_add_to_pool(pool, "prefix1",    row[1])
		_add_to_pool(pool, "middlefix1", row[2])
		_add_to_pool(pool, "suffix1",    row[3])
		_add_to_pool(pool, "prefix2",    row[4])
		_add_to_pool(pool, "middlefix2", row[5])
		_add_to_pool(pool, "suffix2",    row[6])
	file.close()


static func _add_to_pool(pool: Dictionary, key: String, value: String) -> void:
	var v: String = value.strip_edges()
	if v.is_empty():
		return
	var arr: Array = pool[key] as Array
	arr.append(v)
