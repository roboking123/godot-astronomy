class_name AstroMoon
## Moon position — CalcMoon model + Libration
## Ported from cosinekitty/astronomy (MIT License)
## Original algorithm from Montenbruck & Pfleger, Astronomy on the Personal Computer


## CalcMoon ecliptic spherical coordinates (calc_moon return value)
class MoonEcliptic extends RefCounted:
	var lon_rad: float  ## Ecliptic longitude (radians)
	var lat_rad: float  ## Ecliptic latitude (radians)
	var dist_au: float  ## Earth-Moon distance (AU)


## geo_moon return value (J2000 position + calc_moon intermediate results)
class GeoMoonResult extends RefCounted:
	var j2000: Vector3       ## J2000 equatorial rectangular coordinates
	var ecliptic: MoonEcliptic  ## calc_moon intermediate result (reused by libration)
	var tobl: float          ## True obliquity of the ecliptic (degrees, reused by libration)


## Libration + lunar distance + apparent diameter (libration return value)
class LibrationResult extends RefCounted:
	var elon: float      ## Libration longitude (degrees)
	var elat: float      ## Libration latitude (degrees)
	var dist_km: float   ## Earth-Moon distance (km)
	var diam_deg: float  ## Apparent diameter (degrees)
	var mlon: float      ## Moon ecliptic longitude (degrees)
	var mlat: float      ## Moon ecliptic latitude (degrees)
	var pole_equ: Vector3  ## Moon north pole direction (of-date equatorial rectangular)


# ─── CalcMoon AddSol data table ───
# Each entry = [coeffl, coeffs, coeffg, coeffp, p, q, r, s]
const _ADDSOL_DATA: Array = [
	[13.902, 14.06, -0.001, 0.2607, 0, 0, 0, 4],
	[0.403, -4.01, 0.394, 0.0023, 0, 0, 0, 3],
	[2369.912, 2373.36, 0.601, 28.2333, 0, 0, 0, 2],
	[-125.154, -112.79, -0.725, -0.9781, 0, 0, 0, 1],
	[1.979, 6.98, -0.445, 0.0433, 1, 0, 0, 4],
	[191.953, 192.72, 0.029, 3.0861, 1, 0, 0, 2],
	[-8.466, -13.51, 0.455, -0.1093, 1, 0, 0, 1],
	[22639.500, 22609.07, 0.079, 186.5398, 1, 0, 0, 0],
	[18.609, 3.59, -0.094, 0.0118, 1, 0, 0, -1],
	[-4586.465, -4578.13, -0.077, 34.3117, 1, 0, 0, -2],
	[3.215, 5.44, 0.192, -0.0386, 1, 0, 0, -3],
	[-38.428, -38.64, 0.001, 0.6008, 1, 0, 0, -4],
	[-0.393, -1.43, -0.092, 0.0086, 1, 0, 0, -6],
	[-0.289, -1.59, 0.123, -0.0053, 0, 1, 0, 4],
	[-24.420, -25.10, 0.040, -0.3000, 0, 1, 0, 2],
	[18.023, 17.93, 0.007, 0.1494, 0, 1, 0, 1],
	[-668.146, -126.98, -1.302, -0.3997, 0, 1, 0, 0],
	[0.560, 0.32, -0.001, -0.0037, 0, 1, 0, -1],
	[-165.145, -165.06, 0.054, 1.9178, 0, 1, 0, -2],
	[-1.877, -6.46, -0.416, 0.0339, 0, 1, 0, -4],
	[0.213, 1.02, -0.074, 0.0054, 2, 0, 0, 4],
	[14.387, 14.78, -0.017, 0.2833, 2, 0, 0, 2],
	[-0.586, -1.20, 0.054, -0.0100, 2, 0, 0, 1],
	[769.016, 767.96, 0.107, 10.1657, 2, 0, 0, 0],
	[1.750, 2.01, -0.018, 0.0155, 2, 0, 0, -1],
	[-211.656, -152.53, 5.679, -0.3039, 2, 0, 0, -2],
	[1.225, 0.91, -0.030, -0.0088, 2, 0, 0, -3],
	[-30.773, -34.07, -0.308, 0.3722, 2, 0, 0, -4],
	[-0.570, -1.40, -0.074, 0.0109, 2, 0, 0, -6],
	[-2.921, -11.75, 0.787, -0.0484, 1, 1, 0, 2],
	[1.267, 1.52, -0.022, 0.0164, 1, 1, 0, 1],
	[-109.673, -115.18, 0.461, -0.9490, 1, 1, 0, 0],
	[-205.962, -182.36, 2.056, 1.4437, 1, 1, 0, -2],
	[0.233, 0.36, 0.012, -0.0025, 1, 1, 0, -3],
	[-4.391, -9.66, -0.471, 0.0673, 1, 1, 0, -4],
	[0.283, 1.53, -0.111, 0.0060, 1, -1, 0, 4],
	[14.577, 31.70, -1.540, 0.2302, 1, -1, 0, 2],
	[147.687, 138.76, 0.679, 1.1528, 1, -1, 0, 0],
	[-1.089, 0.55, 0.021, 0.0000, 1, -1, 0, -1],
	[28.475, 23.59, -0.443, -0.2257, 1, -1, 0, -2],
	[-0.276, -0.38, -0.006, -0.0036, 1, -1, 0, -3],
	[0.636, 2.27, 0.146, -0.0102, 1, -1, 0, -4],
	[-0.189, -1.68, 0.131, -0.0028, 0, 2, 0, 2],
	[-7.486, -0.66, -0.037, -0.0086, 0, 2, 0, 0],
	[-8.096, -16.35, -0.740, 0.0918, 0, 2, 0, -2],
	[-5.741, -0.04, 0.000, -0.0009, 0, 0, 2, 2],
	[0.255, 0.00, 0.000, 0.0000, 0, 0, 2, 1],
	[-411.608, -0.20, 0.000, -0.0124, 0, 0, 2, 0],
	[0.584, 0.84, 0.000, 0.0071, 0, 0, 2, -1],
	[-55.173, -52.14, 0.000, -0.1052, 0, 0, 2, -2],
	[0.254, 0.25, 0.000, -0.0017, 0, 0, 2, -3],
	[0.025, -1.67, 0.000, 0.0031, 0, 0, 2, -4],
	[1.060, 2.96, -0.166, 0.0243, 3, 0, 0, 2],
	[36.124, 50.64, -1.300, 0.6215, 3, 0, 0, 0],
	[-13.193, -16.40, 0.258, -0.1187, 3, 0, 0, -2],
	[-1.187, -0.74, 0.042, 0.0074, 3, 0, 0, -4],
	[-0.293, -0.31, -0.002, 0.0046, 3, 0, 0, -6],
	[-0.290, -1.45, 0.116, -0.0051, 2, 1, 0, 2],
	[-7.649, -10.56, 0.259, -0.1038, 2, 1, 0, 0],
	[-8.627, -7.59, 0.078, -0.0192, 2, 1, 0, -2],
	[-2.740, -2.54, 0.022, 0.0324, 2, 1, 0, -4],
	[1.181, 3.32, -0.212, 0.0213, 2, -1, 0, 2],
	[9.703, 11.67, -0.151, 0.1268, 2, -1, 0, 0],
	[-0.352, -0.37, 0.001, -0.0028, 2, -1, 0, -1],
	[-2.494, -1.17, -0.003, -0.0017, 2, -1, 0, -2],
	[0.360, 0.20, -0.012, -0.0043, 2, -1, 0, -4],
	[-1.167, -1.25, 0.008, -0.0106, 1, 2, 0, 0],
	[-7.412, -6.12, 0.117, 0.0484, 1, 2, 0, -2],
	[-0.311, -0.65, -0.032, 0.0044, 1, 2, 0, -4],
	[0.757, 1.82, -0.105, 0.0112, 1, -2, 0, 2],
	[2.580, 2.32, 0.027, 0.0196, 1, -2, 0, 0],
	[2.533, 2.40, -0.014, -0.0212, 1, -2, 0, -2],
	[-0.344, -0.57, -0.025, 0.0036, 0, 3, 0, -2],
	[-0.992, -0.02, 0.000, 0.0000, 1, 0, 2, 2],
	[-45.099, -0.02, 0.000, -0.0010, 1, 0, 2, 0],
	[-0.179, -9.52, 0.000, -0.0833, 1, 0, 2, -2],
	[-0.301, -0.33, 0.000, 0.0014, 1, 0, 2, -4],
	[-6.382, -3.37, 0.000, -0.0481, 1, 0, -2, 2],
	[39.528, 85.13, 0.000, -0.7136, 1, 0, -2, 0],
	[9.366, 0.71, 0.000, -0.0112, 1, 0, -2, -2],
	[0.202, 0.02, 0.000, 0.0000, 1, 0, -2, -4],
	[0.415, 0.10, 0.000, 0.0013, 0, 1, 2, 0],
	[-2.152, -2.26, 0.000, -0.0066, 0, 1, 2, -2],
	[-1.440, -1.30, 0.000, 0.0014, 0, 1, -2, 2],
	[0.384, -0.04, 0.000, 0.0000, 0, 1, -2, -2],
	[1.938, 3.60, -0.145, 0.0401, 4, 0, 0, 0],
	[-0.952, -1.58, 0.052, -0.0130, 4, 0, 0, -2],
	[-0.551, -0.94, 0.032, -0.0097, 3, 1, 0, 0],
	[-0.482, -0.57, 0.005, -0.0045, 3, 1, 0, -2],
	[0.681, 0.96, -0.026, 0.0115, 3, -1, 0, 0],
	[-0.297, -0.27, 0.002, -0.0009, 2, 2, 0, -2],
	[0.254, 0.21, -0.003, 0.0000, 2, -2, 0, -2],
	[-0.250, -0.22, 0.004, 0.0014, 1, 3, 0, -2],
	[-3.996, 0.00, 0.000, 0.0004, 2, 0, 2, 0],
	[0.557, -0.75, 0.000, -0.0090, 2, 0, 2, -2],
	[-0.459, -0.38, 0.000, -0.0053, 2, 0, -2, 2],
	[-1.298, 0.74, 0.000, 0.0004, 2, 0, -2, 0],
	[0.538, 1.14, 0.000, -0.0141, 2, 0, -2, -2],
	[0.263, 0.02, 0.000, 0.0000, 1, 1, 2, 0],
	[0.426, 0.07, 0.000, -0.0006, 1, 1, -2, -2],
	[-0.304, 0.03, 0.000, 0.0003, 1, -1, 2, 0],
	[-0.372, -0.19, 0.000, -0.0027, 1, -1, -2, 2],
	[0.418, 0.00, 0.000, 0.0000, 0, 0, 4, 0],
	[-0.330, -0.04, 0.000, 0.0000, 3, 0, 2, 0],
]

# ─── SolarN data ───
# Each entry = [coeffn, p, q, r, s]
const _SOLN_DATA: Array = [
	[-526.069, 0, 0, 1, -2],
	[-3.352, 0, 0, 1, -4],
	[44.297, 1, 0, 1, -2],
	[-6.000, 1, 0, 1, -4],
	[20.599, -1, 0, 1, 0],
	[-30.598, -1, 0, 1, -2],
	[-24.649, -2, 0, 1, 0],
	[-2.000, -2, 0, 1, -2],
	[-22.571, 0, 1, 1, -2],
	[10.985, 0, -1, 1, -2],
]

# ─── Planetary corrections ───
# Each entry = [coeff, phase, freq] (sin in revolutions)
const _PLANETARY_DATA: Array = [
	[0.82, 0.7736, -62.5512],
	[0.31, 0.0466, -125.1025],
	[0.35, 0.5785, -25.1042],
	[0.66, 0.4591, 1335.8075],
	[0.64, 0.3130, -91.5680],
	[1.14, 0.1480, 1331.2898],
	[0.21, 0.5918, 1056.5859],
	[0.44, 0.5784, 1322.8595],
	[0.24, 0.2275, -5.7374],
	[0.28, 0.2965, 2.6929],
	[0.33, 0.3132, 6.3368],
]


## Sine with argument in revolutions, not radians
static func _sine(phi: float) -> float:
	return sin(TAU * phi)


## Long-period perturbations
static func _long_periodic(t: float) -> Dictionary:
	var s1: float = _sine(0.19833 + 0.05611 * t)
	var s2: float = _sine(0.27869 + 0.04508 * t)
	var s3: float = _sine(0.16827 - 0.36903 * t)
	var s4: float = _sine(0.34734 - 5.37261 * t)
	var s5: float = _sine(0.10498 - 5.37899 * t)
	var s6: float = _sine(0.42681 - 0.41855 * t)
	var s7: float = _sine(0.14943 - 5.37511 * t)

	return {
		"dl0": 0.84 * s1 + 0.31 * s2 + 14.27 * s3 + 7.26 * s4 + 0.28 * s5 + 0.24 * s6,
		"dl": 2.94 * s1 + 0.31 * s2 + 14.27 * s3 + 9.34 * s4 + 1.12 * s5 + 0.83 * s6,
		"dls": -6.40 * s1 - 1.89 * s6,
		"df": 0.21 * s1 + 0.31 * s2 + 14.27 * s3 - 88.70 * s4 - 15.30 * s5 + 0.24 * s6 - 1.86 * s7,
		"dgam": -3332e-9 * _sine(0.59734 - 5.37261 * t) - 539e-9 * _sine(0.35498 - 5.37899 * t) - 64e-9 * _sine(0.39943 - 5.37511 * t),
	}


## Initialize CalcMoon context
## co/si are 1D arrays of size 52, emulating Pascal ARRAY[-6..6, 1..4]
## Access: co[(i+6)*4 + (j-1)], i: -6..6, j: 1..4
static func _init_context(t: float) -> Dictionary:
	var t2: float = t * t
	var lp: Dictionary = _long_periodic(t)
	var dd: float = lp.dl0 - lp.dls

	var ctx: Dictionary = {
		"t": t,
		"dgam": lp.dgam,
		"dlam": 0.0,
		"ds": 0.0,
		"gam1c": 0.0,
		"sinpi": 3422.7000,
		"n": 0.0,
		"co": [] as Array[float],
		"si": [] as Array[float],
	}

	# Initialize co/si arrays (52 elements)
	ctx.co.resize(52)
	ctx.si.resize(52)
	for idx: int in range(52):
		ctx.co[idx] = 0.0
		ctx.si[idx] = 0.0

	# Fundamental angles
	var l0: float = TAU * AstroTime.frac(0.60643382 + 1336.85522467 * t - 0.00000313 * t2) + lp.dl0 / AstroTime.ARC
	var l: float = TAU * AstroTime.frac(0.37489701 + 1325.55240982 * t + 0.00002565 * t2) + lp.dl / AstroTime.ARC
	var ls: float = TAU * AstroTime.frac(0.99312619 + 99.99735956 * t - 0.00000044 * t2) + lp.dls / AstroTime.ARC
	var f: float = TAU * AstroTime.frac(0.25909118 + 1342.22782980 * t - 0.00000892 * t2) + lp.df / AstroTime.ARC
	var d: float = TAU * AstroTime.frac(0.82736186 + 1236.85308708 * t - 0.00000397 * t2) + dd / AstroTime.ARC

	ctx["l0"] = l0
	ctx["f"] = f

	# Initialize sin/cos multiples for 4 fundamental frequencies
	var args: Array = [l, ls, f, d]
	var maxj: Array[int] = [4, 3, 4, 6]
	var facs: Array[float] = [1.000002208, 0.997504612 - 0.002495388 * t, 1.000002708 + 139.978 * lp.dgam, 1.0]

	for i: int in range(4):
		var j_idx: int = i + 1  # j = 1~4
		var fac: float = facs[i]
		# co(0, j) = 1, si(0, j) = 0
		ctx.co[(0 + 6) * 4 + (j_idx - 1)] = 1.0
		ctx.si[(0 + 6) * 4 + (j_idx - 1)] = 0.0
		# co(1, j) = cos(arg)*fac, si(1, j) = sin(arg)*fac
		ctx.co[(1 + 6) * 4 + (j_idx - 1)] = cos(args[i]) * fac
		ctx.si[(1 + 6) * 4 + (j_idx - 1)] = sin(args[i]) * fac
		# Multiples: AddThe recurrence
		for jj: int in range(2, maxj[i] + 1):
			var prev_co: float = ctx.co[(jj - 1 + 6) * 4 + (j_idx - 1)]
			var prev_si: float = ctx.si[(jj - 1 + 6) * 4 + (j_idx - 1)]
			var base_co: float = ctx.co[(1 + 6) * 4 + (j_idx - 1)]
			var base_si: float = ctx.si[(1 + 6) * 4 + (j_idx - 1)]
			ctx.co[(jj + 6) * 4 + (j_idx - 1)] = prev_co * base_co - prev_si * base_si
			ctx.si[(jj + 6) * 4 + (j_idx - 1)] = prev_si * base_co + prev_co * base_si
		# Negative indices: co(-j) = co(j), si(-j) = -si(j)
		for jj: int in range(1, maxj[i] + 1):
			ctx.co[(-jj + 6) * 4 + (j_idx - 1)] = ctx.co[(jj + 6) * 4 + (j_idx - 1)]
			ctx.si[(-jj + 6) * 4 + (j_idx - 1)] = -ctx.si[(jj + 6) * 4 + (j_idx - 1)]

	return ctx


## Term(p,q,r,s) -> [x, y] (product combination of cos and sin)
static func _term(ctx: Dictionary, p: int, q: int, r: int, s: int) -> Array[float]:
	var indices: Array[int] = [p, q, r, s]
	var x: float = 1.0
	var y: float = 0.0
	for k: int in range(4):
		var idx: int = indices[k]
		if idx != 0:
			var co_val: float = ctx.co[(idx + 6) * 4 + k]
			var si_val: float = ctx.si[(idx + 6) * 4 + k]
			var new_x: float = x * co_val - y * si_val
			var new_y: float = y * co_val + x * si_val
			x = new_x
			y = new_y
	return [x, y] as Array[float]


## CalcMoon core — compute geocentric ecliptic coordinates of the Moon
static func calc_moon(t: float) -> MoonEcliptic:
	var ctx: Dictionary = _init_context(t)

	# 85 AddSol terms
	for row: Array in _ADDSOL_DATA:
		var xy: Array[float] = _term(ctx, int(row[4]), int(row[5]), int(row[6]), int(row[7]))
		ctx.dlam += row[0] * xy[1]
		ctx.ds += row[1] * xy[1]
		ctx.gam1c += row[2] * xy[0]
		ctx.sinpi += row[3] * xy[0]

	# SolarN
	var n_val: float = 0.0
	for row: Array in _SOLN_DATA:
		var xy: Array[float] = _term(ctx, int(row[1]), int(row[2]), int(row[3]), int(row[4]))
		n_val += row[0] * xy[1]

	# Planetary
	var planetary_dlam: float = 0.0
	for row: Array in _PLANETARY_DATA:
		planetary_dlam += row[0] * _sine(row[1] + row[2] * ctx.t)
	ctx.dlam += planetary_dlam

	# Final latitude calculation
	var s_val: float = ctx.f + ctx.ds / AstroTime.ARC
	var lat_seconds: float = (
		(1.000002708 + 139.978 * ctx.dgam)
		* (18518.511 + 1.189 + ctx.gam1c) * sin(s_val)
		- 6.24 * sin(3.0 * s_val)
		+ n_val
	)

	# Ecliptic longitude (radians)
	var lon_rad: float = TAU * AstroTime.frac((ctx.l0 + ctx.dlam / AstroTime.ARC) / TAU)
	# Ecliptic latitude (radians)
	var lat_rad: float = lat_seconds * (AstroTime.DEG2RAD / 3600.0)
	# Distance (AU)
	var dist_au: float = (AstroTime.ARC * AstroTime.EARTH_EQUATORIAL_RADIUS_AU) / (0.999953253 * ctx.sinpi)

	var result: MoonEcliptic = MoonEcliptic.new()
	result.lon_rad = lon_rad
	result.lat_rad = lat_rad
	result.dist_au = dist_au
	return result


## Geocentric J2000 equatorial position of the Moon (with calc_moon + e_tilt intermediates)
## CalcMoon -> of-date ecliptic spherical -> ecl2equ(true_obliq) -> precession(INTO_2000) -> J2000
## Returns GeoMoonResult: j2000 coords + ecliptic/tobl intermediates for libration() reuse
static func geo_moon(time: AstroTime.Moment) -> GeoMoonResult:
	var t: float = time.tt / 36525.0
	var ecl: MoonEcliptic = calc_moon(t)

	# Spherical to rectangular (ecliptic coordinates)
	var dist_cos_lat: float = ecl.dist_au * cos(ecl.lat_rad)
	var gepos: Vector3 = Vector3(
		dist_cos_lat * cos(ecl.lon_rad),
		dist_cos_lat * sin(ecl.lon_rad),
		ecl.dist_au * sin(ecl.lat_rad),
	)

	# Ecliptic to equatorial (of-date true obliquity — CalcMoon longitude includes nutation, so use tobl not mobl)
	var tilt: AstroCoords.Tilt = AstroCoords.e_tilt(time)
	var tobl: float = tilt.tobl
	var equ: Vector3 = AstroCoords._ecl2equ_vec(tobl, gepos)

	# Of-date true equatorial -> J2000 (reverse precession)
	var prec: Array[float] = AstroCoords.precession_rot(time.tt, AstroCoords.INTO_2000)

	var result: GeoMoonResult = GeoMoonResult.new()
	result.j2000 = AstroCoords.rotate(equ, prec)
	result.ecliptic = ecl
	result.tobl = tobl
	return result


## Libration + lunar distance + apparent diameter
## p_ecl: calc_moon result from geo_moon() (ecliptic spherical coordinates)
## p_tobl: true obliquity from geo_moon() (degrees)
static func libration(time: AstroTime.Moment, p_ecl: MoonEcliptic, p_tobl: float) -> LibrationResult:
	var t: float = time.tt / 36525.0
	var t2: float = t * t
	var t3: float = t2 * t
	var t4: float = t2 * t2

	var mlon: float = p_ecl.lon_rad
	var mlat: float = p_ecl.lat_rad
	var dist_km: float = p_ecl.dist_au * AstroTime.KM_PER_AU

	# Apparent diameter
	var diam_deg: float = (
		2.0 * AstroTime.RAD2DEG * atan(
			AstroTime.MOON_MEAN_RADIUS_KM
			/ sqrt(maxf(dist_km * dist_km - AstroTime.MOON_MEAN_RADIUS_KM * AstroTime.MOON_MEAN_RADIUS_KM, 0.001))
		)
	)

	# Mean longitude of the lunar ascending node
	var omega: float = (
		AstroTime.DEG2RAD * AstroTime.normalize_longitude(
			125.0445479 - 1934.1362891 * t + 0.0020754 * t2 + t3 / 467441.0 - t4 / 60616000.0
		)
	)

	# Moon's argument of latitude
	var f_lib: float = (
		AstroTime.DEG2RAD * AstroTime.normalize_longitude(
			93.2720950 + 483202.0175233 * t - 0.0036539 * t2 - t3 / 3526000.0 + t4 / 863310000.0
		)
	)

	# Sun's mean anomaly
	var m_sun: float = (
		AstroTime.DEG2RAD * AstroTime.normalize_longitude(
			357.5291092 + 35999.0502909 * t - 0.0001536 * t2 + t3 / 24490000.0
		)
	)

	# Moon's mean anomaly
	var mdash: float = (
		AstroTime.DEG2RAD * AstroTime.normalize_longitude(
			134.9633964 + 477198.8675055 * t + 0.0087414 * t2 + t3 / 69699.0 - t4 / 14712000.0
		)
	)

	# Moon's mean elongation
	var d_lib: float = (
		AstroTime.DEG2RAD * AstroTime.normalize_longitude(
			297.8501921 + 445267.1114034 * t - 0.0018819 * t2 + t3 / 545868.0 - t4 / 113065000.0
		)
	)

	# Earth's orbital eccentricity
	var e: float = 1.0 - 0.002516 * t - 0.0000074 * t2

	# ── Optical libration ──
	var sin_i: float = sin(AstroTime.MOON_AXIS_INCLINATION_RADIANS)
	var cos_i: float = cos(AstroTime.MOON_AXIS_INCLINATION_RADIANS)
	var w: float = mlon - omega
	var a: float = atan2(sin(w) * cos(mlat) * cos_i - sin(mlat) * sin_i, cos(w) * cos(mlat))
	var ldash: float = AstroTime.longitude_offset(AstroTime.RAD2DEG * (a - f_lib))
	var bdash: float = asin(-sin(w) * cos(mlat) * sin_i - sin(mlat) * cos_i)

	# ── Physical libration ──
	var k1: float = AstroTime.DEG2RAD * (119.75 + 131.849 * t)
	var k2: float = AstroTime.DEG2RAD * (72.56 + 20.186 * t)

	var rho: float = (
		- 0.02752 * cos(mdash)
		- 0.02245 * sin(f_lib)
		+ 0.00684 * cos(mdash - 2.0 * f_lib)
		- 0.00293 * cos(2.0 * f_lib)
		- 0.00085 * cos(2.0 * f_lib - 2.0 * d_lib)
		- 0.00054 * cos(mdash - 2.0 * d_lib)
		- 0.00020 * sin(mdash + f_lib)
		- 0.00020 * cos(mdash + 2.0 * f_lib)
		- 0.00020 * cos(mdash - f_lib)
		+ 0.00014 * cos(mdash + 2.0 * f_lib - 2.0 * d_lib)
	)

	var sigma: float = (
		- 0.02816 * sin(mdash)
		+ 0.02244 * cos(f_lib)
		- 0.00682 * sin(mdash - 2.0 * f_lib)
		- 0.00279 * sin(2.0 * f_lib)
		- 0.00083 * sin(2.0 * f_lib - 2.0 * d_lib)
		+ 0.00069 * sin(mdash - 2.0 * d_lib)
		+ 0.00040 * cos(mdash + f_lib)
		- 0.00025 * sin(2.0 * mdash)
		- 0.00023 * sin(mdash + 2.0 * f_lib)
		+ 0.00020 * cos(mdash - f_lib)
		+ 0.00019 * sin(mdash - f_lib)
		+ 0.00013 * sin(mdash + 2.0 * f_lib - 2.0 * d_lib)
		- 0.00010 * cos(mdash - 3.0 * f_lib)
	)

	var tau: float = (
		+ 0.02520 * e * sin(m_sun)
		+ 0.00473 * sin(2.0 * mdash - 2.0 * f_lib)
		- 0.00467 * sin(mdash)
		+ 0.00396 * sin(k1)
		+ 0.00276 * sin(2.0 * mdash - 2.0 * d_lib)
		+ 0.00196 * sin(omega)
		- 0.00183 * cos(mdash - f_lib)
		+ 0.00115 * sin(mdash - 2.0 * d_lib)
		- 0.00096 * sin(mdash - d_lib)
		+ 0.00046 * sin(2.0 * f_lib - 2.0 * d_lib)
		- 0.00039 * sin(mdash - f_lib)
		- 0.00032 * sin(mdash - m_sun - d_lib)
		+ 0.00027 * sin(2.0 * mdash - m_sun - 2.0 * d_lib)
		+ 0.00023 * sin(k2)
		- 0.00014 * sin(2.0 * d_lib)
		+ 0.00014 * cos(2.0 * mdash - 2.0 * f_lib)
		- 0.00012 * sin(mdash - 2.0 * f_lib)
		- 0.00012 * sin(2.0 * mdash)
		+ 0.00011 * sin(2.0 * mdash - 2.0 * m_sun - 2.0 * d_lib)
	)

	# Combine optical + physical libration
	var ldash2: float = -tau + (rho * cos(a) + sigma * sin(a)) * tan(bdash)
	bdash *= AstroTime.RAD2DEG
	var bdash2: float = sigma * cos(a) - rho * sin(a)

	# Moon north pole direction (ecliptic rectangular -> of-date equatorial rectangular)
	var pole_ecl: Vector3 = Vector3(
		-sin_i * sin(omega), sin_i * cos(omega), cos_i)
	var tobl: float = p_tobl
	var pole_equ: Vector3 = AstroCoords._ecl2equ_vec(tobl, pole_ecl)

	var result: LibrationResult = LibrationResult.new()
	result.elon = ldash + ldash2
	result.elat = bdash + bdash2
	result.dist_km = dist_km
	result.diam_deg = diam_deg
	result.mlon = AstroTime.RAD2DEG * mlon
	result.mlat = AstroTime.RAD2DEG * mlat
	result.pole_equ = pole_equ
	return result
