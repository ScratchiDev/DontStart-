// Écran d'un appareil connecté (télé, téléphone, ordinateur, caméra…) que S.1.L.3.N.C.3. peut hanter :
// contenu normal (texte ou image dessiné dans un SubViewport), neige, bande qui défile, décrochage
// horizontal, visage qui apparaît à travers le bruit. Non éclairé : c'est l'écran qui éclaire.
shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D content : source_color, filter_linear;
uniform sampler2D face : source_color, filter_linear;
uniform bool has_content = false;
uniform bool has_face = false;
uniform float power = 1.0;         // 0 éteint, 1 allumé
uniform float noise = 0.0;         // neige (0..1)
uniform float face_amt = 0.0;      // visage (0..1)
uniform float roll = 0.0;          // bande sombre qui défile verticalement
uniform float tear = 0.0;          // décrochages horizontaux
uniform float brightness = 1.2;
uniform float curvature = 0.0;     // 0 écran plat ; 0.1 tube cathodique
uniform float scanlines = 0.0;     // 0..1
uniform vec2 res = vec2(320.0, 180.0);
uniform vec3 tint : source_color = vec3(0.82, 0.88, 1.0);
uniform vec3 idle : source_color = vec3(0.02, 0.025, 0.04);   // fond d'un écran allumé sans rien

float rnd(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 uv = UV - 0.5;
	uv *= 1.0 + curvature * dot(uv, uv);
	uv += 0.5;
	float t = TIME;
	float line = floor(uv.y * res.y);
	uv.x += (rnd(vec2(line, floor(t * 24.0))) - 0.5) * 0.06 * tear * step(0.6, rnd(vec2(floor(uv.y * 9.0), floor(t * 7.0))));
	vec3 c = idle;
	if (has_content) {
		c += texture(content, uv).rgb;
	}
	vec2 px = floor(uv * res);
	float n = rnd(px + vec2(floor(t * 30.0) * 17.0, 0.0));
	c = mix(c, vec3(n) * 0.9, clamp(noise, 0.0, 1.0));
	if (has_face) {
		// visage carré quel que soit le format de l'écran (télé large ou téléphone en hauteur)
		float asp = res.x / res.y;
		vec2 fuv = asp > 1.0 ? vec2((uv.x - 0.5) * asp + 0.5, uv.y) : vec2(uv.x, (uv.y - 0.5) / asp + 0.5);
		fuv.x += (rnd(vec2(line, floor(t * 12.0))) - 0.5) * 0.01 * noise;
		vec3 f = texture(face, fuv).rgb * step(0.0, fuv.x) * step(fuv.x, 1.0) * step(0.0, fuv.y) * step(fuv.y, 1.0);
		float lum = dot(f, vec3(0.3, 0.59, 0.11));
		float thr = rnd(px + floor(t * 15.0));
		float show = step(thr, face_amt * (0.35 + 0.9 * lum));
		// le visage « sculpte » la neige : ses creux (orbites, fond) l'assombrissent, ses reliefs l'éclairent
		c = mix(c, f * 1.5, face_amt * mix(0.6, 1.0, show));
	}
	float bar = smoothstep(0.0, 0.18, abs(fract(uv.y * 0.6 - t * 0.35) - 0.5));
	c *= mix(1.0, 0.45 + 0.55 * bar, roll);
	c *= mix(1.0, 0.75 + 0.25 * sin(uv.y * res.y * 3.14159), scanlines);
	vec2 d = uv - 0.5;
	float vig = smoothstep(0.75, 0.2, dot(d, d) * 2.0);
	float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
	float flicker = 0.97 + 0.03 * sin(t * 57.0);
	ALBEDO = c * tint * brightness * vig * flicker * power * inside;
}
