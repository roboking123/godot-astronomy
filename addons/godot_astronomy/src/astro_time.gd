class_name AstroTime
## Time system — Julian Day, Delta T, and constants
## Ported from cosinekitty/astronomy (MIT License)


## Astronomical time object — shared time parameter for all astro functions
## psi/eps/st are lazy cache (initialized to NAN, computed on first access)
## Warning: do not reuse old instances — call make_time() again when time changes, otherwise cached values are stale
class Moment extends RefCounted:
	var ut: float   ## J2000 UT days
	var tt: float   ## Terrestrial Time (TT)
	var psi: float  ## longitude nutation (lazy cache, arcseconds)
	var eps: float  ## obliquity nutation (lazy cache, arcseconds)
	var st: float   ## sidereal time (lazy cache, hours)


# ─── Angle conversion constants ───
const DEG2RAD: float = 0.017453292519943296
const RAD2DEG: float = 57.295779513082321
const HOUR2RAD: float = 0.2617993877991494365
const RAD2HOUR: float = 3.819718634205488

# ─── Astrophysical constants ───
const KM_PER_AU: float = 1.4959787069098932e+8
const SUN_RADIUS_KM: float = 695700.0
const EARTH_EQUATORIAL_RADIUS_KM: float = 6378.1366
const EARTH_FLATTENING: float = 0.996647180302104
const MOON_MEAN_RADIUS_KM: float = 1737.4

# ─── Derived constants ───
## Earth equatorial radius in AU
const EARTH_EQUATORIAL_RADIUS_AU: float = EARTH_EQUATORIAL_RADIUS_KM / KM_PER_AU

# ─── Precision constants ───
## Arcseconds in a full circle
const ASEC360: float = 1296000.0
## Arcseconds to radians
const ASEC2RAD: float = 4.848136811095359935899141e-6
## Arcseconds per radian (= 3600 * 180 / pi)
const ARC: float = 206264.80624709636
## Speed of light (AU/day) — used for light-time correction
const C_AUDAY: float = 173.1446326846693
## Mean synodic month in days
const MEAN_SYNODIC_MONTH: float = 29.530588
## Tropical year in days
const DAYS_PER_TROPICAL_YEAR: float = 365.24217

# ─── Lunar constants ───
## Moon axis inclination (radians)
const MOON_AXIS_INCLINATION_RADIANS: float = DEG2RAD * 1.543


## Create a time object. psi/eps/st initialized to NAN, computed on demand (lazy cache).
static func make_time(
	year: int, month: int, day: int,
	hour: int, minute: int, sec: float
) -> Moment:
	var t := Moment.new()
	t.ut = _julian_day(year, month, day, hour, minute, sec)
	t.tt = _terrestrial_time(t.ut)
	t.psi = NAN
	t.eps = NAN
	t.st = NAN
	return t


## Create a time object directly from ut (J2000 days)
static func time_from_days(p_ut: float) -> Moment:
	var t := Moment.new()
	t.ut = p_ut
	t.tt = _terrestrial_time(p_ut)
	t.psi = NAN
	t.eps = NAN
	t.st = NAN
	return t


## Julian Day calculation — returns days relative to J2000 (2000-01-01 12:00 UTC)
## Formula from Fliegel & Van Flandern (1968), modified to support ancient dates
static func _julian_day(
	year: int, month: int, day: int,
	hour: int, minute: int, sec: float
) -> float:
	var y: int = year
	var m: int = month
	var d: int = day
	@warning_ignore("integer_division")
	var f: int = (14 - m) / 12

	# Integer arithmetic to avoid floating-point precision issues (intentional truncation)
	@warning_ignore("integer_division")
	var y2000: int = (
		(d - 365972956)
		+ (1461 * (y + 1000000 - f)) / 4
		+ (367 * (m - 2 + 12 * f)) / 12
		- (3 * ((y + 1000100 - f) / 100)) / 4
	)

	return (y2000 - 0.5) + (hour / 24.0) + (minute / 1440.0) + (sec / 86400.0)


## UT to TT (Terrestrial Time) = ut + Delta_T / 86400
static func _terrestrial_time(ut: float) -> float:
	return ut + _delta_t(ut) / 86400.0


## Espenak & Meeus multi-segment Delta T polynomial (seconds)
## Covers -500 to ~2150 CE; extrapolated beyond that range
static func _delta_t(ut: float) -> float:
	var y: float = 2000.0 + ((ut - 14.0) / DAYS_PER_TROPICAL_YEAR)
	var u: float
	var u2: float
	var u3: float
	var u4: float
	var u5: float
	var u6: float
	var u7: float

	if y < -500.0:
		u = (y - 1820.0) / 100.0
		return -20.0 + (32.0 * u * u)

	if y < 500.0:
		u = y / 100.0
		u2 = u * u; u3 = u * u2; u4 = u2 * u2; u5 = u2 * u3; u6 = u3 * u3
		return (10583.6 - 1014.41 * u + 33.78311 * u2 - 5.952053 * u3
			- 0.1798452 * u4 + 0.022174192 * u5 + 0.0090316521 * u6)

	if y < 1600.0:
		u = (y - 1000.0) / 100.0
		u2 = u * u; u3 = u * u2; u4 = u2 * u2; u5 = u2 * u3; u6 = u3 * u3
		return (1574.2 - 556.01 * u + 71.23472 * u2 + 0.319781 * u3
			- 0.8503463 * u4 - 0.005050998 * u5 + 0.0083572073 * u6)

	if y < 1700.0:
		u = y - 1600.0
		u2 = u * u; u3 = u * u2
		return 120.0 - 0.9808 * u - 0.01532 * u2 + u3 / 7129.0

	if y < 1800.0:
		u = y - 1700.0
		u2 = u * u; u3 = u * u2; u4 = u2 * u2
		return 8.83 + 0.1603 * u - 0.0059285 * u2 + 0.00013336 * u3 - u4 / 1174000.0

	if y < 1860.0:
		u = y - 1800.0
		u2 = u * u; u3 = u * u2; u4 = u2 * u2; u5 = u2 * u3; u6 = u3 * u3; u7 = u3 * u4
		return (13.72 - 0.332447 * u + 0.0068612 * u2 + 0.0041116 * u3
			- 0.00037436 * u4 + 0.0000121272 * u5 - 0.0000001699 * u6
			+ 0.000000000875 * u7)

	if y < 1900.0:
		u = y - 1860.0
		u2 = u * u; u3 = u * u2; u4 = u2 * u2; u5 = u2 * u3
		return 7.62 + 0.5737 * u - 0.251754 * u2 + 0.01680668 * u3 - 0.0004473624 * u4 + u5 / 233174.0

	if y < 1920.0:
		u = y - 1900.0
		u2 = u * u; u3 = u * u2; u4 = u2 * u2
		return -2.79 + 1.494119 * u - 0.0598939 * u2 + 0.0061966 * u3 - 0.000197 * u4

	if y < 1941.0:
		u = y - 1920.0
		u2 = u * u; u3 = u * u2
		return 21.20 + 0.84493 * u - 0.076100 * u2 + 0.0020936 * u3

	if y < 1961.0:
		u = y - 1950.0
		u2 = u * u; u3 = u * u2
		return 29.07 + 0.407 * u - u2 / 233.0 + u3 / 2547.0

	if y < 1986.0:
		u = y - 1975.0
		u2 = u * u; u3 = u * u2
		return 45.45 + 1.067 * u - u2 / 260.0 - u3 / 718.0

	if y < 2005.0:
		u = y - 2000.0
		u2 = u * u; u3 = u * u2; u4 = u2 * u2; u5 = u2 * u3
		return (63.86 + 0.3345 * u - 0.060374 * u2 + 0.0017275 * u3
			+ 0.000651814 * u4 + 0.00002373599 * u5)

	if y < 2050.0:
		u = y - 2000.0
		return 62.92 + 0.32217 * u + 0.005589 * u * u

	if y < 2150.0:
		u = (y - 1820.0) / 100.0
		return -20.0 + 32.0 * u * u - 0.5628 * (2150.0 - y)

	# Beyond 2150: extrapolation
	u = (y - 1820.0) / 100.0
	return -20.0 + (32.0 * u * u)


## Return fractional part: x - floor(x)
static func frac(x: float) -> float:
	return x - floor(x)


## Normalize angle to [0, 360)
static func normalize_longitude(lon: float) -> float:
	var result: float = fmod(lon, 360.0)
	if result < 0.0:
		result += 360.0
	return result


## Normalize angle offset to (-180, +180]
static func longitude_offset(diff: float) -> float:
	var offset: float = diff
	while offset <= -180.0:
		offset += 360.0
	while offset > 180.0:
		offset -= 360.0
	return offset
