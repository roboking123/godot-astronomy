class_name AstroEngine
## Astronomy engine facade — combines sun/moon/coordinate pipelines into a single entry point
## Ported from cosinekitty/astronomy (MIT License)


## Result returned by compute()
class CelestialResult extends RefCounted:
	var sun_az: float         ## Sun azimuth (degrees, N=0 E=90)
	var sun_alt: float        ## Sun altitude (degrees, includes atmospheric refraction)
	var sun_dist: float       ## Sun distance (AU)
	var moon_az: float        ## Moon azimuth (degrees, N=0 E=90)
	var moon_alt: float       ## Moon altitude (degrees, includes atmospheric refraction)
	var moon_dist_km: float   ## Moon distance (km)
	var moon_diam_deg: float  ## Moon apparent diameter (degrees)
	var libration_elon: float ## Libration in longitude (degrees)
	var libration_elat: float ## Libration in latitude (degrees)
	var moon_phase_deg: float ## Moon phase (degrees, 0=new moon, 180=full moon)
	var moon_pole_equ: Vector3  ## Moon north pole direction (of-date equatorial cartesian)
	var sidereal_time: float  ## GAST sidereal time (hours)
	var moon_ra: float        ## Moon right ascension (hours, of-date)
	var moon_dec: float       ## Moon declination (degrees, of-date)
	var geocentric_elongation: float  ## Geocentric sun-moon elongation (degrees, for eclipse calculations)


## Compute sun/moon astronomical data for a given time and location
static func compute(
	year: int, month: int, day: int,
	hour: int, minute: int, sec: float,
	lat: float, lon: float
) -> CelestialResult:
	var time: AstroTime.Moment = AstroTime.make_time(year, month, day, hour, minute, sec)

	# ── Sun (J2000 geocentric, light-time corrected) ──
	var sun_j2000: Vector3 = AstroSun.sun_position(time)
	var sun_dist: float = sun_j2000.length()

	# ── Moon (J2000 geocentric + calc_moon intermediate results) ──
	var geo: AstroMoon.GeoMoonResult = AstroMoon.geo_moon(time)
	var moon_j2000: Vector3 = geo.j2000

	# ── Topocentric correction (geocentric -> observer viewpoint) ──
	var observer_j2000: Vector3 = AstroCoords.geo_pos(time, lat, lon, 0.0)
	var sun_topo_j2000: Vector3 = sun_j2000 - observer_j2000   ## Sun parallax ~0.003 deg
	var moon_topo_j2000: Vector3 = moon_j2000 - observer_j2000  ## Moon parallax ~1 deg

	# ── J2000 → of-date → RA/Dec → Horizon ──
	var sun_ofdate: Vector3 = AstroCoords.j2000_to_ofdate(sun_topo_j2000, time)
	var sun_rd: AstroCoords.RaDec = AstroCoords.vector2radec(sun_ofdate)
	var sun_hor: AstroCoords.HorizonCoord = AstroCoords.horizon(time, lat, lon, sun_rd.ra, sun_rd.dec)

	var moon_ofdate: Vector3 = AstroCoords.j2000_to_ofdate(moon_topo_j2000, time)
	var moon_rd: AstroCoords.RaDec = AstroCoords.vector2radec(moon_ofdate)
	var moon_hor: AstroCoords.HorizonCoord = AstroCoords.horizon(time, lat, lon, moon_rd.ra, moon_rd.dec)

	# ── Libration + apparent diameter + lunar distance ──
	var lib: AstroMoon.LibrationResult = AstroMoon.libration(time, geo.ecliptic, geo.tobl)

	# ── Moon phase (requires true ecliptic of-date coordinates) ──
	var phase: float = _moon_phase(sun_j2000, moon_j2000, time)

	var r := CelestialResult.new()
	r.sun_az = sun_hor.azimuth
	r.sun_alt = sun_hor.altitude
	r.sun_dist = sun_dist
	r.moon_az = moon_hor.azimuth
	r.moon_alt = moon_hor.altitude
	r.moon_dist_km = lib.dist_km
	r.moon_diam_deg = lib.diam_deg
	r.libration_elon = lib.elon
	r.libration_elat = lib.elat
	r.moon_phase_deg = phase
	r.moon_pole_equ = lib.pole_equ
	r.sidereal_time = AstroCoords.sidereal_time(time)
	r.moon_ra = moon_rd.ra
	r.moon_dec = moon_rd.dec
	# Geocentric sun-moon elongation (for eclipse geometry; avoids ~1 deg topocentric parallax offset)
	var geo_dot: float = sun_j2000.normalized().dot(moon_j2000.normalized())
	r.geocentric_elongation = rad_to_deg(acos(clampf(geo_dot, -1.0, 1.0)))
	return r


## Moon phase = moon true ecliptic longitude - sun true ecliptic longitude (of-date ECT)
## Placed here to avoid cross-module dependency AstroMoon -> AstroSun
static func _moon_phase(
	sun_j2000: Vector3, moon_j2000: Vector3, time: AstroTime.Moment
) -> float:
	var sun_ecl: AstroCoords.EclipticCoord = AstroCoords.ecliptic(sun_j2000, time)
	var moon_ecl: AstroCoords.EclipticCoord = AstroCoords.ecliptic(moon_j2000, time)
	return AstroTime.normalize_longitude(moon_ecl.elon - sun_ecl.elon)
