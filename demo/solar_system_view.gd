extends Control
## Solar system top-down view — shows real-time planet positions on the ecliptic plane

# 天體 ID（0-7 與 AstroPlanets.Planet 數值對齊，可直接轉型）
enum Body {
	MERCURY, VENUS, EARTH, MARS, JUPITER, SATURN, URANUS, NEPTUNE,
	SUN, MOON,
}
const PLANET_COUNT: int = 8  # Body.MERCURY ~ Body.NEPTUNE

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
	3.0, 4.5, 4.5, 3.5, 8.0, 7.5, 6.0, 6.0
]
const SUN_RADIUS_PX: float = 14.0

const ORBIT_PERIODS_DAYS: Array[float] = [
	87.97, 224.70, 365.25, 686.97, 4332.59, 10759.22, 30688.5, 60182.0
]
const ORBIT_SAMPLES: int = 180

@onready var date_label: Label = %DateLabel
@onready var info_panel: PanelContainer = %InfoPanel
@onready var info_label: RichTextLabel = %InfoLabel

var _center: Vector2
var _au_to_px: float = 80.0
var _time_offset_days: float = 0.0
var _time_speed: float = 1.0
var _speed_idx: int = 1
const TIME_SPEEDS: Array[float] = [0.0, 1.0, 7.0, 30.0, 365.0]
const SPEED_NAMES: Array[String] = ["Paused", "1 day/sec", "1 week/sec", "1 month/sec", "1 year/sec"]

var _planet_positions: Array[Vector3] = []
var _moon_pos: Vector3
const MOON_RADIUS_PX: float = 2.0
const MOON_ORBIT_AU: float = 0.00257  # 月球平均軌道半徑（AU）
const MOON_VISIBLE_PX: float = 8.0    # 月球軌道需達此像素才畫
const MOON_COLOR: Color = Color(0.75, 0.75, 0.8)
var _current_time: AstroTime.Moment
var _orbit_points: Array = []  # Array[PackedVector2Array]
var _orbit_base_pos: Array = []  # 烘焙時的行星位置（Vector2）
var _moon_orbit_points: PackedVector2Array

var _selected: int = -1  # -1=無, 其餘用 Body enum
var _focus_offset: Vector2 = Vector2.ZERO
const FOCUS_ZOOM: Dictionary = {
	Body.MERCURY: 3000.0, Body.VENUS: 1500.0, Body.EARTH: 5000.0,
	Body.MARS: 1000.0, Body.JUPITER: 200.0, Body.SATURN: 120.0,
	Body.URANUS: 60.0, Body.NEPTUNE: 40.0,
	Body.SUN: 800.0, Body.MOON: 15000.0,
}
# 內→外順序：太陽、水星、金星、地球、月球、火星～海王星
const SELECT_ORDER: Array[int] = [
	Body.SUN, Body.MERCURY, Body.VENUS, Body.EARTH, Body.MOON,
	Body.MARS, Body.JUPITER, Body.SATURN, Body.URANUS, Body.NEPTUNE,
]


func _ready() -> void:
	_planet_positions.resize(PLANET_COUNT)
	_orbit_points.resize(PLANET_COUNT)
	_orbit_base_pos.resize(PLANET_COUNT)
	_update_positions()
	_bake_orbits()


func _process(delta: float) -> void:
	if _time_speed != 0.0:
		_time_offset_days += _time_speed * delta
	_update_positions()

	# 選中天體時，將其置中
	if _selected >= 0 and _selected < PLANET_COUNT:
		var pos: Vector3 = _planet_positions[_selected]
		_focus_offset = -Vector2(pos.x, -pos.y) * _au_to_px
	elif _selected == Body.MOON:
		_focus_offset = -Vector2(_moon_pos.x, -_moon_pos.y) * _au_to_px
	elif _selected == Body.SUN:
		_focus_offset = Vector2.ZERO
	else:
		_focus_offset = Vector2.ZERO
	_center = size / 2.0 + _focus_offset

	# 任何行星在螢幕上偏離軌道超過 2 像素就重烘焙
	var needs_rebake: bool = false
	for i: int in PLANET_COUNT:
		var pos3d: Vector3 = _planet_positions[i]
		var cur_2d: Vector2 = Vector2(pos3d.x, -pos3d.y)
		var base: Vector2 = _orbit_base_pos[i] as Vector2
		if (cur_2d - base).length() * _au_to_px > 2.0:
			needs_rebake = true
			break
	if needs_rebake:
		_bake_orbits()

	if _selected >= 0:
		_update_info_panel()
	queue_redraw()


func _update_positions() -> void:
	var now: Dictionary = Time.get_datetime_dict_from_system()
	_current_time = AstroTime.make_time(
		now.year, now.month, now.day,
		now.hour, now.minute, float(now.second))
	_current_time = AstroTime.time_from_days(_current_time.ut + _time_offset_days)

	for i: int in PLANET_COUNT:
		var planet: AstroPlanets.Planet = i as AstroPlanets.Planet
		if planet == Body.EARTH:
			_planet_positions[i] = -AstroSun.sun_position(_current_time)
		else:
			_planet_positions[i] = AstroPlanets.helio_position(planet, _current_time)

	# 月球（地心 J2000 座標，轉日心）
	var geo: AstroMoon.GeoMoonResult = AstroMoon.geo_moon(_current_time)
	var earth_pos: Vector3 = _planet_positions[Body.EARTH]
	_moon_pos = earth_pos + geo.j2000
	# Update date label
	var ut: float = _current_time.ut
	var jd: float = ut + 2451545.0
	date_label.text = "JD: %.2f | Offset: %+.0f days | %s" % [jd, _time_offset_days, SPEED_NAMES[_speed_idx]]


func _draw() -> void:
	var bg_color := Color(0.05, 0.05, 0.1)
	draw_rect(Rect2(Vector2.ZERO, size), bg_color)

	var max_orbit: int = PLANET_COUNT

	# 真實軌道線（VSOP87 取樣）
	for i: int in max_orbit:
		var pts: PackedVector2Array = _orbit_points[i]
		if pts.size() < 2:
			continue
		var scaled: PackedVector2Array = PackedVector2Array()
		scaled.resize(pts.size())
		for j: int in pts.size():
			scaled[j] = _center + pts[j] * _au_to_px
		draw_polyline(scaled, Color(0.2, 0.2, 0.3, 0.5), 1.0, true)

	# Draw Sun
	var sun_color := Color(1.0, 0.9, 0.3)
	draw_circle(_center, SUN_RADIUS_PX, sun_color)
	draw_string(ThemeDB.fallback_font, _center + Vector2(SUN_RADIUS_PX + 4, -SUN_RADIUS_PX - 4),
		"Sun", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, sun_color)
	if _selected == Body.SUN:
		_draw_selection_bracket(_center, SUN_RADIUS_PX + 6)

	# Draw planets
	for i: int in max_orbit:
		var pos3d: Vector3 = _planet_positions[i]
		# VSOP J2000 equatorial → ecliptic XY approximation
		# X points to vernal equinox, Y is in ecliptic plane
		# For top-down view, use X and Y directly (Z is ~small for planets)
		var screen_pos: Vector2 = _center + Vector2(pos3d.x, -pos3d.y) * _au_to_px

		var radius: float = PLANET_RADII_PX[i]
		var color: Color = PLANET_COLORS[i]

		# 選中高亮（四角框）
		if i == _selected:
			_draw_selection_bracket(screen_pos, radius + 6)

		# Draw planet dot
		draw_circle(screen_pos, radius, color)

		# Draw label
		var label_offset := Vector2(radius + 4, -radius - 4)
		draw_string(ThemeDB.fallback_font, screen_pos + label_offset,
			PLANET_NAMES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, color)

		# Draw line from Sun to planet
		draw_line(_center, screen_pos, Color(color, 0.2), 1.0)

	# 月球（放大到可見或選中時才畫）
	var moon_real_px: float = MOON_ORBIT_AU * _au_to_px
	if moon_real_px > MOON_VISIBLE_PX or _selected == Body.MOON:
		var earth_screen: Vector2 = _center + Vector2(
			_planet_positions[Body.EARTH].x,
			-_planet_positions[Body.EARTH].y) * _au_to_px
		var moon_screen: Vector2 = _center + Vector2(_moon_pos.x, -_moon_pos.y) * _au_to_px
		if _moon_orbit_points.size() > 1:
			var moon_scaled: PackedVector2Array = PackedVector2Array()
			moon_scaled.resize(_moon_orbit_points.size())
			for j: int in _moon_orbit_points.size():
				moon_scaled[j] = _center + _moon_orbit_points[j] * _au_to_px
			draw_polyline(moon_scaled, Color(MOON_COLOR, 0.3), 1.0, true)
		draw_line(earth_screen, moon_screen, Color(MOON_COLOR, 0.3), 1.0)
		if _selected == Body.MOON:
			_draw_selection_bracket(moon_screen, MOON_RADIUS_PX + 6)
		draw_circle(moon_screen, MOON_RADIUS_PX, MOON_COLOR)
		draw_string(ThemeDB.fallback_font, moon_screen + Vector2(4, -4),
			"Moon", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, MOON_COLOR)


func _bake_orbits() -> void:
	var base_ut: float = _current_time.ut
	for i: int in PLANET_COUNT:
		var planet: AstroPlanets.Planet = i as AstroPlanets.Planet
		var period: float = ORBIT_PERIODS_DAYS[i]
		var pts: PackedVector2Array = PackedVector2Array()
		pts.resize(ORBIT_SAMPLES + 1)
		for j: int in ORBIT_SAMPLES + 1:
			var t: AstroTime.Moment = AstroTime.time_from_days(
				base_ut + period * float(j) / float(ORBIT_SAMPLES))
			var pos: Vector3
			if planet == Body.EARTH:
				pos = -AstroSun.sun_position(t)
			else:
				pos = AstroPlanets.helio_position(planet, t)
			pts[j] = Vector2(pos.x, -pos.y)
		_orbit_points[i] = pts
		# 記住烘焙時的行星位置（第一個取樣點 = 當前時間）
		_orbit_base_pos[i] = pts[0]

	# 月球軌道（過去半圈 + 未來半圈）
	var moon_pts: PackedVector2Array = PackedVector2Array()
	var moon_samples: int = 60
	moon_pts.resize(moon_samples + 1)
	for j: int in moon_samples + 1:
		var t: AstroTime.Moment = AstroTime.time_from_days(
			base_ut - 13.65 + 27.3 * float(j) / float(moon_samples))
		var earth: Vector3 = -AstroSun.sun_position(t)
		var moon_geo: AstroMoon.GeoMoonResult = AstroMoon.geo_moon(t)
		var moon_helio: Vector3 = earth + moon_geo.j2000
		moon_pts[j] = Vector2(moon_helio.x, -moon_helio.y)
	_moon_orbit_points = moon_pts


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_au_to_px = clampf(_au_to_px * 1.15, 5.0, 50000.0)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_au_to_px = clampf(_au_to_px / 1.15, 5.0, 50000.0)
			elif mb.button_index == MOUSE_BUTTON_LEFT:
				_try_select(mb.position)


func _draw_selection_bracket(center: Vector2, half: float) -> void:
	var corner_len: float = half * 0.45
	var col: Color = Color(1, 1, 1, 0.7)
	var w: float = 1.5
	# 左上
	draw_line(center + Vector2(-half, -half), center + Vector2(-half + corner_len, -half), col, w)
	draw_line(center + Vector2(-half, -half), center + Vector2(-half, -half + corner_len), col, w)
	# 右上
	draw_line(center + Vector2(half, -half), center + Vector2(half - corner_len, -half), col, w)
	draw_line(center + Vector2(half, -half), center + Vector2(half, -half + corner_len), col, w)
	# 左下
	draw_line(center + Vector2(-half, half), center + Vector2(-half + corner_len, half), col, w)
	draw_line(center + Vector2(-half, half), center + Vector2(-half, half - corner_len), col, w)
	# 右下
	draw_line(center + Vector2(half, half), center + Vector2(half - corner_len, half), col, w)
	draw_line(center + Vector2(half, half), center + Vector2(half, half - corner_len), col, w)


func _try_select(click_pos: Vector2) -> void:
	# 月球（可見時）
	var moon_screen: Vector2 = _center + Vector2(_moon_pos.x, -_moon_pos.y) * _au_to_px
	if (MOON_ORBIT_AU * _au_to_px > MOON_VISIBLE_PX or _selected == Body.MOON) and click_pos.distance_to(moon_screen) < MOON_RADIUS_PX + 12:
		_select(Body.MOON)
		return
	# 太陽
	if click_pos.distance_to(_center) < SUN_RADIUS_PX + 10:
		_select(Body.SUN)
		return
	# 行星
	var max_orbit: int = PLANET_COUNT
	for i: int in max_orbit:
		var pos3d: Vector3 = _planet_positions[i]
		var screen_pos: Vector2 = _center + Vector2(pos3d.x, -pos3d.y) * _au_to_px
		if click_pos.distance_to(screen_pos) < PLANET_RADII_PX[i] + 12:
			_select(i)
			return
	_deselect()


func _select(idx: int) -> void:
	_selected = idx
	if FOCUS_ZOOM.has(idx):
		_au_to_px = FOCUS_ZOOM[idx] as float
	info_panel.visible = true
	_bake_orbits()


func _select_next() -> void:
	if _selected == -1:
		_select(Body.EARTH)
		return
	var idx: int = SELECT_ORDER.find(_selected)
	_select(SELECT_ORDER[(idx + 1) % SELECT_ORDER.size()])


func _select_prev() -> void:
	if _selected == -1:
		_select(Body.EARTH)
		return
	var idx: int = SELECT_ORDER.find(_selected)
	_select(SELECT_ORDER[(idx - 1 + SELECT_ORDER.size()) % SELECT_ORDER.size()])


func _deselect() -> void:
	_selected = -1
	info_panel.visible = false
	_au_to_px = 80.0
	_bake_orbits()


func _update_info_panel() -> void:
	var text: String = ""

	if _selected == Body.SUN:
		text += "[b]Sun[/b]\n\n"
		text += "Type: G2V Main Sequence\n"
		text += "Distance from Earth: %.4f AU\n" % _planet_positions[Body.EARTH].length()
		info_label.text = text
		return

	if _selected == Body.MOON:
		var geo_moon: AstroMoon.GeoMoonResult = AstroMoon.geo_moon(_current_time)
		var lib: AstroMoon.LibrationResult = AstroMoon.libration(
			_current_time, geo_moon.ecliptic, geo_moon.tobl)
		var sun_j2000: Vector3 = AstroSun.sun_position(_current_time)
		var phase: float = AstroEngine.moon_phase(sun_j2000, geo_moon.j2000, _current_time)
		var phase_name: String = CelestialState.phase_name(phase)
		var illum: float = CelestialState.phase_to_illumination(phase)
		text += "[b]Moon[/b]\n\n"
		text += "Phase: %s (%.0f°)\n" % [phase_name, phase]
		text += "Illumination: %.0f%%\n" % (illum * 100.0)
		text += "Distance from Earth: %.0f km\n" % lib.dist_km
		text += "Apparent diameter: %.4f°\n" % lib.diam_deg
		text += "Orbital period: 27.3 days\n"
		info_label.text = text
		return

	if _selected < 0 or _selected >= PLANET_COUNT:
		return

	var body_name: String = PLANET_NAMES[_selected]
	var pos: Vector3 = _planet_positions[_selected]
	var helio_dist: float = pos.length()

	# 地心距離
	var earth_pos: Vector3 = _planet_positions[Body.EARTH]
	var geo_dist: float = (pos - earth_pos).length()

	# 從地球觀測的方位角/高度角（台北預設）
	var now_dict: Dictionary = Time.get_datetime_dict_from_system(true)
	var hor: AstroCoords.HorizonCoord = AstroPlanets.planet_horizon(
		_selected as AstroPlanets.Planet,
		now_dict.year, now_dict.month, now_dict.day,
		now_dict.hour, now_dict.minute, float(now_dict.second),
		25.03, 121.56)

	var above: String = "Yes" if hor.altitude > 0.0 else "No"

	text += "[b]%s[/b]\n\n" % body_name
	text += "Distance from Sun: %.4f AU\n" % helio_dist
	text += "Distance from Earth: %.4f AU\n" % geo_dist
	text += "Orbital period: %.1f days\n\n" % ORBIT_PERIODS_DAYS[_selected]
	text += "[b]From Taipei (25°N, 121°E)[/b]\n"
	text += "Azimuth: %.1f°\n" % hor.azimuth
	text += "Altitude: %.1f°\n" % hor.altitude
	text += "Above horizon: %s\n" % above

	# 地球特有：月球資訊
	if _selected == Body.EARTH:
		var geo_moon: AstroMoon.GeoMoonResult = AstroMoon.geo_moon(_current_time)
		var lib: AstroMoon.LibrationResult = AstroMoon.libration(
			_current_time, geo_moon.ecliptic, geo_moon.tobl)
		var sun_j2000: Vector3 = AstroSun.sun_position(_current_time)
		var phase: float = AstroEngine.moon_phase(sun_j2000, geo_moon.j2000, _current_time)
		var phase_name: String = CelestialState.phase_name(phase)
		var illum: float = CelestialState.phase_to_illumination(phase)

		text += "\n[b]Moon[/b]\n"
		text += "Phase: %s (%.0f°)\n" % [phase_name, phase]
		text += "Illumination: %.0f%%\n" % (illum * 100.0)
		text += "Distance: %.0f km\n" % lib.dist_km
		text += "Apparent diameter: %.4f°\n" % lib.diam_deg

	info_label.text = text


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var key: InputEventKey = event as InputEventKey
		match key.keycode:
			KEY_LEFT:
				_select_prev()
			KEY_RIGHT:
				_select_next()
			KEY_UP:
				_time_offset_days += 30.0
			KEY_DOWN:
				_time_offset_days -= 30.0
			KEY_ESCAPE:
				_deselect()
			KEY_HOME:
				_time_offset_days = 0.0
			KEY_SPACE:
				_speed_idx = (_speed_idx + 1) % TIME_SPEEDS.size()
				_time_speed = TIME_SPEEDS[_speed_idx]
			KEY_R:
				_time_offset_days = 0.0
				_speed_idx = 0
				_time_speed = 0.0
