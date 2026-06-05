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

# 資訊面板的觀測地點（改這兩個值就能換地點）
const OBSERVER_LAT: float = 25.03
const OBSERVER_LON: float = 121.56

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
var _rebake_cooldown: float = 0.0
const REBAKE_MIN_INTERVAL: float = 0.5  # 最短重烘焙間隔（秒）
var _bake_queue: Array[int] = []  # 待烘焙的行星索引
var _bake_base_ut: float = 0.0
const BAKE_PLANETS_PER_FRAME: int = 2  # 每幀最多烘焙幾顆行星
var _info_update_timer: float = 0.0
const INFO_UPDATE_INTERVAL: float = 0.2  # 資訊面板更新間隔（秒）
var _prev_offset_days: float = 0.0  # 上一幀的時間偏移，用來判斷是否需要重繪

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
	_bake_orbits_sync()


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

	# 任何行星在螢幕上偏離軌道超過 2 像素就重烘焙（有冷卻時間）
	_rebake_cooldown -= delta
	if _rebake_cooldown <= 0.0:
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
			_rebake_cooldown = REBAKE_MIN_INTERVAL

	_bake_tick()

	if _selected >= 0:
		_info_update_timer -= delta
		if _info_update_timer <= 0.0:
			_update_info_panel()
			_info_update_timer = INFO_UPDATE_INTERVAL

	# 只在畫面有變化時才重繪
	if _time_speed != 0.0 or _time_offset_days != _prev_offset_days or not _bake_queue.is_empty():
		_prev_offset_days = _time_offset_days
		queue_redraw()


func _update_positions() -> void:
	var now: Dictionary = Time.get_datetime_dict_from_system(true)
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
	_bake_base_ut = _current_time.ut
	_bake_queue.clear()
	for i: int in PLANET_COUNT:
		_bake_queue.append(i)
	_bake_queue.append(-1)  # -1 = 月球軌道


func _bake_orbits_sync() -> void:
	_bake_base_ut = _current_time.ut
	_bake_queue.clear()
	for i: int in PLANET_COUNT:
		_bake_planet_orbit(i)
	_bake_moon_orbit()


func _bake_tick() -> void:
	if _bake_queue.is_empty():
		return
	var count: int = 0
	while not _bake_queue.is_empty() and count < BAKE_PLANETS_PER_FRAME:
		var idx: int = _bake_queue.pop_front()
		if idx == -1:
			_bake_moon_orbit()
		else:
			_bake_planet_orbit(idx)
		count += 1


func _bake_planet_orbit(i: int) -> void:
	var planet: AstroPlanets.Planet = i as AstroPlanets.Planet
	var period: float = ORBIT_PERIODS_DAYS[i]
	var pts: PackedVector2Array = PackedVector2Array()
	pts.resize(ORBIT_SAMPLES + 1)
	for j: int in ORBIT_SAMPLES + 1:
		var t: AstroTime.Moment = AstroTime.time_from_days(
			_bake_base_ut + period * float(j) / float(ORBIT_SAMPLES))
		var pos: Vector3
		if planet == Body.EARTH:
			pos = -AstroSun.sun_position(t)
		else:
			pos = AstroPlanets.helio_position(planet, t)
		pts[j] = Vector2(pos.x, -pos.y)
	_orbit_points[i] = pts
	_orbit_base_pos[i] = pts[0]


func _bake_moon_orbit() -> void:
	var moon_pts: PackedVector2Array = PackedVector2Array()
	var moon_samples: int = 60
	moon_pts.resize(moon_samples + 1)
	for j: int in moon_samples + 1:
		var t: AstroTime.Moment = AstroTime.time_from_days(
			_bake_base_ut - 13.65 + 27.3 * float(j) / float(moon_samples))
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
	_info_update_timer = 0.0
	_bake_orbits_sync()


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
	_bake_orbits_sync()


func _update_info_panel() -> void:
	var t: String = ""

	if _selected == Body.SUN:
		t += "[b][color=#f0c050]☀ Sun[/color][/b]\n\n"
		t += "[color=#888]Type[/color]  [color=#a0d8ef]G2V Main Sequence[/color]\n"
		t += "[color=#888]Dist from Earth[/color]  [color=#a0d8ef]%.4f AU[/color]\n" % _planet_positions[Body.EARTH].length()
		info_label.text = t
		return

	if _selected == Body.MOON:
		var geo_moon: AstroMoon.GeoMoonResult = AstroMoon.geo_moon(_current_time)
		var lib: AstroMoon.LibrationResult = AstroMoon.libration(
			_current_time, geo_moon.ecliptic, geo_moon.tobl)
		var sun_j2000: Vector3 = AstroSun.sun_position(_current_time)
		var phase: float = AstroEngine.moon_phase(sun_j2000, geo_moon.j2000, _current_time)
		var phase_name: String = CelestialState.phase_name(phase)
		var illum: float = CelestialState.phase_to_illumination(phase)
		t += "[b][color=#b0c4de]☽ Moon[/color][/b]\n\n"
		t += "[color=#888]Phase[/color]  [color=#a0d8ef]%s[/color] [color=#888](%.0f°)[/color]\n" % [phase_name, phase]
		t += "[color=#888]Illum[/color]  [color=#a0d8ef]%.0f%%[/color]\n" % (illum * 100.0)
		t += "[color=#888]Dist[/color]   [color=#a0d8ef]%.0f km[/color]\n" % lib.dist_km
		t += "[color=#888]Diameter[/color] [color=#a0d8ef]%.4f°[/color]\n" % lib.diam_deg
		t += "[color=#888]Period[/color]  [color=#a0d8ef]27.3 days[/color]\n"
		info_label.text = t
		return

	if _selected < 0 or _selected >= PLANET_COUNT:
		return

	var body_name: String = PLANET_NAMES[_selected]
	var pos: Vector3 = _planet_positions[_selected]
	var helio_dist: float = pos.length()

	var earth_pos: Vector3 = _planet_positions[Body.EARTH]
	var geo_dist: float = (pos - earth_pos).length()

	var now_dict: Dictionary = Time.get_datetime_dict_from_system(true)
	var hor: AstroCoords.HorizonCoord = AstroPlanets.planet_horizon(
		_selected as AstroPlanets.Planet,
		now_dict.year, now_dict.month, now_dict.day,
		now_dict.hour, now_dict.minute, float(now_dict.second),
		OBSERVER_LAT, OBSERVER_LON)

	var above_str: String = "[color=#6be86b]Yes[/color]" if hor.altitude > 0.0 else "[color=#e86b6b]No[/color]"

	t += "[b][color=#c4a0e8]%s[/color][/b]\n\n" % body_name
	t += "[color=#888]Dist from Sun[/color]   [color=#a0d8ef]%.4f AU[/color]\n" % helio_dist
	t += "[color=#888]Dist from Earth[/color] [color=#a0d8ef]%.4f AU[/color]\n" % geo_dist
	t += "[color=#888]Period[/color]  [color=#a0d8ef]%.1f days[/color]\n" % ORBIT_PERIODS_DAYS[_selected]
	t += "\n"
	t += "[b][color=#7ec8e3]Observer %.1f°N, %.1f°E[/color][/b]\n" % [OBSERVER_LAT, OBSERVER_LON]
	t += "[color=#888]Az[/color]   [color=#a0d8ef]%.1f°[/color]\n" % hor.azimuth
	t += "[color=#888]Alt[/color]  [color=#a0d8ef]%.1f°[/color]\n" % hor.altitude
	t += "[color=#888]Above horizon[/color]  %s\n" % above_str

	if _selected == Body.EARTH:
		var geo_moon: AstroMoon.GeoMoonResult = AstroMoon.geo_moon(_current_time)
		var lib: AstroMoon.LibrationResult = AstroMoon.libration(
			_current_time, geo_moon.ecliptic, geo_moon.tobl)
		var sun_j2000: Vector3 = AstroSun.sun_position(_current_time)
		var phase: float = AstroEngine.moon_phase(sun_j2000, geo_moon.j2000, _current_time)
		var phase_name: String = CelestialState.phase_name(phase)
		var illum: float = CelestialState.phase_to_illumination(phase)

		t += "\n[b][color=#b0c4de]☽ Moon[/color][/b]\n"
		t += "[color=#888]Phase[/color]  [color=#a0d8ef]%s[/color] [color=#888](%.0f°)[/color]\n" % [phase_name, phase]
		t += "[color=#888]Illum[/color]  [color=#a0d8ef]%.0f%%[/color]\n" % (illum * 100.0)
		t += "[color=#888]Dist[/color]   [color=#a0d8ef]%.0f km[/color]\n" % lib.dist_km
		t += "[color=#888]Diameter[/color] [color=#a0d8ef]%.4f°[/color]\n" % lib.diam_deg

	info_label.text = t


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
			KEY_BACKSPACE:
				_go_back()


func _go_back() -> void:
	get_tree().change_scene_to_file("res://demo/main_menu.tscn")


func _on_back_pressed() -> void:
	_go_back()
