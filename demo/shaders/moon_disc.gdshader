shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec4 disc_color : source_color = vec4(0.9, 0.92, 0.95, 1.0);
uniform float disc_size : hint_range(0.0, 0.5) = 0.2;
uniform float illumination : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]
	);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0)
	);
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float dist = length(uv);
	float disc = 1.0 - smoothstep(disc_size - 0.01, disc_size + 0.01, dist);
	float glow = exp(-dist * dist * 15.0) * 0.2;
	float total = (disc * 2.0 + glow) * illumination;
	ALBEDO = disc_color.rgb * total;
	ALPHA = clamp(total, 0.0, 1.0);
}
