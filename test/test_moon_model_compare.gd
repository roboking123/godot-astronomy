extends SceneTree
## Compares CalcMoon vs Meeus moon models against JPL Horizons data.
## Run: godot --headless -s test/test_moon_model_compare.gd

const OBSERVER_LAT: float = 29.0
const OBSERVER_LON: float = -81.0
const MOON_FILE: String = "res://test/cosinekitty/horizons_Moon.txt"


func _init() -> void:
	print("═══════════════════════════════════════════════════")
	print("  Moon Model Comparison: CalcMoon vs Meeus vs JPL")
	print("═══════════════════════════════════════════════════")

	var file: FileAccess = FileAccess.open(MOON_FILE, FileAccess.READ)
	if file == null:
		print("  ERROR: horizons_Moon.txt not found")
		quit(); return
	var content: String = file.get_as_text()
	file.close()

	var calc_ra_errs: Array[float] = []
	var meeus_ra_errs: Array[float] = []
	var calc_dec_errs: Array[float] = []
	var meeus_dec_errs: Array[float] = []
	var in_data: bool = false
	var sample_idx: int = 0

	for line: String in content.split("\n"):
		if line.begins_with("$$SOE"):
			in_data = true; continue
		if line.begins_with("$$EOE"):
			break
		if not in_data:
			continue
		var trimmed: String = line.strip_edges()
		if trimmed.is_empty():
			continue
		sample_idx += 1
		if sample_idx % 10 != 1:
			continue

		var parsed: Dictionary = _parse_line(trimmed)
		if parsed.is_empty():
			continue

		var time: AstroTime.Moment = AstroTime.make_time(
			parsed.year, parsed.month, parsed.day, parsed.hour, parsed.minute, 0.0)

		# CalcMoon
		var calc_j2000: Vector3 = AstroMoon.geo_moon(time).j2000
		var calc_rd: AstroCoords.RaDec = AstroCoords.vector2radec(calc_j2000)
		var calc_ra_deg: float = calc_rd.ra * 15.0

		# Meeus
		var meeus_j2000: Vector3 = AstroMoonMeeus.geo_moon(time).j2000
		var meeus_rd: AstroCoords.RaDec = AstroCoords.vector2radec(meeus_j2000)
		var meeus_ra_deg: float = meeus_rd.ra * 15.0

		# JPL reference
		var jpl_ra: float = parsed.ra_j2000
		var jpl_dec: float = parsed.dec_j2000

		# RA error (handle wrap)
		var c_ra_err: float = absf(calc_ra_deg - jpl_ra) * 60.0
		if c_ra_err > 180.0 * 60.0: c_ra_err = 360.0 * 60.0 - c_ra_err
		var m_ra_err: float = absf(meeus_ra_deg - jpl_ra) * 60.0
		if m_ra_err > 180.0 * 60.0: m_ra_err = 360.0 * 60.0 - m_ra_err

		var c_dec_err: float = absf(calc_rd.dec - jpl_dec) * 60.0
		var m_dec_err: float = absf(meeus_rd.dec - jpl_dec) * 60.0

		calc_ra_errs.append(c_ra_err)
		meeus_ra_errs.append(m_ra_err)
		calc_dec_errs.append(c_dec_err)
		meeus_dec_errs.append(m_dec_err)

	# Stats
	var n: int = calc_ra_errs.size()
	print("  Samples: %d (1900-2100, every 100 days)" % n)
	print("")
	print("  ┌──────────────┬────────────────┬────────────────┐")
	print("  │              │   CalcMoon     │    Meeus       │")
	print("  ├──────────────┼────────────────┼────────────────┤")
	print("  │ Max RA err   │ %10.3f'    │ %10.3f'    │" % [_max(calc_ra_errs), _max(meeus_ra_errs)])
	print("  │ Avg RA err   │ %10.3f'    │ %10.3f'    │" % [_avg(calc_ra_errs), _avg(meeus_ra_errs)])
	print("  │ Max Dec err  │ %10.3f'    │ %10.3f'    │" % [_max(calc_dec_errs), _max(meeus_dec_errs)])
	print("  │ Avg Dec err  │ %10.3f'    │ %10.3f'    │" % [_avg(calc_dec_errs), _avg(meeus_dec_errs)])
	print("  └──────────────┴────────────────┴────────────────┘")

	var meeus_pass_1: int = 0
	var meeus_pass_5: int = 0
	for i: int in n:
		if meeus_ra_errs[i] < 1.0 and meeus_dec_errs[i] < 1.0:
			meeus_pass_1 += 1
		if meeus_ra_errs[i] < 5.0 and meeus_dec_errs[i] < 5.0:
			meeus_pass_5 += 1

	print("")
	print("  Meeus < 1 arcmin: %d/%d (%.1f%%)" % [meeus_pass_1, n, 100.0 * meeus_pass_1 / n])
	print("  Meeus < 5 arcmin: %d/%d (%.1f%%)" % [meeus_pass_5, n, 100.0 * meeus_pass_5 / n])
	print("═══════════════════════════════════════════════════")
	quit()


func _max(arr: Array[float]) -> float:
	var m: float = 0.0
	for v: float in arr:
		m = maxf(m, v)
	return m

func _avg(arr: Array[float]) -> float:
	var s: float = 0.0
	for v: float in arr:
		s += v
	return s / arr.size()

func _parse_line(line: String) -> Dictionary:
	var date_str: String = line.substr(0, 17).strip_edges()
	var parts: PackedStringArray = date_str.split(" ")
	if parts.size() < 2: return {}
	var date_fields: PackedStringArray = parts[0].split("-")
	if date_fields.size() < 3: return {}
	var month: int = _month(date_fields[1])
	if month == 0: return {}
	var time_fields: PackedStringArray = parts[1].split(":")
	var nums: Array[float] = []
	var regex: RegEx = RegEx.new()
	regex.compile("-?\\d+\\.\\d+")
	for m: RegExMatch in regex.search_all(line.substr(17)):
		nums.append(float(m.get_string()))
	if nums.size() < 6: return {}
	return {
		"year": int(date_fields[0]), "month": month, "day": int(date_fields[2]),
		"hour": int(time_fields[0]),
		"minute": int(time_fields[1]) if time_fields.size() > 1 else 0,
		"ra_j2000": nums[0], "dec_j2000": nums[1],
	}

func _month(name: String) -> int:
	match name:
		"Jan": return 1
		"Feb": return 2
		"Mar": return 3
		"Apr": return 4
		"May": return 5
		"Jun": return 6
		"Jul": return 7
		"Aug": return 8
		"Sep": return 9
		"Oct": return 10
		"Nov": return 11
		"Dec": return 12
	return 0
