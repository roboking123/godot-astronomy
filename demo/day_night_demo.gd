extends Node3D
## 3D Day/Night demo — shows CelestialBody driving sun and moon lights in real time.
## Controls: ← → ±1 hour, ↑ ↓ ±1 day, Space = pause, 1-5 = time scale, R = reset

@onready var celestial: CelestialBody = $CelestialBody
@onready var info_label: Label = $UI/InfoLabel
@onready var help_label: Label = $UI/HelpLabel
@onready var environment: WorldEnvironment = $WorldEnvironment
@onready var camera: Camera3D = $Camera3D

var _time_scales: Array[float] = [1.0, 60.0, 600.0, 3600.0, 86400.0]
var _scale_names: Array[String] = ["Real-time", "1 min/sec", "10 min/sec", "1 hr/sec", "1 day/sec"]
var _current_scale_idx: int = 3

# 瑞利散射預計算天空色查找表（64 格，太陽高度 -18°~90°）
var _sky_lut: PackedColorArray

# 自由鏡頭
var _mouse_captured: bool = false
var _cam_yaw: float = 0.0
var _cam_pitch: float = -20.0
const CAM_SPEED: float = 10.0
const CAM_SENSITIVITY: float = 0.15
const CELESTIAL_DIST: float = 800.0

var _sun_mesh: MeshInstance3D
var _moon_mesh: MeshInstance3D
var _moon_mat: ShaderMaterial
var _planet_meshes: Dictionary = {}  # name → MeshInstance3D
var _planet_mats: Dictionary = {}    # name → ShaderMaterial


func _ready() -> void:
	_sky_lut = _bake_sky_lut()
	celestial.time_scale = _time_scales[_current_scale_idx]
	celestial.use_system_time = true
	help_label.text = "WASD=move | QE=up/down | Mouse=look | Shift=fast | ESC=toggle mouse | ← → ±1hr | ↑ ↓ ±1day | Space=pause | 1-5=speed | R=reset | Backspace=menu"

	celestial.sunrise.connect(func() -> void: _flash_message("Sunrise"))
	celestial.sunset.connect(func() -> void: _flash_message("Sunset"))

	# 鏡頭初始朝向
	var cam_rot: Vector3 = camera.rotation_degrees
	_cam_yaw = cam_rot.y
	_cam_pitch = cam_rot.x
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_mouse_captured = true

	_sun_mesh = _create_disc("res://demo/shaders/sun_disc.gdshader", 60.0)
	var result: Array = _create_disc_with_mat("res://demo/shaders/moon_disc.gdshader", 30.0)
	_moon_mesh = result[0] as MeshInstance3D
	_moon_mat = result[1] as ShaderMaterial

	celestial.compute_planets = true
	var planet_colors: Dictionary = {
		"Mercury": Color(0.8, 0.75, 0.7),
		"Venus": Color(1.0, 0.95, 0.8),
		"Mars": Color(1.0, 0.6, 0.4),
		"Jupiter": Color(0.9, 0.85, 0.7),
		"Saturn": Color(0.95, 0.9, 0.6),
		"Uranus": Color(0.6, 0.85, 0.9),
		"Neptune": Color(0.5, 0.6, 1.0),
	}
	for pname: String in planet_colors:
		var pr: Array = _create_disc_with_mat("res://demo/shaders/star_point.gdshader", 6.0)
		var mesh: MeshInstance3D = pr[0] as MeshInstance3D
		var mat: ShaderMaterial = pr[1] as ShaderMaterial
		mat.set_shader_parameter("star_color", planet_colors[pname])
		mat.set_shader_parameter("brightness", 2.5 if pname == "Venus" else 1.5)
		mesh.visible = false
		_planet_meshes[pname] = mesh
		_planet_mats[pname] = mat


func _process(delta: float) -> void:
	_move_camera(delta)
	_update_celestial_meshes()
	_update_info()
	_update_sky_color()


func _unhandled_input(event: InputEvent) -> void:
	# 滑鼠視角
	if event is InputEventMouseMotion and _mouse_captured:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		_cam_yaw -= motion.relative.x * CAM_SENSITIVITY
		_cam_pitch = clampf(_cam_pitch - motion.relative.y * CAM_SENSITIVITY, -89.0, 89.0)
		camera.rotation_degrees = Vector3(_cam_pitch, _cam_yaw, 0.0)

	if event is InputEventKey and event.pressed:
		match (event as InputEventKey).keycode:
			KEY_ESCAPE:
				_mouse_captured = not _mouse_captured
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _mouse_captured else Input.MOUSE_MODE_VISIBLE
			KEY_LEFT:
				celestial.advance_time(-1.0 / 24.0)
			KEY_RIGHT:
				celestial.advance_time(1.0 / 24.0)
			KEY_DOWN:
				celestial.advance_time(-1.0)
			KEY_UP:
				celestial.advance_time(1.0)
			KEY_SPACE:
				celestial.paused = not celestial.paused
			KEY_R:
				celestial.set_datetime(2026, 1, 1, 12, 0, 0.0)
				celestial.use_system_time = true
			KEY_1:
				_set_scale(0)
			KEY_2:
				_set_scale(1)
			KEY_3:
				_set_scale(2)
			KEY_4:
				_set_scale(3)
			KEY_5:
				_set_scale(4)
			KEY_BACKSPACE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				get_tree().change_scene_to_file("res://demo/main_menu.tscn")


func _move_camera(delta: float) -> void:
	if not _mouse_captured:
		return
	var dir: Vector3 = Vector3.ZERO
	if Input.is_key_pressed(KEY_W): dir -= camera.basis.z
	if Input.is_key_pressed(KEY_S): dir += camera.basis.z
	if Input.is_key_pressed(KEY_A): dir -= camera.basis.x
	if Input.is_key_pressed(KEY_D): dir += camera.basis.x
	if Input.is_key_pressed(KEY_E): dir += Vector3.UP
	if Input.is_key_pressed(KEY_Q): dir += Vector3.DOWN
	if dir.length_squared() > 0.0:
		var speed: float = CAM_SPEED * (3.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0)
		camera.position += dir.normalized() * speed * delta


func _create_disc(shader_path: String, size: float) -> MeshInstance3D:
	var result: Array = _create_disc_with_mat(shader_path, size)
	return result[0] as MeshInstance3D


func _create_disc_with_mat(shader_path: String, size: float) -> Array:
	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(size, size)
	mesh_inst.mesh = quad
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = load(shader_path) as Shader
	mesh_inst.material_override = mat
	mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_inst)
	return [mesh_inst, mat]


func _update_celestial_meshes() -> void:
	var s: CelestialState = celestial.state
	var cam_pos: Vector3 = camera.global_position

	_sun_mesh.global_position = cam_pos + s.sun_direction * CELESTIAL_DIST
	_sun_mesh.visible = s.sun_altitude > -3.0

	_moon_mesh.global_position = cam_pos + s.moon_direction * CELESTIAL_DIST
	_moon_mesh.visible = s.moon_altitude > -3.0
	_moon_mat.set_shader_parameter("illumination", s.moon_illumination)

	for pname: String in _planet_meshes:
		var mesh: MeshInstance3D = _planet_meshes[pname] as MeshInstance3D
		if s.planet_directions.has(pname):
			var alt: float = s.planet_altitudes[pname] as float
			mesh.global_position = cam_pos + (s.planet_directions[pname] as Vector3) * CELESTIAL_DIST
			mesh.visible = alt > 0.0
		else:
			mesh.visible = false


func _set_scale(idx: int) -> void:
	_current_scale_idx = idx
	celestial.time_scale = _time_scales[idx]


func _update_info() -> void:
	var s: CelestialState = celestial.state
	var jd: float = s.julian_day
	var pause_str: String = " [PAUSED]" if celestial.paused else ""

	var condition: String
	if s.is_day: condition = "Day"
	elif s.is_civil_twilight: condition = "Civil Twilight"
	elif s.is_nautical_twilight: condition = "Nautical Twilight"
	elif s.is_astronomical_twilight: condition = "Astro Twilight"
	else: condition = "Night"

	var planet_str: String = ""
	for pname: String in s.planet_altitudes:
		var alt: float = s.planet_altitudes[pname] as float
		if alt > 0.0:
			planet_str += "%s %.0f° | " % [pname, alt]
	if planet_str.length() > 3:
		planet_str = planet_str.left(planet_str.length() - 3)
	else:
		planet_str = "(none above horizon)"

	info_label.text = (
		"Sun: Alt %.1f°  Az %.1f°  Energy %.0f%%\n" % [s.sun_altitude, s.sun_azimuth, s.sun_energy * 100] +
		"Moon: %s (%.0f%% lit)  Alt %.1f°\n" % [s.moon_phase_name, s.moon_illumination * 100, s.moon_altitude] +
		"Planets: %s\n" % planet_str +
		"Sky: %s  Darkness %.0f%%\n" % [condition, s.sky_darkness * 100] +
		"Speed: %s%s\n" % [_scale_names[_current_scale_idx], pause_str] +
		"JD: %.4f" % jd
	)


func _update_sky_color() -> void:
	var s: CelestialState = celestial.state
	var env: Environment = environment.environment
	if env == null:
		return

	var sky_color: Color = _sample_sky_lut(s.sun_altitude)

	env.background_mode = Environment.BG_COLOR
	env.background_color = sky_color

	env.ambient_light_energy = lerpf(0.02, 0.4, 1.0 - s.sky_darkness)
	env.ambient_light_color = sky_color.lerp(Color.WHITE, 0.5)


## 從查找表取樣天空色（線性插值）
func _sample_sky_lut(sun_alt_deg: float) -> Color:
	var t: float = (sun_alt_deg + 18.0) / 108.0  # -18°→0, 90°→1
	t = clampf(t, 0.0, 1.0)
	var idx_f: float = t * (_sky_lut.size() - 1)
	var i0: int = int(idx_f)
	var i1: int = mini(i0 + 1, _sky_lut.size() - 1)
	var frac: float = idx_f - float(i0)
	return _sky_lut[i0].lerp(_sky_lut[i1], frac)


## 天空色查找表烘焙 — 參考 Sky3D Preetham 簡化散射
## 掃太陽高度 -18°~90°，天頂方向瑞利散射
func _bake_sky_lut() -> PackedColorArray:
	const STEPS: int = 64
	const RAYLEIGH_ZENITH: float = 8.4e3
	const SUN_INTENSITY: float = 18.0
	const NIGHT_COLOR: Vector3 = Vector3(0.01, 0.01, 0.04)
	const DAY_TINT: Vector3 = Vector3(0.8, 0.85, 1.0)

	# 波長 680nm, 550nm, 440nm 的瑞利散射係數
	var beta_ray: Vector3 = _compute_beta_ray(Vector3(680.0, 550.0, 440.0))

	var lut: PackedColorArray = PackedColorArray()
	lut.resize(STEPS)

	for i: int in STEPS:
		var sun_deg: float = lerpf(-18.0, 90.0, float(i) / float(STEPS - 1))
		# 太陽方向的 Y 值（仰角正弦）
		var sun_y: float = sin(deg_to_rad(sun_deg))

		# Sky3D 簡化光程：1 / (y * scale) * zenith_length
		var view_y: float = 1.0  # 天頂
		var sr: float = 1.0 / maxf(view_y + 0.03, 0.03) * RAYLEIGH_ZENITH

		# 消光因子
		var extc: Vector3 = Vector3(
			exp(-beta_ray.x * sr),
			exp(-beta_ray.y * sr),
			exp(-beta_ray.z * sr)
		)
		var one_minus_extc: Vector3 = Vector3.ONE - extc

		# 太陽光程（越低越長 → 紅光透過）
		var sun_sr: float = 1.0 / maxf(sun_y + 0.03, 0.03) * RAYLEIGH_ZENITH
		var sun_extc: Vector3 = Vector3(
			exp(-beta_ray.x * sun_sr),
			exp(-beta_ray.y * sun_sr),
			exp(-beta_ray.z * sun_sr)
		)

		# 瑞利相函數（天頂看太陽，散射角 ≈ 90° - sun_elev）
		var mu: float = sun_y  # cos(90° - elev) = sin(elev)
		var phase: float = 3.0 / (8.0 * PI) * (1.0 + mu * mu)

		# 散射輻射亮度
		var scatter: Vector3 = Vector3(
			SUN_INTENSITY * phase * beta_ray.x * one_minus_extc.x * sun_extc.x / (beta_ray.x + 1e-10),
			SUN_INTENSITY * phase * beta_ray.y * one_minus_extc.y * sun_extc.y / (beta_ray.y + 1e-10),
			SUN_INTENSITY * phase * beta_ray.z * one_minus_extc.z * sun_extc.z / (beta_ray.z + 1e-10)
		)

		# 日間色調
		scatter *= DAY_TINT

		# 夜間漸暗
		var night_t: float = clampf((-deg_to_rad(sun_deg) - deg_to_rad(3.0)) / deg_to_rad(15.0), 0.0, 1.0)
		scatter = scatter.lerp(NIGHT_COLOR, night_t)

		# 曝光色調映射（Sky3D 的 photo tonemap）
		scatter *= 3.0
		scatter = Vector3(
			lerpf(scatter.x, 1.0 - exp(-scatter.x), 0.7),
			lerpf(scatter.y, 1.0 - exp(-scatter.y), 0.7),
			lerpf(scatter.z, 1.0 - exp(-scatter.z), 0.7)
		)

		lut[i] = Color(scatter.x, scatter.y, scatter.z)

	return lut


## Sky3D ScatterLib 的瑞利散射係數計算
func _compute_beta_ray(wavelengths_nm: Vector3) -> Vector3:
	const _n_air: float = 1.0003  # n²= n_air² 用於下面的 n2
	const n2: float = 1.00060009
	const mol_N: float = 2.545e25
	const pn_depol: float = 0.035
	var kr: float = 8.0 * pow(PI, 3.0) * pow(n2 - 1.0, 2.0) * (6.0 + 3.0 * pn_depol)
	var wl: Vector3 = wavelengths_nm * 1e-9
	var wl4: Vector3 = Vector3(pow(wl.x, 4.0), pow(wl.y, 4.0), pow(wl.z, 4.0))
	var denom: Vector3 = 3.0 * mol_N * wl4 * (6.0 - 7.0 * pn_depol)
	return Vector3(kr / denom.x, kr / denom.y, kr / denom.z)


var _flash_timer: float = 0.0
var _flash_text: String = ""

func _flash_message(msg: String) -> void:
	_flash_text = msg
	_flash_timer = 3.0
