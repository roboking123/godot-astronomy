@tool
class_name CelestialBody
## Main astronomy node — set location and time, get sky data every frame.
## Drop into your scene, assign lights, done.
extends Node

# ─── Location ───

@export_group("Location")
@export_range(-180.0, 180.0, 0.01, "suffix:°") var longitude: float = 121.56:
	set(v): longitude = v; _dirty = true
@export_range(-90.0, 90.0, 0.01, "suffix:°") var latitude: float = 25.03:
	set(v): latitude = v; _dirty = true
@export_range(0.0, 10000.0, 1.0, "suffix:m") var elevation: float = 0.0

# ─── Lighting (drag your lights here) ───

@export_group("Lighting")
## Drag a DirectionalLight3D here — it will follow the sun automatically
@export var sun_light: DirectionalLight3D
## Drag a DirectionalLight3D here — it will follow the moon automatically
@export var moon_light: DirectionalLight3D
## Sun color at high altitude
@export var sun_color_day: Color = Color(1.0, 0.95, 0.9)
## Sun color near horizon
@export var sun_color_horizon: Color = Color(1.0, 0.6, 0.3)
## Sun maximum light energy
@export_range(0.0, 10.0, 0.1) var sun_max_energy: float = 1.0
## Moon light color
@export var moon_color: Color = Color(0.6, 0.65, 0.8)
## Moon maximum light energy (at full moon, high altitude)
@export_range(0.0, 2.0, 0.01) var moon_max_energy: float = 0.15

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
## Also compute planet positions each frame (costs more)
@export var compute_planets: bool = false
## Sky adapters for advanced integrations (most users don't need this)
@export var adapters: Array[SkyAdapter] = []

# ─── Live Status (read-only, visible in Inspector) ───

@export_group("Status")
@export_storage var _status_sun: String = ""
@export_storage var _status_moon: String = ""
@export_storage var _status_sky: String = ""

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
var _editor_update_timer: float = 0.0

var _PLANET_NAMES: Array[String] = ["Mercury", "Venus", "Mars", "Jupiter", "Saturn", "Uranus", "Neptune"]
var _PLANET_ENUMS: Array[int] = [0, 1, 3, 4, 5, 6, 7]


func _ready() -> void:
	_reset_base_time()
	if not Engine.is_editor_hint():
		_initialized = true


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		# Editor preview: update every 0.5 sec to save CPU
		_editor_update_timer += delta
		if _editor_update_timer < 0.5 and not _dirty:
			return
		_editor_update_timer = 0.0
		_update_state()
		_update_status_strings()
		return

	if not paused:
		_elapsed_days += delta * time_scale / 86400.0

	_update_state()
	_apply_lights()


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
	if not Engine.is_editor_hint():
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


func _apply_lights() -> void:
	var s: CelestialState = state

	if sun_light != null:
		# Direction: light shines FROM the sun toward the scene
		sun_light.basis = Basis.looking_at(-s.sun_direction)
		# Color: warm near horizon, neutral at high altitude
		if s.sun_altitude > 10.0:
			sun_light.light_color = sun_color_day
		elif s.sun_altitude > -2.0:
			var t: float = clampf((s.sun_altitude + 2.0) / 12.0, 0.0, 1.0)
			sun_light.light_color = sun_color_horizon.lerp(sun_color_day, t)
		else:
			sun_light.light_color = sun_color_horizon
		sun_light.light_energy = s.sun_energy * sun_max_energy
		sun_light.visible = s.sun_energy > 0.01

	if moon_light != null:
		moon_light.basis = Basis.looking_at(-s.moon_direction)
		var energy: float = s.moon_illumination * moon_max_energy
		# Fade near horizon
		if s.moon_altitude < 0.0:
			energy *= clampf((s.moon_altitude + 5.0) / 5.0, 0.0, 1.0)
		moon_light.light_energy = energy
		moon_light.light_color = moon_color
		moon_light.visible = energy > 0.001 and s.moon_altitude > -5.0


func _update_status_strings() -> void:
	var s: CelestialState = state
	_status_sun = "Alt %.1f°  Az %.1f°  Energy %.0f%%" % [s.sun_altitude, s.sun_azimuth, s.sun_energy * 100]
	_status_moon = "%s (%.0f%% lit)  Alt %.1f°" % [s.moon_phase_name, s.moon_illumination * 100, s.moon_altitude]
	var condition: String
	if s.is_day: condition = "Day"
	elif s.is_civil_twilight: condition = "Civil Twilight"
	elif s.is_nautical_twilight: condition = "Nautical Twilight"
	elif s.is_astronomical_twilight: condition = "Astro Twilight"
	else: condition = "Night"
	_status_sky = "%s  Darkness %.0f%%" % [condition, s.sky_darkness * 100]
