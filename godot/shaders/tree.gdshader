// Arbres nus dans le vent : le tronc tient, les branches hautes ploient et frémissent.
shader_type spatial;

uniform vec3 color : source_color = vec3(0.06, 0.055, 0.05);
uniform float base_y = -2.8;
uniform float height = 9.0;
uniform float wind = 1.0;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float k = clamp((w.y - base_y) / height, 0.0, 1.0);
	k = k * k;
	float gust = 0.6 + 0.4 * sin(TIME * 0.31 + w.x * 0.05);
	float sway = sin(TIME * 1.1 + w.x * 0.3 + w.z * 0.2) * 0.35 + sin(TIME * 2.7 + w.y * 1.3) * 0.08;
	VERTEX.x += sway * k * wind * gust;
	VERTEX.z += cos(TIME * 0.9 + w.z * 0.4) * 0.18 * k * wind * gust;
}

void fragment() {
	ALBEDO = color;
	ROUGHNESS = 0.9;
}
