class_name AstroSearch
## Astronomical event search — rise/set, moon phase, generic root-finding
## Ported from cosinekitty/astronomy (MIT License)


const _SECONDS_PER_DAY: float = 86400.0
const _SOLAR_DAYS_PER_SIDEREAL_DAY: float = 1.00273781191135448
const _REFRACTION_NEAR_HORIZON: float = 34.0 / 60.0  # degrees
const _SUN_RADIUS_AU: float = 695700.0 / 1.4959787069098932e+8
const _MOON_RADIUS_AU: float = 1737.4 / 1.4959787069098932e+8

enum Direction { RISE = 1, SET = -1 }
enum Body { SUN, MOON, MERCURY, VENUS, MARS, JUPITER, SATURN, URANUS, NEPTUNE }


# ─── Generic root-finding ───


## Generic ascending root search with bisection + quadratic interpolation.
## func_callback takes (AstroTime.Moment) -> float.
## Returns the AstroTime.Moment where func crosses zero ascending, or null.
static func search(
	func_callback: Callable,
	t1: AstroTime.Moment, t2: AstroTime.Moment,
	dt_tolerance_seconds: float
) -> Variant:
	var dt_days: float = absf(dt_tolerance_seconds / _SECONDS_PER_DAY)
	var f1: float = func_callback.call(t1)
	var f2: float = func_callback.call(t2)

	for iter: int in 20:
		var dt: float = (t2.ut - t1.ut) / 2.0
		var tmid: AstroTime.Moment = AstroTime.time_from_days(t1.ut + dt)
		if absf(dt) < dt_days:
			return tmid

		var fmid: float = func_callback.call(tmid)

		# Try quadratic interpolation
		var q_result: Variant = _quad_interp(tmid.ut, t2.ut - tmid.ut, f1, fmid, f2)
		if q_result != null:
			var q_ut: float = q_result[0]
			var q_df_dt: float = q_result[1]
			var tq: AstroTime.Moment = AstroTime.time_from_days(q_ut)
			var fq: float = func_callback.call(tq)
			if q_df_dt != 0.0:
				var dt_guess: float = absf(fq / q_df_dt)
				if dt_guess < dt_days:
					return tq
				dt_guess *= 1.2
				if dt_guess < dt / 10.0:
					var tleft: AstroTime.Moment = AstroTime.time_from_days(tq.ut - dt_guess)
					var tright: AstroTime.Moment = AstroTime.time_from_days(tq.ut + dt_guess)
					if (tleft.ut - t1.ut) * (tleft.ut - t2.ut) < 0.0:
						if (tright.ut - t1.ut) * (tright.ut - t2.ut) < 0.0:
							var fleft: float = func_callback.call(tleft)
							var fright: float = func_callback.call(tright)
							if fleft < 0.0 and fright >= 0.0:
								f1 = fleft; f2 = fright
								t1 = tleft; t2 = tright
								continue

		# Fallback: bisection
		if f1 < 0.0 and fmid >= 0.0:
			t2 = tmid; f2 = fmid
		elif fmid < 0.0 and f2 >= 0.0:
			t1 = tmid; f1 = fmid
		else:
			return null

	return null  # failed to converge


## Quadratic interpolation helper for search().
## Returns [root_ut, derivative] or null.
static func _quad_interp(
	tm: float, dt: float,
	fa: float, fm: float, fb: float
) -> Variant:
	var Q: float = (fb + fa) / 2.0 - fm
	var R: float = (fb - fa) / 2.0
	var S: float = fm

	if absf(Q) < 1.0e-20:
		# Not a parabola — try linear
		if absf(R) < 1.0e-20:
			return null
		var x: float = -S / R
		if x < -1.0 or x > 1.0:
			return null
		return [tm + x * dt, R / dt]

	var u: float = R / (2.0 * Q)
	var disc: float = u * u - S / Q
	if disc < 0.0:
		return null
	var ru: float = sqrt(disc)
	var x1: float = -u + ru
	var x2: float = -u - ru

	# Pick root closest to center and within [-1, 1]
	var x: float = NAN
	if -1.0 <= x1 and x1 <= 1.0:
		if -1.0 <= x2 and x2 <= 1.0:
			# Both valid — pick closest to 0
			x = x1 if absf(x1) <= absf(x2) else x2
		else:
			x = x1
	elif -1.0 <= x2 and x2 <= 1.0:
		x = x2
	else:
		return null

	var t: float = tm + x * dt
	var df_dt: float = (2.0 * Q * x + R) / dt
	return [t, df_dt]


# ─── Moon phase search ───


## Search for the time when the moon reaches a specific phase angle.
## target_lon: 0=new moon, 90=first quarter, 180=full moon, 270=third quarter.
## Returns AstroTime.Moment or null.
static func search_moon_phase(
	target_lon: float,
	start_time: AstroTime.Moment,
	limit_days: float
) -> Variant:
	var uncertainty: float = 1.5
	var ya: float = _moon_offset(target_lon, start_time)
	var dt1: float
	var dt2: float

	if limit_days < 0.0:
		if ya < 0.0:
			ya += 360.0
		var est_dt: float = -(AstroTime.MEAN_SYNODIC_MONTH * ya) / 360.0
		dt2 = est_dt + uncertainty
		if dt2 < limit_days:
			return null
		dt1 = maxf(limit_days, est_dt - uncertainty)
	else:
		if ya > 0.0:
			ya -= 360.0
		var est_dt: float = -(AstroTime.MEAN_SYNODIC_MONTH * ya) / 360.0
		dt1 = est_dt - uncertainty
		if dt1 > limit_days:
			return null
		dt2 = minf(limit_days, est_dt + uncertainty)

	var t1: AstroTime.Moment = AstroTime.time_from_days(start_time.ut + dt1)
	var t2: AstroTime.Moment = AstroTime.time_from_days(start_time.ut + dt2)
	return search(_moon_offset_callable(target_lon), t1, t2, 0.1)


## Compute moon ecliptic longitude offset from target phase angle.
## Returns value in [-180, +180).
static func _moon_offset(target_lon: float, time: AstroTime.Moment) -> float:
	var phase: float = AstroEngine.moon_phase(
		AstroSun.sun_position(time),
		AstroMoon.geo_moon(time).j2000,
		time
	)
	return AstroTime.longitude_offset(phase - target_lon)


## Returns a Callable that captures target_lon for use with search().
static func _moon_offset_callable(target_lon: float) -> Callable:
	return func(time: AstroTime.Moment) -> float:
		return _moon_offset(target_lon, time)


# ─── Rise/set search ───


## Search for the next rise or set of a celestial body.
## Returns AstroTime.Moment or null.
static func search_rise_set(
	body: Body, direction: Direction,
	lat: float, lon: float, height: float,
	start_time: AstroTime.Moment, limit_days: float
) -> Variant:
	var body_radius_au: float = 0.0
	if body == Body.SUN:
		body_radius_au = _SUN_RADIUS_AU
	elif body == Body.MOON:
		body_radius_au = _MOON_RADIUS_AU

	var atmos: float = _atmosphere_density(height)
	var altitude: float = -(_REFRACTION_NEAR_HORIZON * atmos)

	return _search_altitude(
		body, direction, lat, lon, height,
		start_time, limit_days, body_radius_au, altitude
	)


## U.S. Standard Atmosphere density relative to sea level.
## Used to scale atmospheric refraction by elevation.
static func _atmosphere_density(elevation_meters: float) -> float:
	var P0: float = 101325.0
	var T0: float = 288.15
	var T1: float = 216.65
	var pressure: float
	var temperature: float

	if elevation_meters <= 11000.0:
		temperature = T0 - 0.0065 * elevation_meters
		pressure = P0 * pow(T0 / temperature, -5.25577)
	elif elevation_meters <= 20000.0:
		temperature = T1
		pressure = 22632.0 * exp(-0.00015768832 * (elevation_meters - 11000.0))
	else:
		temperature = T1 + 0.001 * (elevation_meters - 20000.0)
		pressure = 5474.87 * pow(T1 / temperature, 34.16319)

	return (pressure / temperature) / (P0 / T0)


## Maximum altitude change rate [degrees/day] for a body at given latitude.
## Used to prune impossible branches in _find_ascent().
static func _max_altitude_slope(body: Body, latitude: float) -> float:
	var deriv_ra: float
	var deriv_dec: float
	match body:
		Body.MOON:
			deriv_ra = 4.5; deriv_dec = 8.2
		Body.SUN:
			deriv_ra = 0.8; deriv_dec = 0.5
		Body.MERCURY:
			deriv_ra = -1.6; deriv_dec = 1.0
		Body.VENUS:
			deriv_ra = -0.8; deriv_dec = 0.6
		Body.MARS:
			deriv_ra = -0.5; deriv_dec = 0.4
		_:  # Jupiter, Saturn, Uranus, Neptune
			deriv_ra = -0.2; deriv_dec = 0.2

	var latrad: float = deg_to_rad(latitude)
	return absf(((360.0 / _SOLAR_DAYS_PER_SIDEREAL_DAY) - deriv_ra) * cos(latrad)) + absf(deriv_dec * sin(latrad))


## Compute altitude difference for rise/set search.
## Positive when the body is above target_altitude (for Direction.RISE)
## or below target_altitude (for Direction.SET).
static func _altdiff(
	body: Body, direction: Direction,
	lat: float, lon: float, height: float,
	body_radius_au: float, target_altitude: float,
	time: AstroTime.Moment
) -> float:
	# Get body's geocentric equatorial position
	var geo_pos: Vector3
	var dist: float
	match body:
		Body.SUN:
			geo_pos = AstroSun.sun_position(time)
			dist = geo_pos.length()
		Body.MOON:
			var mr: AstroMoon.GeoMoonResult = AstroMoon.geo_moon(time)
			geo_pos = mr.j2000
			dist = geo_pos.length()
		_:
			# Body→Planet 對應表（Body 沒有 EARTH，Planet 有）
			var _BODY_TO_PLANET: Dictionary = {
				Body.MERCURY: AstroPlanets.Planet.MERCURY,
				Body.VENUS: AstroPlanets.Planet.VENUS,
				Body.MARS: AstroPlanets.Planet.MARS,
				Body.JUPITER: AstroPlanets.Planet.JUPITER,
				Body.SATURN: AstroPlanets.Planet.SATURN,
				Body.URANUS: AstroPlanets.Planet.URANUS,
				Body.NEPTUNE: AstroPlanets.Planet.NEPTUNE,
			}
			geo_pos = AstroPlanets.geo_position(_BODY_TO_PLANET[body] as AstroPlanets.Planet, time)
			dist = geo_pos.length()

	# Topocentric correction — subtract observer position from geocentric
	var observer: Vector3 = AstroCoords.geo_pos(time, lat, lon, height)
	var topo: Vector3 = geo_pos - observer

	# Convert to horizon coordinates
	var ofdate: Vector3 = AstroCoords.j2000_to_ofdate(topo, time)
	var rd: AstroCoords.RaDec = AstroCoords.vector2radec(ofdate)
	var hor: AstroCoords.HorizonCoord = AstroCoords.horizon(time, lat, lon, rd.ra, rd.dec)

	# Add body angular radius (upper limb tangent)
	var altitude: float = hor.altitude
	if body_radius_au > 0.0 and dist > 0.0:
		altitude += rad_to_deg(asin(minf(body_radius_au / dist, 1.0)))

	return float(direction) * (altitude - target_altitude)


## Recursively find an ascending zero-crossing in altitude difference.
## Returns [t1, t2, a1, a2] bracket or null.
static func _find_ascent(
	depth: int,
	body: Body, direction: Direction,
	lat: float, lon: float, height: float,
	body_radius_au: float, target_altitude: float, max_deriv: float,
	t1: AstroTime.Moment, t2: AstroTime.Moment,
	a1: float, a2: float
) -> Variant:
	if a1 < 0.0 and a2 >= 0.0:
		return [t1, t2, a1, a2]  # trivial success

	if a1 >= 0.0 and a2 < 0.0:
		return null  # trivial failure (Nyquist)

	if depth > 17:
		return null  # safety valve

	var dt: float = t2.ut - t1.ut
	if dt * _SECONDS_PER_DAY < 1.0:
		return null

	var da: float = minf(absf(a1), absf(a2))
	if da > max_deriv * (dt / 2.0):
		return null  # prune: can't reach zero fast enough

	var tmid: AstroTime.Moment = AstroTime.time_from_days((t1.ut + t2.ut) / 2.0)
	var amid: float = _altdiff(body, direction, lat, lon, height, body_radius_au, target_altitude, tmid)

	var left: Variant = _find_ascent(
		depth + 1, body, direction, lat, lon, height,
		body_radius_au, target_altitude, max_deriv,
		t1, tmid, a1, amid
	)
	if left != null:
		return left
	return _find_ascent(
		depth + 1, body, direction, lat, lon, height,
		body_radius_au, target_altitude, max_deriv,
		tmid, t2, amid, a2
	)


## Internal altitude search — scans in RISE_SET_DT steps, finds bracket, then refines.
static func _search_altitude(
	body: Body, direction: Direction,
	lat: float, lon: float, height: float,
	start_time: AstroTime.Moment, limit_days: float,
	body_radius_au: float, target_altitude: float
) -> Variant:
	var RISE_SET_DT: float = 0.42  # ~10 hours, Nyquist-safe for 22-hour period
	var max_deriv: float = _max_altitude_slope(body, lat)

	var t1: AstroTime.Moment = start_time
	var t2: AstroTime.Moment = start_time
	var a1: float = _altdiff(body, direction, lat, lon, height, body_radius_au, target_altitude, t1)
	var a2: float = a1

	var max_steps: int = ceili(absf(limit_days) / RISE_SET_DT) + 2
	for _step: int in max_steps:
		if limit_days < 0.0:
			t1 = AstroTime.time_from_days(t2.ut - RISE_SET_DT)
			a1 = _altdiff(body, direction, lat, lon, height, body_radius_au, target_altitude, t1)
		else:
			t2 = AstroTime.time_from_days(t1.ut + RISE_SET_DT)
			a2 = _altdiff(body, direction, lat, lon, height, body_radius_au, target_altitude, t2)

		var ascent: Variant = _find_ascent(
			0, body, direction, lat, lon, height,
			body_radius_au, target_altitude, max_deriv,
			t1, t2, a1, a2
		)
		if ascent != null:
			var callback: Callable = func(time: AstroTime.Moment) -> float:
				return _altdiff(body, direction, lat, lon, height, body_radius_au, target_altitude, time)
			var result: Variant = search(callback, ascent[0], ascent[1], 0.1)
			if result != null:
				if limit_days < 0.0:
					if result.ut < start_time.ut + limit_days:
						return null
				else:
					if result.ut > start_time.ut + limit_days:
						return null
				return result
			return null  # should not happen

		if limit_days < 0.0:
			if t1.ut < start_time.ut + limit_days:
				return null
			t2 = t1; a2 = a1
		else:
			if t2.ut > start_time.ut + limit_days:
				return null
			t1 = t2; a1 = a2
	return null
