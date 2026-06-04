class_name CelestialState
## Read-only snapshot of the sky at a given moment and location.
## Produced by CelestialBody every frame — other systems consume this.
extends RefCounted


# ─── Sun ───
var sun_direction: Vector3    ## Unit vector pointing toward the sun (world space, Y-up)
var sun_azimuth: float        ## Degrees, N=0 E=90
var sun_altitude: float       ## Degrees, negative = below horizon
var sun_distance_au: float    ## Earth-Sun distance (AU)
var sun_energy: float         ## 0~1 suggested light intensity based on altitude

# ─── Moon ───
var moon_direction: Vector3   ## Unit vector pointing toward the moon (world space, Y-up)
var moon_azimuth: float       ## Degrees, N=0 E=90
var moon_altitude: float      ## Degrees
var moon_distance_km: float   ## Earth-Moon distance (km)
var moon_phase_deg: float     ## 0=new, 90=first quarter, 180=full, 270=third quarter
var moon_phase_name: String   ## Human-readable name
var moon_illumination: float  ## 0~1, fraction of visible disk illuminated
var moon_diameter_deg: float  ## Apparent diameter (degrees)

# ─── Sky condition ───
var is_day: bool              ## Sun altitude > 0
var is_civil_twilight: bool   ## Sun between 0° and -6°
var is_nautical_twilight: bool ## Sun between -6° and -12°
var is_astronomical_twilight: bool ## Sun between -12° and -18°
var is_night: bool            ## Sun altitude < -18°
var sky_darkness: float       ## 0 (noon) ~ 1 (full night), smooth

# ─── Time ───
var sidereal_time: float      ## GAST (hours)
var julian_day: float         ## Julian Day (UT)

# ─── Planets (optional, populated when compute_planets = true) ───
var planet_directions: Dictionary  ## { "Mercury": Vector3, ... }
var planet_altitudes: Dictionary   ## { "Mercury": float, ... }


## Altitude → unit direction vector (Y-up world space, Z-north, X-east)
static func az_alt_to_direction(az_deg: float, alt_deg: float) -> Vector3:
	var az_rad: float = deg_to_rad(az_deg)
	var alt_rad: float = deg_to_rad(alt_deg)
	var cos_alt: float = cos(alt_rad)
	# Godot: Y=up, Z=north(back), X=east(right) → typical sky convention
	return Vector3(
		cos_alt * sin(az_rad),   # X = east component
		sin(alt_rad),            # Y = up
		-cos_alt * cos(az_rad),  # Z = -north (Godot Z is into screen)
	).normalized()


## Sun altitude → suggested energy (smooth ramp through twilight)
static func altitude_to_energy(alt_deg: float) -> float:
	if alt_deg >= 10.0:
		return 1.0
	if alt_deg <= -18.0:
		return 0.0
	# Smooth ramp from -18° to +10°
	return clampf((alt_deg + 18.0) / 28.0, 0.0, 1.0)


## Sun altitude → sky darkness (inverse of energy, 0=bright 1=dark)
static func altitude_to_darkness(alt_deg: float) -> float:
	if alt_deg >= 0.0:
		return 0.0
	if alt_deg <= -18.0:
		return 1.0
	return clampf(-alt_deg / 18.0, 0.0, 1.0)


## Moon phase degrees → human-readable name
static func phase_name(phase_deg: float) -> String:
	if phase_deg < 11.25:
		return "New Moon"
	if phase_deg < 78.75:
		return "Waxing Crescent"
	if phase_deg < 101.25:
		return "First Quarter"
	if phase_deg < 168.75:
		return "Waxing Gibbous"
	if phase_deg < 191.25:
		return "Full Moon"
	if phase_deg < 258.75:
		return "Waning Gibbous"
	if phase_deg < 281.25:
		return "Third Quarter"
	if phase_deg < 348.75:
		return "Waning Crescent"
	return "New Moon"


## Moon phase → illumination fraction (0~1)
static func phase_to_illumination(phase_deg: float) -> float:
	return (1.0 - cos(deg_to_rad(phase_deg))) / 2.0
