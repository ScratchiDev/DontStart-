// Rideau : plis et léger mouvement (un courant d'air qui ne devrait pas exister, la fenêtre est fermée).
shader_type spatial;
render_mode cull_disabled;

uniform vec3 color : source_color = vec3(0.29, 0.12, 0.15);
uniform float sway = 0.015;

void vertex() {
	float folds = sin(VERTEX.x * 26.0) * 0.035;
	float drift = sin(TIME * 0.7 + VERTEX.y * 2.0) * sway * (1.0 - UV.y);
	VERTEX.z += folds + drift;
}

void fragment() {
	float shade = 0.75 + 0.25 * sin(UV.x * 26.0 * 0.65);
	ALBEDO = color * shade;
	ROUGHNESS = 1.0;
}
