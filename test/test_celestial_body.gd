extends SceneTree
## Quick test for CelestialBody node — prints sky state for a few locations.
## Run: godot --headless -s test/test_celestial_body.gd

func _init() -> void:
	print("═══════════════════════════════════════════════════")
	print("  CelestialBody Node Test")
	print("═══════════════════════════════════════════════════")

	var locations: Array[Dictionary] = [
		{"name": "Taipei", "lon": 121.56, "lat": 25.03},
		{"name": "New York", "lon": -74.01, "lat": 40.71},
		{"name": "London", "lon": -0.13, "lat": 51.51},
		{"name": "Sydney", "lon": 151.21, "lat": -33.87},
		{"name": "North Pole", "lon": 0.0, "lat": 89.0},
	]

	var cb: CelestialBody = CelestialBody.new()
	cb.use_system_time = false
	cb.time_scale = 0.0
	cb.paused = true
	root.add_child(cb)

	# Test at 2026-06-04 08:00 UTC
	print("  Time: 2026-06-04 08:00 UTC")
	print("")

	for loc: Dictionary in locations:
		cb.latitude = loc.lat
		cb.longitude = loc.lon
		cb.set_datetime(2026, 6, 4, 8, 0, 0.0)
		# Force one update
		cb._update_state()
		var s: CelestialState = cb.state

		print("  ── %s (%.1f°N, %.1f°E) ──" % [loc.name, loc.lat, loc.lon])
		print("     Sun:  Az=%.1f° Alt=%.1f° Energy=%.2f" % [s.sun_azimuth, s.sun_altitude, s.sun_energy])
		print("     Moon: Az=%.1f° Alt=%.1f° Phase=%s (%.0f°, %.0f%% lit)" % [
			s.moon_azimuth, s.moon_altitude, s.moon_phase_name, s.moon_phase_deg, s.moon_illumination * 100])
		var condition: String = "Day" if s.is_day else ("Civil Twilight" if s.is_civil_twilight else ("Night" if s.is_night else "Twilight"))
		print("     Sky:  %s (darkness=%.2f)" % [condition, s.sky_darkness])
		print("     Sun dir: (%.3f, %.3f, %.3f)" % [s.sun_direction.x, s.sun_direction.y, s.sun_direction.z])
		print("")

	# Test signals — advance through a sunrise
	print("  ── Signal Test (Tokyo, fast-forward through sunrise) ──")
	cb.latitude = 35.68
	cb.longitude = 139.69
	cb.set_datetime(2026, 6, 4, 19, 0, 0.0)  # ~4:00 JST, before sunrise
	cb._update_state()  # seed prev state
	cb._initialized = true

	var counts: Array[int] = [0, 0]  # [sunrise, sunset]
	cb.sunrise.connect(func() -> void: counts[0] += 1)
	cb.sunset.connect(func() -> void: counts[1] += 1)

	print("     Seed: sun_alt=%.1f prev_above=%s" % [cb.state.sun_altitude, cb._prev_sun_above])
	# Step through 24 hours in 10-minute increments
	for step: int in 144:
		cb.advance_time(10.0 / 1440.0)
		cb._update_state()
		if step < 5 or (step > 70 and step < 76):
			print("     Step %d: sun_alt=%.1f" % [step, cb.state.sun_altitude])

	print("     Sunrise signals: %d, Sunset signals: %d" % [counts[0], counts[1]])

	# Test compute_planets
	print("")
	print("  ── Planet Test (Taipei) ──")
	cb.latitude = 25.03
	cb.longitude = 121.56
	cb.compute_planets = true
	cb.set_datetime(2026, 6, 4, 12, 0, 0.0)
	cb._update_state()

	for pname: String in cb.state.planet_directions:
		var alt: float = cb.state.planet_altitudes[pname]
		var dir: Vector3 = cb.state.planet_directions[pname]
		var vis: String = "▲" if alt > 0.0 else "▽"
		print("     %s %s: Alt=%.1f° Dir=(%.2f, %.2f, %.2f)" % [vis, pname, alt, dir.x, dir.y, dir.z])

	print("")
	print("═══════════════════════════════════════════════════")
	print("  ✓ CelestialBody test complete")
	print("═══════════════════════════════════════════════════")
	quit()
