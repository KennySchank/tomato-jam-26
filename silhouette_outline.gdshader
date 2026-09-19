shader_type canvas_item;

uniform bool outline_enabled = false;
uniform vec4 outline_color : source_color = vec4(1.0, 0.95, 0.45, 0.95);
uniform float outline_width = 4.0;

void vertex() {
	// Expand the quad so the outline has transparent padding to render into.
	if (outline_enabled) {
		VERTEX += sign(VERTEX) * outline_width;
	}
}

void fragment() {
	vec4 sprite_color = texture(TEXTURE, UV);
	if (!outline_enabled) {
		COLOR = sprite_color;
	} else if (sprite_color.a > 0.0) {
		COLOR = sprite_color;
	} else {
		float radius = outline_width * max(TEXTURE_PIXEL_SIZE.x, TEXTURE_PIXEL_SIZE.y);
		float surrounding_alpha = 0.0;
		for (float x = -1.0; x <= 1.0; x += 1.0) {
			for (float y = -1.0; y <= 1.0; y += 1.0) {
				surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV + vec2(x, y) * radius).a);
			}
		}
		COLOR = surrounding_alpha > 0.0 ? outline_color : vec4(0.0);
	}
}
