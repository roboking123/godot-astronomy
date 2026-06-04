# Godot Astronomy

Precise astronomical calculations for **Godot 4.6+** — the first GDScript port of [cosinekitty/astronomy](https://github.com/cosinekitty/astronomy).

Pure GDScript, no native extensions, no dependencies, works on all platforms.

## Installation

Copy `addons/godot_astronomy/` into your project's `addons/` directory, then enable the plugin in **Project → Project Settings → Plugins**. All classes are available globally via `class_name`.

## Quick Start

```gdscript
# One call — sun, moon, and everything for a given time and location
var r = AstroEngine.compute(2026, 6, 4, 14, 30, 0.0, 25.033, 121.565)
print(r.sun_alt)         # Sun altitude (degrees)
print(r.moon_phase_deg)  # Moon phase (0=new, 180=full)
print(r.moon_dist_km)    # Moon distance (km)
```

Or use the **CelestialBody** node — add it to your scene and it updates every frame automatically, creating sun/moon lights for you.

---

## API Reference

All modules use `static func` — no instantiation, no state, thread-safe.

### AstroTime

Time system. All other modules take `AstroTime.Moment` as input.

| Function | Returns | Description |
|----------|---------|-------------|
| `make_time(year, month, day, hour, minute, sec)` | `Moment` | Create time from UTC date/time |
| `time_from_days(ut)` | `Moment` | Create time from J2000 UT days |
| `normalize_longitude(lon)` | `float` | Wrap angle to [0, 360) |
| `longitude_offset(diff)` | `float` | Wrap angle difference to [-180, +180) |

**Moment** fields: `ut` (J2000 UT days), `tt` (Terrestrial Time days)

**Constants**: `KM_PER_AU`, `MEAN_SYNODIC_MONTH`, `DAYS_PER_TROPICAL_YEAR`, `C_AUDAY`, `DEG2RAD`, `RAD2DEG`

### AstroSun

Sun position via VSOP87 Earth model.

| Function | Returns | Description |
|----------|---------|-------------|
| `sun_position(time)` | `Vector3` | Geocentric J2000 equatorial position (AU), light-time corrected |
| `helio_distance(time)` | `float` | Earth-Sun distance (AU) |
| `calc_earth(time)` | `Vector3` | Heliocentric Earth position (AU), no light-time correction |

### AstroMoon

Moon position via CalcMoon model + libration.

| Function | Returns | Description |
|----------|---------|-------------|
| `geo_moon(time)` | `GeoMoonResult` | Geocentric J2000 position + ecliptic intermediates |
| `libration(time, ecliptic, tobl)` | `LibrationResult` | Optical + physical libration, distance, apparent diameter |

**GeoMoonResult**: `j2000` (Vector3), `ecliptic` (MoonEcliptic), `tobl` (float)

**LibrationResult**: `elon`, `elat` (libration degrees), `dist_km`, `diam_deg`, `mlon`, `mlat`, `pole_equ` (Vector3)

```gdscript
var geo = AstroMoon.geo_moon(time)
var lib = AstroMoon.libration(time, geo.ecliptic, geo.tobl)
print(lib.dist_km)   # 384400 km (typical)
print(lib.diam_deg)  # ~0.52°
```

### AstroMoonMeeus

Higher-precision moon model (Meeus Ch.47, ~10 arcsec). Drop-in replacement for `AstroMoon.geo_moon()`.

| Function | Returns | Description |
|----------|---------|-------------|
| `position(T)` | `MeeusMoonResult` | Ecliptic position. T = Julian centuries from J2000 (TT) |
| `geo_moon(time)` | `GeoMoonResult` | Same interface as `AstroMoon.geo_moon()` |

### AstroPlanets

Mercury–Neptune positions via VSOP87.

| Function | Returns | Description |
|----------|---------|-------------|
| `helio_position(planet, time)` | `Vector3` | Heliocentric J2000 position (AU) |
| `geo_position(planet, time)` | `Vector3` | Geocentric J2000 position (AU), light-time corrected |
| `planet_horizon(planet, y, m, d, h, min, sec, lat, lon)` | `HorizonCoord` | Azimuth + altitude for an observer (degrees) |

**Planet enum**: `MERCURY`, `VENUS`, `EARTH`, `MARS`, `JUPITER`, `SATURN`, `URANUS`, `NEPTUNE`

```gdscript
var time = AstroTime.make_time(2026, 6, 4, 14, 30, 0.0)
var mars = AstroPlanets.helio_position(AstroPlanets.Planet.MARS, time)
print(mars)  # Vector3 in AU

var hor = AstroPlanets.planet_horizon(
    AstroPlanets.Planet.MARS, 2026, 6, 4, 14, 30, 0.0, 25.033, 121.565)
print(hor.altitude)  # degrees above horizon
```

### AstroCoords

Coordinate transforms, nutation, precession, observer position.

| Function | Returns | Description |
|----------|---------|-------------|
| `j2000_to_ofdate(pos, time)` | `Vector3` | J2000 → of-date (precession + nutation) |
| `ofdate_to_j2000(pos, time)` | `Vector3` | of-date → J2000 |
| `vector2radec(pos)` | `RaDec` | Cartesian → right ascension (hours) + declination (degrees) |
| `horizon(time, lat, lon, ra, dec)` | `HorizonCoord` | Equatorial → horizon (azimuth + altitude with refraction) |
| `ecliptic(j2000_vec, time)` | `EclipticCoord` | J2000 → ecliptic longitude/latitude |
| `geo_pos(time, lat, lon, height)` | `Vector3` | Observer's geocentric J2000 position (WGS84 ellipsoid) |
| `sidereal_time(time)` | `float` | GAST sidereal time (hours) |
| `e_tilt(time)` | `Tilt` | Obliquity + nutation parameters |
| `refraction(altitude)` | `float` | Atmospheric refraction correction (degrees) |

**RaDec**: `ra` (hours), `dec` (degrees), `dist` (AU)

**HorizonCoord**: `azimuth` (degrees, N=0 E=90), `altitude` (degrees, includes refraction)

### AstroSearch

Event search — rise/set times, moon phase timing.

| Function | Returns | Description |
|----------|---------|-------------|
| `search_rise_set(body, direction, lat, lon, height, start_time, limit_days)` | `Moment?` | Find next rise or set |
| `search_moon_phase(target_lon, start_time, limit_days)` | `Moment?` | Find next moon phase (0=new, 90=Q1, 180=full, 270=Q3) |
| `search(func_callback, t1, t2, dt_tolerance_seconds)` | `Moment?` | Generic ascending root search |

**Body enum**: `SUN`, `MOON`, `MERCURY`, `VENUS`, `MARS`, `JUPITER`, `SATURN`, `URANUS`, `NEPTUNE`

**Direction enum**: `RISE`, `SET`

```gdscript
var time = AstroTime.make_time(2026, 6, 4, 0, 0, 0.0)

# Next sunrise in Taipei
var sunrise = AstroSearch.search_rise_set(
    AstroSearch.Body.SUN, AstroSearch.Direction.RISE,
    25.033, 121.565, 0.0, time, 1.0)

# Next full moon within 30 days
var full_moon = AstroSearch.search_moon_phase(180.0, time, 30.0)
```

### AstroEngine

Facade — one call computes everything.

| Function | Returns | Description |
|----------|---------|-------------|
| `compute(year, month, day, hour, minute, sec, lat, lon)` | `CelestialResult` | Sun + moon + sidereal time for a given time and location |
| `moon_phase(sun_j2000, moon_j2000, time)` | `float` | Moon phase angle (degrees, 0=new, 180=full) |

**CelestialResult** fields:

| Field | Type | Description |
|-------|------|-------------|
| `sun_az`, `sun_alt` | float | Sun azimuth / altitude (degrees) |
| `sun_dist` | float | Sun distance (AU) |
| `moon_az`, `moon_alt` | float | Moon azimuth / altitude (degrees) |
| `moon_dist_km` | float | Moon distance (km) |
| `moon_diam_deg` | float | Moon apparent diameter (degrees) |
| `moon_phase_deg` | float | Moon phase angle (0°=new, 180°=full) |
| `libration_elon`, `libration_elat` | float | Libration (degrees) |
| `moon_pole_equ` | Vector3 | Moon north pole (of-date equatorial) |
| `sidereal_time` | float | GAST (hours) |
| `moon_ra`, `moon_dec` | float | Moon RA (hours) / Dec (degrees) |
| `geocentric_elongation` | float | Sun-moon angle (degrees) |

### CelestialState

Utility functions for interpreting astronomical data.

| Function | Returns | Description |
|----------|---------|-------------|
| `az_alt_to_direction(az_deg, alt_deg)` | `Vector3` | Azimuth + altitude → Godot world direction (Y-up) |
| `altitude_to_energy(alt_deg)` | `float` | Sun altitude → suggested light energy (0–1) |
| `altitude_to_darkness(alt_deg)` | `float` | Sun altitude → sky darkness (0–1) |
| `phase_name(phase_deg)` | `String` | Phase angle → name ("Full Moon", "Waxing Crescent", ...) |
| `phase_to_illumination(phase_deg)` | `float` | Phase angle → illuminated fraction (0–1) |

### CelestialBody (Node)

Scene node that updates every frame. Add to your scene tree — it creates sun/moon DirectionalLight3D nodes automatically.

**Exports**: `longitude`, `latitude`, `elevation`, `use_system_time`, `time_scale`, `compute_planets`, `auto_create_lights`, `sun_color_day`, `moon_max_energy`, ...

**Signals**: `sunrise`, `sunset`, `moon_phase_changed(phase_name)`

**Public**: `state` (CelestialState), `set_datetime(y, m, d, h, min, sec)`, `advance_time(days)`, `get_moment()`

---

## Accuracy

Same algorithms as [cosinekitty/astronomy](https://github.com/cosinekitty/astronomy), using 64-bit float (IEEE 754 double).

| Model | Accuracy | Range |
|-------|----------|-------|
| Sun (VSOP87) | < 1 arcsecond | ±4000 years from J2000 |
| Moon (CalcMoon) | ~1 degree | Modern dates |
| Moon (Meeus) | ~10 arcseconds | Modern dates |
| Delta T | Espenak & Meeus polynomial | -500 to 2150 CE |

**Known limitations**: CalcMoon is adequate for phase, illumination, and visual positioning. For sub-arcminute lunar precision, use `AstroMoonMeeus`.

## Demo Scenes

| Scene | Description |
|-------|-------------|
| `demo/solar_system_view.tscn` | Top-down solar system with real VSOP87 orbits (default main scene) |
| `demo/day_night_demo.tscn` | 3D sky with sun/moon/planets, free camera, Rayleigh scattering |
| `demo/demo.tscn` | Text output showing all computed values |

## Roadmap

- [x] Planets (Mercury–Neptune via VSOP87)
- [x] Rise/set search
- [x] Moon phase search
- [ ] Transit search
- [ ] Eclipse prediction
- [ ] Elongation, conjunction, opposition
- [ ] Visual magnitude
- [ ] Jupiter moons

## Credits

Astronomical algorithms ported from [cosinekitty/astronomy](https://github.com/cosinekitty/astronomy) by Don Cross (MIT License).

Moon position algorithm from Montenbruck & Pfleger, *Astronomy on the Personal Computer*.

## License

MIT — see [LICENSE](LICENSE) for details.
