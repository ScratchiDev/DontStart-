// Écran du moniteur : affiche le terminal (SubViewport) avec courbure du tube, lignes de balayage,
// lueur et léger scintillement. Non éclairé : c'est l'écran qui éclaire la pièce.
shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D screen : source_color, filter_linear;
uniform float brightness = 1.45;
uniform float curvature = 0.12;
uniform float power_on = 1.0;     // 0 = éteint (noir), 1 = allumé
uniform float glitch = 0.0;
uniform vec3 phosphor = vec3(0.36, 1.0, 0.42);

float rnd(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 uv = UV - 0.5;
	uv *= 1.0 + curvature * dot(uv, uv);
	uv += 0.5;
	uv.x += (rnd(vec2(floor(uv.y * 60.0), floor(TIME * 20.0))) - 0.5) * 0.03 * glitch;
	vec3 c = vec3(0.0);
	if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) {
		c = texture(screen, uv).rgb;
	}
	float scan = 0.78 + 0.22 * sin(uv.y * 480.0 * 3.14159);
	vec2 d = uv - 0.5;
	float vig = smoothstep(0.62, 0.18, dot(d, d) * 2.0);
	float flicker = 0.96 + 0.04 * sin(TIME * 60.0) + (rnd(vec2(TIME)) - 0.5) * 0.03;
	// fond du tube allumé : jamais complètement noir
	vec3 base = phosphor * 0.035;
	ALBEDO = (c * scan + base) * vig * flicker * brightness * power_on;
}
