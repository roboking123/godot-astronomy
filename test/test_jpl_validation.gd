extends SceneTree
## JPL Horizons validation — compares our calculations against JPL ephemeris data
## Run: godot --headless -s test/test_jpl_validation.gd

const OBSERVER_LAT: float = 29.0
const OBSERVER_LON: float = -81.0  # 279°E = -81°W
const OBSERVER_HEIGHT: float = 10.0  # meters

const BODY_FILES: Dictionary = {
	"Sun": "res://test/horizons/Sun.txt",
	"Moon": "res://test/horizons/Moon.txt",
	"Mercury": "res://test/horizons/Mercury.txt",
	"Venus": "res://test/horizons/Venus.txt",
	"Mars": "res://test/horizons/Mars.txt",
	"Jupiter": "res://test/horizons/Jupiter.txt",
	"Saturn": "res://test/horizons/Saturn.txt",
	"Uranus": "res://test/horizons/Uranus.txt",
	"Neptune": "res://test/horizons/Neptune.txt",
}

# Acceptable error thresholds (arcminutes)
const RA_DEC_TOLERANCE_ARCMIN: float = 1.0  # J2000 RA/Dec
const AZ_ALT_TOLERANCE_ARCMIN: float = 40.0  # Horizon coords (refraction model differs from JPL)

var _total_tests: int = 0
var _passed_tests: int = 0
var _max_ra_err: float = 0.0
var _max_dec_err: float = 0.0
var _max_az_err: float = 0.0
var _max_alt_err: float = 0.0
var _worst_body_ra: String = ""
var _worst_body_az: String = ""


func _init() -> void:
	print("═══════════════════════════════════════════")
	print("  Godot Astronomy — JPL Horizons Validation")
	print("═══════════════════════════════════════════")
	print("Observer: %.1f°N, %.1f°E, %.0fm" % [OBSERVER_LAT, OBSERVER_LON, OBSERVER_HEIGHT])
	print("")

	for body_name: String in BODY_FILES:
		_validate_body(body_name, BODY_FILES[body_name])

	print("")
	print("═══════════════════════════════════════════")
	print("  RESULTS: %d / %d passed" % [_passed_tests, _total_tests])
	print("  Max RA error:  %.4f arcmin (%s)" % [_max_ra_err, _worst_body_ra])
	print("  Max Dec error: %.4f arcmin" % _max_dec_err)
	print("  Max Az error:  %.4f arcmin (%s)" % [_max_az_err, _worst_body_az])
	print("  Max Alt error: %.4f arcmin" % _max_alt_err)
	if _passed_tests == _total_tests:
		print("  ✓ ALL TESTS PASSED")
	else:
		print("  ✗ SOME TESTS FAILED")
	print("═══════════════════════════════════════════")
	quit()


func _validate_body(body_name: String, file_path: String) -> void:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		print("  SKIP %s — file not found" % body_name)
		return

	var content: String = file.get_as_text()
	file.close()

	var lines: PackedStringArray = content.split("\n")
	var in_data: bool = false
	var body_tests: int = 0
	var body_passed: int = 0
	var body_max_ra_err: float = 0.0
	var body_max_alt_err: float = 0.0
	var sample_count: int = 0

	for line: String in lines:
		if line.begins_with("$$SOE"):
			in_data = true
			continue
		if line.begins_with("$$EOE"):
			break
		if not in_data:
			continue

		# Parse: " 1900-Jan-01 00:00 A   282.55694 -22.95057 281.68098 -22.79285 252.9431 -17.0474"
		var trimmed: String = line.strip_edges()
		if trimmed.is_empty():
			continue

		# Only test every 10th sample to keep it fast
		sample_count += 1
		if sample_count % 10 != 1:
			continue

		var parsed: Dictionary = _parse_horizons_line(trimmed)
		if parsed.is_empty():
			continue

		# Compute our values
		var our_result: Dictionary = _compute_position(body_name, parsed)
		if our_result.is_empty():
			continue

		# Compare J2000 RA/Dec
		var ra_err_arcmin: float = absf(our_result.ra - parsed.ra_j2000) * 60.0
		# Handle RA wrap-around
		if ra_err_arcmin > 180.0 * 60.0:
			ra_err_arcmin = 360.0 * 60.0 - ra_err_arcmin
		var dec_err_arcmin: float = absf(our_result.dec - parsed.dec_j2000) * 60.0

		# Compare Az/Alt
		var az_err_arcmin: float = absf(our_result.az - parsed.az) * 60.0
		if az_err_arcmin > 180.0 * 60.0:
			az_err_arcmin = 360.0 * 60.0 - az_err_arcmin
		var alt_err_arcmin: float = absf(our_result.alt - parsed.alt) * 60.0

		_total_tests += 1
		body_tests += 1
		var ra_dec_ok: bool = ra_err_arcmin < RA_DEC_TOLERANCE_ARCMIN and dec_err_arcmin < RA_DEC_TOLERANCE_ARCMIN
		var az_alt_ok: bool = az_err_arcmin < AZ_ALT_TOLERANCE_ARCMIN and alt_err_arcmin < AZ_ALT_TOLERANCE_ARCMIN

		if ra_dec_ok and az_alt_ok:
			_passed_tests += 1
			body_passed += 1

		body_max_ra_err = maxf(body_max_ra_err, ra_err_arcmin)
		body_max_alt_err = maxf(body_max_alt_err, alt_err_arcmin)

		if ra_err_arcmin > _max_ra_err:
			_max_ra_err = ra_err_arcmin
			_worst_body_ra = "%s @ %s" % [body_name, parsed.date_str]
		_max_dec_err = maxf(_max_dec_err, dec_err_arcmin)
		if az_err_arcmin > _max_az_err:
			_max_az_err = az_err_arcmin
			_worst_body_az = "%s @ %s" % [body_name, parsed.date_str]
		_max_alt_err = maxf(_max_alt_err, alt_err_arcmin)

	var status: String = "✓" if body_passed == body_tests else "✗"
	print("  %s %s: %d/%d  (max RA err: %.3f', max Alt err: %.3f')" % [
		status, body_name, body_passed, body_tests, body_max_ra_err, body_max_alt_err])


func _parse_horizons_line(line: String) -> Dictionary:
	# Format: " 1900-Jan-01 00:00 A   282.55694 -22.95057 281.68098 -22.79285 252.9431 -17.0474"
	# The columns are space-separated but the date takes specific positions
	# Date: chars 1-17, then flags, then numbers
	var date_str: String = line.substr(0, 17).strip_edges()

	# Parse date: "1900-Jan-01 00:00"
	var parts: PackedStringArray = date_str.split(" ")
	if parts.size() < 2:
		return {}
	var date_part: String = parts[0]  # "1900-Jan-01"
	var time_part: String = parts[1]  # "00:00"

	var date_fields: PackedStringArray = date_part.split("-")
	if date_fields.size() < 3:
		return {}

	var year: int = int(date_fields[0])
	var month_str: String = date_fields[1]
	var day: int = int(date_fields[2])

	var month: int = _month_from_name(month_str)
	if month == 0:
		return {}

	var time_fields: PackedStringArray = time_part.split(":")
	var hour: int = int(time_fields[0])
	var minute: int = int(time_fields[1]) if time_fields.size() > 1 else 0

	# Extract numeric values — find all floating point numbers after the date/flags
	# Skip date (17 chars) + flag chars, then grab 6 numbers
	var nums: Array[float] = []
	var remaining: String = line.substr(17)
	var regex: RegEx = RegEx.new()
	regex.compile("-?\\d+\\.\\d+")
	var matches: Array[RegExMatch] = regex.search_all(remaining)
	for m: RegExMatch in matches:
		nums.append(float(m.get_string()))

	if nums.size() < 6:
		return {}

	return {
		"date_str": date_str,
		"year": year, "month": month, "day": day,
		"hour": hour, "minute": minute,
		"ra_j2000": nums[0],   # degrees
		"dec_j2000": nums[1],  # degrees
		"ra_apparent": nums[2],
		"dec_apparent": nums[3],
		"az": nums[4],
		"alt": nums[5],
	}


func _month_from_name(name: String) -> int:
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


func _compute_position(body_name: String, parsed: Dictionary) -> Dictionary:
	var time: AstroTime.Moment = AstroTime.make_time(
		parsed.year, parsed.month, parsed.day,
		parsed.hour, parsed.minute, 0.0)

	var geo_j2000: Vector3

	match body_name:
		"Sun":
			geo_j2000 = AstroSun.sun_position(time)
		"Moon":
			geo_j2000 = AstroMoon.geo_moon(time).j2000
		"Mercury":
			geo_j2000 = AstroPlanets.geo_position(AstroPlanets.Planet.MERCURY, time)
		"Venus":
			geo_j2000 = AstroPlanets.geo_position(AstroPlanets.Planet.VENUS, time)
		"Mars":
			geo_j2000 = AstroPlanets.geo_position(AstroPlanets.Planet.MARS, time)
		"Jupiter":
			geo_j2000 = AstroPlanets.geo_position(AstroPlanets.Planet.JUPITER, time)
		"Saturn":
			geo_j2000 = AstroPlanets.geo_position(AstroPlanets.Planet.SATURN, time)
		"Uranus":
			geo_j2000 = AstroPlanets.geo_position(AstroPlanets.Planet.URANUS, time)
		"Neptune":
			geo_j2000 = AstroPlanets.geo_position(AstroPlanets.Planet.NEPTUNE, time)
		_:
			return {}

	# J2000 RA/Dec
	var rd: AstroCoords.RaDec = AstroCoords.vector2radec(geo_j2000)
	var ra_deg: float = rd.ra * 15.0  # hours -> degrees

	# Topocentric correction for horizon
	var observer: Vector3 = AstroCoords.geo_pos(time, OBSERVER_LAT, OBSERVER_LON, OBSERVER_HEIGHT)
	var topo: Vector3 = geo_j2000 - observer
	var ofdate: Vector3 = AstroCoords.j2000_to_ofdate(topo, time)
	var topo_rd: AstroCoords.RaDec = AstroCoords.vector2radec(ofdate)
	var hor: AstroCoords.HorizonCoord = AstroCoords.horizon(
		time, OBSERVER_LAT, OBSERVER_LON, topo_rd.ra, topo_rd.dec)

	return {
		"ra": ra_deg,
		"dec": rd.dec,
		"az": hor.azimuth,
		"alt": hor.altitude,
	}
