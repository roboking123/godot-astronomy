@tool
class_name CelestialBody
## Main astronomy node — set location and time, get sky data every frame.
## Drop into your scene, configure latitude/longitude, and read the state.
extends Node

# ─── Location ───

@export_group("Location")
@export_range(-90.0, 90.0, 0.01, "suffix:°") var latitude: float = 0.0:
	set(v): latitude = v; _dirty = true
@export_range(-180.0, 180.0, 0.01, "suffix:°") var longitude: float = 0.0:
	set(v): longitude = v; _dirty = true
@export_range(0.0, 10000.0, 1.0, "suffix:m") var elevation: float = 0.0

# ─── Time ───

@export_group("Time")
## Use system clock as time source
@export var use_system_time: bool = true
## Starting date/time (used when use_system_time = false)
@export var start_year: int = 2026
@export var start_month: int = 1
@export var start_day: int = 1
@export var start_hour: int = 12
@export var start_minute: int = 0
## Time multiplier. 1.0 = realtime, 60.0 = 1 sec per minute, 3600.0 = 1 sec per hour
@export_range(-86400.0, 86400.0, 1.0) var time_scale: float = 1.0
## Pause time progression
@export var paused: bool = false

# ─── Options ───

@export_group("Options")
## Also compute planet positions each frame (heavier)
@export var compute_planets: bool = false
## Attached sky adapters (called every frame with CelestialState)
@export var adapters: Array[SkyAdapter] = []

# ─── Signals ───

signal sunrise
signal sunset
signal moon_phase_changed(phase_name: String)

# ─── Public state ───

## Current sky state — read this from other scripts
var state: CelestialState = CelestialState.new()

# ─── Internal ───

var _elapsed_days: float = 0.0
var _base_ut: float = 0.0
var _dirty: bool = true
var _prev_sun_above: bool = false
var _prev_phase_name: String = ""
var _initialized: bool = false

var _PLANET_NAMES: Array[String] = ["Mercury", "Venus", "Mars", "Jupiter", "Saturn", "Uranus", "Neptune"]
var _PLANET_ENUMS: Array[int] = [0, 1, 3, 4, 5, 6, 7]  # AstroPlanets.Planet values (skip Earth=2)


func _ready() -> void:
	_reset_base_time()
	_initialized = true


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if not paused:
		_elapsed_days += delta * time_scale / 86400.0

	_update_state()


## Set time programmatically (also switches off system time)
func set_datetime(year: int, month: int, day: int, hour: int = 12, minute: int = 0, sec: float = 0.0) -> void:
	use_system_time = false
	start_year = year; start_month = month; start_day = day
	start_hour = hour; start_minute = minute
	_base_ut = AstroTime.make_time(year, month, day, hour, minute, sec).ut
	_elapsed_days = 0.0
	_dirty = true


## Jump forward/backward in time
func advance_time(days: float) -> void:
	_elapsed_days += days
	_dirty = true


## Get the current simulated UT as a Moment
func get_moment() -> AstroTime.Moment:
	return AstroTime.time_from_days(_current_ut())


# ─── Internal ───


func _reset_base_time() -> void:
	if use_system_time:
		_base_ut = 0.0
	else:
		_base_ut = AstroTime.make_time(
			start_year, start_month, start_day,
			start_hour, start_minute, 0.0
		).ut
	_elapsed_days = 0.0
	_dirty = true


func _current_ut() -> float:
	if use_system_time:
		var now: Dictionary = Time.get_datetime_dict_from_system()
		var sys_time: AstroTime.Moment = AstroTime.make_time(
			now.year, now.month, now.day,
			now.hour, now.minute, float(now.second)
		)
		return sys_time.ut + _elapsed_days
	return _base_ut + _elapsed_days


func _update_state() -> void:
	var time: AstroTime.Moment = AstroTime.time_from_days(_current_ut())
	var s: CelestialState = state

	# ── Sun ──
	var sun_j2000: Vector3 = AstroSun.sun_position(time)
	var observer_j2000: Vector3 = AstroCoords.geo_pos(time, latitude, longitude, elevation)
	var sun_topo: Vector3 = sun_j2000 - observer_j2000
	var sun_ofdate: Vector3 = AstroCoords.j2000_to_ofdate(sun_topo, time)
	var sun_rd: AstroCoords.RaDec = AstroCoords.vector2radec(sun_ofdate)
	var sun_hor: AstroCoords.HorizonCoord = AstroCoords.horizon(time, latitude, longitude, sun_rd.ra, sun_rd.dec)

	s.sun_azimuth = sun_hor.azimuth
	s.sun_altitude = sun_hor.altitude
	s.sun_distance_au = sun_j2000.length()
	s.sun_direction = CelestialState._az_alt_to_direction(sun_hor.azimuth, sun_hor.altitude)
	s.sun_energy = CelestialState._altitude_to_energy(sun_hor.altitude)

	# ── Moon ──
	var geo: AstroMoon.GeoMoonResult = AstroMoon.geo_moon(time)
	var moon_topo: Vector3 = geo.j2000 - observer_j2000
	var moon_ofdate: Vector3 = AstroCoords.j2000_to_ofdate(moon_topo, time)
	var moon_rd: AstroCoords.RaDec = AstroCoords.vector2radec(moon_ofdate)
	var moon_hor: AstroCoords.HorizonCoord = AstroCoords.horizon(time, latitude, longitude, moon_rd.ra, moon_rd.dec)
	var lib: AstroMoon.LibrationResult = AstroMoon.libration(time, geo.ecliptic, geo.tobl)

	s.moon_azimuth = moon_hor.azimuth
	s.moon_altitude = moon_hor.altitude
	s.moon_distance_km = lib.dist_km
	s.moon_diameter_deg = lib.diam_deg
	s.moon_direction = CelestialState._az_alt_to_direction(moon_hor.azimuth, moon_hor.altitude)

	var phase: float = AstroEngine._moon_phase(sun_j2000, geo.j2000, time)
	s.moon_phase_deg = phase
	s.moon_phase_name = CelestialState._phase_name(phase)
	s.moon_illumination = CelestialState._phase_to_illumination(phase)

	# ── Sky condition ──
	s.is_day = sun_hor.altitude > 0.0
	s.is_civil_twilight = sun_hor.altitude <= 0.0 and sun_hor.altitude > -6.0
	s.is_nautical_twilight = sun_hor.altitude <= -6.0 and sun_hor.altitude > -12.0
	s.is_astronomical_twilight = sun_hor.altitude <= -12.0 and sun_hor.altitude > -18.0
	s.is_night = sun_hor.altitude <= -18.0
	s.sky_darkness = CelestialState._altitude_to_darkness(sun_hor.altitude)

	# ── Time ──
	s.sidereal_time = AstroCoords.sidereal_time(time)
	s.julian_day = time.ut + 2451545.0

	# ── Planets ──
	if compute_planets:
		s.planet_directions.clear()
		s.planet_altitudes.clear()
		for i: int in _PLANET_NAMES.size():
			var planet_enum: int = _PLANET_ENUMS[i]
			var pj: Vector3 = AstroPlanets.geo_position(planet_enum as AstroPlanets.Planet, time)
			var pt: Vector3 = pj - observer_j2000
			var po: Vector3 = AstroCoords.j2000_to_ofdate(pt, time)
			var prd: AstroCoords.RaDec = AstroCoords.vector2radec(po)
			var phor: AstroCoords.HorizonCoord = AstroCoords.horizon(time, latitude, longitude, prd.ra, prd.dec)
			s.planet_directions[_PLANET_NAMES[i]] = CelestialState._az_alt_to_direction(phor.azimuth, phor.altitude)
			s.planet_altitudes[_PLANET_NAMES[i]] = phor.altitude

	# ── Signals ──
	var sun_above: bool = sun_hor.altitude > 0.0
	if _initialized:
		if sun_above and not _prev_sun_above:
			sunrise.emit()
		elif not sun_above and _prev_sun_above:
			sunset.emit()
		if s.moon_phase_name != _prev_phase_name and _prev_phase_name != "":
			moon_phase_changed.emit(s.moon_phase_name)
	_prev_sun_above = sun_above
	_prev_phase_name = s.moon_phase_name

	# ── Adapters ──
	for adapter: SkyAdapter in adapters:
		if adapter != null:
			adapter.apply(s)

	_dirty = false
