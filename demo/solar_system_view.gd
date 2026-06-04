extends Control
## Solar system top-down view — shows real-time planet positions on the ecliptic plane

const PLANET_COLORS: Array[Color] = [
	Color(0.7, 0.7, 0.7),     # Mercury — grey
	Color(0.9, 0.8, 0.5),     # Venus — pale yellow
	Color(0.3, 0.5, 0.8),     # Earth — blue
	Color(0.9, 0.4, 0.2),     # Mars — red-orange
	Color(0.8, 0.6, 0.3),     # Jupiter — tan
	Color(0.9, 0.8, 0.5),     # Saturn — gold
	Color(0.5, 0.8, 0.9),     # Uranus — cyan
	Color(0.3, 0.4, 0.9),     # Neptune — deep blue
]

const PLANET_NAMES: Array[String] = [
	"Mercury", "Venus", "Earth", "Mars", "Jupiter", "Saturn", "Uranus", "Neptune"
]

const PLANET_RADII_PX: Array[float] = [
	3.0, 5.0, 5.0, 4.0, 10.0, 9.0, 7.0, 7.0
]

const ORBIT_SEMI_MAJOR_AU: Array[float] = [
	0.387, 0.723, 1.0, 1.524, 5.203, 9.537, 19.191, 30.069
]

@onready var date_label: Label = %DateLabel
@onready var zoom_slider: HSlider = %ZoomSlider
@onready var inner_toggle: CheckBox = %InnerToggle

var _center: Vector2
var _au_to_px: float = 80.0
var _show_inner_only: bool = false
var _time_offset_days: float = 0.0

var _planet_positions: Array[Vector3] = []
var _current_time: AstroTime.Moment


func _ready() -> void:
	_planet_positions.resize(8)
	zoom_slider.value = 80.0
	_update_positions()


func _process(_delta: float) -> void:
	_center = size / 2.0
	_au_to_px = zoom_slider.value
	_show_inner_only = inner_toggle.button_pressed
	_update_positions()
	queue_redraw()


func _update_positions() -> void:
	var now: Dictionary = Time.get_datetime_dict_from_system()
	_current_time = AstroTime.make_time(
		now.year, now.month, now.day,
		now.hour, now.minute, float(now.second))
	_current_time = AstroTime.time_from_days(_current_time.ut + _time_offset_days)

	for i: int in 8:
		var planet: AstroPlanets.Planet = i as AstroPlanets.Planet
		if planet == AstroPlanets.Planet.EARTH:
			_planet_positions[i] = -AstroSun.sun_position(_current_time)
		else:
			_planet_positions[i] = AstroPlanets.helio_position(planet, _current_time)

	# Update date label
	var ut: float = _current_time.ut
	var jd: float = ut + 2451545.0
	date_label.text = "JD: %.2f | Offset: %+.0f days" % [jd, _time_offset_days]


func _draw() -> void:
	var bg_color := Color(0.05, 0.05, 0.1)
	draw_rect(Rect2(Vector2.ZERO, size), bg_color)

	var max_orbit: int = 8 if not _show_inner_only else 4

	# Draw orbit circles
	for i: int in max_orbit:
		var orbit_r: float = ORBIT_SEMI_MAJOR_AU[i] * _au_to_px
		if orbit_r > 2.0 and orbit_r < maxf(size.x, size.y):
			draw_arc(_center, orbit_r, 0, TAU, 64, Color(0.2, 0.2, 0.3, 0.5), 1.0)

	# Draw Sun
	draw_circle(_center, 8.0, Color(1.0, 0.9, 0.3))

	# Draw planets
	for i: int in max_orbit:
		var pos3d: Vector3 = _planet_positions[i]
		# VSOP J2000 equatorial → ecliptic XY approximation
		# X points to vernal equinox, Y is in ecliptic plane
		# For top-down view, use X and Y directly (Z is ~small for planets)
		var screen_pos: Vector2 = _center + Vector2(pos3d.x, -pos3d.y) * _au_to_px

		var radius: float = PLANET_RADII_PX[i]
		var color: Color = PLANET_COLORS[i]

		# Draw planet dot
		draw_circle(screen_pos, radius, color)

		# Draw label
		var label_offset := Vector2(radius + 4, -radius - 4)
		draw_string(ThemeDB.fallback_font, screen_pos + label_offset,
			PLANET_NAMES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, color)

		# Draw line from Sun to planet
		draw_line(_center, screen_pos, Color(color, 0.2), 1.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_slider.value *= 1.1
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_slider.value /= 1.1


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var key: InputEventKey = event as InputEventKey
		match key.keycode:
			KEY_LEFT:
				_time_offset_days -= 1.0
			KEY_RIGHT:
				_time_offset_days += 1.0
			KEY_UP:
				_time_offset_days += 30.0
			KEY_DOWN:
				_time_offset_days -= 30.0
			KEY_HOME:
				_time_offset_days = 0.0
