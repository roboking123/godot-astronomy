extends Control

@onready var output_label: RichTextLabel = %OutputLabel
@onready var lat_input: SpinBox = %LatInput
@onready var lon_input: SpinBox = %LonInput
@onready var use_system_time: CheckBox = %UseSystemTime

var _update_interval: float = 1.0
var _timer: float = 0.0


func _ready() -> void:
	lat_input.value = 25.033  # Taipei
	lon_input.value = 121.565
	_update_display()


func _process(delta: float) -> void:
	if not use_system_time.button_pressed:
		return
	_timer += delta
	if _timer >= _update_interval:
		_timer = 0.0
		_update_display()


func _update_display() -> void:
	var now: Dictionary = Time.get_datetime_dict_from_system(true)
	var result: AstroEngine.CelestialResult = AstroEngine.compute(
		now.year, now.month, now.day,
		now.hour, now.minute, float(now.second),
		lat_input.value, lon_input.value
	)

	var text: String = ""
	text += "[b]Godot Astronomy — Live Demo[/b]\n"
	text += "─────────────────────────────\n"
	text += "Time (UTC): %04d-%02d-%02d %02d:%02d:%02d\n" % [
		now.year, now.month, now.day, now.hour, now.minute, now.second]
	text += "Location: %.3f°N, %.3f°E\n\n" % [lat_input.value, lon_input.value]

	text += "[b]☀ Sun[/b]\n"
	text += "  Azimuth:  %.2f°\n" % result.sun_az
	text += "  Altitude: %.2f°\n" % result.sun_alt
	text += "  Distance: %.6f AU\n\n" % result.sun_dist

	text += "[b]☽ Moon[/b]\n"
	text += "  Azimuth:  %.2f°\n" % result.moon_az
	text += "  Altitude: %.2f°\n" % result.moon_alt
	text += "  Distance: %.1f km\n" % result.moon_dist_km
	text += "  Apparent diameter: %.4f°\n" % result.moon_diam_deg
	text += "  Phase: %.1f° (%s)\n\n" % [result.moon_phase_deg, CelestialState.phase_name(result.moon_phase_deg)]

	text += "[b]⏱ Sidereal[/b]\n"
	text += "  GAST: %.4f h\n\n" % result.sidereal_time

	# Planets
	var time: AstroTime.Moment = AstroTime.make_time(
		now.year, now.month, now.day, now.hour, now.minute, float(now.second))
	var planet_names: Array[String] = [
		"Mercury", "Venus", "Earth", "Mars", "Jupiter", "Saturn", "Uranus", "Neptune"]
	text += "[b]🪐 Planets[/b]\n"
	for i: int in AstroPlanets.Planet.size():
		if i == AstroPlanets.Planet.EARTH:
			continue
		var planet: AstroPlanets.Planet = i as AstroPlanets.Planet
		var hor: AstroCoords.HorizonCoord = AstroPlanets.planet_horizon(
			planet, now.year, now.month, now.day,
			now.hour, now.minute, float(now.second),
			lat_input.value, lon_input.value)
		var helio: Vector3 = AstroPlanets.helio_position(planet, time)
		var dist_au: float = helio.length()
		var above: String = "▲" if hor.altitude > 0.0 else "▽"
		text += "  %s %s  Az:%.1f° Alt:%.1f° R:%.2f AU\n" % [
			above, planet_names[i], hor.azimuth, hor.altitude, dist_au]

	output_label.text = text



func _on_update_button_pressed() -> void:
	_update_display()
