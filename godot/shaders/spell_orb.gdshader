shader_type canvas_item;

// Multi-spell orb: fire / frost / lightning via `mode` (0/1/2)
uniform int mode : hint_range(0, 2) = 0;
uniform vec4 core_color : source_color = vec4(1.0, 0.96, 0.78, 1.0);
uniform vec4 mid_color : source_color = vec4(1.0, 0.7, 0.28, 1.0);
uniform vec4 outer_color : source_color = vec4(1.0, 0.35, 0.05, 1.0);
uniform float intensity : hint_range(0.2, 2.5) = 1.0;
uniform float time_scale : hint_range(0.1, 4.0) = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.05;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float t = TIME * time_scale;
	float r = length(uv);
	float ang = atan(uv.y, uv.x);

	vec3 col = vec3(0.0);
	float alpha = 0.0;

	if (mode == 0) {
		// FIRE — turbulent rising tongues
		float n = fbm(vec2(uv.x * 2.4, uv.y * 2.4 - t * 1.8));
		float shape = 1.0 - smoothstep(0.25, 0.95, r + n * 0.28 - 0.08);
		float core = 1.0 - smoothstep(0.0, 0.42, r);
		col = mix(outer_color.rgb, mid_color.rgb, shape);
		col = mix(col, core_color.rgb, core * 0.9);
		col += core_color.rgb * core * 0.35;
		alpha = shape * intensity;
		// embers
		float sparks = step(0.82, noise(uv * 8.0 + vec2(0.0, -t * 2.0)));
		col += mid_color.rgb * sparks * 0.5;
		alpha = max(alpha, sparks * 0.35 * intensity);
	} else if (mode == 1) {
		// FROST — crystalline hex + soft bloom
		float hex = abs(cos(ang * 3.0 + t * 0.6)) * 0.15;
		float shape = 1.0 - smoothstep(0.35, 0.92, r + hex);
		float shard = smoothstep(0.55, 0.2, abs(sin(ang * 6.0)) * r);
		float core = 1.0 - smoothstep(0.0, 0.38, r);
		float n = fbm(uv * 3.0 + t * 0.3);
		col = mix(outer_color.rgb, mid_color.rgb, shape);
		col = mix(col, core_color.rgb, core);
		col += mid_color.rgb * shard * 0.55;
		col += core_color.rgb * n * 0.12;
		alpha = max(shape, shard * 0.6) * intensity;
	} else {
		// LIGHTNING — crackling bolts + electric core
		float bolt = abs(uv.x + 0.18 * sin(uv.y * 14.0 + t * 12.0) + 0.08 * sin(uv.y * 30.0 - t * 18.0));
		float line = 1.0 - smoothstep(0.02, 0.12, bolt);
		float branch = 1.0 - smoothstep(0.015, 0.09, abs(uv.y + 0.2 * sin(uv.x * 20.0 + t * 10.0)));
		float core = 1.0 - smoothstep(0.0, 0.45, r);
		float glow = 1.0 - smoothstep(0.2, 1.0, r);
		col = mix(outer_color.rgb, mid_color.rgb, line);
		col = mix(col, core_color.rgb, core * 0.85);
		col += mid_color.rgb * branch * 0.45;
		col += outer_color.rgb * glow * 0.25;
		alpha = max(max(line, branch * 0.7), core * 0.65) * glow * intensity;
	}

	alpha = clamp(alpha, 0.0, 1.0);
	// soft edge
	alpha *= 1.0 - smoothstep(0.85, 1.15, r);
	COLOR = vec4(col * intensity, alpha);
}
