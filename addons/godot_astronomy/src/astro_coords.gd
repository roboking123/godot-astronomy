class_name AstroCoords
## Coordinate systems — nutation, precession, sidereal time, observer position, horizon
## Ported from cosinekitty/astronomy (MIT License)

# ─── Precession/nutation rotation direction ───
const FROM_2000: int = 0  ## J2000 → of-date
const INTO_2000: int = 1  ## of-date → J2000


## Obliquity + nutation result (returned by e_tilt)
class Tilt extends RefCounted:
	var mobl: float   ## Mean obliquity (degrees)
	var tobl: float   ## True obliquity (degrees) = mobl + obliquity nutation
	var dpsi: float   ## Longitude nutation (arcseconds)
	var deps: float   ## Obliquity nutation (arcseconds)
	var ee: float     ## Equation of the equinoxes (seconds)


## Right ascension and declination (returned by vector2radec)
class RaDec extends RefCounted:
	var ra: float     ## Right ascension (hours)
	var dec: float    ## Declination (degrees)
	var dist: float   ## Distance (AU)


## Horizontal coordinates (returned by horizon)
class HorizonCoord extends RefCounted:
	var azimuth: float   ## Azimuth (degrees, N=0 E=90)
	var altitude: float  ## Altitude (degrees, includes atmospheric refraction)


## Ecliptic coordinates (returned by ecliptic)
class EclipticCoord extends RefCounted:
	var elon: float   ## Ecliptic longitude (degrees)
	var elat: float   ## Ecliptic latitude (degrees)


## IAU2000b truncated nutation model — 5 major terms manually expanded
## Writes nutation angles psi (longitude) and eps (obliquity) into the time object
## Uses is_nan() for cache detection, not == NAN (IEEE 754: NAN != NAN)
static func iau2000b(time: AstroTime.Moment) -> void:
	if not is_nan(time.psi):
		return

	var t: float = time.tt / 36525.0
	var elp: float = fmod(1287104.79305 + t * 129596581.0481, AstroTime.ASEC360) * AstroTime.ASEC2RAD
	var f: float = fmod(335779.526232 + t * 1739527262.8478, AstroTime.ASEC360) * AstroTime.ASEC2RAD
	var d: float = fmod(1072260.70369 + t * 1602961601.2090, AstroTime.ASEC360) * AstroTime.ASEC2RAD
	var om: float = fmod(450160.398036 - t * 6962890.5431, AstroTime.ASEC360) * AstroTime.ASEC2RAD

	# ── Term 1: Omega ──
	var sarg: float = sin(om)
	var carg: float = cos(om)
	var dp: float = (-172064161.0 - 174666.0 * t) * sarg + 33386.0 * carg
	var de: float = (92052331.0 + 9086.0 * t) * carg + 15377.0 * sarg

	# ── Term 2: 2(F - D + Omega) ──
	var arg: float = 2.0 * (f - d + om)
	sarg = sin(arg); carg = cos(arg)
	dp += (-13170906.0 - 1675.0 * t) * sarg - 13696.0 * carg
	de += (5730336.0 - 3015.0 * t) * carg - 4587.0 * sarg

	# ── Term 3: 2(F + Omega) ──
	arg = 2.0 * (f + om)
	sarg = sin(arg); carg = cos(arg)
	dp += (-2276413.0 - 234.0 * t) * sarg + 2796.0 * carg
	de += (978459.0 - 485.0 * t) * carg + 1374.0 * sarg

	# ── Term 4: 2*Omega ──
	arg = 2.0 * om
	sarg = sin(arg); carg = cos(arg)
	dp += (2074554.0 + 207.0 * t) * sarg - 698.0 * carg
	de += (-897492.0 + 470.0 * t) * carg - 291.0 * sarg

	# ── Term 5: l' (Sun mean anomaly) ──
	sarg = sin(elp); carg = cos(elp)
	dp += (1475877.0 - 3633.0 * t) * sarg + 11817.0 * carg
	de += (73871.0 - 184.0 * t) * carg - 1924.0 * sarg

	# Unit conversion: 0.1 microarcseconds → arcseconds
	time.psi = -0.000135 + (dp * 1.0e-7)
	time.eps = +0.000388 + (de * 1.0e-7)


## Mean obliquity of the ecliptic (degrees) — 5th-order polynomial
static func mean_obliq(tt: float) -> float:
	var t: float = tt / 36525.0
	var asec: float = (
		((((-0.0000000434 * t
			- 0.000000576) * t
			+ 0.00200340) * t
			- 0.0001831) * t
			- 46.836769) * t + 84381.406
	)
	return asec / 3600.0


## Combine nutation/obliquity info → {mobl, tobl, dpsi, deps, ee}
static func e_tilt(time: AstroTime.Moment) -> Tilt:
	iau2000b(time)
	var mobl: float = mean_obliq(time.tt)
	var result: Tilt = Tilt.new()
	result.mobl = mobl
	result.tobl = mobl + (time.eps / 3600.0)
	result.dpsi = time.psi
	result.deps = time.eps
	result.ee = time.psi * cos(mobl * AstroTime.DEG2RAD) / 15.0
	return result


## Earth Rotation Angle ERA (degrees)
static func era(ut: float) -> float:
	var thet1: float = 0.7790572732640 + 0.00273781191135448 * ut
	var thet3: float = fmod(ut, 1.0)
	var theta: float = 360.0 * fmod(thet1 + thet3, 1.0)
	if theta < 0.0:
		theta += 360.0
	return theta


## Greenwich Apparent Sidereal Time GAST (hours, includes equation of equinoxes ee)
## Uses is_nan() for cache detection
static func sidereal_time(time: AstroTime.Moment) -> float:
	if not is_nan(time.st):
		return time.st

	var t: float = time.tt / 36525.0
	var eqeq: float = 15.0 * e_tilt(time).ee
	var theta: float = era(time.ut)
	var st: float = (
		eqeq + 0.014506
		+ ((((- 0.0000000368 * t
			- 0.000029956) * t
			- 0.00000044) * t
			+ 1.3915817) * t
			+ 4612.156534) * t
	)

	var gst: float = fmod(st / 3600.0 + theta, 360.0) / 15.0
	if gst < 0.0:
		gst += 24.0

	time.st = gst
	return gst


## Precession rotation matrix 3x3 (returns flat Array, 9 elements, row-major)
static func precession_rot(tt: float, dir: int) -> Array[float]:
	var eps0: float = 84381.406
	var t: float = tt / 36525.0

	var psia: float = (
		((((- 0.0000000951 * t
			+ 0.000132851) * t
			- 0.00114045) * t
			- 1.0790069) * t
			+ 5038.481507) * t
	)

	var omegaa: float = (
		(((((+ 0.0000003337) * t
			- 0.000000467) * t
			- 0.00772503) * t
			+ 0.0512623) * t
			- 0.025754) * t + eps0
	)

	var chia: float = (
		((((- 0.0000000560 * t
			+ 0.000170663) * t
			- 0.00121197) * t
			- 2.3814292) * t
			+ 10.556403) * t
	)

	eps0 *= AstroTime.ASEC2RAD
	psia *= AstroTime.ASEC2RAD
	omegaa *= AstroTime.ASEC2RAD
	chia *= AstroTime.ASEC2RAD

	var sa: float = sin(eps0)
	var ca: float = cos(eps0)
	var sb: float = sin(-psia)
	var cb: float = cos(-psia)
	var sc: float = sin(-omegaa)
	var cc: float = cos(-omegaa)
	var sd: float = sin(chia)
	var cd: float = cos(chia)

	var xx: float = cd * cb - sb * sd * cc
	var yx: float = cd * sb * ca + sd * cc * cb * ca - sa * sd * sc
	var zx: float = cd * sb * sa + sd * cc * cb * sa + ca * sd * sc
	var xy: float = -sd * cb - sb * cd * cc
	var yy: float = -sd * sb * ca + cd * cc * cb * ca - sa * cd * sc
	var zy: float = -sd * sb * sa + cd * cc * cb * sa + ca * cd * sc
	var xz: float = sb * sc
	var yz: float = -sc * cb * ca - sa * cc
	var zz: float = -sc * cb * sa + cc * ca

	if dir == INTO_2000:
		# of-date → J2000 (transpose)
		return [xx, yx, zx, xy, yy, zy, xz, yz, zz] as Array[float]
	else:
		# J2000 → of-date
		return [xx, xy, xz, yx, yy, yz, zx, zy, zz] as Array[float]


## Nutation rotation matrix 3x3
## dir == FROM_2000: apply nutation (mean equator → true equator)
## dir == INTO_2000: remove nutation (true equator → mean equator)
static func nutation_rot(time: AstroTime.Moment, dir: int) -> Array[float]:
	var tilt: Tilt = e_tilt(time)
	var oblm: float = tilt.mobl * AstroTime.DEG2RAD
	var oblt: float = tilt.tobl * AstroTime.DEG2RAD
	var psi: float = tilt.dpsi * AstroTime.ASEC2RAD
	var cobm: float = cos(oblm)
	var sobm: float = sin(oblm)
	var cobt: float = cos(oblt)
	var sobt: float = sin(oblt)
	var cpsi: float = cos(psi)
	var spsi: float = sin(psi)

	var xx: float = cpsi
	var yx: float = -spsi * cobm
	var zx: float = -spsi * sobm
	var xy: float = spsi * cobt
	var yy: float = cpsi * cobm * cobt + sobm * sobt
	var zy: float = cpsi * sobm * cobt - cobm * sobt
	var xz: float = spsi * sobt
	var yz: float = cpsi * cobm * sobt - sobm * cobt
	var zz: float = cpsi * sobm * sobt + cobm * cobt

	if dir == FROM_2000:
		return [xx, xy, xz, yx, yy, yz, zx, zy, zz] as Array[float]
	else:
		return [xx, yx, zx, xy, yy, zy, xz, yz, zz] as Array[float]


## Vector3 x 3x3 matrix multiply — M^T * v (column-major multiply)
## Matrix is row-major flat Array [r0c0, r0c1, r0c2, r1c0, r1c1, r1c2, r2c0, r2c1, r2c2]
## but multiply takes each column dotted with vec — matches C original astronomy.c:1570-1575
static func rotate(vec: Vector3, rot: Array[float]) -> Vector3:
	return Vector3(
		rot[0] * vec.x + rot[3] * vec.y + rot[6] * vec.z,
		rot[1] * vec.x + rot[4] * vec.y + rot[7] * vec.z,
		rot[2] * vec.x + rot[5] * vec.y + rot[8] * vec.z,
	)


## J2000 → of-date (precession + nutation in one step)
static func j2000_to_ofdate(pos: Vector3, time: AstroTime.Moment) -> Vector3:
	var prec: Array[float] = precession_rot(time.tt, FROM_2000)
	var mean_pos: Vector3 = rotate(pos, prec)
	var nut: Array[float] = nutation_rot(time, FROM_2000)
	return rotate(mean_pos, nut)


## of-date → J2000 (reverse: remove nutation first, then precession)
static func ofdate_to_j2000(pos: Vector3, time: AstroTime.Moment) -> Vector3:
	var nut: Array[float] = nutation_rot(time, INTO_2000)
	var mean_pos: Vector3 = rotate(pos, nut)
	var prec: Array[float] = precession_rot(time.tt, INTO_2000)
	return rotate(mean_pos, prec)


## Ecliptic to equatorial (using given obliquity in degrees)
static func _ecl2equ_vec(obl_deg: float, ecl: Vector3) -> Vector3:
	var obl_rad: float = obl_deg * AstroTime.DEG2RAD
	var cos_obl: float = cos(obl_rad)
	var sin_obl: float = sin(obl_rad)
	return Vector3(
		ecl.x,
		ecl.y * cos_obl - ecl.z * sin_obl,
		ecl.y * sin_obl + ecl.z * cos_obl,
	)


## Equatorial to ecliptic (using obliquity in radians), returns ecliptic cartesian
static func _equ_to_ecl_vec(obliq_rad: float, pos: Vector3) -> Vector3:
	var cos_ob: float = cos(obliq_rad)
	var sin_ob: float = sin(obliq_rad)
	return Vector3(
		pos.x,
		pos.y * cos_ob + pos.z * sin_ob,
		-pos.y * sin_ob + pos.z * cos_ob,
	)


## J2000 equatorial → true ecliptic of-date (ECT) → {elon, elat} (degrees)
## Used for MoonPhase calculation
static func ecliptic(j2000_vec: Vector3, time: AstroTime.Moment) -> EclipticCoord:
	var tilt: Tilt = e_tilt(time)

	# J2000 → of-date mean equator (precession)
	var prec: Array[float] = precession_rot(time.tt, FROM_2000)
	var mean_pos: Vector3 = rotate(j2000_vec, prec)

	# Mean equator → true equator (nutation)
	var nut: Array[float] = nutation_rot(time, FROM_2000)
	var eqd_pos: Vector3 = rotate(mean_pos, nut)

	# True equator → true ecliptic (rotate by tobl)
	var ecl_vec: Vector3 = _equ_to_ecl_vec(tilt.tobl * AstroTime.DEG2RAD, eqd_pos)

	# Cartesian → spherical
	var xyproj: float = hypot(ecl_vec.x, ecl_vec.y)
	var elon: float = 0.0
	if xyproj > 0.0:
		elon = AstroTime.RAD2DEG * atan2(ecl_vec.y, ecl_vec.x)
		if elon < 0.0:
			elon += 360.0
	var elat: float = AstroTime.RAD2DEG * atan2(ecl_vec.z, xyproj)

	var result: EclipticCoord = EclipticCoord.new()
	result.elon = elon
	result.elat = elat
	return result


## Observer surface position → of-date cartesian (AU) — WGS84 ellipsoid
## st = sidereal time (hours)
static func terra(lat: float, lon: float, height: float, st: float) -> Vector3:
	var phi: float = lat * AstroTime.DEG2RAD
	var sinphi: float = sin(phi)
	var cosphi: float = cos(phi)
	var c: float = 1.0 / hypot(cosphi, sinphi * AstroTime.EARTH_FLATTENING)
	var s: float = c * (AstroTime.EARTH_FLATTENING * AstroTime.EARTH_FLATTENING)
	var ht_km: float = height / 1000.0
	var ach: float = AstroTime.EARTH_EQUATORIAL_RADIUS_KM * c + ht_km
	var ash: float = AstroTime.EARTH_EQUATORIAL_RADIUS_KM * s + ht_km
	var stlocl: float = (15.0 * st + lon) * AstroTime.DEG2RAD
	var sinst: float = sin(stlocl)
	var cosst: float = cos(stlocl)

	return Vector3(
		ach * cosphi * cosst / AstroTime.KM_PER_AU,
		ach * cosphi * sinst / AstroTime.KM_PER_AU,
		ash * sinphi / AstroTime.KM_PER_AU,
	)


## Observer J2000 position (of-date → remove nutation → remove precession → J2000)
static func geo_pos(time: AstroTime.Moment, lat: float, lon: float, height: float) -> Vector3:
	var gast: float = sidereal_time(time)
	var pos1: Vector3 = terra(lat, lon, height, gast)
	var nut: Array[float] = nutation_rot(time, INTO_2000)
	var pos2: Vector3 = rotate(pos1, nut)
	var prec: Array[float] = precession_rot(time.tt, INTO_2000)
	return rotate(pos2, prec)


## Cartesian → {ra, dec, dist} (ra in hours, dec in degrees, dist in AU)
static func vector2radec(pos: Vector3) -> RaDec:
	var xyproj: float = pos.x * pos.x + pos.y * pos.y
	var result: RaDec = RaDec.new()
	result.dist = sqrt(xyproj + pos.z * pos.z)

	if xyproj < 1e-16:
		result.ra = 0.0
		result.dec = -90.0 if pos.z < 0.0 else 90.0
	else:
		result.ra = AstroTime.RAD2HOUR * atan2(pos.y, pos.x)
		if result.ra < 0.0:
			result.ra += 24.0
		result.dec = AstroTime.RAD2DEG * atan2(pos.z, sqrt(xyproj))

	return result


## Rotate around Z axis (used for Earth rotation correction)
static func _spin(angle_deg: float, pos: Vector3) -> Vector3:
	var angr: float = angle_deg * AstroTime.DEG2RAD
	var cosang: float = cos(angr)
	var sinang: float = sin(angr)
	return Vector3(
		cosang * pos.x + sinang * pos.y,
		-sinang * pos.x + cosang * pos.y,
		pos.z,
	)


## Equatorial → horizontal coordinates {azimuth, altitude} (degrees, with refraction)
## ra = right ascension (hours), dec = declination (degrees)
## Note: ra/dec must be of-date, not J2000
static func horizon(
	time: AstroTime.Moment, lat: float, lon: float,
	ra: float, dec: float
) -> HorizonCoord:
	var latrad: float = lat * AstroTime.DEG2RAD
	var lonrad: float = lon * AstroTime.DEG2RAD
	var decrad: float = dec * AstroTime.DEG2RAD
	var rarad: float = ra * AstroTime.HOUR2RAD

	var sinlat: float = sin(latrad)
	var coslat: float = cos(latrad)
	var sinlon: float = sin(lonrad)
	var coslon: float = cos(lonrad)
	var sindc: float = sin(decrad)
	var cosdc: float = cos(decrad)
	var sinra: float = sin(rarad)
	var cosra: float = cos(rarad)

	# Zenith, north, west orthogonal basis vectors (before Earth rotation)
	var uze: Vector3 = Vector3(coslat * coslon, coslat * sinlon, sinlat)
	var une: Vector3 = Vector3(-sinlat * coslon, -sinlat * sinlon, coslat)
	var uwe: Vector3 = Vector3(sinlon, -coslon, 0.0)

	# Apply Earth rotation via sidereal time
	var spin_angle: float = -15.0 * sidereal_time(time)
	var uz: Vector3 = _spin(spin_angle, uze)
	var un: Vector3 = _spin(spin_angle, une)
	var uw: Vector3 = _spin(spin_angle, uwe)

	# Celestial direction vector
	var p: Vector3 = Vector3(cosdc * cosra, cosdc * sinra, sindc)

	# Project onto horizontal coordinate system
	var pn: float = p.dot(un)
	var pw: float = p.dot(uw)
	var pz: float = p.dot(uz)

	var proj: float = hypot(pn, pw)
	var az: float = 0.0
	if proj > 0.0:
		az = -atan2(pw, pn) * AstroTime.RAD2DEG
		if az < 0.0:
			az += 360.0

	# Zenith distance → altitude
	var zd: float = atan2(proj, pz) * AstroTime.RAD2DEG
	var altitude: float = 90.0 - zd

	# Atmospheric refraction correction
	altitude += refraction(altitude)

	var result: HorizonCoord = HorizonCoord.new()
	result.azimuth = az
	result.altitude = altitude
	return result


## Atmospheric refraction correction (degrees) — Saemundsson formula
## Max +34 arcmin (~0.567 deg) at low altitude; affects sunrise/sunset and low-altitude moon
static func refraction(altitude: float) -> float:
	if altitude < -90.0 or altitude > 90.0:
		return 0.0

	var hd: float = altitude
	if hd < -1.0:
		hd = -1.0

	var refr: float = (1.02 / tan((hd + 10.3 / (hd + 5.11)) * AstroTime.DEG2RAD)) / 60.0

	# Gradually taper below -1 deg to avoid altitude < -90 deg
	if altitude < -1.0:
		refr *= (altitude + 90.0) / 89.0

	return refr


## hypot helper (GDScript has no built-in hypot)
static func hypot(x: float, y: float) -> float:
	return sqrt(x * x + y * y)
