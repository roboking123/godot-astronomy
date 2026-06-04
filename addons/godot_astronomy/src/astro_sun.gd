class_name AstroSun
## Sun position — VSOP87 Earth model
## Ported from cosinekitty/astronomy (MIT License)

# ─── VSOP Earth data tables ───
# Each entry = [amplitude, phase, frequency]

## Ecliptic longitude L0 (28 terms)
const _VSOP_LON_0: Array = [
	[1.75347045673, 0.00000000000, 0.00000000000],
	[0.03341656453, 4.66925680415, 6283.07584999140],
	[0.00034894275, 4.62610242189, 12566.15169998280],
	[0.00003417572, 2.82886579754, 3.52311834900],
	[0.00003497056, 2.74411783405, 5753.38488489680],
	[0.00003135899, 3.62767041756, 77713.77146812050],
	[0.00002676218, 4.41808345438, 7860.41939243920],
	[0.00002342691, 6.13516214446, 3930.20969621960],
	[0.00001273165, 2.03709657878, 529.69096509460],
	[0.00001324294, 0.74246341673, 11506.76976979360],
	[0.00000901854, 2.04505446477, 26.29831979980],
	[0.00001199167, 1.10962946234, 1577.34354244780],
	[0.00000857223, 3.50849152283, 398.14900340820],
	[0.00000779786, 1.17882681962, 5223.69391980220],
	[0.00000990250, 5.23268072088, 5884.92684658320],
	[0.00000753141, 2.53339052847, 5507.55323866740],
	[0.00000505267, 4.58292599973, 18849.22754997420],
	[0.00000492392, 4.20505711826, 775.52261132400],
	[0.00000356672, 2.91954114478, 0.06731030280],
	[0.00000284125, 1.89869240932, 796.29800681640],
	[0.00000242879, 0.34481445893, 5486.77784317500],
	[0.00000317087, 5.84901948512, 11790.62908865880],
	[0.00000271112, 0.31486255375, 10977.07880469900],
	[0.00000206217, 4.80646631478, 2544.31441988340],
	[0.00000205478, 1.86953770281, 5573.14280143310],
	[0.00000202318, 2.45767790232, 6069.77675455340],
	[0.00000126225, 1.08295459501, 20.77539549240],
	[0.00000155516, 0.83306084617, 213.29909543800],
]

## Ecliptic longitude L1 (3 terms)
const _VSOP_LON_1: Array = [
	[6283.07584999140, 0.00000000000, 0.00000000000],
	[0.00206058863, 2.67823455808, 6283.07584999140],
	[0.00004303419, 2.63512233481, 12566.15169998280],
]

## Ecliptic longitude L2 (1 term)
const _VSOP_LON_2: Array = [
	[0.00008721859, 1.07253635559, 6283.07584999140],
]

## Ecliptic latitude B1 (2 terms; B0 has no terms)
const _VSOP_LAT_1: Array = [
	[0.00227777722, 3.41376620530, 6283.07584999140],
	[0.00003805678, 3.37063423795, 12566.15169998280],
]

## Radius vector R0 (14 terms)
const _VSOP_RAD_0: Array = [
	[1.00013988784, 0.00000000000, 0.00000000000],
	[0.01670699632, 3.09846350258, 6283.07584999140],
	[0.00013956024, 3.05524609456, 12566.15169998280],
	[0.00003083720, 5.19846674381, 77713.77146812050],
	[0.00001628463, 1.17387558054, 5753.38488489680],
	[0.00001575572, 2.84685214877, 7860.41939243920],
	[0.00000924799, 5.45292236722, 11506.76976979360],
	[0.00000542439, 4.56409151453, 3930.20969621960],
	[0.00000472110, 3.66100022149, 5884.92684658320],
	[0.00000085831, 1.27079125277, 161000.68573767410],
	[0.00000057056, 2.01374292245, 83996.84731811189],
	[0.00000055736, 5.24159799170, 71430.69561812909],
	[0.00000174844, 3.01193636733, 18849.22754997420],
	[0.00000243181, 4.27349530790, 11790.62908865880],
]

## Radius vector R1 (2 terms)
const _VSOP_RAD_1: Array = [
	[0.00103018607, 1.10748968172, 6283.07584999140],
	[0.00001721238, 1.06442300386, 12566.15169998280],
]

## Radius vector R2 (1 term)
const _VSOP_RAD_2: Array = [
	[0.00004359385, 5.78455133808, 6283.07584999140],
]

const _DAYS_PER_MILLENNIUM: float = 365250.0


## Evaluate a single VSOP series: sum of A * cos(P + t * F)
static func _vsop_formula(series: Array, t: float) -> float:
	var result: float = 0.0
	for term: Array in series:
		result += term[0] * cos(term[1] + t * term[2])
	return result


## Convert VSOP spherical coordinates to rectangular (Cartesian)
static func _vsop_sphere_to_rect(lon: float, lat: float, radius: float) -> Vector3:
	var r_coslat: float = radius * cos(lat)
	return Vector3(
		r_coslat * cos(lon),
		r_coslat * sin(lon),
		radius * sin(lat),
	)


## Rotate from VSOP ecliptic to J2000 equatorial frame (fixed matrix)
static func _vsop_rotate(ecl: Vector3) -> Vector3:
	return Vector3(
		ecl.x + 0.000000440360 * ecl.y - 0.000000190919 * ecl.z,
		-0.000000479966 * ecl.x + 0.917482137087 * ecl.y - 0.397776982902 * ecl.z,
		0.397776982902 * ecl.y + 0.917482137087 * ecl.z,
	)


## Compute heliocentric Earth position, then negate to get geocentric Sun in J2000 equatorial coords.
## Warning: does not include light-travel time correction; for internal use.
static func calc_earth(time: AstroTime.Moment) -> Vector3:
	var t: float = time.tt / _DAYS_PER_MILLENNIUM

	# Ecliptic longitude = L0 + L1*t + L2*t^2
	var lon: float = _vsop_formula(_VSOP_LON_0, t)
	lon += _vsop_formula(_VSOP_LON_1, t) * t
	lon += _vsop_formula(_VSOP_LON_2, t) * t * t
	lon = fmod(lon, TAU)

	# Ecliptic latitude = B1*t (B0 has no terms)
	var lat: float = _vsop_formula(_VSOP_LAT_1, t) * t

	# Radius vector = R0 + R1*t + R2*t^2
	var rad: float = _vsop_formula(_VSOP_RAD_0, t)
	rad += _vsop_formula(_VSOP_RAD_1, t) * t
	rad += _vsop_formula(_VSOP_RAD_2, t) * t * t

	# Spherical -> rectangular -> rotate to J2000 equatorial
	var ecl: Vector3 = _vsop_sphere_to_rect(lon, lat, rad)
	return _vsop_rotate(ecl)


## Geocentric Sun position in J2000 equatorial coordinates with iterative light-travel time correction.
## Returns Vector3 in AU.
static func sun_position(time: AstroTime.Moment) -> Vector3:
	# Iterative light-travel time correction (ported from C: CorrectLightTravel, line 5243-5277)
	# Compute position -> measure distance -> back-calculate light-travel time -> recompute -> converge
	var ltime: AstroTime.Moment = time
	var pos: Vector3
	for iter: int in 10:
		var earth: Vector3 = calc_earth(ltime)
		pos = -earth
		var dist: float = pos.length()
		var ltime2: AstroTime.Moment = AstroTime.time_from_days(time.ut - dist / AstroTime.C_AUDAY)
		var dt: float = absf(ltime2.tt - ltime.tt)
		if dt < 1.0e-9:  ## Convergence threshold ~86us
			break
		ltime = ltime2
	return pos


## Sun distance in AU — without light-travel time correction.
static func helio_distance(time: AstroTime.Moment) -> float:
	return calc_earth(time).length()
