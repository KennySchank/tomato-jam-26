shader_type canvas_item;
render_mode unshaded;

uniform vec4 shadow_color : source_color = vec4(0.12, 0.19, 0.16, 1.0);
uniform float shadow_strength : hint_range(0.0, 1.0) = 0.38;
uniform vec2 drift = vec2(0.024, 0.001);
uniform vec2 cloud_scale = vec2(3.0, 1.8);
uniform float edge_start : hint_range(0.0, 1.0) = 0.48;
uniform float edge_end : hint_range(0.0, 1.0) = 0.60;

float hash(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = smoothstep(0.0, 1.0, fract(point));
	float bottom = mix(hash(cell), hash(cell + vec2(1.0, 0.0)), local.x);
	float top = mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), local.x);
	return mix(bottom, top, local.y);
}

float cloud_noise(vec2 point) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int octave = 0; octave < 4; octave++) {
		value += noise(point) * amplitude;
		point = point * 2.0 + vec2(17.3, 9.1);
		amplitude *= 0.5;
	}
	return value;
}

void fragment() {
	vec2 cloud_uv = UV * cloud_scale + TIME * drift;
	float broad_clouds = cloud_noise(cloud_uv);
	float soft_edges = cloud_noise(cloud_uv * 1.7 + vec2(4.2, 2.8));
	float coverage = smoothstep(edge_start, edge_end, broad_clouds * 0.8 + soft_edges * 0.2);

	COLOR = vec4(shadow_color.rgb, coverage * shadow_strength);
}
