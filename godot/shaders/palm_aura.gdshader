shader_type canvas_item;

uniform int mode : hint_range(0, 2) = 0;
uniform vec4 core_color : source_color = vec4(1.0, 0.96, 0.78, 1.0);
uniform vec4 mid_color : source_color = vec4(1.0, 0.7, 0.28, 1.0);
uniform vec4 outer_color : source_color = vec4(1.0, 0.35, 0.05, 1.0);
uniform float charge : hint_range(0.0, 1.0) = 0.5;
uniform float openness : hint_range(0.0, 1.0) = 0.5;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	// Strong size link: charge + openness
	float power = max(charge, openness * 0.7);
	float t = TIME;
	float r = length(uv);

	float n = noise(uv * 3.5 + vec2(0.0, -t * 1.6));
	float body = 1.0 - smoothstep(0.15 + power * 0.15, 0.75 + power * 0.35, r + n * 0.2);
	float core = 1.0 - smoothstep(0.0, 0.35 + power * 0.1, r);

	vec3 col = mix(outer_color.rgb, mid_color.rgb, body);
	col = mix(col, core_color.rgb, core);

	if (mode == 1) {
		// frost shards
		float ang = atan(uv.y, uv.x);
		float shard = smoothstep(0.5, 0.15, abs(sin(ang * 6.0)) * r);
		col += mid_color.rgb * shard * 0.5;
		body = max(body, shard * 0.55);
	} else if (mode == 2) {
		float bolt = 1.0 - smoothstep(0.02, 0.1, abs(uv.x + 0.12 * sin(uv.y * 16.0 + t * 10.0)));
		col += mid_color.rgb * bolt * 0.7;
		body = max(body, bolt * 0.7);
	}

	float alpha = body * (0.25 + power * 0.85);
	alpha *= 1.0 - smoothstep(0.9, 1.2, r);
	if (power < 0.05) {
		alpha = 0.0;
	}
	COLOR = vec4(col, clamp(alpha, 0.0, 1.0));
}
