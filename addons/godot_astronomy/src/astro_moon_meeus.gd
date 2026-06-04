class_name AstroMoonMeeus
## High-precision moon position — Meeus "Astronomical Algorithms" Ch.47
## Based on truncated ELP2000-82 with 60 longitude + 60 latitude terms
## Accuracy: ~10 arcseconds (vs CalcMoon's ~1 degree)


## Geocentric ecliptic result
class MeeusMoonResult extends RefCounted:
	var lon_rad: float   ## Ecliptic longitude (radians, mean equinox of date)
	var lat_rad: float   ## Ecliptic latitude (radians)
	var dist_km: float   ## Earth-Moon distance (km)


# ─── Longitude/Distance table (Table 47.A) ───
# [D, M, M', F, Σl (1e-6 deg), Σr (1e-3 km)]
const _TAB_LR: Array = [
	[0, 0, 1, 0, 6288774, -20905355],
	[2, 0, -1, 0, 1274027, -3699111],
	[2, 0, 0, 0, 658314, -2955968],
	[0, 0, 2, 0, 213618, -569925],
	[0, 1, 0, 0, -185116, 48888],
	[0, 0, 0, 2, -114332, -3149],
	[2, 0, -2, 0, 58793, 246158],
	[2, -1, -1, 0, 57066, -152138],
	[2, 0, 1, 0, 53322, -170733],
	[2, -1, 0, 0, 45758, -204586],
	[0, 1, -1, 0, -40923, -129620],
	[1, 0, 0, 0, -34720, 108743],
	[0, 1, 1, 0, -30383, 104755],
	[2, 0, 0, -2, 15327, 10321],
	[0, 0, 1, 2, -12528, 0],
	[0, 0, 1, -2, 10980, 79661],
	[4, 0, -1, 0, 10675, -34782],
	[0, 0, 3, 0, 10034, -23210],
	[4, 0, -2, 0, 8548, -21636],
	[2, 1, -1, 0, -7888, 24208],
	[2, 1, 0, 0, -6766, 30824],
	[1, 0, -1, 0, -5163, -8379],
	[1, 1, 0, 0, 4987, -16675],
	[2, -1, 1, 0, 4036, -12831],
	[2, 0, 2, 0, 3994, -10445],
	[4, 0, 0, 0, 3861, -11650],
	[2, 0, -3, 0, 3665, 14403],
	[0, 1, -2, 0, -2689, -7003],
	[2, 0, -1, 2, -2602, 0],
	[2, -1, -2, 0, 2390, 10056],
	[1, 0, 1, 0, -2348, 6322],
	[2, -2, 0, 0, 2236, -9884],
	[0, 1, 2, 0, -2120, 5751],
	[0, 2, 0, 0, -2069, 0],
	[2, -2, -1, 0, 2048, -4950],
	[2, 0, 1, -2, -1773, 4130],
	[2, 0, 0, 2, -1595, 0],
	[4, -1, -1, 0, 1215, -3958],
	[0, 0, 2, 2, -1110, 0],
	[3, 0, -1, 0, -892, 3258],
	[2, 1, 1, 0, -810, 2616],
	[4, -1, -2, 0, 759, -1897],
	[0, 2, -1, 0, -713, -2117],
	[2, 2, -1, 0, -700, 2354],
	[2, 1, -2, 0, 691, 0],
	[2, -1, 0, -2, 596, 0],
	[4, 0, 1, 0, 549, -1423],
	[0, 0, 4, 0, 537, -1117],
	[4, -1, 0, 0, 520, -1571],
	[1, 0, -2, 0, -487, -1739],
	[2, 1, 0, -2, -399, 0],
	[0, 0, 2, -2, -381, -4421],
	[1, 1, 1, 0, 351, 0],
	[3, 0, -2, 0, -340, 0],
	[4, 0, -3, 0, 330, 0],
	[2, -1, 2, 0, 327, 0],
	[0, 2, 1, 0, -323, 1165],
	[1, 1, -1, 0, 299, 0],
	[2, 0, 3, 0, 294, 0],
	[2, 0, -1, -2, 0, 8752],
]

# ─── Latitude table (Table 47.B) ───
# [D, M, M', F, Σb (1e-6 deg)]
const _TAB_B: Array = [
	[0, 0, 0, 1, 5128122],
	[0, 0, 1, 1, 280602],
	[0, 0, 1, -1, 277693],
	[2, 0, 0, -1, 173237],
	[2, 0, -1, 1, 55413],
	[2, 0, -1, -1, 46271],
	[2, 0, 0, 1, 32573],
	[0, 0, 2, 1, 17198],
	[2, 0, 1, -1, 9266],
	[0, 0, 2, -1, 8822],
	[2, -1, 0, -1, 8216],
	[2, 0, -2, -1, 4324],
	[2, 0, 1, 1, 4200],
	[2, 1, 0, -1, -3359],
	[2, -1, -1, 1, 2463],
	[2, -1, 0, 1, 2211],
	[2, -1, -1, -1, 2065],
	[0, 1, -1, -1, -1870],
	[4, 0, -1, -1, 1828],
	[0, 1, 0, 1, -1794],
	[0, 0, 0, 3, -1749],
	[0, 1, -1, 1, -1565],
	[1, 0, 0, 1, -1491],
	[0, 1, 1, 1, -1475],
	[0, 1, 1, -1, -1410],
	[0, 1, 0, -1, -1344],
	[1, 0, 0, -1, -1335],
	[0, 0, 3, 1, 1107],
	[4, 0, 0, -1, 1021],
	[4, 0, -1, 1, 833],
	[0, 0, 1, -3, 777],
	[4, 0, -2, 1, 671],
	[2, 0, 0, -3, 607],
	[2, 0, 2, -1, 596],
	[2, -1, 1, -1, 491],
	[2, 0, -2, 1, -451],
	[0, 0, 3, -1, 439],
	[2, 0, 2, 1, 422],
	[2, 0, -3, -1, 421],
	[2, 1, -1, 1, -366],
	[2, 1, 0, 1, -351],
	[4, 0, 0, 1, 331],
	[2, -1, 1, 1, 315],
	[2, -2, 0, -1, 302],
	[0, 0, 1, 3, -283],
	[2, 1, 1, -1, -229],
	[1, 1, 0, -1, 223],
	[1, 1, 0, 1, 223],
	[0, 1, -2, -1, -220],
	[2, 1, -1, -1, -220],
	[1, 0, 1, 1, -185],
	[2, -1, -2, -1, 181],
	[0, 1, 2, 1, -177],
	[4, 0, -2, -1, 176],
	[4, -1, -1, -1, 166],
	[1, 0, 1, -1, -164],
	[4, 0, 1, -1, 132],
	[1, 0, -1, -1, -119],
	[4, -1, 0, -1, 115],
	[2, -2, 0, 1, 107],
]


## Compute geocentric ecliptic position of the Moon (mean equinox of date)
## T: Julian centuries from J2000.0 (TT)
static func position(T: float) -> MeeusMoonResult:
	# Mean longitude of Moon (L')
	var Lp: float = _horner(T, 218.3164477, 481267.88123421,
		-0.0015786, 1.0 / 538841.0, -1.0 / 65194000.0)
	Lp = deg_to_rad(_normalize(Lp))

	# Fundamental arguments
	var D: float = _horner(T, 297.8501921, 445267.1114034,
		-0.0018819, 1.0 / 545868.0, -1.0 / 113065000.0)
	D = deg_to_rad(_normalize(D))

	var M: float = _horner(T, 357.5291092, 35999.0502909,
		-0.0001535, 1.0 / 24490000.0, 0.0)
	M = deg_to_rad(_normalize(M))

	var Mp: float = _horner(T, 134.9633964, 477198.8675055,
		0.0087414, 1.0 / 69699.0, -1.0 / 14712000.0)
	Mp = deg_to_rad(_normalize(Mp))

	var F: float = _horner(T, 93.272095, 483202.0175233,
		-0.0036539, -1.0 / 3526000.0, 1.0 / 863310000.0)
	F = deg_to_rad(_normalize(F))

	# Additional correction angles
	var A1: float = deg_to_rad(119.75 + 131.849 * T)
	var A2: float = deg_to_rad(53.09 + 479264.29 * T)
	var A3: float = deg_to_rad(313.45 + 481266.484 * T)

	# Earth orbit eccentricity factor
	var E: float = 1.0 - 0.002516 * T - 0.0000074 * T * T
	var E2: float = E * E

	# Longitude and distance sums
	var sum_l: float = 3958.0 * sin(A1) + 1962.0 * sin(Lp - F) + 318.0 * sin(A2)
	var sum_r: float = 0.0

	for row: Array in _TAB_LR:
		var arg: float = D * row[0] + M * row[1] + Mp * row[2] + F * row[3]
		var sa: float = sin(arg)
		var ca: float = cos(arg)
		var m_abs: int = absi(int(row[1]))
		if m_abs == 0:
			sum_l += row[4] * sa
			sum_r += row[5] * ca
		elif m_abs == 1:
			sum_l += row[4] * sa * E
			sum_r += row[5] * ca * E
		else:
			sum_l += row[4] * sa * E2
			sum_r += row[5] * ca * E2

	# Latitude sum
	var sum_b: float = -2235.0 * sin(Lp) + 382.0 * sin(A3) + 175.0 * sin(A1 - F) + 175.0 * sin(A1 + F) + 127.0 * sin(Lp - Mp) - 115.0 * sin(Lp + Mp)

	for row: Array in _TAB_B:
		var arg: float = D * row[0] + M * row[1] + Mp * row[2] + F * row[3]
		var sb: float = sin(arg)
		var m_abs: int = absi(int(row[1]))
		if m_abs == 0:
			sum_b += row[4] * sb
		elif m_abs == 1:
			sum_b += row[4] * sb * E
		else:
			sum_b += row[4] * sb * E2

	var result: MeeusMoonResult = MeeusMoonResult.new()
	# Σl in 1e-6 degrees → radians, add to mean longitude
	result.lon_rad = fposmod(Lp + deg_to_rad(sum_l * 1e-6), TAU)
	result.lat_rad = deg_to_rad(sum_b * 1e-6)
	# Σr in 1e-3 km
	result.dist_km = 385000.56 + sum_r * 1e-3
	return result


## Geocentric J2000 equatorial position using Meeus model
## Drop-in replacement for AstroMoon.geo_moon()
static func geo_moon(time: AstroTime.Moment) -> AstroMoon.GeoMoonResult:
	var T: float = time.tt / 36525.0
	var m: MeeusMoonResult = position(T)

	var dist_au: float = m.dist_km / AstroTime.KM_PER_AU

	# Spherical ecliptic → rectangular ecliptic
	var cos_lat: float = cos(m.lat_rad)
	var gepos: Vector3 = Vector3(
		dist_au * cos_lat * cos(m.lon_rad),
		dist_au * cos_lat * sin(m.lon_rad),
		dist_au * sin(m.lat_rad),
	)

	# Meeus 用平均黃道 → 用平均傾角轉赤道，回傳也填 mobl 保持一致
	var tilt: AstroCoords.Tilt = AstroCoords.e_tilt(time)
	var equ: Vector3 = AstroCoords._ecl2equ_vec(tilt.mobl, gepos)

	# Of-date mean equatorial → J2000 (reverse precession)
	var prec: Array[float] = AstroCoords.precession_rot(time.tt, AstroCoords.INTO_2000)

	# Build compatible result
	var ecl: AstroMoon.MoonEcliptic = AstroMoon.MoonEcliptic.new()
	ecl.lon_rad = m.lon_rad
	ecl.lat_rad = m.lat_rad
	ecl.dist_au = dist_au

	var result: AstroMoon.GeoMoonResult = AstroMoon.GeoMoonResult.new()
	result.j2000 = AstroCoords.rotate(equ, prec)
	result.ecliptic = ecl
	result.tobl = tilt.mobl
	return result


# ─── Helpers ───

static func _horner(t: float, c0: float, c1: float, c2: float, c3: float, c4: float = 0.0) -> float:
	return c0 + t * (c1 + t * (c2 + t * (c3 + t * c4)))

static func _normalize(deg: float) -> float:
	return fposmod(deg, 360.0)
