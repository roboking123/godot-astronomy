class_name DirectionalLightAdapter
## Example SkyAdapter — drives a DirectionalLight3D with sun/moon position.
## Assign a light node path, and this adapter will update its direction,
## color, and energy every frame based on astronomical data.
extends SkyAdapter


@export var sun_light_path: NodePath
@export var moon_light_path: NodePath

## Sun color at different altitudes
@export var sun_color_day: Color = Color(1.0, 0.95, 0.9)
@export var sun_color_sunset: Color = Color(1.0, 0.6, 0.3)
@export var sun_max_energy: float = 1.0

## Moon light parameters
@export var moon_color: Color = Color(0.6, 0.65, 0.8)
@export var moon_max_energy: float = 0.15

var _sun_light: DirectionalLight3D
var _moon_light: DirectionalLight3D
var _resolved: bool = false


func apply(state: CelestialState) -> void:
	if not _resolved:
		_resolve_lights(state)

	var sun_up: Vector3 = Vector3.FORWARD if absf(state.sun_direction.y) > 0.99 else Vector3.UP

	if _sun_light != null:
		_sun_light.look_at_from_position(
			_sun_light.global_position,
			_sun_light.global_position - state.sun_direction,
			sun_up
		)
		var alt: float = state.sun_altitude
		if alt > 10.0:
			_sun_light.light_color = sun_color_day
		elif alt > -2.0:
			var t: float = clampf((alt + 2.0) / 12.0, 0.0, 1.0)
			_sun_light.light_color = sun_color_sunset.lerp(sun_color_day, t)
		else:
			_sun_light.light_color = sun_color_sunset
		_sun_light.light_energy = state.sun_energy * sun_max_energy
		_sun_light.visible = state.sun_energy > 0.01

	if _moon_light != null:
		var moon_up: Vector3 = Vector3.FORWARD if absf(state.moon_direction.y) > 0.99 else Vector3.UP
		_moon_light.look_at_from_position(
			_moon_light.global_position,
			_moon_light.global_position - state.moon_direction,
			moon_up
		)
		var moon_energy: float = state.moon_illumination * moon_max_energy
		if state.moon_altitude < 0.0:
			moon_energy *= clampf((state.moon_altitude + 5.0) / 5.0, 0.0, 1.0)
		_moon_light.light_energy = moon_energy
		_moon_light.light_color = moon_color
		_moon_light.visible = moon_energy > 0.001 and state.moon_altitude > -5.0


func _resolve_lights(state: CelestialState) -> void:
	# SkyAdapter is a Resource, not a Node — we need the tree.
	# This adapter expects to be used via CelestialBody which passes state.
	# Light resolution happens lazily on first apply through a workaround:
	# The paths are resolved relative to the scene root.
	_resolved = true
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var root: Node = tree.current_scene
	if root == null:
		return
	if not sun_light_path.is_empty():
		_sun_light = root.get_node_or_null(sun_light_path) as DirectionalLight3D
	if not moon_light_path.is_empty():
		_moon_light = root.get_node_or_null(moon_light_path) as DirectionalLight3D
