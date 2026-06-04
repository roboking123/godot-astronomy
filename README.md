# Godot Astronomy

Precise astronomical calculations for **Godot 4** — the first GDScript port of [cosinekitty/astronomy](https://github.com/cosinekitty/astronomy).

Compute real-world sun and moon positions for any date, time, and location on Earth. Built for games, simulations, and visualizations that need accurate celestial mechanics.

## Features

- **Sun position** — VSOP87 model with light-time correction
- **Moon position** — Montenbruck & Pfleger CalcMoon model
- **Moon phase** — 0° (new) to 180° (full) continuous angle
- **Libration** — optical + physical libration for realistic moon rendering
- **Coordinate systems** — J2000, of-date, ecliptic, equatorial, horizon
- **Atmospheric refraction** — Saemundsson formula for accurate rise/set times
- **Nutation & precession** — IAU2000b truncated model + 5th-order precession
- **Sidereal time** — GAST with equation of the equinoxes
- **Observer position** — WGS84 ellipsoid, topocentric parallax correction
- **Planets** — Mercury through Neptune heliocentric and geocentric positions
- **Rise/set search** — find sunrise, moonrise, planet rise/set times
- **Moon phase search** — find next new moon, full moon, or any phase angle
- **Pure GDScript** — no native extensions, no dependencies, works on all platforms

## Quick Start

```gdscript
# Compute sun/moon for Taipei, 2026-06-04 at 14:30:00 UTC
var result = AstroEngine.compute(2026, 6, 4, 14, 30, 0.0, 25.033, 121.565)

print("Sun altitude: ", result.sun_alt)      # degrees above horizon
print("Moon phase: ", result.moon_phase_deg)  # 0=new, 180=full
print("Moon distance: ", result.moon_dist_km) # km
```

### Planets

```gdscript
# Where is Mars right now?
var time = AstroTime.make_time(2026, 6, 4, 14, 30, 0.0)
var mars_pos = AstroPlanets.helio_position(AstroPlanets.Planet.MARS, time)
print("Mars heliocentric: ", mars_pos, " AU")

# Mars horizon coordinates for Taipei
var mars_hor = AstroPlanets.planet_horizon(
    AstroPlanets.Planet.MARS, 2026, 6, 4, 14, 30, 0.0, 25.033, 121.565)
print("Mars altitude: ", mars_hor.altitude)
```

### Rise/Set and Moon Phase Search

```gdscript
var time = AstroTime.make_time(2026, 6, 4, 0, 0, 0.0)

# Find next sunrise in Taipei
var sunrise = AstroSearch.search_rise_set(
    AstroSearch.Body.SUN, AstroSearch.Direction.RISE,
    25.033, 121.565, 0.0, time, 1.0)

# Find next full moon within 30 days
var full_moon = AstroSearch.search_moon_phase(180.0, time, 30.0)
```

### CelestialResult fields

| Field | Type | Description |
|-------|------|-------------|
| `sun_az` | float | Sun azimuth (degrees, N=0 E=90) |
| `sun_alt` | float | Sun altitude (degrees, with refraction) |
| `sun_dist` | float | Sun distance (AU) |
| `moon_az` | float | Moon azimuth (degrees, N=0 E=90) |
| `moon_alt` | float | Moon altitude (degrees, with refraction) |
| `moon_dist_km` | float | Moon distance (km) |
| `moon_diam_deg` | float | Moon apparent diameter (degrees) |
| `moon_phase_deg` | float | Moon phase angle (0°=new, 180°=full) |
| `libration_elon` | float | Libration in longitude (degrees) |
| `libration_elat` | float | Libration in latitude (degrees) |
| `moon_pole_equ` | Vector3 | Moon north pole (of-date equatorial) |
| `sidereal_time` | float | GAST (hours) |
| `moon_ra` | float | Moon right ascension (hours) |
| `moon_dec` | float | Moon declination (degrees) |
| `geocentric_elongation` | float | Sun-moon angle (degrees) |

### Lower-level API

```gdscript
# Use individual modules for specific calculations
var time = AstroTime.make_time(2026, 6, 4, 14, 30, 0.0)

# Sun J2000 geocentric position (AU)
var sun_pos = AstroSun.sun_position(time)

# Moon J2000 geocentric position
var moon_result = AstroMoon.geo_moon(time)

# Convert to horizon coordinates for a specific location
var ofdate = AstroCoords.j2000_to_ofdate(sun_pos, time)
var radec = AstroCoords.vector2radec(ofdate)
var horizon = AstroCoords.horizon(time, 25.033, 121.565, radec.ra, radec.dec)
```

## Installation

### As a Godot addon

1. Copy the `addons/godot_astronomy/` folder into your project's `addons/` directory
2. Enable the plugin in Project → Project Settings → Plugins
3. All `AstroTime`, `AstroSun`, `AstroMoon`, `AstroCoords`, and `AstroEngine` classes are available globally via `class_name`

### From source

```bash
git clone https://github.com/roboking123/godot-astronomy.git
```

Open in Godot 4.4+ and run the demo scene.

## Architecture

```
addons/godot_astronomy/src/
├── astro_time.gd      # Time system, Julian Day, Delta T, constants
├── astro_sun.gd       # VSOP87 sun position
├── astro_moon.gd      # CalcMoon moon position + libration
├── astro_planets.gd   # VSOP87 planets (Mercury–Neptune)
├── astro_coords.gd    # Coordinate transforms, nutation, precession
├── astro_search.gd    # Event search (rise/set, moon phase)
└── astro_engine.gd    # Facade — one call does everything
```

All modules use `static func` — no instantiation needed, no state, fully thread-safe.

## Accuracy

This port implements the same algorithms as [cosinekitty/astronomy](https://github.com/cosinekitty/astronomy), which validates against JPL ephemeris data. The GDScript port uses 64-bit `float` (IEEE 754 double precision), matching the precision of the original C implementation.

- Sun position: < 1 arcsecond error for dates within ±4000 years of J2000
- Moon position: < 10 arcseconds (CalcMoon model limitation)
- Delta T: Espenak & Meeus polynomial, covering -500 to 2150 CE

## Roadmap

- [x] Planets (Mercury through Neptune via VSOP87)
- [x] Rise/set search
- [x] Moon phase search
- [ ] Transit search
- [ ] Eclipse prediction
- [ ] Elongation, conjunction, opposition
- [ ] Visual magnitude
- [ ] Jupiter moons

## Credits

Astronomical algorithms ported from [cosinekitty/astronomy](https://github.com/cosinekitty/astronomy) by Don Cross (MIT License). The original library supports C, C#, JavaScript, Python, and Kotlin — this project adds GDScript as the sixth language.

Moon position algorithm from Montenbruck & Pfleger, *Astronomy on the Personal Computer*.

## License

MIT — see [LICENSE](LICENSE) for details.
